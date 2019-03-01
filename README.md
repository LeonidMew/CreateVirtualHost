# CreateVirtualHost
Simple bash script to create apache2 virtualhost for localhost. Can be used for public sub domains on developer server with changes "replace .localhost".

Tested on Ubuntu, but should work where dependency met.

Not for production, for development purposes only.

Use `zenity` for gui and `pkexec` for root permissions in gui version.

Uses prefered editor or `vim` or `nano` in text version or `zenity` in gui version to edit generated config.

Launch from terminal or install dependences and launch gui version(by .desktop file for example).

/etc/hosts file looks like:
>127.0.0.1	localhost	*.localhost

Note the wildcard, script doesn't create domains
