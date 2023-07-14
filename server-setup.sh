#!/bin/bash
# This script will install LAMP in Ubuntu 22.04
while getopts ":d:p:" o
do
case "${o}" in
d) domain_name=${OPTARG};;
p) repo_pass=${OPTARG};;
esac
done
# Start logging the script
exec > >(tee -i server-setup.log)
exec 2>&1

# check if domain name is provided or not
if [ -z "$domain_name" ]
then
    echo -e "\e[31mPlease provide the domain name with -d option\e[0m"
    exit 1
fi
# check if repo password is provided or not
if [ -z "$repo_pass" ]
then
    echo -e "Repo Password not provided"
    $repo_pass = ""
fi
# check if the domain name is valid or not
if [[ ! $domain_name =~ ^[a-zA-Z0-9]+([-.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$ ]]
then
    echo -e "\e[31mPlease provide a valid domain name\e[0m"
    exit 1
fi
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
apache=$(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed")
if [ $apache -eq 1 ]; then
echo -e "\e[32mApache is installed\e[0m"
# remove apache completely 
echo "Removing Apache completely with configuration files"
sudo service apache2 stop
sudo apt purge apache2 apache2-utils apache2-bin -y
sudo apt autoremove -y
sudo rm -rf /etc/apache2
echo -e "\e[32mApache is removed completely\e[0m"
fi
echo -e "\e[32mInstalling Apache\e[0m"
sudo apt-get install apache2 -y
# Enable Apache Mods
echo -e "\e[32mEnabling Apache Mods\e[0m"
sudo a2enmod rewrite
# Restart Apache
echo -e "\e[32mRestarting Apache\e[0m"
# Restart Apache or it will not work
sudo systemctl restart apache2 
# check if apache is running or not
apache2=$(systemctl status apache2 | grep -c "active (running)")
if [ $apache2 -eq 1 ]; then
echo -e "\e[32mApache Installed Successfully and Running\e[0m"
echo "Apache Version: $(apache2 -v | grep -i apache | awk '{print $1 $3}')"
else
echo -e "\e[31mApache is not installed properly and not running\e[0m"
exit 1
fi
# Install MySQL with defined password
echo -e "\e[32mInstalling MySQL\e[0m"
#check if mysql is already installed
mysql=$(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed")
if [ $mysql -eq 1 ]; then
echo -e "\e[32mMySQL is already installed\e[0m"
echo "Removing MySQL completely"
sudo apt-get purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -y
sudo apt-get autoremove -y
sudo apt-get autoclean
echo -e "\e[32mMySQL is removed completely\e[0m"
fi
echo -e "\e[32mMySQL is installing..\e[0m"
# Generate Random Password
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 12)"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
sudo apt-get install mysql-server -y
echo -e "MySQL Installed with Password: \e[1m$MYSQL_ROOT_PASSWORD\e[0m"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
echo -e "\e[32mMySQL Installed Successfully\e[0m"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"

# Create a database for the domain name provided by the user
echo -e "\e[32mCreating Database and DB User\e[0m"
database_name="smarterspanel_db";
sudo mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $database_name;"
echo -e "\e[32mDatabase Created Successfully\e[0m"
# show databases
echo "Showing Databases"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "show databases;"
echo "Database Configuration Script Completed"
# Create a database user for the domain name provided by the user
echo "Creating Database User"
# Create a database user for the domain name provided by the user
database_user="smarterspanel_user";
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
echo "Database Name: $database_name"
# check if PHP is already installed
php=$(dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed")
if [ $php -eq 1 ]; then
echo -e "\e[32mPHP is already installed\e[0m"
echo "Removing PHP8.1 completely"
sudo apt-get purge php8.1 -y
sudo apt-get autoremove -y
sudo apt-get autoclean
fi
# Install PHP 8.1 and php fpm and its modules ubuntu 22.04
echo -e "\e[32mInstalling PHP 8.1 and its modules\e[0m"
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install php8.1 -y
sudo apt install unzip
sudo apt-get install php8.1-{bcmath,bz2,intl,gd,mbstring,mysql,zip,curl,xml,cli} -y
# check php version 
php_version=$(php -r 'echo PHP_VERSION;')
desired_version="8.1"
if [[ $php_version == *"$desired_version"* ]]; then
echo -e "\e[32mPHP Installed Successfully\e[0m"
echo "PHP Version: $(php -v | grep -i cli | awk '{print $1 $2}')"
else
# switch to php 8.1
sudo update-alternatives --set php /usr/bin/php8.1
# check if php install successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mPHP Installed Successfully\e[0m"
echo "PHP Version: $(php -v | grep -i cli | awk '{print $1 $2}')"
else
# show error message in red color and exit the script
echo -e "\e[31mPHP Installation Failed\e[0m"
exit 1
fi
# Restart Apache
sudo systemctl restart apache2
echo -e "\e[32mPHP Installed Successfully\e[0m"
echo "PHP Version: $(php -v | grep -i cli | awk '{print $1 $2}')"
# Create Virtual Host for the domain name provided by the user
# check if directory already exists
if [ -d "/var/www/vhosts/${domain_name}" ] 
then
echo -e "\e[32mDirectory already exists\e[0m"
rm -rf /var/www/vhosts/${domain_name}
echo -e "\e[32mDirectory deleted\e[0m"
fi
echo -e "\e[32mCreating Directory for $domain_name\e[0m"
sudo mkdir -p /var/www/vhosts/${domain_name}/public/
# Create a virtual host file
# check if virtual host file already exists
if [ -f "/etc/apache2/sites-available/${domain_name}.conf" ] 
then
echo -e "\e[32mVirtual Host File already exists\e[0m"
rm -rf /etc/apache2/sites-available/${domain_name}.conf
echo -e "\e[32mVirtual Host File deleted\e[0m"
fi
echo "Creating Virtual Host File for $domain_name"
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
# Enable the virtual host
sudo a2ensite $domain_name.conf
# Disable the default virtual host
sudo a2dissite 000-default.conf
# Restart Apache
sudo systemctl restart apache2
echo "Virtual Host Created Successfully for $domain_name"
echo "Virtual Host Configuration Script Completed"
# create a php file to test PHP
echo "Creating index.php file to welcome message"
sudo echo "<?php echo 'Welcome to $domain_name'; ?>" > /var/www/vhosts/${domain_name}/public/index.php
sudo echo "<?php phpinfo(); ?>" > /var/www/vhosts/${domain_name}/public/info.php
########## Install Let's Encrypt SSL Certificate for the domain name provided by the user ##########
echo "Installing SSL Certificate"
# Update the repository
#echo "Updating the repository"
#sudo apt-get update -y
echo "Installing Certbot"
# if already certbot exists then delete it
if [ -d "/etc/letsencrypt" ] 
then
echo -e "\e[32mCertbot already exists\e[0m"
echo -e "\e[32mDeleting Existing Certbot\e[0m"
sudo apt-get remove certbot python3-certbot-apache -y
echo -e "\e[32mExisting Certbot Deleted Successfully\e[0m"
fi
# Install Certbot
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
if [ "$isSubdomain" = true ] ; then
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
# Install the Smarters Panel on your server
echo "Installing the Smarters Panel on your server"
cd /var/www/vhosts/${domain_name}/
# remove existing files
rm -rf *
git clone https://techsmarters:${repo_pass}@bitbucket.org/techsmarters8333/smarterpanel-base.git
mv -f smarterpanel-base/* /var/www/vhosts/${domain_name}/
rm -rf smarterpanel-base
# create .env file
cat >> /var/www/vhosts/${domain_name}/.env <<EOF
APP_NAME="Smarters Panel"
APP_ENV=local
APP_KEY=base64:4OhoU51Pl13TVLJb6l2ngm7p9QyVH2yOwmE7Gd5Qm/E=
APP_DEBUG=true
APP_LOG_LEVEL=debug
APP_URL=https://${domain_name}

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

sudo chown -R www-data:www-data /var/www/vhosts/${domain_name}/
sudo chmod -R 755 /var/www/vhosts/${domain_name}/
cd /var/www/vhosts/${domain_name}/public/ 
cd ~
# install composer with no interaction
echo "Installing Composer"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --version=2.1.8 --quiet --no-interaction 
cd /var/www/vhosts/${domain_name}/
# make sure the php versino 8.1 
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
# sudo apt-get install nodejs -y
curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs
# check if nodejs install successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mNodeJS Installed Successfully\e[0m"
else
# show error message in red color and exit the script
echo -e "\e[31mNodeJS Installation Failed\e[0m"
exit 1
fi
# install npm 
sudo apt-get install npm -y
npm install -g npm@latest
# check if npm install successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mNPM Installed Successfully\e[0m"
else
echo -e "\e[31mNPM Installation Failed\e[0m"
exit 1
fi
# npm install 
cd /var/www/vhosts/${domain_name}/
npm install --no-interaction
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
# primission to laravel storage
sudo chmod -R 777 /var/www/vhosts/${domain_name}/storage
# primission to laravel bootstrap
sudo chmod -R 777 /var/www/vhosts/${domain_name}/bootstrap
# primission to laravel cache
sudo chmod -R 777 /var/www/vhosts/${domain_name}/bootstrap/cache
sudo chmod -R 777 /var/www/vhosts/${domain_name}/storage/logs/
# run migration
php artisan migrate --force 
# check if migration successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mMigration Successfully\e[0m"
else
echo -e "\e[31mMigration Failed\e[0m"
fi
# run seeder
php artisan db:seed --class=DatabaseSeeder --force 
# check if seeder successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mSeeder Successfully\e[0m"
else
echo -e "\e[31mSeeder Failed\e[0m"
fi
# run artisan key generate
php artisan key:generate --force
# run artisan optimize 
php artisan optimize --force 
# check if artisan optimize successfully
if [ $? -eq 0 ]; then
echo -e "\e[32mArtisan Optimize Successfully\e[0m"
else
echo -e "\e[31mArtisan Optimize Failed\e[0m"
fi
echo -e "\e[32mSmarters Panel Installed Successfully\e[0m"
# show user the panel url
echo "You can access your admin panel at https://$domain_name/"
echo "You can access your admin panel at https://$domain_name/admin"
echo "Your Admin Username is admin@smarterspanel.com"
echo "Your Admin Password is password"
echo "You can access your client panel at https://$domain_name/auth/signin"