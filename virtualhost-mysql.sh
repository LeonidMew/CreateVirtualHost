#!/usr/bin/env bash

set -e

cd "${0%/*}"

source virtualhost.inc.sh

parseargs "$@" # only --subdomain used
# read values from env
subdomain=$(tolowercase "${config[subdomain]}")
mysql[adminuser]="${adminuser:-root}"
mysql[adminpasswd]="${adminpwd}"
mysql[database]="${mysqldatabase:-${subdomain}}"
mysql[user]="${mysqluser:-${subdomain:-$(id -un)}}"
mysql[passwd]="${mysqlpasswd}"

validate_mysql
escape_mysql

mysqlcreate=$(cat <<EOF
CREATE USER '${mysql[user]}'@'localhost' IDENTIFIED BY '${mysql[passwd]}';
GRANT USAGE ON *.* TO '${mysql[user]}'@'localhost';
CREATE DATABASE IF NOT EXISTS \`${mysql[database]}\` CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON \`${mysql[database]}\`.* TO '${mysql[user]}'@'localhost';
FLUSH PRIVILEGES;
EOF
)

mysql --user="${mysql[adminuser]}" --password="${mysql[adminpasswd]}" <<<$mysqlcreate
