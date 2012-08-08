#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Time::Local;
use HTTP::Tiny;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use threads;
use threads::shared;
use Thread::Semaphore;

my $SECS_PER_MIN  = 60;
my $SECS_PER_HOUR = 60 * 60;

my $WEATHER_UPDATE_INTERVAL  = (15 * 60 * 1000); # millis
my $CALENDAR_UPDATE_INTERVAL = ( 1 * 60 * 1000); # millis
my $STATUS_UPDATE_INTERVAL   =              500; # millis
my $TIME_SYNC_INTERVAL       = ( 5 * 60 * 1000); # millis

# Google calendar
my $GOOGLE_FEED     = "l3rruvhvf2ljvfhm1m4n61pm7g";
my $GOOGLE_PRIVATE  = "76afdddcfc61d8dcdfbc1fe408d4ee91";

# Weather underground
# http://api.wunderground.com/api/a9c5f7a00bf04843/forecast/q/94705.json
my $WUNDERGROUND_APIKEY = "a9c5f7a00bf04843";

# Cosm
my $COSM_FEED    = "43762";
my $COSM_APIKEY  = "hwn3eT8vkWjloTprSVXJ0G9d0RpEOynLTxn6LsGGpgg";


my $last_weather_check  = 0;
my $last_status_print   = 0;
my $last_calendar_check = 0;
my $last_time_sync      = 0;

my $semaphore = new Thread::Semaphore;
my $pop     :shared     = 0;
my $trigger :shared     = 0;
my $valveOn :shared     = 0;
my @valve   = ({name => "1", duration => 20},
                       {name => "2", duration => 20},
                       {name => "3", duration => 20},
                       {name => "4", duration => 20},
                       {name => "5", duration => 20},
                       {name => "6", duration => 20},
                       {name => "7", duration => 20},
                       {name => "8", duration => 20});

#static LiquidCrystal        lcd (8,9,4,5,6,7);

sub millis { return time * 1000; }

