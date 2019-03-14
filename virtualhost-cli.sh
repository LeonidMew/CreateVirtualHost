#!/usr/bin/env bash

set -e

cd "${0%/*}"

die() {
  echo "${2:-Error}: $1" >&2
  exit ${3:-1}
}

source virtualhost.inc.sh

parseargs "$@"
validate
parse
connect

siteconf="${config[readconf]:-${config[writeconf]}}"
[[ -z "$siteconf" ]] && \
  siteconf="${config[apachesites]}${config[a2ensite]}${config[subdomain]}.conf"
if [[ -z "${config[readconf]}" ]];then

(cat >"$siteconf" <<EOF
<VirtualHost ${config[virtualhost]}:${config[virtualport]}>
  ServerAdmin ${config[serveradmin]}
    DocumentRoot ${config[webroot]}
    ServerName  ${config[domain]}
    ServerAlias ${config[domain]}
    <Directory "${config[webroot]}">
      AllowOverride All
      Require local
    </Directory>
    # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
    # error, crit, alert, emerg.
    LogLevel error
</VirtualHost>
# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF
) || die "Run as root"

fi

[[ "${config[writeconf]}" ]] && exit 0

hostfile="${config[apachesites]}${config[a2ensite]}${config[subdomain]}.conf"

mkdir -p "${config[webroot]}"
chown ${config[webmaster]}:${config[webgroup]} "${config[webroot]}"
chmod u=rwX,g=rXs,o= "${config[webroot]}"
[[ "$siteconf" == "$hostfile" ]] || cp "$siteconf" "$hostfile"
chown root:root "$hostfile"
chmod u=rw,g=r,o=r "$hostfile"
a2ensite "${config[a2ensite]}${config[subdomain]}.conf"
systemctl reload apache2

