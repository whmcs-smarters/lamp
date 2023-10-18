#!/bin/bash
# This script will update the Smarters Panel on your server.
# $1 = Document root path
document_root=$1
if [ -z "$document_root" ]
then
     echo "Document root path is empty. please provide the document root path as first argument"
     exit 1
fi
chown -R root:root $document_root
cd $document_root
git stash
git pull 
composer install --no-interaction
php artisan migrate
#run artisan optimize
php artisan optimize:clear
chown -R www-data:www-data $document_root
