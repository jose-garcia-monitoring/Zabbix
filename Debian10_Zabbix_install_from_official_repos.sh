#!/bin/bash

# STILL WORKING ON IT!!!!!

# This script will install Zabbix 5.2 from repositories
# in a fresh Debian 10 Buster installation.

#------------------------------------------------------------------------------#

#############
# VARIABLES #
#############

REPO_FILE=/etc/apt/sources.list
SERVER_FILE=/etc/zabbix/zabbix_server.conf
NGINX_FILE=/etc/zabbix/nginx.conf
LOCALES=/usr/share/zabbix/include/locales.inc.php

# Adapting repositories from "Debian Sources List Generator"
#                            (https://debgen.simplylinux.ch)

read -d '' REPO << EOF
#------------------------------------------------------------------------------#
#                   OFFICIAL DEBIAN REPOS
#------------------------------------------------------------------------------#

###### Debian Main Repos
deb http://deb.debian.org/debian/ stable main non-free
deb-src http://deb.debian.org/debian/ stable main non-free

deb http://deb.debian.org/debian/ stable-updates main non-free
deb-src http://deb.debian.org/debian/ stable-updates main non-free

deb http://deb.debian.org/debian-security stable/updates main
deb-src http://deb.debian.org/debian-security stable/updates main

#------------------------------------------------------------------------------#
#                      UNOFFICIAL  REPOS
#------------------------------------------------------------------------------#

###### 3rd Party Binary Repos
###zabbix
deb http://repo.zabbix.com/zabbix/5.2/debian buster main
deb-src http://repo.zabbix.com/zabbix/5.2/debian buster main

###nginx
deb [arch=amd64] http://nginx.org/packages/debian/ buster nginx
deb-src [arch=amd64] http://nginx.org/packages/debian/ stretch nginx

###PostgreSQL
deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main
EOF

# Making backup for actual repositories
cp "$REPO_FILE" "${REPO_FILE}.BAK"

# Writing new repositories
echo "$REPO" > "$REPO_FILE"

# Updating repositories
apt update
#apt update 2>/dev/null | grep packages | cut -d '.' -f 1

# Installing other requirements.
apt install -y gnupg2 locate sudo wget

# Adding GPG keys for nginx and PostgreSQL repositories
wget https://nginx.org/keys/nginx_signing.key && apt-key add nginx_signing.key
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc \
| apt-key add -

# Installing Zabbix.
apt install -y zabbix-server-pgsql postgresql zabbix-frontend-php php7.3-pgsql \
zabbix-nginx-conf zabbix-agent zabbix-agent2 snmptrapd lm-sensors \
odbc-postgresql snmp-mibs-downloader

# Creating PostgreSQL database for Zabbix
echo 'What is the Zabbix database password?'
read -s PASS
#echo "create user zabbix with encrypted password '$PASS';" \
#| sudo -u postgres psql
#sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
zcat /usr/share/doc/zabbix-server-pgsql*/create.sql.gz \
| sudo -u zabbix psql zabbix

# Making backup for actual Zabbix server configuration file.
cp "$SERVER_FILE" "${SERVER_FILE}.BAK"

# Changing database password in Zabbix server configuration file.
sed -i 's/# DBPassword=/DBPassword=zabbix/g' /etc/zabbix/zabbix_server.conf

# Making backup for actual Nginx configuration file.
cp "$NGINX_FILE" "${NGINX_FILE}.BAK"

# Changing configuration for nginx server.
sed  -i '/^#.* listen /s/^#//' "$NGINX_FILE"
sed  -i '/^#.* server_name /s/^#//' "$NGINX_FILE"

#rm /etc/nginx/sites-enabled/default

# Making backup for actual Zabbix locales.inc.php file.
cp "$LOCALES" "${LOCALES}.BAK"

# Enabling Spanish language for Zabbix.
awk '/es_ES/{sub(/false/, "true")} 1' ${LOCALES}.BAK $LOCALES 

# Updating the filename database.
updatedb

systemctl restart zabbix-server nginx php7.3-fpm zabbix-agent zabbix-agent2
systemctl enable zabbix-server nginx php7.3-fpm zabbix-agent zabbix-agent2

# Archivo de configuracion de Zabbix.
# /usr/share/zabbix/conf/zabbix.conf.php
