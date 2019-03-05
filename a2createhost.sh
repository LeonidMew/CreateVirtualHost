#!/bin/bash

webmaster="leonid"						# user who access web files. group is www-data
maindomain=".localhost"				# domain for creating subdomains, leading dot required
serveradmin="webmaster@localhost"		# admin email
webroot="/home/${webmaster}/Web/"		# root folder where subfolders for virtualhosts created
a2ensite="050-"								# short prefix for virtualhost config file
apachehost="/etc/apache2/sites-available/${a2ensite}"	# prefix for virtualhost config file
tmphost=$(mktemp)							# temp file for edit config
trap 'rm "$tmphost"' EXIT				# rm temp file on exit

have_command() {
	type -p "$1" >/dev/null
}

in_terminal() {
	[ -t 0 ]
}

notify_user () {
	echo "$1" >&2
	in_terminal && return
	local windowicon="info" # 'error', 'info', 'question' or 'warning' or path to icon
	[ "$2" ] && windowicon="$2"
	if have_command zenity; then
		zenity --notification --text="$1" --window-icon="$windowicon"
		return
	fi
	if have_command notify-send; then
		notify-send "$1"
	else
		xmessage -buttons Ok:0 -nearmouse "$1" -timeout 10
	fi
}

if ! in_terminal && ! have_command zenity;then
	notify_user "Use terminal or install zenity for gui. '$ sudo apt install zenity'"
	exit 1
fi

get_virtual_host() {
    if in_terminal; then
        read -p "Create virtualhost (= Folder name,case sensitive)" -r host
    else
        host=$(zenity --forms --add-entry=Name --text='Create virtualhost (= Folder name,case sensitive)')
    fi
    case "$host" in
        "")            notify_user "Bad input: empty" ;      exit 1 ;;
        *"*"*)         notify_user "Bad input: wildcard" ;   exit 1 ;;
        *[[:space:]]*) notify_user "Bad input: whitespace" ; exit 1 ;;
    esac
    echo "$host"
}

host=$(get_virtual_host) || exit

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

find_editor() {
	local editor=${VISUAL:-$EDITOR}
	if [ "$editor" ]; then
		echo "$editor"
		return
	fi

	for cmd in nano vim vi pico; do
		if have_command "$cmd"; then
			echo "$cmd"
			return
		fi
	done
}

if in_terminal; then
	# edit virtualhost config
	editor=$(find_editor)
	if [ -z "$editor" ];then
	    echo "$tmphost:"
	    cat  $tmphost
	    echo "edit '$tmphost' to your liking, then hit Enter"
	    read -p "I'll wait ... "
	else
	    "$editor" "$tmphost"
	fi
else
	# edit virtualhost config
	text=$(zenity --text-info --title="virtualhost config" --filename="$tmphost" --editable)
	if [ -z "$text" ];then
		# cancel button pressed
		exit 0
	fi
	echo "$text" > "$tmphost"
fi
# probably want some validating here that the user has not broken the config
# apache will not reload config if incorrect

getsuperuser () {
	if in_terminal;then
		echo "sudo"
	else
		echo "pkexec"
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

[ "$!" ] && notify_user "Virtualhost added. Apache2 reloaded."
