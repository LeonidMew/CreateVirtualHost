declare -A config=()
config[webmaster]="$(id -un)"   # user who access web files. group is www-data
config[webgroup]="www-data"     # apache2 web group, does't need to be webmaster group. SGID set for folder.
config[webroot]='/home/${webmaster}/Web/${host}'
config[domain]="localhost"      # domain for creating subdomains
config[virtualhost]="*"         # ip of virtualhost in case server listen on many interfaces or "*" for all
config[virtualport]="80"        # port of virtualhost. apache2 must listen on that ip:port
config[serveradmin]="webmaster@localhost" # admin email
config[a2ensite]="050-"         # short prefix for virtualhost config file
config[apachesites]="/etc/apache2/sites-available/" # virtualhosts config folder

have_command() {
  type -p "$1" >/dev/null
}

if_match() {
  [[ "$1" =~ $2 ]]
}

validate() {
  [[ -z "${config[subdomain]}" ]] && die "--subdomain required"
  [[ "${config[webmaster]}" == "root" ]] && die "--webmaster should not be root"
  id "${config[webmaster]}" >/dev/null 2>&1 || die "--webmaster user '${config[webmaster]}' not found"
  getent group "${config[webgroup]}" > /dev/null 2&>1
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
}


