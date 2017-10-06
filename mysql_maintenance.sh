#!/bin/bash
# =============================================================================
# Name: mysql_maintenance.sh
# Purpose: Perfrom MySQL maintenance tasks
# Author:  David Brass (risual)
# Release: 1.0 29/08/2017
#          1.1 05/10/2017 (Amended ssh parameters to avoid using known hosts)
# =============================================================================

PARAMETER_FILE=/home/risual-admin/db_servers
ALL_MYSQL_SERVERS=`cat $PARAMETER_FILE|grep mysql|cut -f2 -d: -s`
NOW=`date`
GREEN='\033[0;32m'
NC='\033[0m'
MYUSER=risualmysqladmin
MYPORT=3306

echo ""
echo "  MySQL Maintenance - $NOW"
echo "  ================================================="
echo ""
for SERVER in $ALL_MYSQL_SERVERS
do
	SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
        echo "    Connecting to MySQL server: $SERVER_NAME"
	echo ""
	OLDFILE=`ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q $SERVER ls -tr /var/log/mysql/mysql-bin-*|head -n 1`
	OLD_SEQUENCE=`echo $OLDFILE|tail -c 6`
	echo "      Purging binary logs older than 7 days ..."
	mysql --defaults-file=/home/risual-admin/.my.cnf -u $MYUSER -h $SERVER -P $MYPORT <<EOF
	PURGE BINARY LOGS BEFORE DATE_SUB( NOW( ), INTERVAL 7 DAY);
EOF
	NEWFILE=`ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q $SERVER ls -tr /var/log/mysql/mysql-bin-*|head -n 1`
	NEW_SEQUENCE=`echo $NEWFILE|tail -c 6`
	NEW_TIMESTAMP=`ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q $SERVER date -r $NEWFILE`
	COUNT=$((NEW_SEQUENCE-OLD_SEQUENCE))
	if [ $COUNT -eq 0 ]; then
	  echo "      No binary logs purged"
	  echo "      Last binary log on disk is ..."
	  echo "        Sequence: $NEW_SEQUENCE Timestamp: $NEW_TIMESTAMP"
	else
	  OLD_SEQUENCE=$((OLD_SEQUENCE-0))
	  LAST_PURGED=$((NEW_SEQUENCE-1))
	  echo "      $COUNT binary logs purged, from $OLD_SEQUENCE to $LAST_PURGED"
	  echo "      Last binary log on disk is ..."
	  echo "        Sequence: $NEW_SEQUENCE Timestamp: $NEW_TIMESTAMP"
	fi
	echo ""
done
echo ""

# =============================================================================
# End of Script
# =============================================================================
