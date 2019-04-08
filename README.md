# CreateVirtualHost
Bash script to create apache2 virtualhost for local server. Optionally creates mysql db, user.

Tested on Ubuntu, but should work where dependency met.

Not for production, for development purposes only.

Use `yad` for gui and `pkexec` for root permissions in gui version, also depends on `notify-send`, but it optional.
All available in main ubuntu repo.

Launch from terminal or install dependences and launch gui version(by .desktop file for example). GUI version can create .desktop shortcut with some values defined as defaults in shortcut

/etc/hosts file looks like:
>127.0.0.1	localhost	*.localhost

Note the wildcard, script doesn't create domains

**Man page:**


       virtualhost-cli.sh    --subdomain=domain   [--domain=localhost]   [--webmaster=username]   [--webgroup=usergroup]   [--webroot='${homedir}/Web/${subdomain}']     [--serveradmin=webmaster@localhost]    [--virtualhost=localhost]  [--virtualport=80]

       virtualhost-yad.sh [same options as defaults]...

       virtualhost-install.sh [same options as defaults]...

      virtualhost-cli.sh
              Create configuration and folder for virtual host, then reload apache.
              Do  not  create  DNS  record for domain, so works best with something
              like *.localhost in /etc/hosts

       virtualhost-yad.sh
              GUI tool on top of cli. Get optional arguments as defaults  what  can
              be changed by user.  Requires package yad.

       virtualhost-install.sh
              Install  .desktop  shortcut  for  current user(or --webmaster user is
              specified), not system  wide.  Shortcut  to  virtualhost-yad.sh  with
              default  parameters, and can be called by it one to make new shortcut
              with new defaults

OPTIONS

       --subdomain
              Subdomain for virtual host, also can be used in webroot  folder  name
              so case sensetive. Only for virtualhost-cli.sh, GUI version expect it
              from user input.

       --webroot
              Folder of virtual host root. Can contain variables ${homedir}(of web‐
              master)  ${subdomain}  ${webmaster}  ${domain}.  Variables  validated
              against restrective regexp, for security reason.  Default is '${home‐
              dir}/Web/${subdomain}'.
