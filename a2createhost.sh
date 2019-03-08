#!/bin/bash

webmaster="$(id -un)"   # user who access web files. group is www-data
webgroup="www-data"     # apache2 web group, does't need to be webmaster group. SGID set for folder.
maindomain=".localhost" # domain for creating subdomains, leading dot required
virtualhost="*"         # ip of virtualhost in case server listen on many interfaces or "*" for all
virtualport="80"        # port of virtualhost. apache2 must listen on that ip:port
serveradmin="webmaster@localhost" # admin email
# declare -a webroots=("/home/\${webmaster}/Web/\${host}"
#                      "/var/www/\${host}"
#                      "/var/www/\${webmaster}/\${host}")
# declared below, after a chanse to edit inlined variadles
webroot=0              # folder index in webroots array
a2ensite="050-"        # short prefix for virtualhost config file
apachehost="/etc/apache2/sites-available/${a2ensite}"	# prefix for virtualhost config file
tmphost=$(mktemp)      # temp file for edit config
trap 'rm "$tmphost"' EXIT # rm temp file on exit
host=""                # no default subdomain
skipmysql=""
mysqladmin="root"
mysqladminpwd=""


have_command() {
  type -p "$1" >/dev/null
}

in_terminal() {
  [ -t 0 ]
}
in_terminal && start_in_terminal=1

info_user() {
  local msg=$1
  local windowicon="info" # 'error', 'info', 'question' or 'warning' or path to icon
  [ "$2" ] && windowicon="$2"
  if in_terminal; then
    echo "$msg"
  else
    zenity --info --text="$msg" --icon-name="${windowicon}" \
           --no-wrap --title="Virtualhost" 2>/dev/null
  fi
}

notify_user () {
  echo "$1" >&2
  in_terminal && return
  local windowicon="info" # 'error', 'info', 'question' or 'warning' or path to icon
  local msgprefix=""
  local prefix="Virtualhost: "
  [ "$2" ] && windowicon="$2" && msgprefix="$2: "
  if have_command zenity; then
    zenity --notification --text="${prefix}$1" --window-icon="$windowicon"
    return
  fi
  if have_command notify-send; then
    notify-send "${prefix}${msgprefix}$1"
  else
    xmessage -buttons Ok:0 -nearmouse "${prefix}${msgprefix}$1" -timeout 10
  fi
}

# sudo apt hangs when run from script, thats why terminal needed
install_zenity() {
  have_command gnome-terminal && gnome-terminal --title="$1" --wait -- $1
  have_command zenity && exit 0
  exit 1
}
# check if zenity must be installed or text terminal can be used
# if fails = script exit
# to install zenity, run: ./script.sh --gui in X terminal
# ask user to confirm install if able to ask
check_gui() {
  local msg="Use terminal or install zenity for gui. '$ sudo apt install zenity'"
  local cmd="sudo apt install zenity"
  local notfirst=$1
  if ! have_command zenity;then
    notify_user "$msg" "error"
    # --gui set and input/output from terminal possible
    if [[ "${gui_set}" && "${start_in_terminal}" ]]; then
      read -p "Install zenity for you? sudo required.[y/N]" -r autozenity
      reg="^[yY]$"
      if [[ "$autozenity" =~ $reg ]]; then
        $(install_zenity "$cmd") || exit
        exit 0
      else
        exit 1
      fi
    else
      if [[ "${gui_set}" ]]; then
        $(install_zenity "$cmd") || exit
        exit 0
      else
        if ! in_terminal;then
          $(install_zenity "$cmd") || exit
          exit 0
        fi
      fi
    fi

  fi
  exit 0
}
$(check_gui) || exit


validate_input() {
  local msg="$1"
  local var="$2"
  local reg=$3
  if ! [[ "$var" =~ $reg ]]; then
    notify_user "$msg" "error"
    exit 1
  fi
  exit 0
}

validate_domain() {
  $(LANG=C; validate_input "Bad domain with leading . (dot)" "$1" \
    "^\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9\.])*$") || exit 1
  exit 0
}

validate_username() {
  $(LANG=C; validate_input "Bad username." "$1" \
    "^[[:lower:]_][[:lower:][:digit:]_-]{2,15}$") || exit 1
  if ! id "$1" >/dev/null 2>&1; then
    notify_user "User not exists" "error"
    exit 1
  fi
  exit 0
}

validate_group() {
  getent group "$1" > /dev/null 2&>1
  [ $? -ne 0 ] && notify_user "Group $1 not exists" "error" && exit 1
  exit 0
}

validate_email() {
  $(LANG=C; validate_input "Bad admin email." "$1" \
    "^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)*[a-z0-9]([a-z0-9-]*[a-z0-9])?\$") 	|| exit 1
  exit 0
}

