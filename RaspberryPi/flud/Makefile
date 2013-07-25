REMOTE_MACHINE=flud
REMOTE_USER=pi

all:

.PHONY: install uninstall remote-install remote-uninstall perl-modules

install: perl-modules
	-service flud stop
	cp flud /usr/sbin
	chmod 0755 /usr/sbin/flud
	cp logrotate.d-flud /etc/logrotate.d/flud
	chmod 0644 /etc/logrotate.d/flud
	cp init.d-flud /etc/init.d/flud
	chmod 0755 /etc/init.d/flud
	-cp flud.conf /etc/flud.conf
	-chmod 0644 /etc/flud.conf
	insserv --verbose flud
	service flud start

uninstall:
	-service flud stop
	insserv --verbose --remove flud
	-rm -f /etc/init.d/flud
	-rm -f /etc/logrotate.d/flud
	-rm -f /usr/sbin/flud
#	-rm -f /etc/flud.conf
	-rm -f /var/log/flud.log*
	-rm -f /var/run/flud.pid

remote-install:
	( cd .. ; \
	  tar cvf - \
	    flud/init.d-flud \
	    flud/logrotate.d-flud \
	    flud/flud \
	    flud/Makefile \
            `test -f flud/flud.conf && echo flud/flud.conf` \
	  | ssh $(REMOTE_USER)@$(REMOTE_MACHINE) tar xvf - )
	ssh $(REMOTE_USER)@$(REMOTE_MACHINE) "cd ~/flud; sudo make install"

remote-uninstall:
	ssh $(REMOTE_USER)@$(REMOTE_MACHINE) "cd ~/flud; sudo make uninstall"

#
# The following targets satisfy dependencies of flud, which may
# typically already exist on the system.  If not, they'll be
# permanently installed, and won't be removed when the uninstall target
# above is made.
# These include the common programs 'curl' and 'cpanm', several common
# perl modules as well as the Broadcom BMC2835 library.
#

curl ::
ifeq ($(shell which curl),)
curl ::
	apt-get install curl
endif

cpanm :: curl
ifeq ($(shell which cpanm),)
cpanm ::
	apt-get install cpanminus
endif

gcc-4.7 ::
ifeq ($(shell which gcc-4.7),)
gcc-4.7 ::
	apt-get install gcc-4.7
endif


/usr/local/lib/libbcm2835.a : | curl
	echo install Broadcom BCM 2835 chip library
	( cd /tmp ; \
	curl -L http://www.airspayce.com/mikem/bcm2835/bcm2835-1.25.tar.gz | \
	tar zxvf - && \
	cd bcm2835-1.25 ; \
	machine=`uname -m` ; \
	if [ "$machine" = "armv6l" ] ; then ./configure; else ./configure CFLAGS=-fPIC ; fi ; \
	make clean ; \
	make ; \
	make check ; \
	make install ; \
	cd /tmp; \
	rm -rf bcm2835-1.25 ; \
	)

Device-BCM2835:: /usr/local/lib/libbcm2835.a

HTTP-Daemon::    gcc-4.7

PERLMODULES = HTTP::Daemon Proc::PID::File Log::Log4perl Device::BCM2835 Device::SerialPort Proc::Daemon HTML::Entities JSON::Any

define PERLMODULE_template
ifneq ($(shell perl -e "eval q{use $(1); 1;} && print q(found)"),found)
perl-modules:: cpanm
perl-modules:: $(subst ::,-,$(1))
$(subst ::,-,$(1)) ::
	cpanm $(1)
endif
endef

$(foreach module,$(PERLMODULES),$(eval $(call PERLMODULE_template,$(module))))
