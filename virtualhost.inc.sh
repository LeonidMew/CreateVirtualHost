#check if function exists
if ! type die &>/dev/null;then
  die() {
    echo "${2:-Error}: $1" >&2
    exit ${3:-1}
  }
fi
[[ "${BASH_VERSINFO:-0}" -ge 4 ]] || die "Bash version 4 or above required"

# defaults
declare -A config=()
config[webmaster]="$(id -un)"   # user who access web files. group is www-data
config[webgroup]="www-data"     # apache2 web group, does't need to be webmaster group. SGID set for folder.
config[webroot]='${homedir}/Web/${subdomain}'
config[domain]="localhost"      # domain for creating subdomains
config[virtualhost]="*"         # ip of virtualhost in case server listen on many interfaces or "*" for all
config[virtualport]="80"        # port of virtualhost. apache2 must listen on that ip:port
config[serveradmin]="webmaster@localhost" # admin email
config[a2ensite]="050-"         # short prefix for virtualhost config file
config[apachesites]="/etc/apache2/sites-available/" # virtualhosts config folder

declare -A mysql=() # mysql script read values from env
declare -r mysqlconf="$( getent passwd "${config[webmaster]}" | cut -d: -f6 )/.config/virtualhost_mysql.cnf"

have_command() {
  type -p "$1" >/dev/null
}

try() {
  have_command "$1" && "$@"
}

if_match() {
  [[ "$1" =~ $2 ]]
}

validate_args() {
  [[ -z $1 && -z "${config[subdomain]}" ]] && die "--subdomain required"
  [[ "${config[webmaster]}" == "root" ]] && die "--webmaster should not be root"
  id "${config[webmaster]}" >& /dev/null || die "--webmaster user '${config[webmaster]}' not found"
  getent group "${config[webgroup]}" >& /dev/null
  [[ $? -ne 0 ]] && die "Group ${config[webgroup]} not exists"
  have_command apache2 || die "apache2 not found"
  [[ -d ${config[apachesites]} ]] || die "apache2 config folder not found"

  LANG=C; if_match "${config[domain]}" "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9\.])*$" || \
    die "Bad domain"
  [[ -z "$1" ]] && (LANG=C; if_match "${config[subdomain]}" "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$" || \
    die "Bad subdomain")
  LANG=C; if_match "${config[serveradmin]}" \
    "^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)*[a-z0-9]([a-z0-9-]*[a-z0-9])?\$" \
    || die "Bad admin email"

  octet="(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])"
  if_match "${config[virtualhost]}" "^$octet\\.$octet\\.$octet\\.$octet$" || \
    if_match "${config[virtualhost]}" "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9\.])*$" || \
    if_match "${config[virtualhost]}" "^\*$" || \
    die "Bad virtualhost"
  if_match "${config[virtualport]}" "^[1-9][0-9]+$" || die "Bad virtualport"
}

tolowercase() {
  tr '[:upper:]' '[:lower:]' <<< "${1}"
}

process_args() {
  config[webroot]=$(echo "${config[webroot]}" | \
  homedir=$( getent passwd "${config[webmaster]}" | cut -d: -f6 ) \
  webmaster="${config[webmaster]}" \
  subdomain="${config[subdomain]}" \
  domain="${config[subdomain]}.${config[domain]}" \
  envsubst '${homedir},${webmaster},${subdomain},${domain}')

  config[domain]="${config[subdomain]}.${config[domain]}"
  config[domain]=$(tolowercase "${config[domain]}")
  config[subdomain]=$(tolowercase "${config[subdomain]}")
  config[virtualhost]=$(tolowercase "${config[virtualhost]}")
}

# check if apache listening on defined host:port
check_virtualhost_port() {
  (systemctl status apache2) &>/dev/null || return
  local host="${config[virtualhost]}"
  [[ "$host" == "*" ]] && host="localhost"
  local ret=0
  msg=$(netcat -vz "$host" "${config[virtualport]}" 2>&1) || ret=$? && true
  [[ $ret -ne 0 ]] && die "$msg"
}

# load all allowed arguments into $config array
parseargs() {
  (getopt --test > /dev/null) || true
  [[ "$?" -gt 4 ]] && die 'I’m sorry, `getopt --test` failed in this environment.'
  local OPTIONS=""
  local LONGOPTS="$parseargs_opts"
  # "help,webmaster:,webgroup:,webroot:,domain:,subdomain:,virtualhost:,virtualport:,serveradmin:"
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
      --help)
        man -P cat ./virtualhost.1
        exit 0
        ;;
      --saveloginpassword)
        mysql[savemysql]=1
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        index=${1#--} # limited to LONGOPTS
        config[$index]=$2
        shift 2
        ;;
    esac
  done

}

mysql_saveloginconfig() {
cat >"$mysqlconf" <<EOF
[client]
user = $1
password = $2
host = localhost
EOF
chmod u=rw,g=,o= "$mysqlconf"
}

