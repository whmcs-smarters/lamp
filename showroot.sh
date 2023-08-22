#!/bin/bash
echo -e "\e[1;43mWelcome to Smarters Panel Installation with LAMP\e[0m"
while getopts ":d:m:b:" o
do
case "${o}" in
d) domain_name=${OPTARG};;
m) mysql_root_pass=${OPTARG};;
b) git_branch=${OPTARG};;
esac
done