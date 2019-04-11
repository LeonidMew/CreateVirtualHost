#!/usr/bin/env bash

set -e

cd "${0%/*}"

source virtualhost.inc.sh

parseargs_opts="help,subdomain:,saveloginpassword"
parseargs "$@" # only --subdomain used
# read values from env
subdomain=$(tolowercase "${config[subdomain]}")
mysql[adminuser]="${adminuser:-root}"
mysql[adminpasswd]="${adminpwd}"
mysql[database]="${mysqldatabase:-${subdomain}}"
mysql[user]="${mysqluser:-${subdomain:-$(id -un)}}"
mysql[passwd]="${mysqlpasswd}"

for key in adminuser database user;do
  LANG=C; if_match "${mysql[$key]}" "^[a-zA-Z][a-zA-Z0-9_-]*$" || die "bad mysql $key"
done

[[ "${mysql[adminuser]}" && "${mysql[adminpasswd]}" ]] \
  && mysql_saveloginconfig "${mysql[adminuser]}" "${mysql[adminpasswd]}" && \
  [[ ! "${mysql[savemysql]}" ]] && trap 'rm "$mysqlconf"' EXIT

for key in adminpasswd passwd;do
  printf -v var "%q" "${mysql[$key]}"
  mysql[$key]=$var
done

mysqlcreate=$(cat <<EOF
CREATE USER '${mysql[user]}'@'localhost' IDENTIFIED BY '${mysql[passwd]}';
GRANT USAGE ON *.* TO '${mysql[user]}'@'localhost';
CREATE DATABASE IF NOT EXISTS \`${mysql[database]}\` CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON \`${mysql[database]}\`.* TO '${mysql[user]}'@'localhost';
FLUSH PRIVILEGES;
EOF
)

mysql --defaults-extra-file="$mysqlconf" <<<"$mysqlcreate"
