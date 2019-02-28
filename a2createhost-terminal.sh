#!/bin/bash

webroot="/home/leonid/Web/" # root folder where subfolders for virtualhosts created
apachehost="/etc/apache2/sites-available/050-" # prefix for virtualhost config file
a2ensite="050-"             # short prefix for virtualhost config file
tmphost=$(mktemp)
trap "rm $tmphost" EXIT

if [ "$USER" == "root" ]
then
    echo "You should not run this script as root but as user going to edit web files." >&2
    exit 1
fi

read -p"Create virtualhost (= Folder name,case sensitive)" -r host
case "$host" in
    "")            echo "Bad input: empty" >&2;      exit 1 ;;
    *"*"*)         echo "Bad input: wildcard" >&2;   exit 1 ;;
    *[[:space:]]*) echo "Bad input: whitespace" >&2; exit 1 ;;
esac

# braces only for readability
hostfile="${apachehost}${host}.conf"    # apache virtualhost config file
dir="${webroot}${host}"                 # folder used as document root for virtualhost

# virtualhost template
cat >"$tmphost" <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $dir
    ServerName  $host.localhost
    ServerAlias $host.localhost
    <Directory "$dir">
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
editor=${VISUAL:-$EDITOR}
if [ -z "$editor" ]
then
    echo "edit '$tmphost' to your liking, then hit Enter"
    read -p "I'll wait ... "
else
    "$editor" "$tmphost"
fi
# probably want some validating here that the user has not broken the config

echo "execute root tools with pkexec to create virtualhost"
mkdir -p "$dir"

pkexec /bin/bash <<EOF
chgrp www-data "$dir"
chmod u=rwX,g=rX,o= "$dir"
mv "$tmphost" "$hostfile"
chown root:root "$hostfile"
chmod u=rw,g=r,o=r "$hostfile"
a2ensite "${a2ensite}${host}.conf"
EOF