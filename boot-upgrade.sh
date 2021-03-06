#!/bin/bash

set -e

# Starts the DB and upgrade the data
db_pass=$(egrep '^\$sys_dbpasswd' /etc/tuleap/conf/database.inc | sed -e 's/^\$sys_dbpasswd="\(.*\)";$/\1/')
db_host=$(egrep '^\$sys_dbhost' /etc/tuleap/conf/database.inc | sed -e 's/^\$sys_dbhost="\(.*\)";$/\1/')
if [ "$db_host" == "localhost" ]
then
	host_string=""
	echo "Start mysql"
	/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/bin/mysqld_safe &
else
	host_string="-h $db_host"
	cp /etc/supervisord-nodb.conf /etc/supervisord.conf
fi

echo "Wait mysql"
sleep 1
while ! mysql -ucodendiadm -p$db_pass $host_string -e "show databases" >/dev/null; do 
    echo "Wait for the db";
    sleep 1
done

# On start, ensure db is consistent with data (useful for version bump)
/usr/lib/forgeupgrade/bin/forgeupgrade --config=/etc/codendi/forgeupgrade/config.ini update

# Ensure system will be synchronized ASAP (once system starts)
/usr/share/tuleap/src/utils/php-launcher.sh /usr/share/tuleap/src/utils/launch_system_check.php

# Stop Mysql
if [ "$db_host" == "localhost" ]
then
	echo "Stop mysql"
	PID=$(cat /var/run/mysqld/mysqld.pid)
	kill -15 $PID
	while ps -p $PID >/dev/null 2>&1; do
    		echo "Waiting for mysql ($PID) to stop"
    		sleep 1
	done
fi
