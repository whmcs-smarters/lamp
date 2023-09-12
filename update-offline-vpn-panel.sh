#!/bin/bash
# This script will update the Smarters Panel on your server.
chown -R root:root /var/www/billing.smartersvpn.com
cd /var/www/billing.smartersvpn.com
git stash
git pull 
composer install --no-interaction
php artisan migrate
#run artisan optimize
php artisan optimize:clear
chown -R www-data:www-data /var/www/billing.smartersvpn.com