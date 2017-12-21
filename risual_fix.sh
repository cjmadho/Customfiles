#!/bin/bash
# =============================================================================
# Name: risual_fix.sh
# Purpose: Perfrom fixes for deployed OpenEdX environment
# Author:  David Brass (risual) Modified: Daniel Cubley (risual)
# Release: 1.0 08/09/2017
#          1.1 05/10/2017 (amended ssh connections to avoid using known hosts)
#                         (amended mongodb pid location)
#                         (changed backup script to use new location)
#                         (corrected path for mongo script in crontab)
#                         (added powerbi_ro account for MySQL)
#          1.2 15/12/2017 (Amended oxa-tools2 to oxa-tools5)
#          1.3 21/12/2017 (copy custom files into the correct directory following deployment)
#                         (amended oxatools5 backup script for container name)
#                         (amended AZURE_CONNECTION_STRING in both backup configuration files)
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

PARAMETER_FILE=/etc/risualCustom/db_servers
HOSTNAME=`hostname`
CRON_MYSQL_LOG_PURGE="0 17 * * * sudo /home/risual-admin/mysql_maintenance.sh > /home/risual-admin/mysql_maintenance.log 2>&1"
CRON_MONGO_BACKUP="0 16 * * * sudo bash /oxa/oxa-tools5/scripts/db_backup.sh.mongo"
ALL_MYSQL_SERVERS=`cat $PARAMETER_FILE|grep mysql|cut -f2 -d: -s`
ALL_MONGO_SERVERS=`cat $PARAMETER_FILE|grep mongo|cut -f2 -d: -s`
NOW=`date`
GREEN='\033[0;32m'
NC='\033[0m'
MYUSER=risualmysqladmin
MYPORT=3306
STATUS_FILE=/home/risual-admin/.risual_fix_executed
ENV_NAME=`hostname | rev | cut -c3- | rev`

# =============================================================================
# Execution Checks
# =============================================================================

if [ $EUID != 0 ]; then
	echo ""
	echo "  This script must be run with root permission ... exiting"
	echo ""
	exit
fi

if [ -f $STATUS_FILE ]; then
	echo ""
	echo "  This script has already been executed in this environment ... exiting"
	echo ""
	exit
fi

date > $STATUS_FILE

# =============================================================================
# Functions
# =============================================================================

