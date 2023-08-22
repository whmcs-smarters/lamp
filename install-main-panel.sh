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
rm -rf /root/install-main-vpn-panel.sh 2> /dev/null # remove files
echo "Check Logs for more details: install-main-vpn-panel-$domain_name.log"
exit 1
fi
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
database_name=smarters_radius_$(generate_random_database_name)
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
function add_ssh_known_hosts {
# "Adding bitbucket.org to known hosts"
echo "Adding bitbucket.org to known hosts"
# create known_hosts file
sudo truncate -s 0 ~/.ssh/known_hosts
ssh-keygen -R bitbucket.org && curl https://bitbucket.org/site/ssh >> ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts && chmod 700 ~/.ssh
check_last_command_execution "bitbucket.org added to known hosts" "Failed to add bitbucket.org to known hosts"
}
## Function to clone from git 
function clone_from_git {
git_branch=$1
document_root=$2
add_ssh_known_hosts # call function to add bitbucket.org to known hosts
cd $document_root
apt install git -y # install git
git clone  -b $git_branch git clone git@bitbucket.org:techsmarters8333/smarters-vpn-panel-freeradius.git .
check_last_command_execution "Smarters VPN Panel Cloned Successfully" "Smarters VPN Panel Cloning Failed"
}
### Function to create .env File ####
function create_db_file {
echo "Creating db.js file"
document_root=$1
database_name=$2
database_user=$3
database_user_password=$4
sudo truncate -s 0 $document_root/db.js
cat >> $document_root/db.js <<EOF
DB_PASSWORD=$database_user_password
exports.dbname = $database_name;
exports.dbhost = 127.0.0.1';
exports.dbuser = $database_user;
exports.dbpassword = $database_user_password;
EOF
}
### Function to create config.js File ####
function edit_config_js {
echo "Editing config.js file"
document_root=$1
app_url=$2
sudo truncate -s 0 $document_root/config.js
cat >> $document_root/config.js <<EOF
exports.panelurl = '$app_url';
EOF
}
## Function Node JS Installation ##
function install_nodejs {
echo "Installing NodeJS"
# install nodejs
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
check_last_command_execution "NodeJS Installed Successfully" "NodeJS Installation Failed.Exit the script"
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

function check_ubuntu_20_04 {
    if [[ $(lsb_release -rs) == "20.04" ]]; then
        echo "OS Confirmed: Ubuntu 20.04"
    else
        echo "Ubuntu 20.04 is required to run this script"
        exit 1
    fi
}
function check_root {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# function to import freeradius mysql and configure it
function configure_mysql_freeradius {
$MYSQL_ROOT_PASSWORD=$1
$database_name=$2
$database_user=$3
$database_user_password=$4

# Import the freeradius mysql schema
mysql -u root -p$MYSQL_ROOT_PASSWORD $database_name < /etc/freeradius/mods-config/sql/main/mysql/schema.sql
check_last_command_execution "Freeradius MySQL Schema Imported Successfully" "Freeradius MySQL Schema Import Failed"
# Configure the freeradius mysql module
# empty the file
truncate -s 0 /etc/freeradius/mods-available/sql
cat > /etc/freeradius/mods-available/sql <<EOF
sql {
driver = "rlm_sql_mysql"

dialect = "mysql"

# Connection info:
server = "127.0.0.1"
port = 3306
login = "$database_user"
password = "$database_user_password"

# Database table configuration for everything except Oracle
radius_db = "$database_name"

 acct_table1 = "radacct"
 acct_table2 = "radacct"

# Allow for storing data after authentication
postauth_table = "radpostauth"

# Tables containing 'check' items
authcheck_table = "radcheck"
groupcheck_table = "radgroupcheck"

# Tables containing 'reply' items
authreply_table = "radreply"
groupreply_table = "radgroupreply"

# Table to keep group info
usergroup_table = "radusergroup"

# Remove stale session if checkrad does not see a double login
delete_stale_sessions = yes

# Set to ‘yes’ to read radius clients from the database (‘nas’ table)
# Clients will ONLY be read on server startup.
read_clients = yes

# Table to keep radius client info
client_table = "nas"

# This entry should be used for the default instance (sql {})
# of the SQL module.
group_attribute = "SQL-Group"

\$INCLUDE \${modconfdir}/\${.:name}/main/\${dialect}/queries.conf
}
EOF
ln -s /etc/freeradius/mods-available/sql /etc/freeradius/mods-enabled/sql
# change the group of sql configuration file
echo "`date +"%Y%m%d"` `date +"%H:%M:%S"` vpnpanel setup: INFO: changing group of sql configuration file "
chgrp -h freerad /etc/freeradius/mods-enabled/sql
chown freerad:freerad /etc/freeradius/mods-enabled/sql
chmod 644 /etc/freeradius/mods-enabled/sql
#restart freeradius
systemctl restart freeradius
check_last_command_execution "Freeradius Restarted Successfully" "Freeradius Restart Failed"
}
## Function to set up virtual server for freeradius 
  function configure_freeradius_virtual_server {
	# removing existing default virtual server
	echo "removing existing default virtual server"
	rm -rf /etc/freeradius/sites-enabled/default
	rm -rf /etc/freeradius/sites-available/default 
	cd /etc/freeradius/sites-available/
	echo "Downloading default virtual server"
 	wget https://raw.githubusercontent.com/whmcs-smarters/lamp/main/default
	ln -s /etc/freeradius/sites-available/default /etc/freeradius/sites-enabled/default
	# restart freeradius
	systemctl restart freeradius
	check_last_command_execution "Freeradius Restarted Successfully" "Freeradius Restart Failed"
  }

# Install Freeradius
function install_freeradius {
check_ubuntu_20_04
check_root
echo "Installing Freeradius"
apt-get update -y && apt-get install -y gnupg2 curl
install -d -o root -g root -m 0755 /etc/apt/keyrings
curl -s 'https://packages.networkradius.com/pgp/packages%40networkradius.com' | \
    sudo tee /etc/apt/keyrings/packages.networkradius.com.asc > /dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.networkradius.com.asc] http://packages.networkradius.com/freeradius-3.2/ubuntu/focal focal main" | \
    sudo tee /etc/apt/sources.list.d/networkradius.list > /dev/null
    apt-get update -y &&
    apt-get install -y freeradius freeradius-mysql
    check_last_command_execution "Freeradius Installed Successfully" "Freeradius Installation Failed"
    # Configure Freeradius
	configure_mysql_freeradius $MYSQL_ROOT_PASSWORD $database_name $database_user $database_user_password
   	configure_freeradius_virtual_server
    # restart freeradius
    systemctl restart freeradius
    # check freeradius status
    systemctl status freeradius
    # check freeradius version
    freeradius -v | head -n 1
}
########### FUNCTION to Install Smarters Panel ###########
function install_smarters_panel {
domain_name=$1
document_root=$2
git_branch=$3
mysql_root_pass=$4
isSubdomain=$5
install_mysql_with_defined_password $mysql_root_pass
create_database_and_database_user $mysql_root_pass
mysql -u $database_user -p$database_user_password -e "show databases;" 2> /dev/null
check_last_command_execution " MySQL Connection is Fine. Green Flag to create .env file" "MySQL Connection Failed.Exit the script"
clone_from_git $git_branch $document_root # call function to clone from git
create_db_file $document_root $database_name $database_user $database_user_password
edit_config_js $document_root $app_url
install_nodejs
#npm install 
npm install
check_last_command_execution "NPM Installed Successfully" "NPM Installation Failed.Exit the script"
cd $document_root
NODE_ENV=production pm2 start app.js
NODE_ENV=production pm2 start checkstatus.js
check_last_command_execution "Smarters Panel Installed Successfully" "Smarters Panel Installation Failed.Exit the script"
# Install Freeradius
install_freeradius
print_gui_pattern $app_url
rm -rf /root/install-main-vpn-panel.sh 2> /dev/null # remove files
}
# Function to update the Smarters Panel on Commit
function update_smarters_panel {
echo "Updating the Smarters VPN Panel on Commit"
document_root=$1
git_branch=$2
cd $document_root
chown -R $USER:$USER $document_root # change ownership to current user for clonning
# rm -rf smarterpanel-base
git stash
git pull origin $git_branch
check_last_command_execution "Smarters Panel Updated Successfully" "Smarters Panel Update Failed.Exit the script"
pm2 restart all
}
################### Start Script ##################
echo -e "\e[1;43mWelcome to Smarters VPN Panel Installation with LAMP\e[0m"
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
document_root="/home/vpn-panel"
mkdir -p $document_root
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
echo -e "\033[33mLogging the script into install-main-vpn-panel-$domain_name.log\e[0m"
exec > >(tee -i install-main-vpn-panel-$domain_name.log)
exec 2>&1
# if git_branch is empty then set it to master
if [ -z "$git_branch" ]
then
echo -e "\033[33m Provide Git Branch So, It can not be empty \033[0m"
exit 1
fi
echo "SET - ${bold}Domain Name is: ${normal} $domain_name"
#document_root="/var/www/$domain_name" #Till here domain either is domain /subdomain OR IP Address 
echo "SET - ${bold}Document Root is: ${normal} $document_root"
echo "SET - ${bold}Git Branch is: ${normal} $git_branch"
########### Smarters Panel Installation &  Updating Started  #####
echo "##### Checking if Smarters Panel is already installed or not #####"
# check if laravel is installed already or not
if [ -f "$document_root/db.js" ] && [ -f "$document_root/config.js" ]; then
echo -e "\e[32mSmarters Panel is already installed\e[0m"
## Update the Smarters Panel ####
update_smarters_panel $document_root $git_branch
else
echo "##### Installing Smarters Panel #####"
install_smarters_panel $domain_name $document_root $git_branch $mysql_root_pass $isSubdomain
fi
########### Smarters Panel Installation &  Updating Ended  #####