all:

.PHONY: install uninstall

install:
	cp flud /usr/sbin
	cp logrotate.d-flud /etc/logrotate.d/flud
	cp init.d-flud /etc/init.d/flud
	update-rc.d flud defaults 99

uninstall:
	update-rc.d -f flud remove
	rm -f /etc/init.d/flud
	rm -f /etc/logrotate.d/flud
	rm -f /usr/sbin/flud
	rm -f /etc/flud.conf
	rm -f /var/log/flud.log*
	rm -f /var/run/flud.pid
