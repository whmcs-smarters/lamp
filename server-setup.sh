#!/bin/bash

########### Functions ###########
# This functino first check if domain is empty or not then check if it's valid or not then it set the domain namea and isSubdomain variable too
function check_domain_or_subdomain {
# Get the input from user
input=$1
# Split the input into an array using dot as the delimiter
IFS='.' read -ra parts <<< "$input"
# Check the number of parts in the input
num_parts=${#parts[@]}
if [[ $num_parts -gt 2 ]]; then
    # The input is a subdomain and bold it
    echo -e "The input \033[97;44;1m $input \033[m is a subdomain."
    isSubdomain=true
elif [[ $num_parts -eq 2 ]]; then
    echo -e "The input \033[97;44;1m $input \033[m is a domain."
    isSubdomain=false
else
    echo -e "\033[1;31mInvalid Input:\033[0m\033[97;44;1m $input \033[m.\033[1;31mPlease provide a valid domain or subdomain.\033[0m"
    exit 1
fi
echo "SET - ${bold}isSubomain: ${normal} $isSubdomain"
}
function set_check_valid_domain_name {
if [ -z "$1" ]
then
echo -e "\033[33mDomain Name not provided So, We are using IP Address \033[0m"
ip_address=$(curl -s http://checkip.amazonaws.com)
domain_name=$ip_address
sslInstallation=false
app_url="http://$domain_name"
else
echo -e "\033[33mDomain Name is provided\033[0m"
check_domain_or_subdomain $1
domain_name=$1
sslInstallation=true
app_url="http://$domain_name"
fi
}
# function to check if last command executed successfully or not with message
function check_last_command_execution {
if [ $? -eq 0 ]; then
echo -e "\e[32m$1\e[0m"
else
echo -e "\e[31m$2\e[0m"
# remove files
rm -rf /root/server-setup.sh 2> /dev/null # remove files
echo "Check Logs for more details: server-setup-$domain_name.log"
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
check_last_command_execution "MySQL Installed Successfully" "MySQL Installation Failed"
echo "MySQL Version: $(mysql -V | awk '{print $1,$2,$3}')"
if [ "$isMasked" = false ] ; then
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
fi
}
# function to create random database name
generate_random_database_name() {
    length=5
    characters='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    echo $(LC_ALL=C tr -dc "$characters" < /dev/urandom | head -c "$length")
}
# function to create database and database user
function create_database_and_database_user {
MYSQL_ROOT_PASSWORD=$1
# Create a database for the domain name provided by the user
echo -e "\e[32mCreating Database and DB User\e[0m"
database_name=smarters_$(generate_random_database_name)
# create database if not exists
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $database_name;"
check_last_command_execution "Database $database_name Created Successfully" "Database $database_name Creation Failed"
# show databases
if [ "$isMasked" = false ] ; then
echo "Showing Databases"
mysql -u root -p$MYSQL_ROOT_PASSWORD -e "show databases;"
fi
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
if [ "$isMasked" = false ] ; then
echo "*************** Database Details ******************"
echo "Database Name: $database_name"
echo "Database User: $database_user"
echo "Database User Password: $database_user_password"
fi
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
check_last_command_execution "PHP $desired_version Installed Successfully" "PHP $desired_version Installation Failed"
php_version=$(php -r 'echo PHP_VERSION;')
if [[ $php_version == *"$desired_version"* ]]; then
echo -e "\e[32mPHP Installed with version $php_version\e[0m"
# nothing to do as PHP is already installed with desired version
else
echo -e "\e[31mPHP Version is $php_version that is not desired one\e[0m"
# installed desired version of php
sudo a2dismod php$php_version
sudo a2enmod php$desired_version
sudo update-alternatives --set php /usr/bin/php$desired_version
fi
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
document_root=$2
# Create the document root directory
mkdir -p "$document_root"
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
a2ensite "$domain_name.conf" # enable virtual host
systemctl restart apache2 # restart apache
check_last_command_execution "Virtual host for $domain_name created successfully!" "Failed to create virtual host for $domain_name"
}
# function to check domain or sub domain
function installSSL {
domain_name=$1
isSubdomain=$2
echo "Installing Certbot first."
sudo apt-get install certbot python3-certbot-apache -y
check_last_command_execution "Certbot Installed Successfully" "Failed Certbot Installation"
sudo a2enmod ssl
sudo systemctl restart apache2
if [ "$isSubdomain" = true ] ; then
sudo certbot --apache -d $domain_name --register-unsafely-without-email --agree-tos -n
else
sudo certbot --apache -d $domain_name -d www.$domain_name --register-unsafely-without-email --agree-tos -n 
fi
if [ $? -eq 0 ]; then
echo -e "\e[32mSSL Installed Successfully\e[0m"
app_url="https://$domain_name"
else
echo -e "\e[31mSSL Installation Failed\e[0m"
app_url="http://$domain_name"
fi
echo "SET - APP Url is: $app_url"
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
function add_ssh_known_hosts {
# "Adding bitbucket.org to known hosts"
echo "Adding bitbucket.org to known hosts"
# create known_hosts file
sudo truncate -s 0 ~/.ssh/known_hosts
ssh-keygen -R bitbucket.org && curl https://bitbucket.org/site/ssh >> ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts && chmod 700 ~/.ssh
check_last_command_execution "bitbucket.org added to known hosts" "Failed to add bitbucket.org to known hosts"
}
## Function to clean installation directories first
function clean_installation_directories {
echo "Cleaning Installation Directories"
document_root=$1
rm -rf $document_root/*  2> /dev/null # remove files
rm -rf $document_root/.* 2> /dev/null # remove hidden files
}
## Function to clone from git 
function clone_from_git {
git_branch=$1
document_root=$2
add_ssh_known_hosts # call function to add bitbucket.org to known hosts
cd $document_root
apt install git -y # install git
git clone  -b $git_branch git@bitbucket.org:techsmarters8333/smarterpanel-base.git .
check_last_command_execution "Smarters Panel Cloned Successfully" "Smarters Panel Cloning Failed"
}
### Function to create .env File ####
function create_env_file {
echo "Creating .env file"
document_root=$1
app_url=$2
database_name=$3
database_user=$4
database_user_password=$5
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
}
## Function to install Composer ##
function install_composer {
echo "Installing Composer"
cd ~
# install composer with no interaction
echo "Installing Composer"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --version=2.1.8 --quiet --no-interaction 
check_last_command_execution "Composer Installed Successfully" "Composer Installation Failed.Exit the script"
}
## Function Node JS Installation ##
function install_nodejs {
echo "Installing NodeJS"
# install nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
check_last_command_execution "NodeJS Installed Successfully" "NodeJS Installation Failed.Exit the script"
}
### Function to Give Permissions to Laravel Directories ###
function give_permissions_to_laravel_directories {
echo "Giving Permissions to Laravel Directories"
document_root=$1
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
}
# Function to print a horizontal line
print_horizontal_line() {
    echo "-----------------------------------------"
}

# Function to print a vertical line
print_vertical_line() {
echo "|                                                            |"
}
# Function to print the GUI pattern
print_gui_pattern() {
app_url=$1
print_horizontal_line
print_vertical_line
echo "|     Smarters Panel Installed"
echo "|     App URL: $app_url"                   
echo "|     Admin APP URL: $app_url/admin"
echo "|     Admin Username: admin@smarterspanel.com"  
echo "|     Admin Password: password"               
print_vertical_line
print_horizontal_line
}
function final_check {
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
nodejs_path=$(which node)
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
}
########### FUNCTION to Install Smarters Panel ###########
function install_smarters_panel {
domain_name=$1
document_root=$2
git_branch=$3
mysql_root_pass=$4
isSubdomain=$5
desired_version="8.1" # desired version of php
install_apache
install_mysql_with_defined_password $mysql_root_pass
create_database_and_database_user $mysql_root_pass
install_php_with_desired_version $desired_version
create_virtual_host $domain_name $document_root
if [ "$sslInstallation" = true ] ; then
installSSL $domain_name $isSubdomain
fi 
clean_installation_directories $document_root # call function to clean installation directories
clone_from_git $git_branch $document_root # call function to clone from git
mysql -u $database_user -p$database_user_password -e "show databases;" 2> /dev/null
check_last_command_execution " MySQL Connection is Fine. Green Flag to create .env file" "MySQL Connection Failed.Exit the script"
create_env_file $document_root $app_url $database_name $database_user $database_user_password
install_composer
cd $document_root # change directory to document root
# install composer
composer install --no-interaction
check_last_command_execution "Composer Installed Successfully" "Composer Installation Failed.Exit the script"
install_nodejs
npm install 
check_last_command_execution "NPM Installed Successfully" "NPM Installation Failed.Exit the script"
npm run prod
check_last_command_execution "NPM Run Dev Successfully" "NPM Run Dev Failed.Exit the script"
php artisan key:generate
check_last_command_execution "Artisan Key Generated Successfully" "Artisan Key Generation Failed.Exit the script"
php artisan migrate
check_last_command_execution "Artisan Migrate Successfully" "Artisan Migrate Failed.Exit the script"
php artisan db:seed
check_last_command_execution "Artisan Seed Successfully" "Artisan Seed Failed.Exit the script"
php artisan storage:link
check_last_command_execution "Artisan Storage Link Successfully" "Artisan Storage Link Failed.Exit the script"
# run artisan optimize
php artisan optimize:clear
check_last_command_execution "Artisan Optimize Successfully" "Artisan Optimize Failed.Exit the script"
final_check # call function to check if everything is working fine
give_permissions_to_laravel_directories $document_root
print_gui_pattern $app_url
rm -rf /root/server-setup.sh 2> /dev/null # remove files
}
# Function to update the Smarters Panel on Commit
function update_smarters_panel {
echo "Updating the Smarters Panel on Commit"
document_root=$1
git_branch=$2
cd $document_root
chown -R $USER:$USER $document_root # change ownership to current user for clonning
# rm -rf smarterpanel-base
git stash
git pull origin $git_branch
check_last_command_execution "Smarters Panel Updated Successfully" "Smarters Panel Update Failed.Exit the script"
npm run prod
check_last_command_execution "NPM Run Prod Successfully" "NPM Run Prod Failed.Exit the script"
php artisan migrate
check_last_command_execution "Artisan Migrate Successfully" "Artisan Migrate Failed.Exit the script"
# run artisan optimize
php artisan optimize:clear
check_last_command_execution "Artisan Optimize Successfully" "Artisan Optimize Failed.Exit the script"
# give permissions to laravel directories
give_permissions_to_laravel_directories $document_root
}
################### Start Script ##################
echo -e "\e[1;43mWelcome to Smarters Panel Installation with LAMP\e[0m"
while getopts ":d:m:b:" o
do
case "${o}" in
d) domain_name=${OPTARG};;
m) mysql_root_pass=${OPTARG};;
b) git_branch=${OPTARG};;
esac
done
# Define Some Variables
bold=$(tput bold)
normal=$(tput sgr0)
isMasked=false # by default it's false to show credentials in the logs
# Echo the options provided by user
echo "###### Options Provided by User ######"
[[ ! -z $domain_name ]] && echo "${bold}domain_name:${normal}" $domain_name
if [ "$isMasked" = false ] ; then
[[ ! -z $mysql_root_pass ]] && echo "${bold}mysql_root_pass:${normal}" $mysql_root_pass
fi
[[ ! -z $git_branch ]] && echo "${bold}git_branch:${normal}" $git_branch
echo "###### Options Provided by User ######"
set_check_valid_domain_name $domain_name 
# Start logging the script
echo -e "\033[33mLogging the script into server-setup-$domain_name.log\e[0m"
exec > >(tee -i server-setup-$domain_name.log)
exec 2>&1
# if git_branch is empty then set it to master
if [ -z "$git_branch" ]
then
echo -e "\033[33m Provide Git Branch So, It can not be empty \033[0m"
exit 1
fi
echo "SET - ${bold}Domain Name is: ${normal} $domain_name"
document_root="/var/www/$domain_name" #Till here domain either is domain /subdomain OR IP Address 
echo "SET - ${bold}Document Root is: ${normal} $document_root"
echo "SET - ${bold}Git Branch is: ${normal} $git_branch"
########### Smarters Panel Installation &  Updating Started  #####
echo "##### Checking if Smarters Panel is already installed or not #####"
# check if laravel is installed already or not
if [ -f "$document_root/.env" ] && [ -f "$document_root/server.php" ]; then
echo -e "\e[32mSmarters Panel is already installed\e[0m"
## Update the Smarters Panel ####
update_smarters_panel $document_root $git_branch
else
echo "##### Installing Smarters Panel #####"
install_smarters_panel $domain_name $document_root $git_branch $mysql_root_pass $isSubdomain
fi
########### Smarters Panel Installation &  Updating Ended  #####