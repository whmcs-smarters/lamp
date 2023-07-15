#!/bin/bash
# This script will install LAMP in Ubuntu 22.04
while getopts ":d:p:m:" o
do
case "${o}" in
d) domain_name=${OPTARG};;
p) repo_pass=${OPTARG};;
m) mysql_pass=${OPTARG};;
esac
done
# Start logging the script
exec > >(tee -i server-setup.log)
exec 2>&1

# check if domain name is provided or not
if [ ! -z "$domain_name" ]; then
# check if the domain name is valid or not
if [[ ! $domain_name =~ ^[a-zA-Z0-9]+([-.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$ ]] ; then
# check if domain or subdomain 
input=$domain_name
# Split the input into an array using dot as the delimiter
IFS='.' read -ra parts <<< "$input"
# Check the number of parts in the input
num_parts=${#parts[@]}
if [[ $num_parts -gt 2 ]]; then
    echo "The input '$input' is a subdomain."
    isSubdomain=true
elif [[ $num_parts -eq 2 ]]; then
    echo "The input '$input' is a domain."
    isSubdomain=false
else
    echo "Invalid input. Please provide a valid domain or subdomain."
    exit 1
fi
else
echo -e "\e[31mPlease provide a valid domain name\e[0m"
exit 1
fi
else
echo -e "\e[32mDomain name is not provided by user with -d option\e[0m"
fi
# check if repo password is provided or not
if [ -z "$repo_pass" ]
then
echo -e "Repo Password not provided"
repo_pass=""
else
echo -e "Repo Password is provided"
repo_pass=":$repo_pass"
fi

# This script will install LAMP in Ubuntu 22.04
echo -e "\e[32mWelcome to LAMP Installation & Configuration Script\e[0m"
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
# Install Apache
#check if apache is already installed
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is installed\e[0m"
# check if apache is running or not
echo -e "\e[32mChecking if Apache is running or not\e[0m"
apache_running=$(systemctl status apache2 | grep -c "active (running)")
if [ $apache_running -eq 1 ]; then
echo -e "\e[32mApache is running\e[0m"
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
echo -e "\e[32mApache is removed completely\e[0m"
echo -e "\e[32mInstalling Apache\e[0m"
sudo apt-get install apache2 -y
# check last command executed successfully or not
if [ $? -eq 0 ]; then
echo -e "\e[32mApache is installed successfully\e[0m"
else
echo -e "\e[31mApache is not installed successfully\e[0m"
exit 1
fi
fi
fi
else
echo -e "\e[32mInstalling Apache\e[0m"
sudo apt-get install apache2 -y
fi

# Enable Apache Mods
echo -e "\e[32mEnabling Apache Mods\e[0m"
sudo a2enmod rewrite
# Restart Apache
echo -e "\e[32mRestarting Apache\e[0m"
# Restart Apache or it will not work
sudo systemctl restart apache2 
# Install MySQL with defined password
echo -e "\e[32mInstalling MySQL\e[0m"
# check if mysql is already installed and running
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is already installed\e[0m"
# check if mysql is running or not
echo -e "\e[32mChecking if MySQL is running or not\e[0m"
mysql_running=$(systemctl status mysql | grep -c "active (running)")
if [ $mysql_running -eq 1 ]; then
echo -e "\e[32mMySQL is running\e[0m"
MYSQL_ROOT_PASSWORD=$mysql_pass
else
echo -e "\e[31mMySQL is not running\e[0m"
echo -e "\e[32mStarting MySQL\e[0m"
sudo systemctl start mysql 
mysql_running=$(systemctl status mysql | grep -c "active (running)")
if [ $mysql_running -eq 1 ]; then
echo -e "\e[32mMySQL is running\e[0m"
MYSQL_ROOT_PASSWORD=$mysql_pass
else
echo -e "\e[31mMySQL is not running\e[0m"
# remove mysql completely
echo "Removing MySQL completely with configuration files"
sudo service mysql stop
sudo apt purge mysql-server mysql-client mysql-common -y
sudo apt autoremove -y
sudo rm -rf /etc/mysql
sudo rm -rf /var/lib/mysql
echo -e "\e[32mMySQL is removed completely\e[0m"
echo -e "\e[32mInstalling MySQL\e[0m"
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
if $? -eq 0 ]; then
echo -e "\e[32mMySQL Installed with Password: \e[1m$MYSQL_ROOT_PASSWORD\e[0m"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
else
echo -e "\e[31mMySQL Installation Failed\e[0m"
exit 1
fi
fi
fi
else
echo -e "\e[32mInstalling MySQL\e[0m"
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
if [ $? -eq 0 ]; then
echo -e "\e[32mMySQL Installed with Password: \e[1m$MYSQL_ROOT_PASSWORD\e[0m"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
else
echo -e "\e[31mMySQL Installation Failed\e[0m"
exit 1
fi
fi
# Create a database for the domain name provided by the user
echo -e "\e[32mCreating Database and DB User\e[0m"
database_name="smarterspanel_db";
# create databse and databse user if mysql root password is not empty
if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
echo -e "\e[32mCreating Database\e[0m"
# create database if not exists
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $database_name;"
echo -e "\e[32mDatabase $database_name Created Successfully\e[0m"
# show databases
echo "Showing Databases"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "show databases;"
database_user="smarterspanel_user";
# check if database user is already created or not
database_user_exists=$(mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$database_user' AND host = 'localhost');")
if [ $database_user_exists -eq 1 ]; then
echo "Database User Already Exists"
else
echo "Creating Database User and Granting Privileges"
# Create a database user for the domain name provided by the user
database_user_password="$(openssl rand -base64 12)"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$database_user'@'localhost' IDENTIFIED BY '$database_user_password';"
# Grant privileges to the database user
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $database_name.* TO '$database_user'@'localhost';"
# Flush privileges
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
echo -e "\e[32mDatabase User Created Successfully\e[0m"
echo "*************** Database Details ******************"
echo "Database User: $database_user"
echo "Database User Password: $database_user_password"
fi
# else
# echo -e "\e[31mMySql is already installed Please provide MySQL ROOT PASSWOrd as option -m\e[0m"
# exit 1
fi
# check if PHP is already installed
desired_version="8.1"
#check php is installed or not
php_path=$(which php)
if [ -x "$php_path" ]; then
echo "PHP is installed at: $php_path"
php_version=$(php -v | head -n 1 | cut -d ' ' -f 2)
echo "PHP version: $php_version"
echo "Comparing PHP version"
php_version=$(php -r 'echo PHP_VERSION;')
if [[ $php_version == *"$desired_version"* ]]; then
echo -e "\e[32mPHP Version is $php_version\e[0m"
else
echo -e "\e[31mPHP Version is $php_version\e[0m"
# installed desired version of php
echo -e "\e[32mInstalling PHP $desired_version\e[0m"
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install php$desired_version -y
sudo apt install unzip
sudo apt-get install php$desired_version-{bcmath,bz2,intl,gd,mbstring,mysql,zip,curl,xml,cli} -y
# check php version
sudo a2dismod php$php_version
sudo a2enmod php$desired_version
sudo service apache2 restart
sudo update-alternatives --set php /usr/bin/php$desired_version
fi
else
echo -e "\e[32mPHP is not installed\e[0m"
# installed desired version of php
echo -e "\e[32mInstalling PHP $desired_version\e[0m"
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install php$desired_version -y
sudo apt install unzip
sudo apt-get install php$desired_version-{bcmath,bz2,intl,gd,mbstring,mysql,zip,curl,xml,cli} -y
# check 
fi # main if to check if php is already installed
# Restart Apache
sudo systemctl restart apache2
echo "PHP Version: $(php -v | grep -i cli | awk '{print $1 $2}')"
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
