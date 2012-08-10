#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Time::Local;
use HTTP::Tiny;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use HTML::Entities;
use threads;
use threads::shared;
use Thread::Semaphore;
use Device::BCM2835;
use POSIX qw(uname);

my $SECS_PER_MIN  = 60;
my $SECS_PER_HOUR = 60 * 60;

my $WEATHER_UPDATE_INTERVAL  = (15 * 60 * 1000); # millis
my $CALENDAR_UPDATE_INTERVAL = ( 1 * 60 * 1000); # millis
my $STATUS_UPDATE_INTERVAL   =              500; # millis
my $TIME_SYNC_INTERVAL       = ( 5 * 60 * 1000); # millis

use vars qw/$GOOGLE_FEED
            $GOOGLE_PRIVATE
            $WUNDERGROUND_APIKEY
            $COSM_FEED
            $COSM_APIKEY/;
require 'credentials.pl' || die;

my $last_weather_check  = 0;
my $last_status_print   = 0;
my $last_calendar_check = 0;
my $last_time_sync      = 0;

my $semaphore = new Thread::Semaphore;
my $pop     :shared     = 0;
my $trigger :shared     = 0;
my $valveOn :shared     = 0;  # 1-based; 0 means "all off"
my $valve_specs :shared = &share([]);
{
    for (my $ii = 1; $ii <= 8; ++$ii) {
        my $valve_spec = &share({});
        $valve_spec->{name}     = "$ii";
        $valve_spec->{duration} = 20;
        push @$valve_specs, $valve_spec;
    }
}

# Connect the shift register pins to these GPIO pins.
my $shift_pin = &Device::BCM2835::RPI_GPIO_P1_11; # -> SH_CP 11 (shift clock)
my $store_pin = &Device::BCM2835::RPI_GPIO_P1_13; # -> ST_CP 12 (storage clock)
my $data_pin  = &Device::BCM2835::RPI_GPIO_P1_15; # -> DS    14 (data in)
# connect rPi 2 5v  to VCC 16
# connect rPi 6 GND to GND  8
# connect rPi 6 GND to ~OE 13 (output enable, active low) to ground


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
        my ($year, $mon, $mday, $hour, $min, $sec, $zone_sign, $zone_hour, $zone_min) =
                ($1, $2, $3, $4, $5, $6, $7, $8, $9);
        $trigger = timegm ($sec, $min, $hour, $mday, $mon-1, $year-1900) -
                (($zone_sign eq '-' ? -1 : 1) * ($zone_hour * $SECS_PER_HOUR + $zone_min * $SECS_PER_MIN));
    }
    $semaphore->up;
    $last_calendar_check = millis();
}


sub initValves {
    # call set_debug(1) to do a non-destructive test on non-RPi hardware
    my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();
    Device::BCM2835::set_debug($machine ne 'armv6l');
    Device::BCM2835::init()
              || die "Could not init library";

    Device::BCM2835::gpio_fsel ($data_pin,
                                &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
    Device::BCM2835::gpio_fsel ($shift_pin,
                                &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
    Device::BCM2835::gpio_fsel ($store_pin,
                                &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);

    Device::BCM2835::gpio_write ($data_pin,  0);
    Device::BCM2835::gpio_write ($shift_pin, 0);
    Device::BCM2835::gpio_write ($store_pin, 0);
}


sub commitValves {
    print "latch lo\n";
    Device::BCM2835::gpio_write ($store_pin, 0);
    for (my $ii = 8; $ii > 0; --$ii) {
        print "shift lo\n";
        Device::BCM2835::gpio_write ($shift_pin, 0);
        print "data ", $valveOn == $ii ? "hi" : "lo", "\n";
        Device::BCM2835::gpio_write ($data_pin, $valveOn == $ii ? 1 : 0);
        print "shift hi\n";
        Device::BCM2835::gpio_write ($shift_pin, 1);
    }
    print "latch hi\n";
    Device::BCM2835::gpio_write ($store_pin, 1);
    putCosmData (1, $valveOn);
}


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
    } while ($valveOn <= (scalar @$valve_specs) && !$valve_specs->[$valveOn-1]->{duration});

    if ($valveOn > scalar @$valve_specs) {
        $valveOn = 0;
        $trigger = 0;
    }
    else {
        $trigger = time() + $valve_specs->[$valveOn-1]->{duration} * $SECS_PER_MIN;
    }
    $semaphore->up;

    commitValves();
}


sub run_webserver {
    my $sock = IO::Socket::INET->new (PeerAddr => "example.com",
                                      PeerPort => 80,
                                      Proto    => "tcp");
    my $localip = $sock->sockhost;
    my $d = HTTP::Daemon->new (ReuseAddr => 1,
                               LocalAddr => $localip,
                               LocalPort => 8888,
                               Listen    => 20) || die;

    print "Web Server started!\n";
    print "Server Address: ", $d->sockhost(), "\n";
    print "Server Port: ",    $d->sockport(), "\n";

    while (my $c = $d->accept) {
        threads->create (\&process_one_req, $c)->detach();
    }
}


sub send_index {
    my ($client) = @_;
    my $response = HTTP::Response->new(200);
    $response->header ("Content-Type" => "text/html");

    my $body = join ('',
                     "time = ", time, "<br>",
                     "pop = $pop<br>",
                     "Valves <form method='POST'>");
    for (my $ii = 0; $ii < scalar @$valve_specs; ++$ii) {
        $body .= "<input type='text' name='n$ii' value='" . encode_entities($valve_specs->[$ii]->{name}) . "' />";
        $body .= "<input type='text' name='d$ii' value='$valve_specs->[$ii]->{duration}' />";
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
                my ($index, $name) = ($1, $2);
                $name =~ s/\+/ /g;
                $name =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
                $valve_specs->[$index]->{name} = $name;
            }
            while ($content =~ s/d(\d+)=(\d+)&//) {
                $valve_specs->[$1]->{duration} = int ($2);
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
initValves();
commitValves();

threads->create(\&run_webserver);

# FIXME: don't spin
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
