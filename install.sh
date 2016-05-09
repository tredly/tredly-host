#!/bin/sh

LOGFILE="/var/log/tredly-install.log"

# make sure this user is root
euid=$( id -u )
if test $euid != 0
then
   echo "Please run this installer as root." 1>&2
   exit 1
fi

# force an update on pkg in case the cache is out of date and bash install fails
pkg update -f

# install bash before invoking the bash installer
pkg install -y bash

if test $? != 0
then
    echo "Failed to Download Bash"
    exit 1
fi

./helpers/bash_install.sh

if test $? == 0
then
    echo -e "\e[35m"
    echo "################"
    echo "Install complete"
    echo "################"
    echo "Please reboot your host for the new kernel and settings to take effect."
    echo -e "\e[39m"
else
    echo -e "\e[35m"
    echo "################"
    echo "An error occurred during tredly-host installation."
    echo "################"
    echo -e "\e[39m"
fi
