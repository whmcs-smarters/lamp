#!/bin/bash
# This script will install LAMP in Ubuntu 22.04
echo -e "\e[1;43mWelcome to Smarters Panel Installation with LAMP\e[0m"
# USAGE: ./server-setup.sh -d domain_name -p repo_password -m mysql_password
# EXAMPLE: ./server-setup.sh -d example.com -p password -m password
# Get the options from user input
while getopts ":d:p:m:" o
do
case "${o}" in
d) domain_name=${OPTARG};;
p) repo_pass=${OPTARG};;
m) mysql_root_pass=${OPTARG};;
esac
done
# Start logging the script
echo -e "\033[33mLogging the script into server-setup.log\e[0m"
exec > >(tee -i server-setup.log)
exec 2>&1

# Functions Declaration


# function to check if last command executed successfully or not with message
function check_last_command_execution {
if [ $? -eq 0 ]; then
echo -e "\e[32m$1\e[0m"
else
echo -e "\e[31m$2\e[0m"
exit 1
fi
}
# function to install apache
function install_apache {
# Install Apache
echo -e "\e[32mInstalling Apache\e[0m"
sudo apt-get install apache2 -y
check_last_command_execution "Apache Installed Successfully" "Apache Installation Failed"
# Enable Apache Mods
echo -e "\e[32mEnabling Apache Mods\e[0m"
sudo a2enmod rewrite
check_last_command_execution "Apache Mods Enabled Successfully" "Apache Mods Enabling Failed"
# Restart Apache
echo -e "\e[32mRestarting Apache\e[0m"
sudo systemctl restart apache2
check_last_command_execution "Apache Restarted Successfully" "Apache Restarting Failed"
}
# function to install mysql with default password
function install_mysql_with_defined_password {
# Install MySQL with default password
MYSQL_ROOT_PASSWORD=$1
echo -e "\e[32mInstalling MySQL\e[0m"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
check_last_command_execution "MySQL Installed with Password: $MYSQL_ROOT_PASSWORD" "MySQL Installation Failed"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
}
# function to create database and database user
function create_database_and_database_user {
MYSQL_ROOT_PASSWORD=$1
# Create a database for the domain name provided by the user
echo -e "\e[32mCreating Database and DB User\e[0m"
database_name="smarterspanel_db";
# create database if not exists
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $database_name;"
check_last_command_execution "Database $database_name Created Successfully" "Database $database_name Creation Failed"
# show databases
echo "Showing Databases"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "show databases;"
# Generating Random Username and Password for Database User
database_user="$(openssl rand -base64 12)"
# Create a database user for the domain name provided by the user
database_user_password="$(openssl rand -base64 12)"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$database_user'@'localhost' IDENTIFIED BY '$database_user_password';"
# Grant privileges to the database user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $database_name.* TO '$database_user'@'localhost';"
# Flush privileges
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
check_last_command_execution "Database User Created Successfully" "Database User Creation Failed"
echo "*************** Database Details ******************"
echo "Database Name: $database_name"
echo "Database User: $database_user"
echo "Database User Password: $database_user_password"
# store database details in file
echo "Storing Database Details in file"
sudo truncate -s 0 /root/database_details.txt
cat > /root/database_details.txt <<EOF
database_name=$database_name
database_user=$database_user
database_user_password=$database_user_password
EOF
}
# function to get mysql details from the file
function get_mysql_details_from_file {
# get database details from file
database_name=$(cat /root/database_details.txt | grep database_name | cut -d'=' -f2)
database_user=$(cat /root/database_details.txt | grep database_user | cut -d'=' -f2)
database_user_password=$(cat /root/database_details.txt | grep database_user_password | cut -d'=' -f2)
}