validate_subdomain() {
  $(LANG=C; validate_input "Bad subdomain" "$1" \
    "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$") || exit 1
  exit 0
}

getopt --test > /dev/null
if [ "$?" -gt 4 ];then
  echo 'I’m sorry, `getopt --test` failed in this environment.'
else
  OPTIONS="w:d:a:ghi"
  LONGOPTS="webmaster:,domain:,adminemail:,gui,help,webroot:,webgroup:,install,subdomain:,skipmysql,mysqlauto"
  ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    # then getopt has complained about wrong arguments to stdout
    exit 2
  fi
  # read getopt’s output this way to handle the quoting right:
  eval set -- "$PARSED"
  while true; do
    case "$1" in
        "--skipmysql")
            skipmysql=1
            shift
            ;;
        "--mysqlauto")
            mysqlauto=1
            shift
            ;;
        "-w"|"--webmaster")
            webmaster="$2"
            webmaster_set=1
            shift 2
            ;;
        "--webgroup")
            webgroup="$2"
            webgroup_set=1
            shift 2
            ;;
        "--subdomain")
            host="$2"
            host_set=1
            shift 2
            ;;
        "-d"|"--domain")
            maindomain="$2"
            maindomain_set=1
            shift 2
            ;;
        "-a"|"--adminemail")
            serveradmin="$2"
            serveradmin_set=1
            shift 2
            ;;
        "--webroot")
            declare -i webroot="$2"
            webroot_set=1
            shift 2
            ;;
        "-g"|"--gui")
            if [ -z "$DISPLAY" ];then
              notify_user "GUI failed. No DISPLAY." "error"
              exit 1
            else
              gui_set=1
              # GUI can be enabled at this point, when run from terminal /
              # with --gui, so check again
              $(check_gui) || exit
              in_terminal() {
                false
              }
            fi
            shift
            ;;
        "-i"|"--install")
            install_set=1
            shift
            ;;
        "-h"|"--help")
            cat << EOF
usage: ./${0}                    # if some arguments specified in command
                                 # line, script will not ask to input it value
                                 # --install of script makes some values predefined
       [--webmaster="userlogin"] # user with permissions to edit www
                                 # files. group is 'www-data'
       [--webgroup="www-data"]   # group of apache2 service user
       [--domain=".localhost"]   # leading dot required
       [--subdomain="Example"]   # Subdomain and webroot folder name
                                 # (folder case censetive)
       [--adminemail="admin@localhost"]
       [--webroot="0"]           # documentroot of virtualhost, zero based index
       # webroots[0]="/home/\${webmaster}/Web/\${subdomain}"
       # webroots[1]="/var/www/\${subdomain}"
       # webroots[2]="/var/www/\${webmaster}/\${subdomain}"
       [--skipmysql]             # don't create mysql db and user
       [--mysqlauto]             # use subdomain as mysql db name, username, empty password
       [--gui]                   # run gui version from terminal else be autodetected without this.
                                 # attemps to install zenity

       ${0}
       --help                    # this help

       ${0}
       --gui --install           # install .desktop shortcut for current user
                                 # and optionally copy script to $home/bin
                                 # --install requires --gui
                                 # shortcut have few options to run, without mysql for example
       ${0} "without arguments"  # will read values from user
