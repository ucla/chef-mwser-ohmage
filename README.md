# ectg-ohmage-cookbook

"wrapper" cookbook for ohmage. Preps a box to have ohmage deployed (not added by this cookbook!)

## Supported Platforms

Ubuntu 12.04, Ubuntu 14.04

## Usage

Adding `ectg-ohmage` to your node's run list will result in a few things happening:

  * tomcat7/java/mysql/nginx will all be installed and configured
  * an `ohmage` db and user will be created
  * necessary ohmage fs locations will be created and `chown`ed for tomcat (`/var/lib/ohmage` and `/var/log/ohmage`)
  * flyway installed at `/opt/flyway-ohmage/` (most just a convenience measure for using flyway while managing ohmage)

You'll need to have chef-vault databags for `passwords/db_root`, `passwords/ohmage` `ssl/#{fqdn_of_node}`.

## License and Authors

Author:: Steve Nolen (<technolengy@gmail.com>)
