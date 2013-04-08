#!/usr/bin/perl

# Test application receive packets from JeeNode running dirtmon
# Presumes JeeLink is plugged into $PORT (see below)
# Run with "sudo perl test.pl"

use strict;
use Device::SerialPort;

my $PORT = '/dev/ttyUSB1';

my $ob = Device::SerialPort->new ($PORT) || die "Can't Open $PORT: $!";
$ob->baudrate(57600)   || die "failed setting baudrate";
$ob->parity("none")    || die "failed setting parity";
$ob->databits(8)       || die "failed setting databits";
$ob->handshake("none") || die "failed setting handshake";
$ob->write_settings    || die "no settings";
open(DEV, "+<$PORT")   || die "Cannot open $PORT: $_";

print DEV '1i 212g\n'; # node 1 in group 212

while (1) {
  while ($_ = <DEV>) {
    # print;

    # byte -> 0  1  2  3  4  5  6   7   8  9  10  11  12
    #         ====  ----------  - --- ---  -----  ------
    # eg   -> OK 2  2  0  0  0  2 115 117  0   0   0   0
    #  long ping;      // 32-bit counter
    #  byte id :7;     // identity, should be different for each node
    #  byte boost :1;  // whether compiled for boost chip or not
    #  byte vcc1;      // VCC before transmit, 1.0V = 0 .. 6.0V = 250
    #  byte vcc2;      // battery voltage (BOOST=1), or VCC after transmit (BOOST=0)
    #  word sensor;    // sensor1
    #  word sensor;    // sensor2

    if (/^OK 2/) {
        my @rec = split(' ', $_);
        my $ping  = $rec[2] + $rec[3] * 256 + $rec[4] * 256 * 256 + $rec[5] * 256 * 256 * 256;
        my $id    = $rec[6];
        my $vcc1  = $rec[7] / 250.0 * 5.0 + 1.0;
        my $vcc2  = $rec[8] / 250.0 * 5.0 + 1.0;
        my $sensor1 = $rec[9] + $rec[10] * 256;
        my $sensor2 = $rec[11] + $rec[12] * 256;
        print join (' ', $ping, $id, $vcc1, $vcc2, $sensor1, $sensor2), "\n";
        # system (q"spd-say --voice-type female2 ouch\!");
      }
  }
  sleep 1;
}
