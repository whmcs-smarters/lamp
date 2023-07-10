#!/bin/bash
# This script will install LAMP in Ubuntu 22.04
echo -e "\e[32mWelcome to LAMP Installation & Configuration Script\e[0m"
# Take Permission to Continue
until [[ $CONTINUE =~ (y|n) ]]; do
read -rp "Continue? [y/n]: " -e CONTINUE
done
if [[ $CONTINUE == "n" ]]; then
echo -e "\e[31mInstallation aborted\e[0m"
exit 1
fi
echo -e "\e[32mUpdating the repository\e[0m"
sudo apt-get update -y 
# Install Apache, MySQL, PHP
echo -e "\e[32mInstalling Apache, MySQL, PHP\e[0m"
# check if apache is already installed
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is already installed\e[0m"
until [[ $apache =~ (y|n) ]]; do
read -rp "Do you want to install Apache? [y/n]: " -e -i "n" apache
done
else
until [[ $apache =~ (y|n) ]]; do
read -rp "Do you want to install Apache? [y/n]: " -e -i "y" apache
done
fi
if [[ $apache == "y" ]]; then
sudo apt-get install apache2 -y
# Enable Apache Mods
sudo a2enmod rewrite
# Restart Apache
sudo systemctl restart apache2
echo -e "\e[32mApache Installed and Restart Successfully\e[0m"
echo "Apache Version: $(apache2 -v | grep -i apache | awk '{print $1 $3}')"
fi
# Install MySQL with defined password
echo -e "\e[32mInstalling MySQL\e[0m"
#check if mysql is already installed
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is already installed\e[0m"
until [[ $mysql =~ (y|n) ]]; do
read -rp "Do you want to install MySQL? [y/n]: " -e -i "n" mysql
done
else
until [[ $mysql =~ (y|n) ]]; do
read -rp "Do you want to install MySQL? [y/n]: " -e -i "y" mysql
done
fi
if [[ $mysql == "y" ]]; then
# Generate Random Password
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
echo -e "MySQL Installed with Password: \e[1m$MYSQL_ROOT_PASSWORD\e[0m"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
echo -e "\e[32mMySQL Installed Successfully\e[0m"
# Create a database for the domain name provided by the user
echo "Creating Database User"
until [[ $createuser =~ (y|n) ]]; do
read -rp "Do you want to create Database and DB User? [y/n]: " -e -i "y" createuser
done
if [[ $createuser == "y" ]]; then
# Create a database for the domain name provided by the user
echo -e "\e[32mCreating Database and DB User\e[0m"
# Input the database name
echo "Enter the database name:"
read database_name
# Create a database
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $database_name;"
echo -e "\e[32mDatabase Created Successfully\e[0m"
# show databases
echo "Showing Databases"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "show databases;"
echo "Database Configuration Script Completed"
# Create a database user for the domain name provided by the user
echo "Creating Database User"
# Input the database user name
echo "Enter the database user name: "
read database_user
# Input the database user password
echo "Enter the database user password: "
read database_user_password
# Create a database user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$database_user'@'localhost' IDENTIFIED BY '$database_user_password';"
# Grant privileges to the database user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $database_name.* TO '$database_user'@'localhost';"
# Flush privileges
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
echo "Database User: \e[1m$database_user\e[0m"
echo "Database User Password: \e[1m$database_user_password\e[0m"
echo "Database Name: \e[1m$database_name\e[0m"
echo -e "\e[32mDatabase User Created Successfully\e[0m"
fi
fi

# check if PHP is already installed
php=$(dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed")
if [ $php -eq 1 ]; then
echo -e "\e[32mPHP is already installed\e[0m"
until [[ $php =~ (y|n) ]]; do
read -rp "Do you want to install PHP 8.1 and its modules? [y/n]: " -e -i "n" php
done
else
# Install PHP 8.1 and its modules ubuntu 22.04
echo -e "\e[32mInstalling PHP 8.1 and its modules\e[0m"
until [[ $php =~ (y|n) ]]; do
read -rp "Do you want to install PHP 8.1 and its modules? [y/n]: " -e -i "y" php
done
if [[ $php == "y" ]]; then
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install php8.1 -y
sudo apt install unzip
sudo apt-get install php8.1-{bcmath,bz2,intl,gd,mbstring,mysql,zip,curl} -y
sudo apt-get install php libapache2-mod-php php-mysql -y
# Restart Apache
sudo systemctl restart apache2
echo -e "\e[32mPHP Installed Successfully\e[0m"
echo "PHP Version: $(php -v | grep -i cli | awk '{print $1 $2}')"
fi
fi
# Create Virtual Host for the domain name provided by the user
until [[ $vhost =~ (y|n) ]]; do 
read -rp "Do you want to create Virtual Host? [y/n]: " -e -i "y" vhost
done
if [[ $vhost == "y" ]]; then
echo "Creating Virtual Host"
# Input the domain name
echo "Enter the domain name: "
read domain_name
# create a directory for the domain name
echo "Creating Directory for $domain_name"
sudo mkdir -p /var/www/vhosts/${domain_name}/public/
# Create a virtual host file
echo "Creating Virtual Host File for $domain_name"
cat >> /etc/apache2/sites-available/${domain_name}.conf <<EOF
<VirtualHost *:80>
<Directory /var/www/vhosts/${domain_name}/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
     </Directory>
    ServerAdmin webmaster@${domain_name}
    ServerName ${domain_name}
    ServerAlias www.${domain_name}
    DocumentRoot /var/www/vhosts/${domain_name}/public/
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
# Enable the virtual host
sudo a2ensite $domain_name.conf
# Disable the default virtual host
sudo a2dissite 000-default.conf
# Restart Apache
sudo systemctl restart apache2
echo "Virtual Host Created Successfully for $domain_name"
echo "Virtual Host Configuration Script Completed"
# create a php file to test PHP
sudo echo "<?php phpinfo(); ?>" > /var/www/vhosts/${domain_name}/public//info.php
fi
########## Install Let's Encrypt SSL Certificate for the domain name provided by the user ##########
until [[ $ssl =~ (y|n) ]]; do
read -rp "Do you want to install SSL Certificate? [y/n]: " -e -i "y" ssl
done
if [[ $ssl == "y" ]]; then
echo "Installing SSL Certificate"
# Update the repository
echo "Updating the repository"
sudo apt-get update -y
# # Input the domain name
# echo "Enter the domain name for SSL Certificate: "
# read domain_name
# # Install Certbot
echo "Installing Certbot"
sudo apt-get install certbot python3-certbot-apache -y
echo -e "\e[32mCertbot Installed Successfully\e[0m"
# Install SSL Certificate
echo "Installing SSL Certificate for $domain_name"
# Install SSL Certificate with www and non-www domain name and without email address
until [[ $subdomain =~ (y|n) ]]; do
read -rp "Is it a subdomain? (y/n): " -e -i "n" subdomain
done
if [ $subdomain == "y" ]
then
    sudo certbot --apache -d $domain_name --register-unsafely-without-email --agree-tos -n
elif
    [ $subdomain == "n" ]
then
    sudo certbot --apache -d $domain_name -d www.$domain_name --register-unsafely-without-email --agree-tos -n 
fi
# Enable SSL
sudo a2enmod ssl
sudo systemctl restart apache2
echo -e "\e[32mSSL Certificate Installed Successfully\e[0m"
fi
echo -e "\e[32mScript Completed Successfully\e[0m"