sub timestamp {
    my ($time) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    return sprintf ("%04d-%02d-%02dT%02d:%02d:%02dZ", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}


sub say {
    my ($message) = @_;
    print $message, "\n";
}


sub printStatus {
  my $current = time;
  if ($valveOn) {
      print sprintf ("v%d %02d:%02d\n",
                     $valveOn,
                     ($trigger - $current) / $SECS_PER_MIN,
                     ($trigger - $current) % $SECS_PER_MIN);
  }
  elsif ($trigger > $current) {
      print sprintf ("%d%% %02d:%02d\n", $pop,
                     ($trigger - $current) / $SECS_PER_MIN,
                     ($trigger - $current) % $SECS_PER_MIN);
  }
  else {
      print sprintf ("%d%%\n", $pop);
  }
  print timestamp(time), "\n";
  $last_status_print = millis();
}


sub putCosmData {
    my ($stream, $value) = @_;

    my $url = "http://api.cosm.com/v2/feeds/${COSM_FEED}";
    my $json = qq( { "version" : "1.0.0", "datastreams" : [ {"id" : "$stream", "current_value" : "$value"} ] } );
    my $response = HTTP::Tiny->new->request ('PUT', $url,
                                             {'headers' => {
                                                            "Host"         => "api.cosm.com",
                                                            'X-ApiKey'     => ${COSM_APIKEY},
                                                            'Content-Type' => 'application/json; charset=UTF-8',
                                                            'Accept'       => 'application/json'},
                                              'content' => $json});
    if ($response->{success}) {
        #print $response->{content};
    } else {
        warn "Cosm replied '", $response->{status}, "'\n";
        #print STDERR Dumper($response);
    }
}


sub checkWeather {
    say ("weather");
    my $url = "http://api.wunderground.com/api/${WUNDERGROUND_APIKEY}/forecast/q/94705.json";
    $_ = HTTP::Tiny->new->get(${url})->{content};
    if (/\"pop\":(\d+)/) {
        $pop = $1;
        putCosmData (0, $pop);
    }
    else {
        warn "error getting weather";
    }
    $last_weather_check = millis();
}


sub checkCalendar {
    say ("calendar");
    $semaphore->down;
    $trigger = 0;
    my $url = "http://www.google.com/calendar/feeds/${GOOGLE_FEED}\@group.calendar.google.com/private-${GOOGLE_PRIVATE}/full" .
              "?fields=entry(gd:when,title[text()='flud'])" .
              "&singleevents=true&prettyprint=true&max-results=1&orderby=starttime&sortorder=a&" .
              "&start-min=" . timestamp(time) .
              "&start-max=" . timestamp(time + $SECS_PER_HOUR);
    $_ = HTTP::Tiny->new->get($url);
    if (/startTime='(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.\d{3}([\+\-])(\d{2}):(\d{2})'/) {
        my ($year, $mon, $mday, $hour, $min, $sec, $zone_sign, $zone_hour, $zone_min) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
        $trigger = timegm ($sec,$min,$hour,$mday,$mon-1,$year-1900) -
                (($zone_sign eq '-' ? -1 : 1) * ($zone_hour * $SECS_PER_HOUR + $zone_min * $SECS_PER_MIN));
    }
    $semaphore->up;
    $last_calendar_check = millis();
}


sub commitValves {}


sub stopValves {
    $semaphore->down;
    putCosmData (1, $valveOn);
    $valveOn = 0;
    $trigger = 0;
    $semaphore->up;
    commitValves();
}


sub advanceValves {
    $semaphore->down;
    putCosmData (1, $valveOn);

    do {
        ++$valveOn;
    } while ($valveOn <= (scalar @valve) && !$valve[$valveOn-1]{duration});

    if ($valveOn > scalar @valve) {
        $valveOn = 0;
        $trigger = 0;
    }
    else {
        $trigger = time() + $valve[$valveOn-1]{duration} * $SECS_PER_MIN;
    }
    $semaphore->up;

    commitValves();
}


threads->create(\&run_webserver);
sub run_webserver {
    my $d = HTTP::Daemon->new(
                              ReuseAddr => 1,
                              LocalAddr => '127.0.0.1',
                              LocalPort => 8888,
                              Listen    => 20
                             ) || die;

    print "Web Server started!\n";
    print "Server Address: ", $d->sockhost(), "\n";
    print "Server Port: ",    $d->sockport(), "\n";

    while (my $c = $d->accept) {
        threads->create(\&process_one_req, $c)->detach();
    }
}


sub send_index {
    my ($client) = @_;
    my $response = HTTP::Response->new(200);
    $response->header("Content-Type" => "text/html");

    my $body = join ('',
                     "time = ", time, "<br>",
                     "pop = $pop<br>",
                     "Valves <form method='POST'>");
    for (my $ii = 0; $ii < scalar @valve; ++$ii) {
        $body .= "<input type='text' name='n$ii' value='$valve[$ii]{name}' />";
        $body .= "<input type='text' name='d$ii' value='$valve[$ii]{duration}' />";
        $body .= "\&lt;-- ON" if ($ii + 1 == $valveOn);
        $body .= "<br>";
    }
    $body .= "<input type='hidden' name='h' />";
    $body .= "<input type='submit' value='Submit' /></form>";
    $body .= "<form action='advance'><input type='submit' value='Advance' /></form>";
    $body .= "<form action='stop'><input type='submit' value='Stop' /></form>";

    $response->content($body);
    $client->send_response($response);
}


sub process_one_req {
    STDOUT->autoflush(1);
    my $client = shift;
    while (my $r = $client->get_request) {
        if ($r->method eq "GET") {
            if ($r->uri->path eq "/advance") {
                advanceValves();
            }
            elsif ($r->uri->path eq "/stop") {
                stopValves();
            }
            send_index ($client);
        }
        elsif ($r->method eq "POST") {
            my $content = $r->content;
            while ($content =~ s/n(\d+)=(.*?)&//) {
                $valve[$1]{name} = $2;
            }
            while ($content =~ s/d(\d+)=(\d+)&//) {
                $valve[$1]{duration} = $2;
            }
            send_index ($client);
        }
        else {
            $client->send_error(RC_FORBIDDEN);
        }
    }
    $client->close;
    undef($client);
}


say ("flud.");
do {
    if (0) {}
    elsif (!$valveOn && (!$last_weather_check  || (millis() - $last_weather_check > $WEATHER_UPDATE_INTERVAL))) {
        checkWeather();
    }
    elsif (!$valveOn && (!$last_calendar_check || (millis() - $last_calendar_check > $CALENDAR_UPDATE_INTERVAL))) {
        checkCalendar();
    }
    elsif ($trigger && $trigger < time) {
        advanceValves();
    }
    elsif (!$last_status_print || (millis() - $last_status_print > $STATUS_UPDATE_INTERVAL)) {
        printStatus();
    }
} while (1);


__END__
