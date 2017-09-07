sudo mv /edx/app/edxapp/lms.env.json /edx/app/edxapp/lms.env.json.bak
sudo cp -f /etc/risualCustom/lms.env.json /edx/app/edxapp/lms.env.json 
sudo /edx/bin/supervisorctl restart edxapp: 
