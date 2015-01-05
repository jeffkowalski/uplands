REMOTE_MACHINE=flud
REMOTE_USER=pi

all:

.PHONY: install uninstall remote-install remote-uninstall ruby-gems

install: ruby-gems
	-service flud stop
	cp flud /usr/sbin
	chmod 0755 /usr/sbin/flud
	cp logrotate.d-flud /etc/logrotate.d/flud
	chmod 0644 /etc/logrotate.d/flud
	cp init.d-flud /etc/init.d/flud
	chmod 0755 /etc/init.d/flud
	-cp flud.yml /etc/flud.yml
	-chmod 0644 /etc/flud.yml
	-cp ~${REMOTE_USER}/.google-api.yaml /etc/google-api.yaml
	-chmod 0600 /etc/google-api.yaml
	insserv --verbose flud
	service flud start

uninstall:
	-service flud stop
	-insserv --verbose --remove flud
	-rm -f /etc/init.d/flud
	-rm -f /etc/logrotate.d/flud
	-rm -f /usr/sbin/flud
#	-rm -f /etc/flud.yml
	-rm -f /var/log/flud.log*
	-rm -f /var/run/flud.pid

remote-install:
	( cd .. ; \
	  tar cvf - \
	    flud/init.d-flud \
	    flud/logrotate.d-flud \
	    flud/flud \
	    flud/Makefile \
            `test -f flud/flud.yml && echo flud/flud.yml` \
	  | ssh $(REMOTE_USER)@$(REMOTE_MACHINE) tar xvf - )
	ssh $(REMOTE_USER)@$(REMOTE_MACHINE) "cd ~/flud; sudo make install"

remote-uninstall:
	ssh $(REMOTE_USER)@$(REMOTE_MACHINE) "cd ~/flud; sudo make uninstall"

#
# The following targets satisfy dependencies of flud, which may
# typically already exist on the system.  If not, they'll be
# permanently installed, and won't be removed when the uninstall target
# above is made.
#

#RUBYGEMS = fileutils google-api-client logger serialport webrick wiringpi wunderground xively-rb yaml
RUBYGEMS = fileutils logger serialport webrick wiringpi wunderground xively-rb yaml

/usr/lib/ruby/1.9.1/mkmf.rb:
	apt-get --assume-yes install ruby1.9.1-dev

define RUBYGEM_template
ifneq ($(shell ruby -e "begin ; require '$(1)'; rescue Exception; exit; end; puts 'found'"),found)
ruby-gems:: /usr/lib/ruby/1.9.1/mkmf.rb
ruby-gems:: $(subst ::,-,$(1))
$(subst ::,-,$(1)) ::
	gem install -V $(1)
endif
endef

$(foreach module,$(RUBYGEMS),$(eval $(call RUBYGEM_template,$(module))))
