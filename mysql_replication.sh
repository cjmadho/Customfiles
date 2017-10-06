#!/bin/bash
# =============================================================================
# Name: mysql_replication.sh
# Purpose: Check the status of the MySQL replication
# Author:  David Brass (risual)
# Release: 1.0 29/08/2017
# =============================================================================

PARAMETER_FILE=/home/risual-admin/db_servers
ALL_MYSQL_SERVERS=`cat $PARAMETER_FILE|grep mysql|cut -f2 -d: -s`
ALL_MYSQL_REPL_SLAVES=`cat $PARAMETER_FILE|grep mysql|grep slave|cut -f2 -d: -s`
NOW=`date`
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
MYUSER=risualmysqladmin
MYPORT=3306
STATUS=0

echo ""
echo "  MySQL Replication Status - $NOW"
echo "  ======================================================="
echo ""
for SERVER in $ALL_MYSQL_REPL_SLAVES
do
	SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
	STATUS=0
	echo "    Connecting to MySQL replication slave $SERVER_NAME"
	SQLCHECK=`mysql --defaults-file=/home/risual-admin/.my.cnf -u $MYUSER -h $SERVER -P $MYPORT -e "show slave status\G" |grep -i "Slave_SQL_Running:"|gawk '{print $2}'`
	IOCHECK=`mysql --defaults-file=/home/risual-admin/.my.cnf -u $MYUSER -h $SERVER -P $MYPORT -e "show slave status\G" |grep -i "Slave_IO_Running:"|gawk '{print $2}'`
	ERRORCHECK=`mysql --defaults-file=/home/risual-admin/.my.cnf -u $MYUSER -h $SERVER -P $MYPORT -e "show slave status\G" |grep -i "Last_Error:"|gawk '{print $2}'`
	SYNCCHECK=`mysql --defaults-file=/home/risual-admin/.my.cnf -u $MYUSER -h $SERVER -P $MYPORT -e "show slave status\G" |grep -i "Seconds_Behind_Master:"|gawk '{print $2}'`
	if [ "$SQLCHECK" = "No" ]; then
	STATUS=1
	fi
	if [ "$IOCHECK" = "No" ]; then
	STATUS=1
	fi
	if [ $STATUS = 1 ]; then
	  echo -e "      ${RED}There is a problem with the MySQL Replication"
	  echo -e "      Slave SQL running: $SQLCHECK"
	  echo -e "      Slave IO running: $IOCHECK"
	  echo -e "      Seconds Behind Master: $SYNCCHECK"
	  echo -e "      Last Error: $ERRORCHECK ${NC}"
	else
	  echo -e "      ${GREEN}MySQL Replication is applying data from the Master"
	  echo -e "      The replication is running $SYNCCHECK seconds behind Master ${NC}"
	fi
	echo ""
done
echo ""

# =============================================================================
# End of Script
# =============================================================================
