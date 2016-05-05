#!/bin/sh

# make sure this user is root
euid=$( id -u )
if test $euid != 0
then
   echo "Please run this installer as root." 1>&2
   exit 1
fi
# install bash before invoking the bash installer
pkg install -y bash

./helpers/bash_install.sh

if test $? == 0
then
    echo -e "\e[35m"
    echo "################"
    echo "Install complete"
    echo "################"
    echo "Please reboot your host for the new kernel and settings to take effect."
    echo -e "\e[39m"
fi
