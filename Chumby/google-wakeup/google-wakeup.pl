#!/usr/bin/perl
BEGIN {
    our $directory = $0;
    $directory =~ s|/[^/]*$||;
    push @INC, $directory;
}
#use strict;
#use Data::Dumper;
#use LWP::Simple;
use BDXML;

require "credentials.pl";

my $alarm_file = "/psp/alarms";

main();

sub main {
    my $alarms = read_alarm_file($alarm_file);
    my $new_alarms = [];
    push @$new_alarms, shift(@$alarms);
    my $google_alarm = read_calendar();
    push @$new_alarms, $google_alarm if ($google_alarm);
    for my $alarm (@$alarms) {
        next if $alarm->{'properties'}->{'name'} =~ /Google Wakeup/i;
        push @$new_alarms, $alarm;
    }
    #print Dumper $new_alarms;

    save_alarm_file($new_alarms, $alarm_file);
}


sub read_calendar {
    my ($junk1, $junk2, $junk3, $day, $month, $year) = localtime(time);
    my $date = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $day);

    # see http://code.google.com/apis/gdata/docs/2.0/reference.html#PartialResponse
    # see http://code.google.com/apis/calendar/data/2.0/reference.html#Calendar_feeds
    my $url = qq|https://www.google.com/calendar/feeds/${google_feed}\@group.calendar.google.com/private-${google_private}/full?fields=entry(gd:when,title[text()="wakeup"])&singleevents=true&prettyprint=true&max-results=30&orderby=starttime&sortorder=a&start-min=${date}T00:00:00.000-08:00&start-max=${date}T23:59:59.000-08:00|;
    my $content = `curl --silent --insecure --globoff '$url'`;
    my $alarm = undef;
    if ($content =~ /<gd:when.*startTime='.*?T(\d{2}):(\d{2}):.*?'/m) {
        $alarm = {
          'value' => undef,
          'name' => 'alarm',
          'id' => undef,
          'children' => [],
          'children_hash' => {},
          'properties' => {
            'when' => 'daily',
            'action_param' => 'E8D1B6C0-0FB0-11DF-8AED-001E681DF646',
            'time' => $1*60+$2,
            'arg' => 'directurl',
            'name' => sprintf ("Google Wakeup %02d:%02d", $1, $2),
            'duration' => '60',
            'backupDelay' => '5',
            'auto_dismiss' => '0',
            'snooze' => '10',
            'action' => 'profile',
            'type' => 'audio',
            'backup' => '1',
            'param' => '&lt;stream url=&quot;http://www.kqed.org/listen/live/mp3/kqedradio.pls&quot; id=&quot;0001&quot; mimetype=&quot;audio/x-scpls&quot; name=&quot;KQED Radio&quot; /&gt;',
            'enabled' => '1',
            'param_description' => 'My Streams: KQED Radio'
           }
        };
    }
#    print Dumper $alarm;

    return $alarm;
}


sub read_alarm_file {
    my ($file) = @_;

    # Slurp the alarm file.
    my $text;
    {
        local( $/, *FH ) ;
        open( FH, $file ) or die("Unable to open alarm file: $!");
        $text = <FH>
    }
    my $alarms = BDXML::parse($text);

    # Ensure the file has a root tag that we recognize.
    if( !defined($alarms) || $$alarms{'name'} ne "alarms" ) {
        warn("Root <alarms> tag not found\n");
        return;
    }

    my $i=0;
    $alarms = $$alarms{'children'};
    for my $alarm(@$alarms) {
        $$alarm{'id'} = $i++;
    }

    return $alarms;
}


sub save_alarm_file {
    my ($alarms, $file) = @_;

    open(my $fh, '>', $file) || die("Unable to open alarm file for writing: $!\n");
    print $fh BDXML::unparse({
            name        => 'alarms',
            children    => $alarms,
        });
    close($fh);

    # Force flashplayer to reload the alarm file.
    open($fh, '>', '/tmp/flashplayer.event')
        or die("Couldn't open FP event file: $!\n");
    print $fh "<event type=\"AlarmPlayer\" value=\"reload\" comment=\"/psp/alarms\"/>\n";
    close($fh);

    # Issue the "Read flashplayer.event" command.  Redirect to /dev/null to
    # ignore the flashplayer's greeting banner.
    system("chumbyflashplayer.x -F1 > /dev/null 2> /dev/null");
}


__END__

/psp/alarms

<alarms>
  <alarm name="" backupDelay="5" backup="1" action_param="" action="" auto_dismiss="0" param_description="Gong" param="" arg="Gong" type="beep" duration="30" snooze="5" enabled="0" time="525" when="daily" />
  <alarm name="Weekdays at 6:30 am" backupDelay="5" backup="1" action_param="E8D1B6C0-0FB0-11DF-8AED-001E681DF646" action="profile" auto_dismiss="0" param_description="My Streams: KQED Radio" param="&lt;stream url=&quot;http://www.kqed.org/listen/live/mp3/kqedradio.pls&quot; id=&quot;0001&quot; mimetype=&quot;audio/x-scpls&quot; name=&quot;KQED Radio&quot; /&gt;" arg="directurl" type="audio" duration="60" snooze="10" enabled="0" time="390" when="weekday" />
  <alarm name="Weekdays at 7:00 am" backupDelay="5" backup="1" action_param="E8D1B6C0-0FB0-11DF-8AED-001E681DF646" action="profile" auto_dismiss="0" param_description="My Streams: KQED Radio" param="&lt;stream url=&quot;http://www.kqed.org/listen/live/mp3/kqedradio.pls&quot; id=&quot;0001&quot; mimetype=&quot;audio/x-scpls&quot; name=&quot;KQED Radio&quot; /&gt;" arg="directurl" type="audio" duration="60" snooze="10" enabled="0" time="420" when="weekday" />
  <alarm name="Weekdays at 7:30 am" backupDelay="5" backup="1" action_param="E8D1B6C0-0FB0-11DF-8AED-001E681DF646" action="profile" auto_dismiss="0" param_description="My Streams: KQED Radio" param="&lt;stream url=&quot;http://www.kqed.org/listen/live/mp3/kqedradio.pls&quot; id=&quot;0001&quot; mimetype=&quot;audio/x-scpls&quot; name=&quot;KQED Radio&quot; /&gt;" arg="directurl" type="audio" duration="60" snooze="10" enabled="0" time="450" when="weekday" />
  <alarm name="Weekdays at 8:00 am" backupDelay="5" backup="1" action_param="E8D1B6C0-0FB0-11DF-8AED-001E681DF646" action="profile" auto_dismiss="0" param_description="My Streams: KQED Radio" param="&lt;stream url=&quot;http://www.kqed.org/listen/live/mp3/kqedradio.pls&quot; id=&quot;0001&quot; mimetype=&quot;audio/x-scpls&quot; name=&quot;KQED Radio&quot; /&gt;" arg="directurl" type="audio" duration="60" snooze="10" enabled="0" time="480" when="weekday" />
  <alarm name="Weekdays at 8:30 am" backupDelay="5" backup="1" action_param="E8D1B6C0-0FB0-11DF-8AED-001E681DF646" action="profile" auto_dismiss="0" param_description="My Streams: KQED Radio" param="&lt;stream url=&quot;http://www.kqed.org/listen/live/mp3/kqedradio.pls&quot; id=&quot;0001&quot; mimetype=&quot;audio/x-scpls&quot; name=&quot;KQED Radio&quot; /&gt;" arg="directurl" type="audio" duration="60" snooze="10" enabled="1" time="510" when="weekday" />
</alarms>
