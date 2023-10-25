#!/bin/bash

# Function to check the last command execution
function check_last_command_execution {
if [ $? -eq 0 ]; then
echo -e "\e[32m$1\e[0m"
else
echo -e "\e[31m$2\e[0m"
# remove files
rm -rf /root/install-webplayer.sh 2> /dev/null # remove files
echo "Check Logs for more details: install-webplayer.log"
exit 1
fi
}
## Function Node JS Installation ##
function install_nodejs {
echo "Installing NodeJS"
# install nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
check_last_command_execution "NodeJS Installed Successfully" "NodeJS Installation Failed.Exit the script"
}
# function to install nginx
function install_nginx {
echo "Installing Nginx"
# install nginx
sudo apt-get install -y nginx
check_last_command_execution "Nginx Installed Successfully" "Nginx Installation Failed.Exit the script"
}



apt-get update  -y && apt-get install -y wget
#install nginx for ubuntu 20.04
apt-get install -y nginx