EOF
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error" >&2
            exit 3
            ;;
    esac
  done
  if [ "$install_set" ]; then
    ! [ "$gui_set" ] && notify_user "--gui must be set with --install" && exit 1
    homedir=$( getent passwd "$(id -un)" | cut -d: -f6 )

    source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do # resolve $SOURCE until the file is no longer a symlink
      dir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
      source="$(readlink "$source")"
      [[ $source != /* ]] && source="$dir/$source"
      # ^ if $SOURCE was a relative symlink, we need to resolve it relative to
      # the path where the symlink file was located
    done
    dir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
    scriptname=$( basename "$source" )

    # make a form where script args can be predefined, so not needed every launch
    pipestring=$(zenity --forms --add-entry="Domain(leading dot)(Default .localhost)" \
      --add-entry="Webmaster(default: current username)" \
      --add-entry="Webgroup(Default: www-data)" \
      --add-entry="Server admin(Default: webmaster@localhost)" \
      --text="Predefined values(empty=interactive edit)" --title="Desktop shortcut" \
      --add-combo="Install path" --combo-values="${homedir}/bin/|${dir}/" 2>/dev/null)

    # zenity stdout if like value1|value2|etc
    IFS='|' read -r -a form <<< "$pipestring"
    args=""
    if [ "${form[0]}" ]; then $(validate_domain "${form[0]}") || exit 60; fi
    if [ "${form[1]}" ]; then $(validate_username "${form[1]}") || exit 61; fi
    if [ "${form[2]}" ]; then $(validate_group "${form[2]}") || exit 62; fi
    if [ "${form[3]}" ]; then $(validate_email "${form[3]}") || exit 63; fi
    if [ "${form[4]}" ]; then mkdir -p "${form[4]}"; fi

    [ "${form[0]}" ] && args="$args --domain='${form[0]}'"
    [ "${form[1]}" ] && args="$args --webmaster='${form[1]}'"
    [ "${form[2]}" ] && args="$args --webgroup='${form[2]}'"
    [ "${form[3]}" ] && args="$args --adminemail='${form[3]}'"
    installpath="${dir}/${scriptname}"
    if [ "${form[4]}" != " " ]; then installpath="${form[4]}${scriptname}"; fi

    cp "${dir}/${scriptname}" "$installpath" >/dev/null 2>&1
    chmod u+rx "$installpath"

    desktop="$homedir/.local/share/applications/virtualhost.desktop"
    cat >"$desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=Create Virtualhost
Comment=Easy to create new virtualhost for apache2 server
Keywords=Virtualhost;Apache;Apache2
Exec=/bin/bash ${installpath} ${args}
Terminal=false
X-MultipleArgs=true
Type=Application
Icon=network-wired
Categories=GTK;Development;
StartupNotify=false
Actions=without-arguments;new-install

[Desktop Action without-arguments]
Name=Clean launch
Exec=/bin/bash ${installpath}

[Desktop Action without-mysql]
Name=Without mysql config
Exec=/bin/bash ${installpath} ${args} --skipmysql

[Desktop Action new-install]
Name=Reinstall (define new configuration)
Exec=/bin/bash ${installpath} --install --gui
X-MultipleArgs=true
EOF

    exit 0
  fi

  # if arguments passed - validate them.
  msg=""
  if [ "$maindomain_set" ]; then
    $(validate_domain "$maindomain") \
      || msg="Bad value for --domain. Should have leading dot.  \".localhost\"\n"
  fi
  if [ "$serveradmin_set" ]; then
    $(validate_email "$serveradmin") || msg="Bad value for --adminemail\n$msg"
  fi
  if [ "$host_set" ]; then
    $(validate_subdomain "$host") || msg="Bad value for --subdomain\n$msg"
  fi
  if [ "$webmaster_set" ]; then
    $(validate_username "$webmaster") || msg="Bad value for --webmaster\n$msg"
  fi
  if [ "$webgroup_set" ]; then
    $(validate_group "$webgroup") || msg="Bad value for --webgroup\n$msg"
  fi
  have_command apache2 || msg="Apache2 not installed\n$msg"
  if [ "$msg" ];then
    [ "$gui_set" ] && info_user "$msg" "error"
    exit 1
  fi
fi

if [ "$(id -un)" == "root" ];then
   notify_user "You should not run this script as root but as user with 'sudo' rights." "error"
   exit 1
fi

get_text_input() {
    if in_terminal; then
        defaulttext=""
        [ "$3" ] && defaulttext="[Default: ${3}]"
        read -p "${2}$defaulttext" -r input
        # default
        [ "$3" ] && [ -z "$input" ] && input="$3"
    else
       input=$(zenity --entry="$1" --title="Virtualhost" --text="$2" --entry-text="$3" 2>/dev/null)
       if [ "$?" == "1" ]; then
         echo "[$1]Cancel button" 1>&2
         exit 1		# Cancel button pressed
     fi
    fi
    if [ -z "$4" ]; then
      case "$input" in
          "")            notify_user "[$1]Bad input: empty" "error" ;      exit 1 ;;
          *"*"*)         notify_user "[$1]Bad input: wildcard" "error" ;   exit 1 ;;
          *[[:space:]]*) notify_user "[$1]Bad input: whitespace" "error" ; exit 1 ;;
      esac
    fi
    echo "$input"
}

# get input and validate it
if [ -z "$host" ]; then host=$(get_text_input "Subdomain" "Create virtualhost (= Folder name,case sensitive)" "") || exit; fi
$(validate_subdomain "$host") || exit

if [ -z "$maindomain_set" ]; then maindomain=$(get_text_input "Domain" "Domain with leading dot." "$maindomain") || exit; fi
$(validate_domain "$maindomain") || exit

if [ -z "$webmaster_set" ]; then webmaster=$(get_text_input "Username" "Webmaster username" "$webmaster") || exit; fi
$(validate_username "$webmaster") || exit

if [ -z "$serveradmin_set" ]; then serveradmin=$(get_text_input "Admin email" "Server admin email" "$serveradmin") || exit; fi
$(validate_email "$serveradmin") || exit

homedir=$( getent passwd "$webmaster" | cut -d: -f6 )
# webroot is a choise of predefined paths array
declare -a webroots=("${homedir}/Web/${host}" "/var/www/${host}" "/var/www/${webmaster}/${host}")
zenitylistcmd=""
# zenily list options is all columns of all rows as a argument, one by one
for (( i=0; i<${#webroots[@]}; i++ ));do
  if in_terminal; then
    echo "[${i}] ${webroots[$i]}" # reference for text read below
  else
    zenitylistcmd="${zenitylistcmd}${i} ${i} ${webroots[$i]} "
  fi
done
dir=""
[ -z "$webroot_set" ] && if in_terminal; then
  webroot=$(get_text_input 'Index' 'Website folder' "$webroot") || exit
else
  webroot=$(zenity --list --column=" " --column="Idx" --column="Path" --hide-column=2 \
    --hide-header --radiolist --title="Choose web folder" $zenitylistcmd 2>/dev/null)
fi
if [ -z "${webroots[$webroot]}" ]; then notify_user "Invalid webroot index"; exit 1; fi

dir="${webroots[$webroot]}"          # folder used as document root for virtualhost
hostfile="${apachehost}${host}.conf" # apache virtualhost config file

# virtualhost template
cat >"$tmphost" <<EOF
<VirtualHost ${virtualhost}:${virtualport}>
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
  # edit virtualhost config GUI
  text=$(zenity --text-info --title="Virtualhost config" --filename="$tmphost" --editable 2>/dev/null)
  if [ -z "$text" ];then
    # cancel button pressed
    exit 0
  fi
  echo "$text" > "$tmphost"
fi
# probably want some validating here that the user has not broken the config
# apache will not reload config if incorrect

mysqlskip="$skipmysql"	# skip if --skipmysql set
[ -z "$mysqlskip" ] && if have_command mysqld; then
  if [ -z "$mysqlskip" ]; then mysqladminpwd=$(get_text_input "Admin password" "Admin password (${mysqladmin})" "" "skipcheck") || mysqlskip=1; fi
  if [ "$mysqlauto" ]; then
    mysqldb="$host"
    mysqluser="$host"
    mysqlpwd=""
  else
    if [ -z "$mysqlskip" ]; then
      mysqldb=$(get_text_input "Database" "Database name(Enter for default)" "$host") || mysqlskip=1
    fi
    if [ -z "$mysqlskip" ]; then
      mysqluser=$(get_text_input "Username" "Mysql user for db:$mysqldb host:localhost(Enter for default)" "$mysqldb") || mysqlskip=1
    fi
    if [ -z "$mysqlskip" ]; then
      mysqlpwd=$(get_text_input "Password" "Mysql password for user:$mysqluser db:$mysqldb host:localhost(Enter for empty)" "" "skipcheck") || mysqlskip=1
    fi
  fi

  if [ -z "$mysqlskip" ]; then
    tmpmysqlinit=$(mktemp)
    trap 'rm "$tmpmysqlinit"' EXIT
    cat >"$tmpmysqlinit" <<EOF
CREATE USER '${mysqluser}'@'localhost' IDENTIFIED BY '${mysqlpwd}';
GRANT USAGE ON *.* TO '${mysqluser}'@'localhost';
CREATE DATABASE IF NOT EXISTS \`${mysqldb}\` CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON \`${mysqldb}\`.* TO '${mysqluser}'@'localhost';
FLUSH PRIVILEGES;
EOF
  fi
fi

getsuperuser () {
  if in_terminal;then
    echo "sudo"
  else
    echo "pkexec"
  fi
}

notify_user "execute root commands with $(getsuperuser) to create virtualhost" "warning"

tmpresult=$(mktemp)
trap 'rm "$tmpresult"' EXIT
tmpmysqlresult=$(mktemp)
trap 'rm "$tmpmysqlresult"' EXIT

$(getsuperuser) /bin/bash <<EOF
mkdir -p "$dir"
chown ${webmaster}:${webgroup} "$dir"
chmod u=rwX,g=rXs,o= "$dir"
cp "$tmphost" "$hostfile"
chown root:root "$hostfile"
chmod u=rw,g=r,o=r "$hostfile"
a2ensite "${a2ensite}${host}.conf"
systemctl reload apache2
echo "\$?" > "$tmpresult"
if [ -z "${mysqlskip}" ]; then
  systemctl start mysql
  mysql --user="$mysqladmin" --password="$mysqladminpwd" <"$tmpmysqlinit"
  echo "\$?" > "$tmpmysqlresult"
fi
EOF

if [ $(cat "$tmpmysqlresult") ]; then $mysqlresult="\nMysql db,user created"; fi
if [ $(cat "$tmpresult") ]; then notify_user "Virtualhost added. Apache2 reloaded.${mysqlresult}"; fi
