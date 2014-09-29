all:

.PHONY: install uninstall

install: timekpr-web timekpr-web.conf
	-service timekpr-web stop
	cp timekpr-web /usr/sbin
	chmod 0755 /usr/sbin/timekpr-web
	cp timekpr-web.conf /etc/init/timekpr-web.conf
	chmod 0644 /etc/init/timekpr-web.conf
	start timekpr-web

uninstall:
	-stop timekpr-web
	-rm -f /etc/init/timekpr-web.conf
	-rm -f /usr/sbin/timekpr-web
	-rm -f /var/log/timekpr-web.log*
	-rm -f /var/run/timekpr-web.pid
