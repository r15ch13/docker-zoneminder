#!/bin/bash


set -e

if [ -f /etc/configured ]; then
        echo 'already configured'
        
        /sbin/zm.sh&
else
        #to fix problem with data.timezone that appear at 1.28.108 for some reason
        sed -i 's/\;date.timezone =/date.timezone = \"$PHP_TIMEZONE\"/' /etc/php/7.0/apache2/php.ini
        #configuration for zoneminder
        #trays to fix problem with https://github.com/QuantumObject/docker-zoneminder/issues/22
        chown www-data /dev/shm
        cp /etc/mysql/mysql.conf.d/mysqld.cnf /usr/my.cnf
        #this only happends if -V was used and data was not from another container for that reason need to recreate the db.
        if [ ! -f /var/lib/mysql/ibdata1 ]; then
          chown -R mysql:mysql /var/lib/mysql 
          #mysql_install_db
          mysqld --initialize-insecure=on
          #create database for zm
          /usr/bin/mysqld_safe &
          sleep 7s
          mysqladmin -u root password mysqlpsswd
          mysqladmin -u root -pmysqlpsswd reload
          mysqladmin -u root -pmysqlpsswd create zm
          echo "grant select,insert,update,delete on zm.* to 'zmuser'@localhost identified by 'zmpass'; flush privileges; " | mysql -u root -pmysqlpsswd
          mysql -u root -pmysqlpsswd < /usr/share/zoneminder/db/zm_create.sql
          killall mysqld
          sleep 5s
        fi
        
        #check if Directory inside of /var/cache/zoneminder are present.
        if [ ! -d /var/cache/zoneminder/events ]; then
           mkdir -p /var/cache/zoneminder/events
           mkdir -p /var/cache/zoneminder/images
           mkdir -p /var/cache/zoneminder/temp
        fi
        
        chown -R root:www-data /var/cache/zoneminder /etc/zm/zm.conf
        chown -R mysql:mysql /var/lib/mysql 
        chmod -R 770 /var/cache/zoneminder /etc/zm/zm.conf
        
        #needed to fix problem with ubuntu ... and cron 
        update-locale
        date > /etc/configured
        
        /sbin/zm.sh&
fi
