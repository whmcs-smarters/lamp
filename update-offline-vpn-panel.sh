#!/bin/bash
# This script will update the Smarters Panel on your server.
document_root="<give-path-here>"
chown -R root:root $document_root
cd $document_root
git stash
git pull 
composer install --no-interaction
php artisan migrate
#run artisan optimize
php artisan optimize:clear
chown -R www-data:www-data $document_root
