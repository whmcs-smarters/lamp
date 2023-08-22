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
app_url=$2
database_name=$3
database_user=$4
database_user_password=$5
sudo truncate -s 0 $document_root/db.js
cat >> $document_root/db.js <<EOF
DB_PASSWORD=$database_user_password
exports.dbname = $database_name;
exports.dbhost = 127.0.0.1';
exports.dbuser = $database_user;
exports.dbpassword = $database_user_password;
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
function edit_config.js {
echo "Editing config.js file"
document_root=$1
app_url=$2
sudo truncate -s 0 $document_root/config.js
cat >> $document_root/config.js <<EOF
exports.panelurl = '$app_url';
EOF
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
function configure_freeradius {
$MYSQL_ROOT_PASSWORD=$1
$database_name=$1
$database_user=$2
$database_user_password=$3

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
# function configure_freeradius_virtual_server {
# 	rm -rf /etc/freeradius/sites-av/default
# 	wget 
# }
function custom_default_virtual_server {
truncate -s 0 /etc/freeradius/sites-available/default
# rm -rf /etc/freeradius/sites-enabled/default
cat > /etc/freeradius/sites-available/default <<EOF
######################################################################
#
#	As of 2.0.0, FreeRADIUS supports virtual hosts using the
#	"server" section, and configuration directives.
#
#	Virtual hosts should be put into the "sites-available"
#	directory.  Soft links should be created in the "sites-enabled"
#	directory to these files.  This is done in a normal installation.
#
#	If you are using 802.1X (EAP) authentication, please see also
#	the "inner-tunnel" virtual server.  You will likely have to edit
#	that, too, for authentication to work.
#
#	$Id: 3616050e7625eb6b5e2ba44782fcb737b2ae6136 $
#
######################################################################
#
#	Read "man radiusd" before editing this file.  See the section
#	titled DEBUGGING.  It outlines a method where you can quickly
#	obtain the configuration you want, without running into
#	trouble.  See also "man unlang", which documents the format
#	of this file.
#
#	This configuration is designed to work in the widest possible
#	set of circumstances, with the widest possible number of
#	authentication methods.  This means that in general, you should
#	need to make very few changes to this file.
#
#	The best way to configure the server for your local system
#	is to CAREFULLY edit this file.  Most attempts to make large
#	edits to this file will BREAK THE SERVER.  Any edits should
#	be small, and tested by running the server with "radiusd -X".
#	Once the edits have been verified to work, save a copy of these
#	configuration files somewhere.  (e.g. as a "tar" file).  Then,
#	make more edits, and test, as above.
#
#	There are many "commented out" references to modules such
#	as ldap, sql, etc.  These references serve as place-holders.
#	If you need the functionality of that module, then configure
#	it in radiusd.conf, and un-comment the references to it in
#	this file.  In most cases, those small changes will result
#	in the server being able to connect to the DB, and to
#	authenticate users.
#
######################################################################

server default {
#
#  If you want the server to listen on additional addresses, or on
#  additional ports, you can use multiple "listen" sections.
#
#  Each section make the server listen for only one type of packet,
#  therefore authentication and accounting have to be configured in
#  different sections.
#
#  The server ignore all "listen" section if you are using '-i' and '-p'
#  on the command line.
#
listen {
	#  Type of packets to listen for.
	#  Allowed values are:
	#	auth	listen for authentication packets
	#	acct	listen for accounting packets
	#	proxy   IP to use for sending proxied packets
	#	detail  Read from the detail file.  For examples, see
	#               raddb/sites-available/copy-acct-to-home-server
	#	status  listen for Status-Server packets.  For examples,
	#		see raddb/sites-available/status
	#	coa     listen for CoA-Request and Disconnect-Request
	#		packets.  For examples, see the file
	#		raddb/sites-available/coa
	#
	type = auth

	#  Note: "type = proxy" lets you control the source IP used for
	#        proxying packets, with some limitations:
	#
	#    * A proxy listener CANNOT be used in a virtual server section.
	#    * You should probably set "port = 0".
	#    * Any "clients" configuration will be ignored.
	#
	#  See also proxy.conf, and the "src_ipaddr" configuration entry
	#  in the sample "home_server" section.  When you specify the
	#  source IP address for packets sent to a home server, the
	#  proxy listeners are automatically created.

	#  ipaddr/ipv4addr/ipv6addr - IP address on which to listen.
	#  If multiple ones are listed, only the first one will
	#  be used, and the others will be ignored.
	#
	#  The configuration options accept the following syntax:
	#
	#  ipv4addr - IPv4 address (e.g.192.0.2.3)
	#  	    - wildcard (i.e. *)
	#  	    - hostname (radius.example.com)
	#  	      Only the A record for the host name is used.
	#	      If there is no A record, an error is returned,
	#	      and the server fails to start.
	#
	#  ipv6addr - IPv6 address (e.g. 2001:db8::1)
	#  	    - wildcard (i.e. *)
	#  	    - hostname (radius.example.com)
	#  	      Only the AAAA record for the host name is used.
	#	      If there is no AAAA record, an error is returned,
	#	      and the server fails to start.
	#
	#  ipaddr   - IPv4 address as above
	#  	    - IPv6 address as above
	#  	    - wildcard (i.e. *), which means IPv4 wildcard.
	#	    - hostname
	#	      If there is only one A or AAAA record returned
	#	      for the host name, it is used.
	#	      If multiple A or AAAA records are returned
	#	      for the host name, only the first one is used.
	#	      If both A and AAAA records are returned
	#	      for the host name, only the A record is used.
	#
	# ipv4addr = *
	# ipv6addr = *
	ipaddr = *

	#  Port on which to listen.
	#  Allowed values are:
	#	integer port number (1812)
	#	0 means "use /etc/services for the proper port"
	port = 0

	#  Some systems support binding to an interface, in addition
	#  to the IP address.  This feature isn't strictly necessary,
	#  but for sites with many IP addresses on one interface,
	#  it's useful to say "listen on all addresses for eth0".
	#
	#  If your system does not support this feature, you will
	#  get an error if you try to use it.
	#
#	interface = eth0

	#  Per-socket lists of clients.  This is a very useful feature.
	#
	#  The name here is a reference to a section elsewhere in
	#  radiusd.conf, or clients.conf.  Having the name as
	#  a reference allows multiple sockets to use the same
	#  set of clients.
	#
	#  If this configuration is used, then the global list of clients
	#  is IGNORED for this "listen" section.  Take care configuring
	#  this feature, to ensure you don't accidentally disable a
	#  client you need.
	#
	#  See clients.conf for the configuration of "per_socket_clients".
	#
#	clients = per_socket_clients

	#
	#  Connection limiting for sockets with "proto = tcp".
	#
	#  This section is ignored for other kinds of sockets.
	#
	limit {
	      #
	      #  Limit the number of simultaneous TCP connections to the socket
	      #
	      #  The default is 16.
	      #  Setting this to 0 means "no limit"
	      max_connections = 16

	      #  The per-socket "max_requests" option does not exist.

	      #
	      #  The lifetime, in seconds, of a TCP connection.  After
	      #  this lifetime, the connection will be closed.
	      #
	      #  Setting this to 0 means "forever".
	      lifetime = 0

	      #
	      #  The idle timeout, in seconds, of a TCP connection.
	      #  If no packets have been received over the connection for
	      #  this time, the connection will be closed.
	      #
	      #  Setting this to 0 means "no timeout".
	      #
	      #  We STRONGLY RECOMMEND that you set an idle timeout.
	      #
	      idle_timeout = 30
	}
}

#
#  This second "listen" section is for listening on the accounting
#  port, too.
#
listen {
	ipaddr = *
#	ipv6addr = ::
	port = 0
	type = acct
#	interface = eth0
#	clients = per_socket_clients

	limit {
		#  The number of packets received can be rate limited via the
		#  "max_pps" configuration item.  When it is set, the server
		#  tracks the total number of packets received in the previous
		#  second.  If the count is greater than "max_pps", then the
		#  new packet is silently discarded.  This helps the server
		#  deal with overload situations.
		#
		#  The packets/s counter is tracked in a sliding window.  This
		#  means that the pps calculation is done for the second
		#  before the current packet was received.  NOT for the current
		#  wall-clock second, and NOT for the previous wall-clock second.
		#
		#  Useful values are 0 (no limit), or 100 to 10000.
		#  Values lower than 100 will likely cause the server to ignore
		#  normal traffic.  Few systems are capable of handling more than
		#  10K packets/s.
		#
		#  It is most useful for accounting systems.  Set it to 50%
		#  more than the normal accounting load, and you can be sure that
		#  the server will never get overloaded
		#
#		max_pps = 0

		# Only for "proto = tcp". These are ignored for "udp" sockets.
		#
#		idle_timeout = 0
#		lifetime = 0
#		max_connections = 0
	}
}

# IPv6 versions of the above - read their full config to understand options
listen {
	type = auth
	ipv6addr = ::	# any.  ::1 == localhost
	port = 0
#	interface = eth0
#	clients = per_socket_clients
	limit {
	      max_connections = 16
	      lifetime = 0
	      idle_timeout = 30
	}
}

listen {
	ipv6addr = ::
	port = 0
	type = acct
#	interface = eth0
#	clients = per_socket_clients

	limit {
#		max_pps = 0
#		idle_timeout = 0
#		lifetime = 0
#		max_connections = 0
	}
}

#  Authorization. First preprocess (hints and huntgroups files),
#  then realms, and finally look in the "users" file.
#
#  Any changes made here should also be made to the "inner-tunnel"
#  virtual server.
#
#  The order of the realm modules will determine the order that
#  we try to find a matching realm.
#
#  Make *sure* that 'preprocess' comes before any realm if you
#  need to setup hints for the remote radius server
authorize {
	#
	#  Take a User-Name, and perform some checks on it, for spaces and other
	#  invalid characters.  If the User-Name appears invalid, reject the
	#  request.
	#
	#  See policy.d/filter for the definition of the filter_username policy.
	#
	filter_username

	#
	#  Some broken equipment sends passwords with embedded zeros.
	#  i.e. the debug output will show
	#
	#	User-Password = "password\000\000"
	#
	#  This policy will fix it to just be "password".
	#
#	filter_password

	#
	#  The preprocess module takes care of sanitizing some bizarre
	#  attributes in the request, and turning them into attributes
	#  which are more standard.
	#
	#  It takes care of processing the 'raddb/mods-config/preprocess/hints' 
	#  and the 'raddb/mods-config/preprocess/huntgroups' files.
	preprocess

	#  If you intend to use CUI and you require that the Operator-Name
	#  be set for CUI generation and you want to generate CUI also
	#  for your local clients then uncomment the operator-name
	#  below and set the operator-name for your clients in clients.conf
#	operator-name

	#
	#  If you want to generate CUI for some clients that do not
	#  send proper CUI requests, then uncomment the
	#  cui below and set "add_cui = yes" for these clients in clients.conf
#	cui

	#
	#  If you want to have a log of authentication requests,
	#  un-comment the following line.
#	auth_log

	#
	#  The chap module will set 'Auth-Type := CHAP' if we are
	#  handling a CHAP request and Auth-Type has not already been set
	chap

	#
	#  If the users are logging in with an MS-CHAP-Challenge
	#  attribute for authentication, the mschap module will find
	#  the MS-CHAP-Challenge attribute, and add 'Auth-Type := MS-CHAP'
	#  to the request, which will cause the server to then use
	#  the mschap module for authentication.
	mschap

	#
	#  If you have a Cisco SIP server authenticating against
	#  FreeRADIUS, uncomment the following line, and the 'digest'
	#  line in the 'authenticate' section.
	digest

	#
	#  The WiMAX specification says that the Calling-Station-Id
	#  is 6 octets of the MAC.  This definition conflicts with
	#  RFC 3580, and all common RADIUS practices.  Un-commenting
	#  the "wimax" module here means that it will fix the
	#  Calling-Station-Id attribute to the normal format as
	#  specified in RFC 3580 Section 3.21
#	wimax

	#
	#  Look for IPASS style 'realm/', and if not found, look for
	#  '@realm', and decide whether or not to proxy, based on
	#  that.
#	IPASS

	#
	#  If you are using multiple kinds of realms, you probably
	#  want to set "ignore_null = yes" for all of them.
	#  Otherwise, when the first style of realm doesn't match,
	#  the other styles won't be checked.
	#
	suffix
#	ntdomain

	#
	#  This module takes care of EAP-MD5, EAP-TLS, and EAP-LEAP
	#  authentication.
	#
	#  It also sets the EAP-Type attribute in the request
	#  attribute list to the EAP type from the packet.
	#
	#  The EAP module returns "ok" or "updated" if it is not yet ready
	#  to authenticate the user.  The configuration below checks for
	#  "ok", and stops processing the "authorize" section if so.
	#
	#  Any LDAP and/or SQL servers will not be queried for the
	#  initial set of packets that go back and forth to set up
	#  TTLS or PEAP.
	#
	#  The "updated" check is commented out for compatibility with
	#  previous versions of this configuration, but you may wish to
	#  uncomment it as well; this will further reduce the number of
	#  LDAP and/or SQL queries for TTLS or PEAP.
	#
	eap {
		ok = return
#		updated = return
	}

	#
	#  Pull crypt'd passwords from /etc/passwd or /etc/shadow,
	#  using the system API's to get the password.  If you want
	#  to read /etc/passwd or /etc/shadow directly, see the
	#  mods-available/passwd module.
	#
#	unix

	#
	#  Read the 'users' file.  In v3, this is located in
	#  raddb/mods-config/files/authorize
	files

	#
	#  Look in an SQL database.  The schema of the database
	#  is meant to mirror the "users" file.
	#
	#  See "Authorization Queries" in mods-available/sql
	sql

	#
	#  If you are using /etc/smbpasswd, and are also doing
	#  mschap authentication, the un-comment this line, and
	#  configure the 'smbpasswd' module.
#	smbpasswd

	#
	#  The ldap module reads passwords from the LDAP database.
	-ldap

	#
	#  Enforce daily limits on time spent logged in.
#	daily

	#
	expiration
	logintime

	#
	#  If no other module has claimed responsibility for
	#  authentication, then try to use PAP.  This allows the
	#  other modules listed above to add a "known good" password
	#  to the request, and to do nothing else.  The PAP module
	#  will then see that password, and use it to do PAP
	#  authentication.
	#
	#  This module should be listed last, so that the other modules
	#  get a chance to set Auth-Type for themselves.
	#
	pap

	#
	#  If "status_server = yes", then Status-Server messages are passed
	#  through the following section, and ONLY the following section.
	#  This permits you to do DB queries, for example.  If the modules
	#  listed here return "fail", then NO response is sent.
	#
#	Autz-Type Status-Server {
#
#	}
}


#  Authentication.
#
#
#  This section lists which modules are available for authentication.
#  Note that it does NOT mean 'try each module in order'.  It means
#  that a module from the 'authorize' section adds a configuration
#  attribute 'Auth-Type := FOO'.  That authentication type is then
#  used to pick the appropriate module from the list below.
#

#  In general, you SHOULD NOT set the Auth-Type attribute.  The server
#  will figure it out on its own, and will do the right thing.  The
#  most common side effect of erroneously setting the Auth-Type
#  attribute is that one authentication method will work, but the
#  others will not.
#
#  The common reasons to set the Auth-Type attribute by hand
#  is to either forcibly reject the user (Auth-Type := Reject),
#  or to or forcibly accept the user (Auth-Type := Accept).
#
#  Note that Auth-Type := Accept will NOT work with EAP.
#
#  Please do not put "unlang" configurations into the "authenticate"
#  section.  Put them in the "post-auth" section instead.  That's what
#  the post-auth section is for.
#
authenticate {
	#
	#  PAP authentication, when a back-end database listed
	#  in the 'authorize' section supplies a password.  The
	#  password can be clear-text, or encrypted.
	Auth-Type PAP {
		pap
	}

	#
	#  Most people want CHAP authentication
	#  A back-end database listed in the 'authorize' section
	#  MUST supply a CLEAR TEXT password.  Encrypted passwords
	#  won't work.
	Auth-Type CHAP {
		chap
	}

	#
	#  MSCHAP authentication.
	Auth-Type MS-CHAP {
		mschap
	}

	#
	#  For old names, too.
	#
	mschap

	#
	#  If you have a Cisco SIP server authenticating against
	#  FreeRADIUS, uncomment the following line, and the 'digest'
	#  line in the 'authorize' section.
	digest

	#
	#  Pluggable Authentication Modules.
#	pam

	#  Uncomment it if you want to use ldap for authentication
	#
	#  Note that this means "check plain-text password against
	#  the ldap database", which means that EAP won't work,
	#  as it does not supply a plain-text password.
	#
	#  We do NOT recommend using this.  LDAP servers are databases.
	#  They are NOT authentication servers.  FreeRADIUS is an
	#  authentication server, and knows what to do with authentication.
	#  LDAP servers do not.
	#
#	Auth-Type LDAP {
#		ldap
#	}

	#
	#  Allow EAP authentication.
	eap

	#
	#  The older configurations sent a number of attributes in
	#  Access-Challenge packets, which wasn't strictly correct.
	#  If you want to filter out these attributes, uncomment
	#  the following lines.
	#
#	Auth-Type eap {
#		eap {
#			handled = 1
#		}
#		if (handled && (Response-Packet-Type == Access-Challenge)) {
#			attr_filter.access_challenge.post-auth
#			handled  # override the "updated" code from attr_filter
#		}
#	}
}


#
#  Pre-accounting.  Decide which accounting type to use.
#
preacct {
	preprocess

	#
	#  Merge Acct-[Input|Output]-Gigawords and Acct-[Input-Output]-Octets
	#  into a single 64bit counter Acct-[Input|Output]-Octets64.
	#
#	acct_counters64

	#
	#  Session start times are *implied* in RADIUS.
	#  The NAS never sends a "start time".  Instead, it sends
	#  a start packet, *possibly* with an Acct-Delay-Time.
	#  The server is supposed to conclude that the start time
	#  was "Acct-Delay-Time" seconds in the past.
	#
	#  The code below creates an explicit start time, which can
	#  then be used in other modules.  It will be *mostly* correct.
	#  Any errors are due to the 1-second resolution of RADIUS,
	#  and the possibility that the time on the NAS may be off.
	#
	#  The start time is: NOW - delay - session_length
	#

#	update request {
#	  	&FreeRADIUS-Acct-Session-Start-Time = "%{expr: %l - %{%{Acct-Session-Time}:-0} - %{%{Acct-Delay-Time}:-0}}"
#	}


	#
	#  Ensure that we have a semi-unique identifier for every
	#  request, and many NAS boxes are broken.
	acct_unique

	#
	#  Look for IPASS-style 'realm/', and if not found, look for
	#  '@realm', and decide whether or not to proxy, based on
	#  that.
	#
	#  Accounting requests are generally proxied to the same
	#  home server as authentication requests.
#	IPASS
	suffix
#	ntdomain

	#
	#  Read the 'acct_users' file
	files
}

#
#  Accounting.  Log the accounting data.
#
accounting {
	#  Update accounting packet by adding the CUI attribute
	#  recorded from the corresponding Access-Accept
	#  use it only if your NAS boxes do not support CUI themselves
#	cui
	#
	#  Create a 'detail'ed log of the packets.
	#  Note that accounting requests which are proxied
	#  are also logged in the detail file.
	detail
#	daily

	#  Update the wtmp file
	#
	#  If you don't use "radlast", you can delete this line.
	unix

	#
	#  For Simultaneous-Use tracking.
	#
	#  Due to packet losses in the network, the data here
	#  may be incorrect.  There is little we can do about it.
#	radutmp
#	sradutmp

	#  Return an address to the IP Pool when we see a stop record.
#	main_pool

	#
	#  Log traffic to an SQL database.
	#
	#  See "Accounting queries" in mods-available/sql
	sql

	#
	#  If you receive stop packets with zero session length,
	#  they will NOT be logged in the database.  The SQL module
	#  will print a message (only in debugging mode), and will
	#  return "noop".
	#
	#  You can ignore these packets by uncommenting the following
	#  three lines.  Otherwise, the server will not respond to the
	#  accounting request, and the NAS will retransmit.
	#
#	if (noop) {
#		ok
#	}

	#  Cisco VoIP specific bulk accounting
#	pgsql-voip

	# For Exec-Program and Exec-Program-Wait
	exec

	#  Filter attributes from the accounting response.
	attr_filter.accounting_response

	#
	#  See "Autz-Type Status-Server" for how this works.
	#
#	Acct-Type Status-Server {
#
#	}
}


#  Session database, used for checking Simultaneous-Use. Either the radutmp
#  or rlm_sql module can handle this.
#  The rlm_sql module is *much* faster
session {
#	radutmp

	#
	#  See "Simultaneous Use Checking Queries" in mods-available/sql
	sql
}


#  Post-Authentication
#  Once we KNOW that the user has been authenticated, there are
#  additional steps we can take.
post-auth {
	#
	#  If you need to have a State attribute, you can
	#  add it here.  e.g. for later CoA-Request with
	#  State, and Service-Type = Authorize-Only.
	#
#	if (!&reply:State) {
#		update reply {
#			State := "0x%{randstr:16h}"
#		}
#	}

	#
	#  For EAP-TTLS and PEAP, add the cached attributes to the reply.
	#  The "session-state" attributes are automatically cached when
	#  an Access-Challenge is sent, and automatically retrieved
	#  when an Access-Request is received.
	#
	#  The session-state attributes are automatically deleted after
	#  an Access-Reject or Access-Accept is sent.
	#
	update {
		&reply: += &session-state:
	}

	#  Get an address from the IP Pool.
#	main_pool


	#  Create the CUI value and add the attribute to Access-Accept.
	#  Uncomment the line below if *returning* the CUI.
#	cui

	#
	#  If you want to have a log of authentication replies,
	#  un-comment the following line, and enable the
	#  'detail reply_log' module.
#	reply_log

	#
	#  After authenticating the user, do another SQL query.
	#
	#  See "Authentication Logging Queries" in mods-available/sql
	-sql

	#
	#  Un-comment the following if you want to modify the user's object
	#  in LDAP after a successful login.
	#
#	ldap

	# For Exec-Program and Exec-Program-Wait
	exec

	#
	#  Calculate the various WiMAX keys.  In order for this to work,
	#  you will need to define the WiMAX NAI, usually via
	#
	#	update request {
	#	       WiMAX-MN-NAI = "%{User-Name}"
	#	}
	#
	#  If you want various keys to be calculated, you will need to
	#  update the reply with "template" values.  The module will see
	#  this, and replace the template values with the correct ones
	#  taken from the cryptographic calculations.  e.g.
	#
	# 	update reply {
	#		WiMAX-FA-RK-Key = 0x00
	#		WiMAX-MSK = "%{EAP-MSK}"
	#	}
	#
	#  You may want to delete the MS-MPPE-*-Keys from the reply,
	#  as some WiMAX clients behave badly when those attributes
	#  are included.  See "raddb/modules/wimax", configuration
	#  entry "delete_mppe_keys" for more information.
	#
#	wimax


	#  If there is a client certificate (EAP-TLS, sometimes PEAP
	#  and TTLS), then some attributes are filled out after the
	#  certificate verification has been performed.  These fields
	#  MAY be available during the authentication, or they may be
	#  available only in the "post-auth" section.
	#
	#  The first set of attributes contains information about the
	#  issuing certificate which is being used.  The second
	#  contains information about the client certificate (if
	#  available).
#
#	update reply {
#	       Reply-Message += "%{TLS-Cert-Serial}"
#	       Reply-Message += "%{TLS-Cert-Expiration}"
#	       Reply-Message += "%{TLS-Cert-Subject}"
#	       Reply-Message += "%{TLS-Cert-Issuer}"
#	       Reply-Message += "%{TLS-Cert-Common-Name}"
#	       Reply-Message += "%{TLS-Cert-Subject-Alt-Name-Email}"
#
#	       Reply-Message += "%{TLS-Client-Cert-Serial}"
#	       Reply-Message += "%{TLS-Client-Cert-Expiration}"
#	       Reply-Message += "%{TLS-Client-Cert-Subject}"
#	       Reply-Message += "%{TLS-Client-Cert-Issuer}"
#	       Reply-Message += "%{TLS-Client-Cert-Common-Name}"
#	       Reply-Message += "%{TLS-Client-Cert-Subject-Alt-Name-Email}"
#	}

	#  Insert class attribute (with unique value) into response,
	#  aids matching auth and acct records, and protects against duplicate
	#  Acct-Session-Id. Note: Only works if the NAS has implemented
	#  RFC 2865 behaviour for the class attribute, AND if the NAS
	#  supports long Class attributes.  Many older or cheap NASes
	#  only support 16-octet Class attributes.
#	insert_acct_class

	#  MacSEC requires the use of EAP-Key-Name.  However, we don't
	#  want to send it for all EAP sessions.  Therefore, the EAP
	#  modules put required data into the EAP-Session-Id attribute.
	#  This attribute is never put into a request or reply packet.
	#
	#  Uncomment the next few lines to copy the required data into
	#  the EAP-Key-Name attribute
#	if (&reply:EAP-Session-Id) {
#		update reply {
#			EAP-Key-Name := &reply:EAP-Session-Id
#		}
#	}

	#  Remove reply message if the response contains an EAP-Message
	remove_reply_message_if_eap

	#
	#  Access-Reject packets are sent through the REJECT sub-section of the
	#  post-auth section.
	#
	#  Add the ldap module name (or instance) if you have set
	#  'edir_account_policy_check = yes' in the ldap module configuration
	#
	#  The "session-state" attributes are not available here.
	#
	Post-Auth-Type REJECT {
		# log failed authentications in SQL, too.
		-sql
		attr_filter.access_reject

		# Insert EAP-Failure message if the request was
		# rejected by policy instead of because of an
		# authentication failure
		eap

		#  Remove reply message if the response contains an EAP-Message
		remove_reply_message_if_eap
	}

	#
	#  Filter access challenges.
	#
	Post-Auth-Type Challenge {
#		remove_reply_message_if_eap
#		attr_filter.access_challenge.post-auth
	}

}

#
#  When the server decides to proxy a request to a home server,
#  the proxied request is first passed through the pre-proxy
#  stage.  This stage can re-write the request, or decide to
#  cancel the proxy.
#
#  Only a few modules currently have this method.
#
pre-proxy {
	# Before proxing the request add an Operator-Name attribute identifying
	# if the operator-name is found for this client.
	# No need to uncomment this if you have already enabled this in
	# the authorize section.
#	operator-name

	#  The client requests the CUI by sending a CUI attribute
	#  containing one zero byte.
	#  Uncomment the line below if *requesting* the CUI.
#	cui

	#  Uncomment the following line if you want to change attributes
	#  as defined in the preproxy_users file.
#	files

	#  Uncomment the following line if you want to filter requests
	#  sent to remote servers based on the rules defined in the
	#  'attrs.pre-proxy' file.
#	attr_filter.pre-proxy

	#  If you want to have a log of packets proxied to a home
	#  server, un-comment the following line, and the
	#  'detail pre_proxy_log' section, above.
#	pre_proxy_log
}

#
#  When the server receives a reply to a request it proxied
#  to a home server, the request may be massaged here, in the
#  post-proxy stage.
#
post-proxy {

	#  If you want to have a log of replies from a home server,
	#  un-comment the following line, and the 'detail post_proxy_log'
	#  section, above.
#	post_proxy_log

	#  Uncomment the following line if you want to filter replies from
	#  remote proxies based on the rules defined in the 'attrs' file.
#	attr_filter.post-proxy

	#
	#  If you are proxying LEAP, you MUST configure the EAP
	#  module, and you MUST list it here, in the post-proxy
	#  stage.
	#
	#  You MUST also use the 'nostrip' option in the 'realm'
	#  configuration.  Otherwise, the User-Name attribute
	#  in the proxied request will not match the user name
	#  hidden inside of the EAP packet, and the end server will
	#  reject the EAP request.
	#
	eap

	#
	#  If the server tries to proxy a request and fails, then the
	#  request is processed through the modules in this section.
	#
	#  The main use of this section is to permit robust proxying
	#  of accounting packets.  The server can be configured to
	#  proxy accounting packets as part of normal processing.
	#  Then, if the home server goes down, accounting packets can
	#  be logged to a local "detail" file, for processing with
	#  radrelay.  When the home server comes back up, radrelay
	#  will read the detail file, and send the packets to the
	#  home server.
	#
	#  With this configuration, the server always responds to
	#  Accounting-Requests from the NAS, but only writes
	#  accounting packets to disk if the home server is down.
	#
#	Post-Proxy-Type Fail-Accounting {
#			detail
#	}
}
}
EOF
# enable default freeradius virtual server
service freeradius restart
#ln -s /etc/freeradius/sites-available/default /etc/freeradius/sites-enabled/
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
    configure_freeradius $MYSQL_ROOT_PASSWORD $database_name $database_user $database_user_password
    custom_default_virtual_server
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
clone_from_git $git_branch $document_root # call function to clone from git
mysql -u $database_user -p$database_user_password -e "show databases;" 2> /dev/null
check_last_command_execution " MySQL Connection is Fine. Green Flag to create .env file" "MySQL Connection Failed.Exit the script"
create_db_file $document_root $app_url $database_name $database_user $database_user_password
edit_config.js $document_root $app_url
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
document_root="/root/"
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
exec > >(tee -i install-main-vpn-panel-$domain_name.log)
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
if [ -f "$document_root/db.js" ] && [ -f "$document_root/config.js" ]; then
echo -e "\e[32mSmarters Panel is already installed\e[0m"
## Update the Smarters Panel ####
update_smarters_panel $document_root $git_branch
else
echo "##### Installing Smarters Panel #####"
install_smarters_panel $domain_name $document_root $git_branch $mysql_root_pass $isSubdomain
fi
########### Smarters Panel Installation &  Updating Ended  #####
