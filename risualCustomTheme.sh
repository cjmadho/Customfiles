#############################################################################

# Log a message

#############################################################################



log()

{

    # By default, we'd like logged messages to be sent to syslog. 

    # We also want to enable logging for error messages

    

    # $1 - the message to log

    # $2 - flag for error message = 1 (only presence test)

    

    TIMESTAMP=`date +"%D %T"`

    

    # check if this is an error message

    LOG_MESSAGE="${TIMESTAMP} :: $1"

    

    if [ ! -z $2 ]; then

        # stderr logging

        LOG_MESSAGE="${TIMESTAMP} :: [ERROR] $1"

        echo $LOG_MESSAGE >&2

    else

        echo $LOG_MESSAGE

    fi

    

    # send the message to syslog

    logger $1 >> /var/log/risualThemeLog


}



log "Adding and compiling risual theme"

sudo mv /edx/app/edxapp/themes /edx/app/edxapp/themes.old


log "Cloning risual Repo for risual theme"



sudo git clone --branch oxa/master.fic https://github.com/risualSupport/edx-theme.git /edx/app/edxapp/themes



log "Change ownership on the folder"



sudo chown -R edxapp:edxapp /edx/app/edxapp/themes



sudo chmod -R u+rw /edx/app/edxapp/themes

log "Compile the themes"

sudo -H -u edxapp bash



source /edx/app/edxapp/edxapp_env



cd /edx/app/edxapp/edx-platform



paver update_assets lms --settings=aws

exit

log "Restart website"



sudo /edx/bin/supervisorctl restart edxapp:lms



log "risual Done"

exit 0
