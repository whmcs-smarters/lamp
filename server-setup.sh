#!/bin/bash
# get the domain name from the user as argument
while getopts ":d:" o
do
    case "${o}" in
    d) domain_name=${OPTARG}
    ;;
    esac
done
# check if domain name is provided or not
if [ -z "$domain_name" ]
then
    echo -e "\e[31mPlease provide the domain name with -d option\e[0m"
    exit 1
fi
# check if the domain name is valid or not
if [[ ! $domain_name =~ ^[a-zA-Z0-9]+([-.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$ ]]
then
    echo -e "\e[31mPlease provide a valid domain name\e[0m"
    exit 1
fi
# check if it's domain or sub domain
if [[ $domain_name =~ ^[a-zA-Z0-9]+([-.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$ ]]
then
    echo -e "\e[32mDomain Name: $domain_name\e[0m"
    isSubdomain = false;
else
    echo -e "\e[32mSub Domain Name: $domain_name\e[0m"
    isSubdomain = true;
fi
# This script will install LAMP in Ubuntu 22.04
echo -e "\e[32mWelcome to LAMP Installation & Configuration Script\e[0m"
# Check if the script is running on Ubuntu 22.04 or not
if [[ $(lsb_release -rs) != "22.04" ]]; then
echo -e "\e[31mYou are not running Ubuntu 22.04. This script is made for Ubuntu 22.04 only!\e[0m"
exit 1
fi
# Check if the script is running as root or not
if [ "$EUID" -ne 0 ]; then
echo -e "\e[31mPlease run this script as root\e[0m"
exit 1
fi
# Update the repository
echo -e "\e[32mUpdating the repository\e[0m"
sudo apt-get update -y 
# Install Apache, MySQL, PHP
echo -e "\e[32mInstalling Apache, MySQL, PHP\e[0m"
# check if apache is already installed
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is already installed\e[0m"
else
echo -e "\e[32mApache is installing..\e[0m"
sudo apt-get install apache2 -y
fi
# check if apache is already installed
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is installed\e[0m"
else
echo -e "\e[31mApache is not installed\e[0m"
exit 1
fi
# Enable Apache Mods
echo -e "\e[32mEnabling Apache Mods\e[0m"

sudo a2enmod rewrite
# Restart Apache
echo -e "\e[32mRestarting Apache\e[0m"
sudo systemctl restart apache2
echo -e "\e[32mApache Installed and Restart Successfully\e[0m"
echo "Apache Version: $(apache2 -v | grep -i apache | awk '{print $1 $3}')"
# Install MySQL with defined password
echo -e "\e[32mInstalling MySQL\e[0m"
#check if mysql is already installed
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is already installed\e[0m"
else
echo -e "\e[32mMySQL is installing..\e[0m"
# Generate Random Password
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
echo -e "MySQL Installed with Password: \e[1m$MYSQL_ROOT_PASSWORD\e[0m"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
echo -e "\e[32mMySQL Installed Successfully\e[0m"
fi
# check if mysql is already installed
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is installed\e[0m"
else
echo -e "\e[31mMySQL is not installed\e[0m"
exit 1
fi
# Create a database for the domain name provided by the user
echo "Creating Database User"
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
echo -e "\e[32mCreating Database and DB User\e[0m"
$database_name = "smarterspanel_db";
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $database_name;"
echo -e "\e[32mDatabase Created Successfully\e[0m"
# show databases
echo "Showing Databases"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "show databases;"
echo "Database Configuration Script Completed"
# Create a database user for the domain name provided by the user
echo "Creating Database User"
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
# Install PHP 8.1 and its modules ubuntu 22.04
echo -e "\e[32mInstalling PHP 8.1 and its modules\e[0m"
# check if PHP is already installed
php=$(dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed")
if [ $php -eq 1 ]; then
echo -e "\e[32mPHP is already installed\e[0m"
else
# Install PHP 8.1 and its modules ubuntu 22.04
echo -e "\e[32mInstalling PHP 8.1 and its modules\e[0m"
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

# Create Virtual Host for the domain name provided by the user
# create a directory for the domain name
# check if directory already exists
if [ -d "/var/www/vhosts/${domain_name}" ] 
then
echo -e "\e[32mDirectory already exists\e[0m"
rm -rf /var/www/vhosts/${domain_name}
echo -e "\e[32mDirectory deleted\e[0m"
echo -e "\e[32mCreating Directory for $domain_name\e[0m"
sudo mkdir -p /var/www/vhosts/${domain_name}/public/
else
echo -e "\e[32mCreating Directory for $domain_name\e[0m"
sudo mkdir -p /var/www/vhosts/${domain_name}/public/
fi
# Create a virtual host file
# check if virtual host file already exists
if [ -f "/etc/apache2/sites-available/${domain_name}.conf" ] 
then
echo -e "\e[32mVirtual Host File already exists\e[0m"
rm -rf /etc/apache2/sites-available/${domain_name}.conf
echo -e "\e[32mVirtual Host File deleted\e[0m"
fi
echo "Creating Virtual Host File for $domain_name"
if ($isSubdomain){
cat >> /etc/apache2/sites-available/${domain_name}.conf <<EOF
<VirtualHost *:80>
<Directory /var/www/vhosts/${domain_name}/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
     </Directory>
    ServerAdmin webmaster@${domain_name}
    ServerName ${domain_name}
    DocumentRoot /var/www/vhosts/${domain_name}/public/
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
}else
{
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
}
fi
# Enable the virtual host
sudo a2ensite $domain_name.conf
# Disable the default virtual host
sudo a2dissite 000-default.conf
# Restart Apache
sudo systemctl restart apache2
echo "Virtual Host Created Successfully for $domain_name"
echo "Virtual Host Configuration Script Completed"
# create a php file to test PHP
sudo echo "<?php phpinfo(); ?>" > /var/www/vhosts/${domain_name}/public/info.php
########## Install Let's Encrypt SSL Certificate for the domain name provided by the user ##########
echo "Installing SSL Certificate"
# Update the repository
echo "Updating the repository"
sudo apt-get update -y
echo "Installing Certbot"
sudo apt-get install certbot python3-certbot-apache -y
echo -e "\e[32mCertbot Installed Successfully\e[0m"
# Install SSL Certificate
echo "Installing SSL Certificate for $domain_name"
# if already SSL certificate exists for the domain name then delete it
if [ -d "/etc/letsencrypt/live/${domain_name}" ] 
then
echo -e "\e[32mSSL Certificate already exists\e[0m"
echo -e "\e[32mDeleting Existing SSL Certificate\e[0m"
sudo certbot delete --cert-name $domain_name
echo -e "\e[32mExisting SSL Certificate Deleted Successfully\e[0m"
fi
# Install SSL Certificate with www and non-www domain name and without email address
if($isSubdomain)
then
sudo certbot --apache -d $domain_name --register-unsafely-without-email --agree-tos -n
else
sudo certbot --apache -d $domain_name -d www.$domain_name --register-unsafely-without-email --agree-tos -n 
fi
sleep 5
# Enable SSL
echo "Enabling SSL"
sudo a2enmod ssl
sudo systemctl restart apache2
echo -e "\e[32mSSL Certificate Installed Successfully\e[0m"
echo -e "\e[32mScript Completed Successfully\e[0m"