#!/usr/bin/env bash

set -e

# get script installation dir, where it placed
source="${BASH_SOURCE[0]}"
while [ -h "$source" ]; do # resolve $SOURCE until the file is no longer a symlink
  sourcedir="$( cd -P "$( dirname "$source" )" >& /dev/null && pwd )"
  source="$(readlink "$source")"
  [[ $source != /* ]] && source="$sourcedir/$source"
  # ^ if $SOURCE was a relative symlink, we need to resolve it relative to
  # the path where the symlink file was located
done
sourcedir="$( cd -P "$( dirname "$source" )" >& /dev/null && pwd )"

cd "${sourcedir}"

source virtualhost.inc.sh

parseargs "$@"
validate "skipsubdomain"

args=""
config[domain]=${config[domain]#.}
for key in domain webmaster webgroup webroot virtualhost virtualport serveradmin;do
  [[ "${config[$key]}" ]] && args+=" --${key} '${config[$key]}'"
done

homedir=$( getent passwd "${config[webmaster]}" | cut -d: -f6 )
installpath="${sourcedir}/virtualhost-yad.sh"
desktop="$homedir/.local/share/applications/virtualhost.desktop"

cat >"$desktop" <<EOF
[Desktop Entry]
Version=2.0
Name=Create Virtualhost
Comment=Easy to create new virtualhost for apache2 server
Keywords=Virtualhost;Apache;Apache2
Exec=${installpath} ${args}
Terminal=false
X-MultipleArgs=true
Type=Application
Icon=preferences-system
Categories=GTK;Development;
StartupNotify=false
Actions=without-arguments

[Desktop Action without-arguments]
Name=Clean launch
Exec=${installpath}
EOF

