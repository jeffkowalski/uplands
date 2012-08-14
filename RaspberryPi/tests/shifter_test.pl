#!/usr/bin/perl
use strict;
use warnings;

use Device::BCM2835;


# Connect the shift register pins to these GPIO pins.
my $shift_pin = &Device::BCM2835::RPI_GPIO_P1_11; # -> SH_CP 11 (shift clock)
my $store_pin = &Device::BCM2835::RPI_GPIO_P1_13; # -> ST_CP 12 (storage clock)
my $data_pin  = &Device::BCM2835::RPI_GPIO_P1_15; # -> DS    14 (data in)
# connect rPi 2 5v  to VCC 16
# connect rPi 6 GND to GND  8
# connect rPi 6 GND to ~OE 13 (output enable, active low) to ground


# call set_debug(1) to do a non-destructive test on non-RPi hardware
#Device::BCM2835::set_debug(1);
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

local $|=1;
my $value = 0;
while (1) {
    print "$value";
    Device::BCM2835::gpio_write ($store_pin, 0);
    for (my $bit = 1<<7; $bit > 0; $bit >>= 1) {
        Device::BCM2835::gpio_write ($shift_pin, 0);
        Device::BCM2835::gpio_write ($data_pin, $value & $bit ? 1 : 0);
        Device::BCM2835::gpio_write ($shift_pin, 1);
    }
    Device::BCM2835::gpio_write ($store_pin, 1);
    print ".\n";
    ++$value;

    Device::BCM2835::delay(500); # Milliseconds
}
