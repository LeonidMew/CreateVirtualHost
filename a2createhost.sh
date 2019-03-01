#!/bin/bash

webmaster="leonid"						# user who access web files. group is www-data
maindomain=".localhost"				# domain for creating subdomains, leading dot required
serveradmin="webmaster@localhost"		# admin email
webroot="/home/${webmaster}/Web/"		# root folder where subfolders for virtualhosts created
a2ensite="050-"								# short prefix for virtualhost config file
apachehost="/etc/apache2/sites-available/${a2ensite}"	# prefix for virtualhost config file
tmphost=$(mktemp)							# temp file for edit config
trap "rm $tmphost" EXIT				# rm temp file on exit

notify_user () {
	echo "$1" >&2
	# xmessage will run only once to show first error message
	[ -t 0 ] || if type -p notify-send >/dev/null; then notify-send "$1"; else xmessage -buttons Ok:0 -nearmouse "$1" -timeout 10; fi
}

if [ -t 0 ];then
	usegui=
else
	if ! type -p zenity >/dev/null;then
		notify_user "Use terminal or install zenity for gui. sudo apt install zenity"
		exit 1
	else
		usegui="yes"
	fi
fi

if [ "$(id -un)" == "root" ]
then
    notify_user "You should not run this script as root but as user going to edit web files."
    exit 1
fi

get_virtual_host() {
    if [ -t 0 ]; then
        read -p "Create virtualhost (= Folder name,case sensitive)" -r host
    else
        host=$(zenity --forms --add-entry=Name --text='Create virtualhost (= Folder name,case sensitive)')
    fi
    case "$host" in
        "")            echo "Bad input: empty" >&2;      exit 1 ;;
        *"*"*)         echo "Bad input: wildcard" >&2;   exit 1 ;;
        *[[:space:]]*) echo "Bad input: whitespace" >&2; exit 1 ;;
    esac
    echo "$host"
}

host=$(get_virtual_host)

hostfile="${apachehost}${host}.conf"    # apache virtualhost config file
dir="${webroot}${host}"                 # folder used as document root for virtualhost

# virtualhost template
cat >"$tmphost" <<EOF
<VirtualHost *:80>
    ServerAdmin $serveradmin
    DocumentRoot $dir
  	ServerName  ${host}${maindomain}
    ServerAlias ${host}${maindomain}
    <Directory "$dir">
        AllowOverride All
        Require local
    </Directory>
    # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
    # error, crit, alert, emerg.
    LogLevel error
</VirtualHost>
# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

if [ ! -z "$usegui" ];then
	# edit virtualhost config
	text=$(zenity --text-info --title="virtualhost config" --filename="$tmphost" --editable)
	if [ -z "$text" ]
	then
		# cancel button pressed
		exit 0
	fi
	echo "$text" > "$tmphost"
else
	# edit virtualhost config
	editor=${VISUAL:-$EDITOR}
	if [ -z "$editor" ];then
		if type -p nano >/dev/null;then editor="nano"; fi
	fi
	if [ -z "$editor" ];then
		if type -p vim >/dev/null;then editor="vim"; fi
	fi
	if [ -z "$editor" ];then
	    echo "edit '$tmphost' to your liking, then hit Enter"
	    read -p "I'll wait ... "
	else
	    "$editor" "$tmphost"
	fi
fi
# probably want some validating here that the user has not broken the config
# apache will not reload config if incorrect

getsuperuser () {
	if [ ! -z "$usegui" ];then
		echo "pkexec"
	else
		echo "sudo"
	fi
}

notify_user "execute root commands with $(getsuperuser) to create virtualhost"

$(getsuperuser) /bin/bash <<EOF
mkdir -p "$dir"
chown ${webmaster}:www-data "$dir"
chmod u=rwX,g=rX,o= "$dir"
cp "$tmphost" "$hostfile"
chown root:root "$hostfile"
chmod u=rw,g=r,o=r "$hostfile"
a2ensite "${a2ensite}${host}.conf"
systemctl reload apache2
EOF

notify_user "Virtualhost added. Apache2 reloaded."
