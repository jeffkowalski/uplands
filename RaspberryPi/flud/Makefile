all:

.PHONY: install uninstall

install:
	cp init.d-flud /etc/init.d/flud
	cp flud /usr/sbin
	touch /var/log/flud.log
	sudo chmod 640 /var/log/flud.log
	sudo chown root:adm /var/log/flud.log
	update-rc.d flud defaults 99

uninstall:
	update-rc.d -f flud remove
	rm -f /etc/init.d/flud
	rm -f /usr/sbin/flud
	rm -f /etc/flud.conf
	rm -f /var/log/flud.log
	rm -f /var/run/flud.pid
