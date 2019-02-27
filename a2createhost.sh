#!/bin/bash

WEBROOT="/home/leonid/Web/" # root folder where subfolders for virtualhosts created
APACHEHOST="/etc/apache2/sites-available/050-" # prefix for virtualhost config file
A2ENSITE="050-" # short prefix for virtualhost config file
TMPHOST="/tmp/a2host-" # tmp prefix for virtualhost config while editing or rejecting

if ((`which zenity|wc -w` == 0)) # check dependency
then
	echo "Error: zenity not installed."
	exit
fi

if [ "$USER" == "root" ]
then
	zenity --error --text="You should not run this script as root but as user going to edit web files."
	exit
fi

HOST=`zenity --forms --add-entry=Name --text='Create virtualhost (= Folder name,case sensitive)'`
words=$( wc -w <<<"$HOST" )

if (($words == "0" || $words > 1)) # this not check for fully qualified sub domain name. ".localhost" added
then
	zenity --error --text="More then one word for sub domain or empty"
	exit
fi

HOSTFILE="$APACHEHOST$HOST"
HOSTFILE=$HOSTFILE".conf"   # apache virtualhost config file
DIR="$WEBROOT$HOST"         # folder used as document root for virtualhost

# virtualhost template 
cat >$TMPHOST$HOST <<EOF
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot $DIR
	ServerName	$HOST.localhost
	ServerAlias	$HOST.localhost
	<Directory "$DIR">
		AllowOverride All
		Require local
	</Directory>
	# Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
	# error, crit, alert, emerg.
	LogLevel warn
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

# edit virtualhost config
TEXT=`zenity --text-info --filename=$TMPHOST$HOST --editable`
words=$( wc -w <<<"$TEXT" )
if (($words == 0))
then
	echo "Cancel"
	rm $TMPHOST$HOST
	exit
fi
echo "$TEXT" > $TMPHOST$HOST

A2ENSITE=$A2A2ENSITE$HOST".conf" # params for a2ensite

echo "execute root tools with pkexec to create virtualhost"
[ -d "$DIR" ] || mkdir -p "$DIR"
pkexec /bin/bash <<EOF
chgrp www-data "$DIR"
chmod u=rwX,g=rX,o= "$DIR"
mv $TMPHOST$HOST $HOSTFILE
chown root:root $HOSTFILE
chmod u=rw,g=r,o=r $HOSTFILE
a2ensite $A2ENSITE
EOF