# function to install php and modules with desired version
function install_php_with_desired_version {
desired_version=$1
# installed desired version of php
echo -e "\e[32mInstalling PHP $desired_version\e[0m"
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install php$desired_version -y
sudo apt install unzip
sudo apt-get install php$desired_version-{bcmath,bz2,intl,gd,mbstring,mysql,zip,curl,xml,cli} -y
}
# function to remove mysql completely
function remove_mysql_completely {
# remove mysql completely
echo "Removing MySQL completely with configuration files"
sudo service mysql stop
sudo apt purge mysql-server mysql-client mysql-common -y
sudo apt autoremove -y
sudo rm -rf /etc/mysql
sudo rm -rf /var/lib/mysql
check_last_command_execution "MySQL Removed Completely" "MySQL Removal Failed"
}
function create_virtual_host {
domain_name=$1
# Define the variables
document_root="/var/www/$domain_name"
# Create the document root directory
mkdir -p "$document_root"
# sudo chown -R www-data:www-data $document_root
# sudo chmod -R 755 $document_root
# Create the virtual host file
virtual_host_file="/etc/apache2/sites-available/$domain_name.conf"
sudo truncate -s 0 "$virtual_host_file"
cat << EOF > "$virtual_host_file"
<VirtualHost *:80>
    ServerName $domain_name
    DocumentRoot $document_root/public/
    <Directory $document_root/public/>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
# Enable the virtual host
a2ensite "$domain_name.conf"
# Restart Apache
systemctl restart apache2
echo "Creating index.php file to welcome message"
#sudo echo "<?php echo 'Welcome to $domain_name'; ?>" > $document_root/public/index.php
echo "Virtual host for $domain_name created successfully!"
}
# function to check domain or sub domain
function check_domain {
# Get the input from user
input=$1
# Split the input into an array using dot as the delimiter
IFS='.' read -ra parts <<< "$input"
# Check the number of parts in the input
num_parts=${#parts[@]}
if [[ $num_parts -gt 2 ]]; then
    # The input is a subdomain and bold it
    echo -e " The input \033[97;44;1m $input \033[m is a subdomain."
    isSubdomain=true
    # set isSubdomain to true globally
    export isSubdomain=true

elif [[ $num_parts -eq 2 ]]; then
    echo -e "The input \033[97;44;1m $input \033[m is a domain."
    isSubdomain=false
    # set isSubdomain to false globally
    export isSubdomain=false
else
    echo -e "\033[1;31mInvalid Input:\033[0m\033[97;44;1m $input \033[m.\033[1;31mPlease provide a valid domain or subdomain.\033[0m"
    exit 1
fi
}
function installSSL {
domain_name=$1
echo "Installing Certbot first."
sudo apt-get install certbot python3-certbot-apache -y
check_last_command_execution "Certbot Installed Successfully" "Failed Certbot Installation"
sudo a2enmod ssl
sudo systemctl restart apache2
# Split the input into an array using dot as the delimiter
IFS='.' read -ra parts <<< "$domain_name"
# Check the number of parts in the input
num_parts=${#parts[@]}
if [[ $num_parts -gt 2 ]]; then
    # The input is a subdomain and bold it
    echo -e " The input \033[97;44;1m $domain_name \033[m is a subdomain."
    isSubdomain=true

elif [[ $num_parts -eq 2 ]]; then
    echo -e "The input \033[97;44;1m $domain_name \033[m is a domain."
    isSubdomain=false
 

else
    echo -e "\033[1;31mInvalid Input:\033[0m\033[97;44;1m $domain_name \033[m.\033[1;31mPlease provide a valid domain or subdomain.\033[0m"
    exit 1
fi
if [ "$isSubdomain" = true ] ; then
sudo certbot --apache -d $domain_name --register-unsafely-without-email --agree-tos -n
else
sudo certbot --apache -d $domain_name -d www.$domain_name --register-unsafely-without-email --agree-tos -n 
fi
# check if ssl certificate installed successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mSSL Certificate Installed Successfully\e[0m"
app_url="https://$domain_name"
else
echo -e "\e[31mFailed to Install SSL Certificate\e[0m"
app_url="http://$domain_name"
fi
}
# function to remove apache completely
function remove_apache_completely {
echo "Removing Apache completely with configuration files"
sudo service apache2 stop
sudo apt purge apache2 apache2-utils apache2-bin -y
sudo apt autoremove -y
sudo rm -rf /etc/apache2
echo -e "Apache is removed completely"
}

# check if repo password is provided or not
echo -e "Checking if repo password is provided by user with -p option"
if [ -z "$repo_pass" ]
then
echo -e "\033[33mRepo Password not provided\033[0m"
repo_pass=""
else
echo -e "\033[33mRepo Password is provided\033[0m"
repo_pass=":$repo_pass"
fi
# Check if the script is running as root or not
if [ "$EUID" -ne 0 ]; then
echo -e "\e[31mPlease run this script as root\e[0m"
exit 1
fi
# Update the repository
echo -e "\e[32mUpdating the repository\e[0m"
sudo apt-get update -y 
# check if apt-get update successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mRepository Updated Successfully\e[0m"
else
# show error message in red color and exit the script
echo -e "\e[31mRepository Update Failed\e[0m"
fi
# Install Apache, MySQL, PHP
echo -e "\e[32mInstalling Apache, MySQL, PHP\e[0m"
################# Install Apache ##################
echo "################# Install Apache ##################"
# check if apache is already installed
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is already installed\e[0m"
# check if apache is running or not
echo -e "\e[32mChecking if Apache is running or not\e[0m"
apache_running=$(systemctl status apache2 | grep -c "active (running)")
if [ $apache_running -eq 1 ]; then
echo -e "\e[32mApache is running\e[0m"
#nothing to do as apache is already installed and running
else
echo -e "\e[31mApache is not running\e[0m"
# remove apache completely
echo "Removing Apache completely with configuration files"
# call function to remove apache completely
remove_apache_completely
# call function to install apache
install_apache
fi # Closed if "Apache is running"
else # Apache is already installed else condition
# call function to install apache
install_apache
fi # main if to check if apache is already installed

############### Installing MySQL Server ##################
echo "############### Installing MySQL Server ##################"
# check if mysql_root_pass is empty or not
if [ ! -z "$mysql_root_pass" ]; then  
echo -e "\e[32mInstalling MySQL\e[0m"
MYSQL_ROOT_PASSWORD=$mysql_root_pass
# check if mysql is already installed and running
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is already installed\e[0m"
# check if mysql is running or not
echo -e "\e[32mChecking if MySQL is running or not\e[0m"
mysql_running=$(systemctl status mysql | grep -c "active (running)")
if [ $mysql_running -eq 1 ]; then
echo -e "\e[32mMySQL is running\e[0m"
# call function to create database and database user
create_database_and_database_user $MYSQL_ROOT_PASSWORD
else
echo -e "\e[31mMySQL is not running\e[0m"
echo -e "\e[32mStarting MySQL\e[0m"
sudo systemctl start mysql
mysql_running=$(systemctl status mysql | grep -c "active (running)")
if [ $mysql_running -eq 1 ]; then
echo -e "\e[32mMySQL is running now \e[0m"
# call function to create database and database user
create_database_and_database_user $MYSQL_ROOT_PASSWORD
else
echo -e "\e[31mMySQL is not running\e[0m"
# remove mysql completely
echo "Removing MySQL completely with configuration files"
# call function to remove mysql completely
remove_mysql_completely
# call function to install mysql with defined password
install_mysql_with_defined_password $MYSQL_ROOT_PASSWORD
create_database_and_database_user $MYSQL_ROOT_PASSWORD
fi # Closed if "Mysql is running now
fi # Closed if mysql is running or not
else # MySQL is already installed else condition
# call function to install mysql with defined password
install_mysql_with_defined_password $MYSQL_ROOT_PASSWORD
create_database_and_database_user $MYSQL_ROOT_PASSWORD
fi # main if to check if mysql is already installed
else # mysql_root_pass if condition empty or not
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
# check if it's already installed
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is already installed\e[0m"
# # remove mysql completely
# echo "Removing MySQL completely with configuration files"
# # call function to remove mysql completely
# remove_mysql_completely
# # call function to install mysql with defined password
# install_mysql_with_defined_password $MYSQL_ROOT_PASSWORD
# create_database_and_database_user $MYSQL_ROOT_PASSWORD
else
install_mysql_with_defined_password $MYSQL_ROOT_PASSWORD
create_database_and_database_user $MYSQL_ROOT_PASSWORD
fi 
fi # mysql_root_pass if condition empty or not
################### Install PHP ##################
echo "################### Install PHP ##################"
# check if PHP is already installed
desired_version="8.1"
#check php is installed or not
php_path=$(which php)
if [ -x "$php_path" ]; then
echo "PHP is installed at: $php_path"
# check if php version is empty
echo "Comparing PHP version"
php_version=$(php -r 'echo PHP_VERSION;')
if [[ $php_version == *"$desired_version"* ]]; then
echo -e "\e[32mPHP Version is $php_version\e[0m"
# nothing to do as PHP is already installed with desired version
else
echo -e "\e[31mPHP Version is $php_version that is not desired one\e[0m"
# installed desired version of php
echo -e "\e[32mInstalling PHP $desired_version\e[0m"
install_php_with_desired_version $desired_version
sudo a2dismod php$php_version
sudo a2enmod php$desired_version
sudo update-alternatives --set php /usr/bin/php$desired_version
fi
else
echo -e "\e[32mPHP is not installed\e[0m"
install_php_with_desired_version $desired_version
fi # main if to check if php is already installed
echo -e "\e[32mRestarting Apache after PHP installation\e[0m"
sudo systemctl restart apache2
echo -e "Checking if domain name is provided by user with -d option"
if [ ! -z "$domain_name" ]; then
echo -e "\e[32mDomain Name is provided by user with -d option\e[0m"
create_virtual_host $domain_name
app_url="http://$domain_name"
################## Free SSL Letsencrypt Installing ##################
echo "################## Free SSL Letsencrypt Installing ##################"
echo "Free SSL Letsencrypt Installing..."
if [ -f "/etc/letsencrypt/live/${domain_name}/fullchain.pem" ]; then
echo -e "\e[32mSSL Certificate already exists\e[0m"
app_url="https://$domain_name"
else
installSSL $domain_name
fi
else
echo -e "\e[32mDomain Name is not provided by user with option -d So, we are installing with IP Address\e[0m"
domain_name=$(curl -s http://checkip.amazonaws.com)
create_virtual_host $domain_name
app_url="http://$domain_name"
fi
# Enable the virtual host
sudo a2ensite $domain_name.conf
# Disable the default virtual host
sudo a2dissite 000-default.conf
# Restart Apache
sudo systemctl restart apache2
# check if virtual host created successfully  and enable site
echo "########## Installing Smarters Panel #############"
########## Installing Smarters Panel #############
# check if laravel is installed already or not
# check vendor and node modules folder exists or not
apt install git -y
ssh-keygen -R bitbucket.org && curl https://bitbucket.org/site/ssh >> ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts && chmod 700 ~/.ssh 
if [ -d "$document_root/vendor" ] && [ -d "$document_root/node_modules" ]; then
echo -e "\e[32mSmarters Panel already installed\e[0m"
# git pull
echo "Updating the Smarters Panel"
cd $document_root
# rm -rf smarterpanel-base
git pull origin Smarters-Panel-Base
if [ $? -eq 0 ]; then
echo -e "\e[32mSmarters Panel updated successfully\e[0m"
else
echo -e "\e[31mSmarters Panel updating failed\e[0m"
fi
#git clone https://techsmarters${repo_pass}@bitbucket.org/techsmarters8333/smarterpanel-base.git
# rsync -av smarterpanel-base $document_root
# rm -rf smarterpanel-base
INSTALLTION_TYPE="update"
else
cd $document_root
# remove existing files
rm -rf $document_root/*  2> /dev/null # remove files
rm -rf $document_root/.* 2> /dev/null # remove hidden files
# git clone https://techsmarters${repo_pass}@bitbucket.org/techsmarters8333/smarterpanel-base.git
git clone git@bitbucket.org:techsmarters8333/smarterpanel-base.git .
if [ $? -eq 0 ]; then
echo -e "\e[32mSmarters Panel clonned successfully\e[0m"
else
echo -e "\e[31mSmarters Panel clonning failed\e[0m"
fi
# mv -f smarterpanel-base/* $document_root
# rm -rf smarterpanel-base
# create .env file
echo "fetching mysql details from file"
get_mysql_details_from_file
echo "Creating .env file"
sudo truncate -s 0 $document_root/.env
cat >> $document_root/.env <<EOF
APP_NAME="Smarters Panel"
APP_ENV=local
APP_KEY=base64:4OhoU51Pl13TVLJb6l2ngm7p9QyVH2yOwmE7Gd5Qm/E=
APP_DEBUG=true
APP_LOG_LEVEL=debug
APP_URL=${app_url}

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=$database_name
DB_USERNAME=$database_user
DB_PASSWORD=$database_user_password

BROADCAST_DRIVER=log
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=sync

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_DRIVER=smtp
MAIL_HOST=email-smtp.ap-south-1.amazonaws.com
MAIL_PORT=587
MAIL_USERNAME=AKIAZ6HORLNX6MJLRA52
MAIL_PASSWORD="BAOjk/ZI5MaZwluDLBQLylMIjr+de8YnVIqmXVpD5MQu"
# MAIL_ENCRYPTION=ssl
MAIL_FROM_NAME="Smarter Panel"
mail_from_address=support@smarterspanel.com

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
QUEUE_CONNECTION=database
EOF
#sudo chown -R www-data:www-data $document_root
sudo chmod -R 755 $document_root
cd ~
# install composer with no interaction
echo "Installing Composer"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --version=2.1.8 --quiet --no-interaction 
cd $document_root
# install composer
composer install --no-interaction
#composer update --no-interaction
# check if composer install successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mComposer Installed Successfully\e[0m"
else
# show error message in red color and exit the script
echo -e "\e[31mComposer Installation Failed\e[0m"
exit 1
fi
# install nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
# check if nodejs install successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mNodeJS Installed Successfully\e[0m"
else
# show error message in red color and exit the script
echo -e "\e[31mNodeJS Installation Failed\e[0m"
exit 1
fi
cd $document_root
npm install 
# check if npm install successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mNPM Installed Successfully\e[0m"
else
echo -e "\e[31mNPM Installation Failed\e[0m"
exit 1
fi
# npm run dev
npm run dev
# check if npm run dev successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mNPM Run Dev Successfully\e[0m"
else
echo -e "\e[31mNPM Run Dev Failed\e[0m"
exit 1
fi
php artisan key:generate
INSTALLTION_TYPE="install"
fi # main if to check if laravel is installed already or not
php artisan migrate
# check if artisan migrate successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mArtisan Migrate Successfully\e[0m"
else
echo -e "\e[31mArtisan Migrate Failed\e[0m"
exit 1
fi
# check if laravel is installed successfully
# if [ ! -f "$document_root/composer.json" ] && [ ! -d "$document_root/node_modules" ]; then
# php artisan db:seed
# fi
if [ "$INSTALLTION_TYPE" = "install" ] ; then
php artisan db:seed
fi
# Time to give the accurate permissions
sudo chown -R www-data:www-data $document_root
sudo chmod -R 755 $document_root
# primission to laravel storage
sudo chmod -R 777 $document_root/storage
# primission to laravel bootstrap
sudo chmod -R 777 $document_root/bootstrap
# primission to laravel cache
sudo chmod -R 777 $document_root/bootstrap/cache
sudo chmod -R 777 $document_root/storage/logs/
# Restart Apache
sudo systemctl restart apache2
# run artisan optimize 
php artisan optimize:clear
# check if artisan optimize successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mArtisan Optimize Successfully\e[0m"
else
echo -e "\e[32mArtisan Optimize Failed\e[0m"
fi
# last check to make sure everything is working fine
# check if apache is running or not
echo -e "\e[32mChecking if Apache is running or not\e[0m"
apache_running=$(systemctl status apache2 | grep -c "active (running)")
if [ $apache_running -eq 1 ]; then
echo -e "\e[32mApache is running\e[0m"
else
echo -e "\e[31mApache is not running\e[0m"
fi
# check if mysql is running or not
echo -e "\e[32mChecking if MySQL is running or not\e[0m"
mysql_running=$(systemctl status mysql | grep -c "active (running)")
if [ $mysql_running -eq 1 ]; then
echo -e "\e[32mMySQL is running\e[0m"
else
echo -e "\e[31mMySQL is not running\e[0m"
fi
# check if php is running or not
echo -e "\e[32mChecking if PHP is running or not\e[0m"
php_version=$(php -r 'echo PHP_VERSION;')
if [[ $php_version == *"$desired_version"* ]]; then
echo -e "\e[32mPHP Version is $php_version\e[0m"
else
echo -e "\e[31mPHP Version is $php_version that is not desired one\e[0m"
fi
# check if composer is installed or not
echo -e "\e[32mChecking if Composer is installed or not\e[0m"
composer_path=$(which composer)
if [ -x "$composer_path" ]; then
echo -e "\e[32mComposer is installed at: $composer_path\e[0m"
else
echo -e "\e[31mComposer is not installed\e[0m"
fi
# check if nodejs is installed or not
echo -e "\e[32mChecking if NodeJS is installed or not\e[0m"
nodejs_path=$(which nodejs)
if [ -x "$nodejs_path" ]; then
echo -e "\e[32mNodeJS is installed at: $nodejs_path\e[0m"
else
echo -e "\e[31mNodeJS is not installed\e[0m"
fi
# check if npm is installed or not
echo -e "\e[32mChecking if NPM is installed or not\e[0m"
npm_path=$(which npm)
if [ -x "$npm_path" ]; then
echo -e "\e[32mNPM is installed at: $npm_path\e[0m"
else
echo -e "\e[31mNPM is not installed\e[0m"
fi
# check if Smarters Panel cloned and installed successfully
echo -e "\e[32mChecking if Smarters Panel cloned and installed successfully\e[0m"
if [ -d "$document_root/vendor" ] && [ -d "$document_root/node_modules" ]; then
echo -e "\e[32mSmarters Panel cloned and installed successfully\e[0m"
else
echo -e "\e[31mSmarters Panel cloned and installed failed\e[0m"
fi
# check if Smarters Panel is running or not
echo -e "\e[32mChecking if Smarters Panel is running or not\e[0m"
if [ -f "$document_root/composer.json" ] && [ -d "$document_root/.env" ]; then
echo -e "\e[32mSmarters Panel is running\e[0m"
else
echo -e "\e[31mSmarters Panel is not running\e[0m"
fi
#  clear files 
rm -rf /root/database_details.txt 2> /dev/null # remove files
# clear installation files
rm -rf /root/server-setup.sh 2> /dev/null # remove files
# show success message in green color

echo -e "\e[32mSmarters Panel Installed Successfully\e[0m"
# show user the panel url
echo "You can access your smarters panel at $app_url"
echo "You can access your admin panel at $app_url/admin"
echo "Your Admin Username is admin@smarterspanel.com"
echo "Your Admin Password is password"
echo "You can access your client panel at $app_url/auth/signin"