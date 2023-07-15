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

# check if domain name with -d  option is provided or not
echo -e "Checking if domain name is provided by user with -d option"
if [ ! -z "$domain_name" ]; then
input=$domain_name
# Split the input into an array using dot as the delimiter
IFS='.' read -ra parts <<< "$input"
# Check the number of parts in the input
num_parts=${#parts[@]}
if [[ $num_parts -gt 2 ]]; then
    # The input is a subdomain and bold it
    echo -e " The input \033[97;44;1m $input \033[m is a subdomain."
    isSubdomain=true
elif [[ $num_parts -eq 2 ]]; then
    echo -e "The input \033[97;44;1m $input \033[m is a domain."
    isSubdomain=false
else
    echo -e "\033[1;31mInvalid Input:\033[0m\033[97;44;1m $domain_name \033[m.\033[1;31mPlease provide a valid domain or subdomain.\033[0m"
    exit 1
fi
else
echo -e "\033[33mDomain name is not provided by user with -d option\033[0m"
fi
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
# Install Apache
#check if apache is already installed
echo -e "Checking if Apache is already installed or not"
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is installed\e[0m"
# check if apache is running or not
echo -e "\e[32mChecking if Apache is running or not\e[0m"
apache_running=$(systemctl status apache2 | grep -c "active (running)")
if [ $apache_running -eq 1 ]; then
echo -e "\e[32mApache is running too\e[0m"
else
echo -e "\e[31mApache is not running\e[0m"
echo -e "\e[32mStarting Apache\e[0m"
sudo systemctl start apache2
apache_running=$(systemctl status apache2 | grep -c "active (running)")
if [ $apache_running -eq 1 ]; then
echo -e "\e[32mApache is running\e[0m"
else
echo -e "\e[31mApache is not running\e[0m"
# remove apache completely 
echo "Removing Apache completely with configuration files"
sudo service apache2 stop
sudo apt purge apache2 apache2-utils apache2-bin -y
sudo apt autoremove -y
sudo rm -rf /etc/apache2
echo -e "mApache is removed completely"
echo -e "\e[32mInstalling Apache\e[0m"
sudo apt-get install apache2 -y
# check last command executed successfully or not
if [ $? -eq 0 ]; then
echo -e "\e[32mApache is installed successfully\e[0m"
else
echo -e "\e[31mApache is not installed successfully\e[0m"
exit 1
fi # check last command executed successfully or not
fi # main if to check if apache is running or not
fi # main if to check if apache is running or not
else # main else to check if apache is already installed
echo -e "\e[32mInstalling Apache\e[0m"
sudo apt-get install apache2 -y
fi #main if to check if apache is already installed
# Enable Apache Mods if not enabled
enable_mods=$(a2query -m rewrite)
if [ "$enable_mods" = *"rewrite (enabled by site administrator)"* ]; then
echo -e "\e[32mApache Mods are already enabled\e[0m"
else
echo -e "Enabling Apache Mods"
sudo a2enmod rewrite
# Restart Apache
echo -e "mRestarting Apache"
sudo systemctl restart apache2 
fi
# Installing MySQL Server with default password
echo -e "\e[32mInstalling MySQL\e[0m"
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
echo -e "\e[32mInstalling MySQL\e[0m"
# call function to install mysql with defined password
install_mysql_with_defined_password $MYSQL_ROOT_PASSWORD
create_database_and_database_user $MYSQL_ROOT_PASSWORD
fi # main if to check if mysql is already installed
else # mysql_root_pass if condition empty or not
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
install_mysql_with_defined_password $MYSQL_ROOT_PASSWORD
create_database_and_database_user $MYSQL_ROOT_PASSWORD
fi # mysql_root_pass if condition


# Install PHP
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
fi
else
echo -e "\e[32mPHP is not installed\e[0m"
install_php_with_desired_version $desired_version
fi # main if to check if php is already installed
php_version=$(php -v | head -n 1 | cut -d ' ' -f 2 | cut -c 1-3)
sudo a2dismod php$php_version
sudo a2enmod php$desired_version
sudo service apache2 restart
sudo update-alternatives --set php /usr/bin/php$desired_version
sudo systemctl restart apache2
# check if domain name is not empty
if [ ! -z "$domain_name" ]; then
public_dir="/var/www/vhosts/${domain_name}/public/"
larave_dir="/var/www/vhosts/${domain_name}/"
app_url="http://${domain_name}"
# Create Virtual Host for the domain name provided by the user
echo "Creating Virtual Host File for $domain_name"
# check if already virtual host file exists
if [ -f "/etc/apache2/sites-available/${domain_name}.conf" ]; then
echo -e "\e[32mVirtual Host File Already Exists\e[0m"
else
echo -e "\e[32mCreating Virtual Host File\e[0m"
if [ "$isSubdomain" = true ] ; then
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
else
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
fi
fi
# Enable the virtual host
sudo a2ensite $domain_name.conf
# Disable the default virtual host
sudo a2dissite 000-default.conf
# Restart Apache
sudo systemctl restart apache2
echo "Virtual Host Created Successfully for $domain_name"
echo "Virtual Host Configuration Script Completed"
echo "*************** Virtual Host Details ******************"
echo "Domain Name: $domain_name"
echo "Public Directory: $public_dir"
echo "*******************************************************"
# Create public directory
echo "Creating public directory"
sudo mkdir -p $public_dir
sudo chown -R $USER:$USER $public_dir
sudo chmod -R 755 $public_dir
# create a php file to test PHP
echo "Creating index.php file to welcome message"
sudo echo "<?php echo 'Welcome to $domain_name'; ?>" > $public_dir/index.php
sudo echo "<?php phpinfo(); ?>" > $public_dir/info.php
########## Install Let's Encrypt SSL Certificate for the domain name provided by the user ##########
echo "Installing SSL Certificate"
# Update the repository
#echo "Updating the repository"
#sudo apt-get update -y
echo "Installing Certbot"
# if already certbot is installed and running
certbot=$(dpkg-query -W -f='${Status}' certbot 2>/dev/null | grep -c "ok installed")
if [ $certbot -eq 1 ]; then
echo -e "\e[32mCertbot is already installed\e[0m"
# check if certbot is running
certbot_status=$(systemctl is-active certbot.service)
if [[ $certbot_status == *"active"* ]]; then
echo -e "\e[32mCertbot is running\e[0m"
else
echo -e "\e[31mCertbot is not running\e[0m"
echo -e "\e[32mStarting Certbot\e[0m"
sudo systemctl start certbot.service
if [ $? -eq 0 ]; then
echo -e "\e[32mCertbot started successfully\e[0m"
else
echo -e "\e[31mFailed to start Certbot\e[0m"
echo -e "\e[32mDeleting Existing Certbot\e[0m"
sudo apt-get remove certbot python3-certbot-apache -y
echo -e "\e[32mExisting Certbot Deleted Successfully\e[0m"
fi
fi
else
echo -e "\e[31mCertbot is not installed\e[0m"
# Install Certbot
sudo apt-get install certbot python3-certbot-apache -y
echo -e "\e[32mCertbot Installed Successfully\e[0m"
fi
# Install SSL Certificate
echo "Installing SSL Certificate for $domain_name"
# check if ssl certificate already exists
if [ -f "/etc/letsencrypt/live/${domain_name}/fullchain.pem" ]; then
echo -e "\e[32mSSL Certificate already exists\e[0m"
# check https is enabled or not
echo "Checking if SSL is enabled"
if grep -q "SSLEngine on" /etc/apache2/sites-available/${domain_name}.conf; then
echo -e "\e[32mSSL is already enabled\e[0m"
else
echo -e "\e[32mEnabling SSL\e[0m"
# Enable SSL
sudo a2enmod ssl
# Restart Apache
sudo systemctl restart apache2
fi
else
# Enable SSL
echo "Enabling SSL"
sudo a2enmod ssl
# Restart Apache
sudo systemctl restart apache2
# Install SSL Certificate with www and non-www domain name and without email address
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
fi
else
echo -e "\e[32mDomain Name is not provided by user with option -d So, we are installing with IP Address\e[0m"
public_dir="/var/www/html/public/"
larave_dir="/var/www/html/"
ip_address=$(curl -s http://checkip.amazonaws.com)
app_url="http://$ip_address"
# get ip address
# check if ip address is empty
if [ -z "$ip_address" ]; then
echo -e "\e[31mIP Address is Empty\e[0m"
exit 1
else
echo -e "\e[32mIP Address: $ip_address\e[0m"
domain_name=$ip_address
fi
echo "Creating Virtual Host fro default /var/www/html/ directory"
# Create virtual host configuration file
echo "Creating virtual host configuration file"
# empty the file
sudo truncate -s 0 /etc/apache2/sites-available/001-default.conf
cat >> /etc/apache2/sites-available/001-default.conf <<EOF
<VirtualHost *:80>
<Directory /var/www/html/public/>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
     </Directory>
    ServerAdmin webmaster@localhost
    ServerName localhost
    DocumentRoot /var/www/html/public/
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
 # enable the virtual host
echo "Enabling the virtual host"
sudo a2ensite 000-default.conf
sudo a2ensite 001-default.conf
# Restart Apache
echo "Restarting Apache"
sudo systemctl restart apache2
fi
########## Install Smarters Panel ##########
# Install the Smarters Panel on your server
echo "######################Installing the Smarters Panel on your server######################"
cd $larave_dir
# check if laravel is installed already or not
if [ -f "$larave_dir/composer.json" ]; then
# git pull
echo "Updating the Smarters Panel"
git clone https://techsmarters${repo_pass}@bitbucket.org/techsmarters8333/smarterpanel-base.git
mv -f smarterpanel-base/* $larave_dir
rm -rf smarterpanel-base
else
# remove existing files
rm -rf *
git clone https://techsmarters${repo_pass}@bitbucket.org/techsmarters8333/smarterpanel-base.git
mv -f smarterpanel-base/* $larave_dir
rm -rf smarterpanel-base
# create .env file
echo "Creating .env file"
sudo truncate -s 0 $larave_dir/.env
cat >> $larave_dir/.env <<EOF
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
sudo chown -R www-data:www-data $larave_dir
sudo chmod -R 755 $larave_dir
cd ~
# install composer with no interaction
echo "Installing Composer"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --version=2.1.8 --quiet --no-interaction 
cd $larave_dir
# install composer
composer install --no-interaction
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
cd $larave_dir
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
# primission to laravel storage
sudo chmod -R 777 $larave_dir/storage
# primission to laravel bootstrap
sudo chmod -R 777 $larave_dir/bootstrap
# primission to laravel cache
sudo chmod -R 777 $larave_dir/bootstrap/cache
sudo chmod -R 777 $larave_dir/storage/logs/
# run migration
php artisan migrate 
# run seeder
# check if laravel vendor folder exist
if [ -d "$larave_dir/vendor" ]; then
php artisan db:seed
fi
# run artisan key generate
fi
# check if migration successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mMigration Successfully\e[0m"
else
echo -e "\e[32mMigration Failed\e[0m"
fi
# check if seeder successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mSeeder Successfully\e[0m"
else
echo -e "\e[32mSeeder Failed\e[0m"
fi
# run artisan optimize 
php artisan optimize:clear
# check if artisan optimize successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mArtisan Optimize Successfully\e[0m"
else
echo -e "\e[32mArtisan Optimize Failed\e[0m"
fi

echo -e "\e[32mSmarters Panel Installed Successfully\e[0m"
# show user the panel url
echo "You can access your smarters panel at $app_url"
echo "You can access your admin panel at $app_url/admin"
echo "Your Admin Username is admin@smarterspanel.com"
echo "Your Admin Password is password"
echo "You can access your client panel at $app_url/auth/signin"



# function to check if last command executed successfully or not with message
function check_last_command_execution {
if [ $? -eq 0 ]; then
echo -e "\e[32m$1\e[0m"
else
echo -e "\e[31m$2\e[0m"
exit 1
fi
}
# function to check if last command executed successfully or not without message
function check_last_command_execution_without_message {
if [ $? -eq 0 ]; then
echo -e "\e[32mLast Command Executed Successfully\e[0m"
else
echo -e "\e[31mLast Command Execution Failed\e[0m"
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
function install_mysql_with_defined_password(MYSQL_ROOT_PASSWORD) {
# Install MySQL with default password
echo -e "\e[32mInstalling MySQL\e[0m"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
check_last_command_execution "MySQL Installed with Password: $MYSQL_ROOT_PASSWORD" "MySQL Installation Failed"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
}
# function to create database and database user
function create_database_and_database_user(MYSQL_ROOT_PASSWORD){
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
}
# function to install php and modules with desired version
function install_php_with_desired_version(desired_version) {
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







