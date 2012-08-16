#!/bin/bash

cd ..
tar cvf - \
    flud/init.d-flud \
    flud/logrotate.d-flud \
    flud/flud \
    flud/flud.conf.save \
    flud/Makefile \
    | ssh pi@raspberrypi tar xvf -
