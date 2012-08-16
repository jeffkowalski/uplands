#!/bin/sh

# install CPAN minus
apt-get install curl gcc-4.7
curl -L http://cpanmin.us | perl - --sudo App::cpanminus

# install Broadcom BCM 2835 chip library
pushd /tmp
curl -OL http://www.open.com.au/mikem/bcm2835/bcm2835-1.6.tar.gz
tar zxvf bcm2835-1.6.tar.gz
cd bcm2835-1.6
machine=`uname -m`
if [ "$machine" = "armv6l" ] ; then
    ./configure
else
    ./configure CFLAGS=-fPIC
fi
make clean
make
make check
make install
popd

# install perl module dependencies
cpanm HTTP::Daemon
cpanm Proc::PID::File
cpanm Log::Log4perl
cpanm Device::BCM2835
