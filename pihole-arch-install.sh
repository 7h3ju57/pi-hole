#! /bin/bash

PISRC="https://github.com/7h3ju57/pi-hole.git"
GUISRC="https://github.com/7h3ju57/AdminLTE.git"
APP=pihole
WEBAPP=AdminLTE
WebRoot=/srv/http
PIDIRSRC="/usr/share/webapps/pihole"
GUIDIRSRC="${WebRoot}/AdminLTE"
SRCDIR=/etc/.pihole
depends="dnsmasq lighttpd php-cgi bc figlet git"
pibin=/usr/bin/$APP
PILOG=/run/log/$APP
WEBUSER=http

check4root() {

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
}


INSTALL() {
	if [ ! -e $PIDIRSRC ]; then
		mkdir -p $PIDIRSRC
	fi
	if [ ! -e $GUIDIRSRC ]; then
		mkdir -p $GUIDIRSRC
	fi
	if [ ! -e $SRCDIR ]; then
		mkdir -p $SRCDIR
	fi
	for i in $depends 
	    do
		    if ! $(pacman -Q --quiet "$i")
		    then
			    pacman -S --noconfirm "$i"
		    fi
	    done
	#Change to Source Sirectory
	cd "$SRCDIR" || return 1
	#clone repos
	git clone "$PISRC" $APP
	git clone "$GUISRC"
	
	#Install to final destination
	grep -q "#piholed" /etc/dnsmasq.conf
	if [ $? != 0 ]; then cp /etc/dnsdmasq.conf $PIDIRSRC/; fi
	cp ./advanced/01-pihole.conf /etc/dnsmasq.conf && echo "#piholed" >> /etc/dnsmasq.conf
	cp ./advanced/lighttpd.conf /etc/lighttpd/lighttpd.conf
	rsync -ru $APP/advanced/Scripts/ $PIDIRSRC/
	rsync -u $APP/adlist.default $PIDIRSRC/
	rsync -ru $WEBAPP/ $GUIDIRSRC/
	rsync -u pihole $pibin
	rsync -u ./gravity.sh $PIDIRSRC/
	rsync -r {$APP-gravity,$APP-logtruncate}.timer /usr/lib/systemd/system/
	rsync -r {$APP-gravity,$APP-logtruncate}.service /usr/lib/systemd/system/
	mkdir -p $PILOG
	mkdir -p /usr/lib/systemd/system/multi-user.target.wants
	touch $PILOG/$APP.log
	touch $PIDIRSRC/{blacklist,whitelist}.txt
	ln -s /usr/lib/systemd/system/$APP-gravity.timer "/usr/lib/systemd/system/multi-user.target.wants/$APP-gravity.timer"
    ln -s /usr/lib/systemd/system/$APP-logtruncate.timer "/usr/lib/systemd/system/multi-user.target.wants/$APP-logtruncate.timer"
}

PERMS() {
	
	chmod 644 /usr/lib/systemd/system/{$APP-gravity,$APP-logtruncate}.timer
	chmod 644 /usr/lib/systemd/system/{$APP-gravity,$APP-logtruncate}.service
	chmod 0755 $PILOG
	chmod 0644 $PILOG/$APP.log
	chmod -R 755 $PIDIRSRC
	chmod -R 755 $GUIDIRSRC
	chown -R $WEBUSER:$WEBUSER $GUIDIRSRC
}

