#!/bin/sh
# This script will install the Smarters Panel on your server.
# Created by Amanpreet Singh (www.whmcssmarters.com)
# Version 1.0
# License: MIT License
# check if user is root

if [ $(id -u) != "0" ]; then
echo "Error: You must be root to run this script, please use root to install the Smarters Panel"
exit 1
fi
clear
echo "#############################################################"
echo "# Smarters Panel Auto Install Script #"
echo "# Created by Amanpreet Singh (www.whmcssmarters.com) #"
echo "# Version 1.0 #"
echo "# License: MIT License #"
echo "#############################################################"
echo ""
echo "This script will install the Smarters Panel on your server."
echo ""
cd /va
