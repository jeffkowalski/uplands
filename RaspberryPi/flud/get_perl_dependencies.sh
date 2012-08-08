#!/bin/sh
sudo apt-get install curl gcc-4.7
sudo curl -L http://cpanmin.us | perl - --sudo App::cpanminus
sudo cpanm HTTP::Daemon
