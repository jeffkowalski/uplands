#!/bin/bash

cd ..
tar cvf - \
    flud/flud.pl \
    flud/get_perl_dependencies.sh \
    | ssh pi@raspberrypi tar xvf -
