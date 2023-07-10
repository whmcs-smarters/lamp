#!/bin/bash
# This script is used to install the software - Smarters Panel v1.0
# Download zip file 
ZIP_FILE=https://www.dropbox.com/s/g2ihowweblmlz41/smarterspanel.zip
wget -O /var/www/vhosts/demo.smarterspanel.com/ $ZIP_FILE
cd /var/www/vhosts/demo.smarterspanel.com/
unzip smarterspanel.zip
rm -rf smarterspanel.zip
chown -R apache:apache /var/www/vhosts/demo.smarterspanel.com/
chmod -R 755 /var/www/vhosts/demo.smarterspanel.com/storage/framework/
chmod -R 755 /var/www/vhosts/demo.smarterspanel.com/storage/logs/
chmod -R 755 /var/www/vhosts/demo.smarterspanel.com/bootstrap/cache/
echo "Smarters Panel v1.0 installed successfully"
echo "Please visit http://demo.smarterspanel.com to access the panel and Complete the installation"