StartServices() {
	systemctl enable dnsmasq 
	systemctl enable lighttpd
	systemctl start dnsmasq
	systemctl start lighttpd
}
  
  
  ARCHIFY() {
  	if [ -d $PIDIRSRC ]; then
  sed -i 's/$SUDO service dnsmasq start/$SUDO systemctl start dnsmasq/' "$PIDIRSRC"/gravity.sh
  sed -i 's/$SUDO service dnsmasq start/$SUDO systemctl start dnsmasq/' "$PIDIRSRC"/blacklist.sh
  sed -i 's/$SUDO service dnsmasq start/$SUDO systemctl start dnsmasq/' "$PIDIRSRC"/whitelist.sh
  sed -i "s|/var/log/pihole.log|$PILOG/$APP.log|" "$PIDIRSRC"/piholeLogFlush.log
  sed -i "s|'piholeDir=/etc/$basename'|$PIDIRSRC|" $PIDIRSRC/gravity.sh
  sed -i "s|'piholeDir=/etc/$basename'|$PIDIRSRC|" $PIDIRSRC/blacklist.sh
  sed -i "s|'piholeDir=/etc/$basename'|$PIDIRSRC|" $PIDIRSRC/whitelist.sh
  sed -i "s|/etc/pihole|$PIDIRSRC|" "$PIDIRSRC"/blacklist.sh
  sed -i "s|/etc/pihole|$PIDIRSRC|" "$PIDIRSRC"/whitelist.sh
  sed -i "s|/etc/pihole|$PIDIRSRC|" "$PIDIRSRC"/gravity.sh

   # change log location in admin php interface and scripts
  sed -i 's|/var/log/pihole.log|/run/log/pihole/pihole.log|' $PIDIRSRC/chronometer.sh

  # original toilet is in aur, enter figlet
  sed -i 's|		toilet -f small -F gay Pi-hole|		figlet Pi-hole|' $PIDIRSRC/chronometer.sh

  # little arch changes to chronometer.sh
  sed -i "/figlet Pi-hole/a NICDEV=$\(ip route get 8.8.8.8 | awk '{for\(i=1;i<=NF;i++\)if\(\$\i~/dev/\)print $\(i+1\)}'\)" /usr/bin/chronometer.sh
  sed -i 's|$(ifconfig eth0 \||$(ifconfig $NICDEV \||' $PIDIRSRC/chronometer.sh
  sed -i 's|/inet addr/|/inet /|' $PIDIRSRC/chronometer.sh
  
  sed -i "s|piholeDir=/etc/$basename|$PIDIRSRC|" $PIDIRSRC/chronometer.sh 
  fi
  
  if [ -d $GUIDIRSRC ]; then
   # change bin location in admin php interface
  sed -i 's|/usr/local/bin/|/usr/bin/|' "$GUIDIRSRC"/index.php
  sed -i 's|/usr/local/bin/|/usr/bin/|' "$GUIDIRSRC"/api.php
  

  # change log location in admin php interface
  sed -i "s|/var/log/pihole.log|$PILOG/$APP.log|" "$GUIDIRSRC"/data.php
  sed -i "s|/etc/pihole|$PIDIRSRC|" "$GUIDIRSRC"/data.php
  sed -i "s|/etc/.pihole|$SRCDIR/$APP|" "$GUIDIRSRC"/footer.php
  sed -i "s|/var/www/html|$SRCDIR/$WEBAPP|" "$GUIDIRSRC"/data.php
  fi
  
 # Changes to DNSMASQ.conf
  sed -i 's|@DNS1@|8.8.8.8|' /etc/dnsmasq.conf
  sed -i 's|@DNS2@|8.8.4.4|' /etc/dnsmasq.conf
  sed -i 's|listen-adress.*|listen-address=127.0.0.1,$(hostname --ip-address | cut -d" " -f3)|' /etc/dnsmasq.conf
  sed -i 's|interface=@INT@|#interface=@INT@|' /etc/dnsmasq.conf
 
  #Changes to pihole
  sed -i "s|/opt/pihole|$PIDIRSRC|" $pibin
  
  #changes lighttp
  sed -i "s|/var/www/html|$WebRoot|" /etc/lighttpd/lighttpd.conf
  sed -i "s|www-data|$WEBUSER|" /etc/lighttpd/lighttpd.conf

}

check4root
INSTALL
ARCHIFY
PERMS


