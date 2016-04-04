#
# Cookbook Name:: mwser-ohmage
# Recipe:: default
#
# Copyright (C) 2016 UC Regents
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

chef_gem 'chef-vault'
require 'chef-vault'

fqdn = node['fqdn']

# install/enable nginx
node.set['nginx']['default_site_enabled'] = false
node.set['nginx']['install_method'] = 'package'
include_recipe 'nginx::repo'
include_recipe 'nginx'

# install/enable tomcat (also pulls in a needed jre)
package 'tomcat7'
service 'tomcat7' do
  supports status: true, restart: true, reload: false
  action [:enable, :start]
end

# install/enable mysql
db_root_obj = ChefVault::Item.load("passwords", "db_root")
db_root = db_root_obj[fqdn]
db_ohmage_obj = ChefVault::Item.load("passwords", "ohmage")
db_ohmage = db_ohmage_obj[fqdn]

# don't set this service up, currently uses the distro default.
mysql_service 'default' do
  port '3306'
  version '5.6'
  initial_root_password db_root
  action [:create, :start]
end

mysql_connection = {
  :host => '127.0.0.1',
  :port => 3306,
  :username => 'root',
  :password => db_root
}

# set up casa db
mysql2_chef_gem 'default'
mysql_database 'ohmage' do
  connection mysql_connection
  action :create
end
mysql_database_user 'ohmage' do
  connection mysql_connection
  password db_ohmage
  database_name 'ohmage'
  action [:create,:grant]
end

# /etc/ohmage.conf

template '/etc/ohmage.conf' do
  source 'ohmage.conf.erb'
  mode '0755'
  variables(
    ohmage_db_password: db_ohmage,
    log_level: 'WARN'
  )
  action :create
end

template '/etc/default/tomcat7' do
  source 'tomcat7_default.conf.erb'
  mode '0755'
  action :create
end

template '/etc/default/tomcat7' do
  source 'tomcat7_setenv.sh.erb'
  mode '0775'
  user 'tomcat7'
  group 'tomcat7'
  action :create
end

# install flyway, configure conf file for ohmage
flyway 'ohmage' do
  url 'jdbc:mysql://127.0.0.1:3306/ohmage'
  user 'ohmage'
  password db_ohmage
  additional_options(
    'placeholders.fqdn' => fqdn,
    'placeholders.base_dir' => '/var/lib/ohmage',
    'locations' => 'filesystem:/opt/ohmage-source/db/migration/'
  )
  action :create
end

file '/opt/flyway-ohmage/flyway' do
  mode '0755'
end

# SSL
item = ChefVault::Item.load('ssl', fqdn)
file "/etc/ssl/certs/#{fqdn}.crt" do
  owner 'root'
  group 'root'
  mode '0777'
  content item['cert']
  notifies :reload, 'service[nginx]', :delayed
end
file "/etc/ssl/private/#{fqdn}.key" do
  owner 'root'
  group 'root'
  mode '0600'
  content item['key']
  notifies :reload, 'service[nginx]', :delayed
end

# nginx conf
directory '/etc/nginx/includes' do
  mode 0755
  action :create
end
template '/etc/nginx/includes/ro-ohmage' do
  source 'ohmage-nginx-ro.conf.erb'
  mode '0755'
  action :create
end

template '/etc/nginx/sites-available/ohmage' do
  source 'ohmage-nginx.conf.erb'
  mode '0775'
  action :create
  variables(
    ssl_name: fqdn,
    ocpu: 'ocpu.ohmage.org',
    read_only: false
  )
  notifies :reload, 'service[nginx]', :delayed
end
nginx_site 'ohmage' do
  action :enable
end

directory '/var/log/ohmage' do
  mode 0755
  owner 'tomcat7'
  group 'tomcat7'
  action :create
end

directory '/var/lib/ohmage' do
  mode 0755
  owner 'tomcat7'
  group 'tomcat7'
  action :create
end

%w(audits audio images documents videos).each do |dir|
  directory "/var/lib/ohmage/#{dir}" do
   mode 0755
   owner 'tomcat7'
   group 'tomcat7'
   action :create
  end
end