copy_files() {
cp -r /etc/risualCustom/. /home/risual-admin/
chmod +x /home/risual-admin/*.sh
}

local_crontab() {
echo ""
echo "  Amending crontab entries for database backups"
echo ""
echo "  Adding crontab entry for MySQL binary log purge"
echo ""

(crontab -l; echo "# Start of changes by risual" ) 2> /dev/null | crontab -
crontab -l | grep -v "db_backup.sh.mongo" | crontab -
crontab -l | grep -v "mysql_maintenance.sh" | crontab -
(crontab -l; echo "$CRON_MONGO_BACKUP" ) 2> /dev/null | crontab -
(crontab -l; echo "$CRON_MYSQL_LOG_PURGE" ) 2> /dev/null | crontab -
(crontab -l; echo "# End of changes by risual" ) 2> /dev/null | crontab -
crontab -l | grep '[^[:blank:]]' | crontab -

echo "  New root crontab for $HOSTNAME"
echo ""
crontab -l
echo ""
}

mongo_parameters() {
echo "  Amending mongod.conf to ensure fork=true"
echo ""

for SERVER in $ALL_MONGO_SERVERS
do
	SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER "sudo sed -i 's/fork: false/fork: true/g' /etc/mongod.conf"
	echo "    updating /etc/mongod.conf on $SERVER_NAME"
done

echo ""
echo "  Amending mongod.conf to ensure correct pidFilePath"
echo ""

for SERVER in $ALL_MONGO_SERVERS
do
        SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER "sudo sed -i 's#/var/run/mongodb/mongod.pid#/datadisks/disk1/mongodb/db/mongod.pid#g' /etc/mongod.conf"
        echo "    updating /etc/mongod.conf on $SERVER_NAME"
done
}

mongo_logrotate() {
echo ""
echo "  Setting up logrotate for the mongo database server log files"
echo ""

for SERVER in $ALL_MONGO_SERVERS
do
        SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
	echo "    updating /etc/mongod.conf on $SERVER_NAME"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER "sudo sed -i 's/logAppend: true/logAppend: true\n    logRotate: reopen/' /etc/mongod.conf"
	echo "    creating /etc/logrotate.d/mongodb on $SERVER_NAME"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo dd of=/etc/logrotate.d/mongodb << EOF
/mongo/log/*.log {
    daily

rotate 7
    compress
    dateext
    missingok
    notifempty
    sharedscripts
    copytruncate
    postrotate
        /bin/kill -SIGUSR1 \`cat /mongo/db/mongod.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}
EOF
done
}

mongo_reboot() {
echo ""
echo "  Rebooting mongo database servers for the changes to take effect"
echo ""

for SERVER in $ALL_MONGO_SERVERS
do
        SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER "sudo reboot"
done
}

mysql_logrotate() {
echo ""
echo "  Setting up logrotate for the MySQL database server log files"
echo ""

for SERVER in $ALL_MYSQL_SERVERS
do
        SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
        echo "    creating /root/.my.cnf on $SERVER_NAME"
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo dd of=/root/.my.cnf << EOF
[client]
password=Risual4404
EOF
        echo "    creating /etc/logrotate.d/mysql-server on $SERVER_NAME"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo dd of=/etc/logrotate.d/mysql-server << EOF
/var/log/mysql/*.log {
        daily
        rotate 7
        missingok
        create 640 mysql adm
        compress
        sharedscripts
        postrotate
                # run if mysqld is running
                if ps -ef|grep mysqld &>/dev/null; then
                /usr/bin/mysqladmin --defaults-file=/root/.my.cnf -u risualmysqladmin flush-logs
                fi
        endscript
}
EOF
done}

mysql_data_location() {
echo ""
echo "  Moving the MySQL data file location to /datadisks/disk1/mysql"
echo ""

for SERVER in $ALL_MYSQL_SERVERS
do
        SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
	echo "    Relocating MySQL data on $SERVER_NAME"
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo systemctl stop mysqld
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo rsync -av /var/lib/mysql /datadisks/disk1/
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo mv /var/lib/mysql /var/lib/mysql.old
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo ln -s /datadisks/disk1/mysql /var/lib/mysql
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER "sudo sed -i 's#datadir=/var/lib/mysql#datadir=/datadisks/disk1/mysql#' /etc/mysql/conf.d/mysqld.cnf"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo tee -a /etc/apparmor.d/tunables/alias << EOF
alias /var/lib/mysql/ -> /datadisks/disk1/mysql,
EOF
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo systemctl restart apparmor
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER sudo systemctl start mysqld
done
}

mysql_reboot() {
echo ""
echo "  Rebooting MySQL database servers for the changes to take effect"
echo ""

for SERVER in $ALL_MYSQL_SERVERS
do
        SERVER_NAME=`grep $SERVER $PARAMETER_FILE|cut -f3 -d: -s`
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q risual-admin@$SERVER "sudo reboot"
done
}

backup_script() {
echo ""
echo "  Amending MySQL Backup script to use shared backup storage account"
echo ""

cp /oxa/oxa-tools5/scripts/backup_configuration_mysql.sh /oxa/oxa-tools5/scripts/backup_configuration_mysql.sh.orig
sed -i '1s/.*/BACKUP_STORAGEACCOUNT_NAME=risedulrnbackups/' /oxa/oxa-tools5/scripts/backup_configuration_mysql.sh
sed -i '2s/.*/BACKUP_STORAGEACCOUNT_KEY=Ucy7jysAPEj2vWU72YtPAWM67UnMvlVjzUmdETurGcMF+N7Lr38PB0LCYgeC9WvRm5qz+ptmXEXvzwXBdfN7vQ==/' /oxa/oxa-tools5/scripts/backup_configuration_mysql.sh
sed -i '15s/.*/AZURE_STORAGEACCOUNT_CONNECTIONSTRING=DefaultEndpointsProtocol=https;AccountName=risedulrnbackups;AccountKey=Ucy7jysAPEj2vWU72YtPAWM67UnMvlVjzUmdETurGcMF+N7Lr38PB0LCYgeC9WvRm5qz+ptmXEXvzwXBdfN7vQ==;EndpointSuffix=core.windows.net' /oxa/oxa-tools5/scripts/backup_configuration_mysql.sh

echo ""
echo "  Amending Mongo Backup script to use shared backup storage account"
echo ""

cp /oxa/oxa-tools5/scripts/backup_configuration_mongo.sh /oxa/oxa-tools5/scripts/backup_configuration_mongo.sh.orig
sed -i '1s/.*/BACKUP_STORAGEACCOUNT_NAME=risedulrnbackups/' /oxa/oxa-tools5/scripts/backup_configuration_mongo.sh
sed -i '2s/.*/BACKUP_STORAGEACCOUNT_KEY=Ucy7jysAPEj2vWU72YtPAWM67UnMvlVjzUmdETurGcMF+N7Lr38PB0LCYgeC9WvRm5qz+ptmXEXvzwXBdfN7vQ==/' /oxa/oxa-tools5/scripts/backup_configuration_mongo.sh
sed -i '15s/.*/AZURE_STORAGEACCOUNT_CONNECTIONSTRING=DefaultEndpointsProtocol=https;AccountName=risedulrnbackups;AccountKey=Ucy7jysAPEj2vWU72YtPAWM67UnMvlVjzUmdETurGcMF+N7Lr38PB0LCYgeC9WvRm5qz+ptmXEXvzwXBdfN7vQ==;EndpointSuffix=core.windows.net' /oxa/oxa-tools5/scripts/backup_configuration_mongo.sh

echo ""
echo "  Amending core backup script to use modified container name"
echo ""

cp /oxa/oxa-tools5/scripts/db_backup.sh /oxa/oxa-tools5/scripts/db_backup.sh.orig
sed -i '137s/.*/    CONTAINER_NAME=`echo "${HOSTNAME,,}" | rev | cut -c3- | rev`/' /oxa/oxa-tools5/scripts/db_backup.sh
sed -i '138s/.*/    CONTAINER_NAME="$CONTAINER_NAME-${DATABASE_TYPE}-backup"/' /oxa/oxa-tools5/scripts/db_backup.sh
}

powerbi_ro_user () {
echo ""
echo "  Adding MySQL PowerBI Reporting User"
echo ""

mysql --defaults-file=/home/risual-admin/.my.cnf -u $MYUSER -h 10.0.0.16 -P $MYPORT <<EOF
CREATE USER 'powerbi'@'10.0.0.6' IDENTIFIED BY 'Risual4404';
GRANT SELECT ON *.* TO 'powerbi'@'10.0.0.6';
FLUSH PRIVILEGES;
EOF
}

# =============================================================================
# Call block
# =============================================================================

echo "  ==========================================================================="
echo "  risual fix script executing on $HOSTNAME on $NOW"
echo "  ==========================================================================="

copy_files
local_crontab
mongo_parameters
mongo_logrotate
mongo_reboot
mysql_logrotate
powerbi_ro_user
mysql_data_location
mysql_reboot
backup_script

# =============================================================================
# Finishing Output
# =============================================================================

NOW=`date`
echo ""
echo "  Script Completed at $NOW"
echo ""

# =============================================================================
# End of Script
# =============================================================================
