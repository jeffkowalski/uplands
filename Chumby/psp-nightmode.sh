#!/bin/sh
echo '<event type="NightMode" value="on" comment=""/>' > /tmp/flashplayer.event
/usr/bin/chumbyflashplayer.x -F1
chmod 755 /psp/nightmode.sh
