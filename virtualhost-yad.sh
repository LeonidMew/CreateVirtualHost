#!/usr/bin/env bash

set -e

cd "${0%/*}"

die() {
  echo "${2:-Error}: $1" >&2
  xmessage -buttons Ok:0 -nearmouse "${2:-Error}: $1" -timeout 10
  exit ${3:-1}
}

source virtualhost.inc.sh

in_terminal() {
  [ -t 0 ]
}

die() {
  local msg="${2:-Error}: $1"
  echo "$msg" >&2
  in_terminal && exit ${3:-1}
  try notify-send "$msg" && exit ${3:-1}
  try yad --info --text="$msg" && exit ${3:-1}
  try xmessage -buttons Ok:0 -nearmouse "$msg" -timeout 10 && exit ${3:-1}
  exit ${3:-1}
}

have_command yad || die "yad package required. 'sudo apt install yad'"

user_info() {
  yad --title="Virtualhost" --window-icon="${2:-error}" --info --text="$1" --timeout="${3:-15}" --button="Ok:0" --center
}

parseargs_opts="help,webmaster:,webgroup:,webroot:,domain:,subdomain:,virtualhost:,virtualport:,serveradmin:"
parseargs "$@"
# validate_args called in loop below, notifying user about errors each submit

#set -x

while true; do
  # notify user what mysql login already saved
  loginpassword_saved=""
  [[ -r "$mysqlconf" ]] && loginpassword_saved="(saved)"

  # mysql var not set at first loop run
  formbutton=0
  formoutput=$(yad --form --field="Subdomain" --field="Domain" --field="Web master username" \
    --field="Apache group" --field='Webroot' \
    --field='Webroot variables - ${homedir}(of webmaster) ${subdomain} ${webmaster} ${domain}:LBL' \
    --field="Virtualhost ip or domain" \
    --field="Virtualhost port" --field="Server admin email" \
    --field="Create mysql user&db:CHK" \
    --field="Mysql admin user${loginpassword_saved}" \
    --field="Mysql admin password${loginpassword_saved}" \
    --field="Admin login/password:CB" \
    --field="Database(empty={subdomain})" \
    --field="Mysql user(empty={subdomain})" --field="Mysql password" \
    --button="Cancel:5" --button="Save defaults:2" --button="Create:0" \
    --title="Create apache virtualhost" \
    --text='Subdomain are case sensetive for Webroot folder ${subdomain} variable' \
    --num-output \
    --focus-field=1 --center --window-icon="preferences-system" --width=600 \
    "${config[subdomain]}" "${config[domain]}" "${config[webmaster]}" "${config[webgroup]}" \
    "${config[webroot]}" "test" "${config[virtualhost]}" "${config[virtualport]}" \
    "${config[serveradmin]}" true \
    "${mysql[adminuser]}" "${mysql[adminpasswd]}" \
    "Save/Restore!Forget on exit" \
    "${mysql[database]}" "${mysql[user]}" "${mysql[passwd]}" \
    ) || formbutton="$?" && true
  # Cancel(5) or close window(other code)
  [[ "$formbutton" -ne 0 && "$formbutton" -ne 2 && "$formbutton" -ne 1 ]] && die "Cancel"

  IFS='|' read -r -a form <<< "$formoutput"

  declare -i pos=0
  for key in subdomain domain webmaster webgroup webroot nothing virtualhost virtualport serveradmin;do
    config[$key]="${form[$pos]}"
    ((pos++)) || true
  done

  usemysql=
  [[ "${form[9]}" -eq "TRUE" ]] && usemysql=1

  pos=10
  for key in adminuser adminpasswd savemysql database user passwd;do
    mysql[$key]="${form[$pos]}"
    ((pos++)) || true
  done
  [[ "$usemysql" && "${mysql[adminuser]}" ]] \
    && mysql_saveloginconfig "${mysql[adminuser]}" "${mysql[adminpasswd]}"
  [[ "${mysql[savemysql]}" -eq "2" ]] && trap 'rm "$mysqlconf"' EXIT

  vres=0
  # subdomain can't be default option, skip it
  [[ "$formbutton" -eq 2 ]] && skipsubdomain=1 || skipsubdomain=
  # validate input, continue or show error and return to form
  valoutput=$(validate_args $skipsubdomain 2>&1) || vres=$? && true
  [[ "$vres" -ne 0 ]] && user_info "$valoutput" && continue

  clires=0
  # if [[ "$formbutton" -ne 2 ]]; then
    cmd="pkexec `pwd`/virtualhost-cli.sh"
    [[ "$formbutton" -eq 2 ]] && cmd="./virtualhost-install.sh"
    clioutput=$($cmd --subdomain "${config[subdomain]}" \
    --domain "${config[domain]}" --webmaster "${config[webmaster]}" \
    --webgroup "${config[webgroup]}" --webroot "${config[webroot]}" \
    --virtualhost "${config[virtualhost]}" --virtualport "${config[virtualport]}" \
    --serveradmin "${config[serveradmin]}" 2>&1) || clires=$? && true
    [[ "$clioutput" ]] && user_info "$clioutput" || true
    [[ "$clires" -ne 0 ]] && continue
    # mysql
    if [[ "$usemysql" ]]; then
      mysqlres=0
      mysqloutput=$(database="${mysql[database]}" mysqluser="${mysql[user]}" \
      mysqlpasswd="${mysql[passwd]}" ./virtualhost-mysql.sh \
      --subdomain "${config[subdomain]}" 2>&1) || mysqlres=$? && true
      [[ "$mysqloutput" ]] && user_info "$mysqloutput" || true
      [[ "$mysqlres" -ne 0 ]] && continue
      break
    fi
  #  break
  # fi
done
