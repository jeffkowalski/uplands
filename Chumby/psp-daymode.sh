#!/bin/sh
echo '<event type="NightMode" value="off" comment=""/>' > /tmp/flashplayer.event
/usr/bin/chumbyflashplayer.x -F1
chmod 755 /psp/daymode.sh
