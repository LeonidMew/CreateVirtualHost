#!/usr/bin/env bash

set -e

cd "${0%/*}"

source virtualhost.inc.sh

parseargs "$@"
validate
parse
#connect

hostfile="${config[a2ensite]}${config[subdomain]}.conf"
siteconf="${config[apachesites]}${hostfile}"

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
) || die "May run as root or give $siteconf writable permissions to current user"

(
  mkdir -p "${config[webroot]}"
  chown ${config[webmaster]}:${config[webgroup]} "${config[webroot]}"
  chmod u=rwX,g=rXs,o= "${config[webroot]}"
  chown root:root "$siteconf"
  chmod u=rw,g=r,o=r "$siteconf"
  a2ensite "${hostfile}"
  systemctl reload apache2
) || die "Run as root"

die "Config file saved and enabled at ${siteconf}" "Notice" 0
