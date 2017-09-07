mv /edx/app/edxapp/lms.env.json /edx/app/edxapp/lms.env.json.bak
CD /
git clone https://github.com/risualSupport/Customfiles.git 
cp -f /Customfiles/lms.env.json /edx/app/edxapp/lms.env.json 
/edx/bin/supervisorctl restart edxapp: 
