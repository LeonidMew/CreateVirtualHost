[[ "${BASH_VERSINFO:-0}" -ge 4 ]] || die "Bash version 4 or above required"

declare -A config=()
config[webmaster]="$(id -un)"   # user who access web files. group is www-data
config[webgroup]="www-data"     # apache2 web group, does't need to be webmaster group. SGID set for folder.
config[webroot]='/home/${webmaster}/Web/${subdomain}'
config[domain]="localhost"      # domain for creating subdomains
config[virtualhost]="*"         # ip of virtualhost in case server listen on many interfaces or "*" for all
config[virtualport]="80"        # port of virtualhost. apache2 must listen on that ip:port
config[serveradmin]="webmaster@localhost" # admin email
config[a2ensite]="050-"         # short prefix for virtualhost config file
config[apachesites]="/etc/apache2/sites-available/" # virtualhosts config folder

have_command() {
  type -p "$1" >/dev/null
}

try() {
  have_command "$1" && "$@"
}

if_match() {
  [[ "$1" =~ $2 ]]
}

validate() {
  [[ -z "${config[subdomain]}" ]] && die "--subdomain required"
  [[ "${config[webmaster]}" == "root" ]] && die "--webmaster should not be root"
  id "${config[webmaster]}" >/dev/null 2>&1 || die "--webmaster user '${config[webmaster]}' not found"
  getent group "${config[webgroup]}" > /dev/null 2>&1
  [[ $? -ne 0 ]] && die "Group ${config[webgroup]} not exists"
  have_command apache2 || die "apache2 not found"
  [[ -d ${config[apachesites]} ]] || die "apache2 config folder not found"

  (LANG=C; if_match "${config[domain]}" "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9\.])*$") || \
    die "Bad domain"
  (LANG=C; if_match "${config[subdomain]}" "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$") || \
    die "Bad subdomain"
  (LANG=C; if_match "${config[serveradmin]}" \
    "^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)*[a-z0-9]([a-z0-9-]*[a-z0-9])?\$" \
    ) || die "Bad admin email"

  octet="(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])"
  (if_match "${config[virtualhost]}" "^$octet\\.$octet\\.$octet\\.$octet$") || \
    (if_match "${config[virtualhost]}" "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9\.])*$") || \
    (if_match "${config[virtualhost]}" "^\*$") || \
    die "Bad virtualhost"
  (if_match "${config[virtualport]}" "^[1-9][0-9]+$") || die "Bad virtualport"
}

tolowercase() {
  echo "${1}" | tr '[:upper:]' '[:lower:]'
}

parse() {
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

connect() {
  (systemctl status apache2) &>/dev/null || return
  local host="${config[virtualhost]}"
  [[ "$host" == "*" ]] && host="localhost"
  set +e
  msg=$(netcat -vz "$host" "${config[virtualport]}" 2>&1)
  [[ $? -ne 0 ]] && die "$msg"
  set -e
}
