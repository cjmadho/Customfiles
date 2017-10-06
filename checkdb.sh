#!/bin/bash
# =============================================================================
# Name: checkdb.sh
# Purpose: Check on the status of the database servers and their services
# Author:  David Brass (risual)
# Release: 1.0 15/08/2017
#	   1.1 29/08/2017 (added PARAMETER_FILE variable)
#          1.2 05/10/2017 (amended ssh parameters to know use known hosts)
# =============================================================================

PARAMETER_FILE=/home/risual-admin/db_servers
ALL_SERVERS=`cat $PARAMETER_FILE|cut -f2 -d: -s`
NOW=`date`
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "  Database Server Check  - $NOW"
echo "  ====================================================="
echo ""
for SERVER in $ALL_SERVERS
do
	SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
	echo -n "    Checking database server: $SERVER_NAME ... "
	if ping -qc 3 ${SERVER} > /dev/null; then
		echo -e -n "${GREEN}UP${NC}.  "
		MTYPE=`grep "${SERVER}" $PARAMETER_FILE|cut -f1 -d: -s`
        	if ssh  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q ${SERVER} ps -ef|grep ${MTYPE} &>/dev/null; then
			echo -e "${MTYPE} is ${GREEN}running${NC}."
		else
			echo -e "${MTYPE} is ${RED}not running${NC}."
		fi
	else
		echo -e "${RED}DOWN${NC}."
	fi
done
echo ""

# =============================================================================
# End of script
# =============================================================================
