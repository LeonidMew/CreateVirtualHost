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

have_command yad || die "yad required. 'sudo apt install yad'"

user_info() {
  yad --title="Virtualhost" --window-icon="${2:-error}" --info --text="$1" --timeout="${3:-15}" --button="Ok:0" --center
}

parseargs "$@"

while true; do
  formbutton=0
  formoutput=$(yad --form --field="Subdomain" --field="Domain" --field="Web master username" \
    --field="Apache group" --field='Webroot' \
    --field='Webroot variables - ${homedir}(of webmaster) ${subdomain} ${webmaster} ${domain}:LBL' \
    --field="Virtualhost ip or domain" \
    --field="Virtualhost port" --field="Server admin email" \
    --field="Create mysql user&db:CHK" \
    --button="Cancel:3" --button="Save defaults:2" --button="Create:0" \
    --title="Create apache virtualhost" \
    --text='Subdomain are case sencetive for Webroot folder ${subdomain} variable' \
    --focus-field=1 --center --window-icon="preferences-system" --width=600 \
    "${config[subdomain]}" "${config[domain]}" "${config[webmaster]}" "${config[webgroup]}" \
    "${config[webroot]}" "test" "${config[virtualhost]}" "${config[virtualport]}" "${config[serveradmin]}" 1) || formbutton="$?" && true
  [[ "$formbutton" -ne 0 && "$formbutton" -ne 2 ]] && die "Cancell"

  IFS='|' read -r -a form <<< "$formoutput"
  config[subdomain]="${form[0]}"
  config[domain]="${form[1]}"
  config[webmaster]="${form[2]}"
  config[webgroup]="${form[3]}"
  config[webroot]="${form[4]}"
  config[virtualhost]="${form[6]}"
  config[virtualport]="${form[7]}"
  config[serveradmin]="${form[8]}"

  vres=0
  [[ "$formbutton" -eq 2 ]] && skipsubdomain=1 || skipsubdomain=
  valoutput=$(validate $skipsubdomain 2>&1) || vres=$? && true
  [[ "$vres" -ne 0 ]] && user_info "$valoutput" && continue

  args=""

  [[ "$formbutton" -ne 2 && "${config[subdomain]}" ]] && args+=" --subdomain ${config[subdomain]}"
  [[ "${config[domain]}" ]] && args+=" --domain '${config[domain]}'"
  [[ "${config[webmaster]}" ]] && args+=" --webmaster ${config[webmaster]}"
  [[ "${config[webgroup]}" ]] && args+=" --webgroup ${config[webgroup]}"
  [[ "${config[webroot]}" ]] && args+=" --webroot ${config[webroot]}"
  [[ "${config[virtualhost]}" ]] && args+=" --virtualhost ${config[virtualhost]}"
  [[ "${config[virtualport]}" ]] && args+=" --virtualport ${config[virtualport]}"
  [[ "${config[serveradmin]}" ]] && args+=" --serveradmin ${config[serveradmin]}"
  clires=0
  if [[ "$formbutton" -ne 2 ]]; then
    set -x
    clioutput=$(./virtualhost-cli.sh --subdomain "${config[subdomain]}" \
    --domain "${config[domain]}" --webmaster "${config[webmaster]}" \
    --webgroup "${config[webgroup]}" --webroot "${config[webroot]}" \
    --virtualhost "${config[virtualhost]}" --virtualport "${config[virtualport]}" \
    --serveradmin "${config[serveradmin]}" 2>&1) || clires=$? && true
    set +x
    echo "[$clires]"
    [[ "$clires" -ne 0 ]] && user_info "$clioutput" && continue
  fi
done
