#!/usr/local/bin/bash
##########################################################################
# Copyright 2016 Vuid Pty Ltd
# https://www.vuid.com
#
# This file is part of tredly-host.
#
# tredly-build is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# tredly-build is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with tredly-build.  If not, see <http://www.gnu.org/licenses/>.
##########################################################################

set -o pipefail

LOGFILE="/var/log/legr-install.log"
TREDLY_GIT_URL="https://github.com/tredly/tredly-build.git"
DEFAULT_CONTAINER_SUBNET="10.0.0.0/16"

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

source "${DIR}/lib/util.sh"
# make sure this script is running as root
cmn_assert_running_as_root

# Ask the user which interface they would like tredly set up on
IFS=$'\n' _interfaces=($( ifconfig | grep "^[a-zA-Z].*[0-9].*:" | grep -v "^lo0:" | grep -v "^bridge[0-9].*:" | awk '{ print $1 }' | tr -d : ))
echo ''
echo "=============================="
echo "Setting up networking"
echo ''

# if only one interface was found then use that by default
if [[ ${#_interfaces[@]} -eq 1 ]]; then
    EXT_INTERFACE="${_interfaces[0]}"
else
    while [[ -z "${EXT_INTERFACE}" ]]; do
        # have the user select the interface
        echo "More than one interface was found on this machine:"
        for _i in ${!_interfaces[@]}; do
            echo "$(( ${_i} + 1 )). ${_interfaces[${_i}]}"
        done
        
        read -p "Which would you like to use? " _userSelectInterface
        
        # ensure that the value we received lies within the bounds of the array
        if [[ ${_userSelectInterface} -lt 1 ]] || [[ ${_userSelectInterface} -gt ${#_interfaces[@]} ]] || ! is_int ${_userSelectInterface}; then
            echo "Invalid selection. Please try again."
            _userSelectInterface=''
        elif [[ -n "$( ifconfig | grep "^${_interfaces[$(( ${_userSelectInterface} - 1 ))]}:" )" ]]; then
            EXT_INTERFACE="${_interfaces[$(( ${_userSelectInterface} - 1 ))]}"
        fi
        
    done
fi

echo "Using ${EXT_INTERFACE} as your external interface."

# check if this has an ip address assigned to it
DEFAULT_EXT_IP=$( ifconfig ${EXT_INTERFACE} | grep 'inet ' | awk '{ print $2 }' )
DEFAULT_EXT_MASK_HEX=$( ifconfig ${EXT_INTERFACE} | grep 'inet ' | awk '{ print $4 }' | cut -d 'x' -f 2 )

DEFAULT_EXT_MASK=$(( 16#${DEFAULT_EXT_MASK_HEX:0:2} )).$(( 16#${DEFAULT_EXT_MASK_HEX:2:2} )).$(( 16#${DEFAULT_EXT_MASK_HEX:4:2} )).$(( 16#${DEFAULT_EXT_MASK_HEX:6:2} ))
DEFAULT_EXT_GATEWAY=$( netstat -r4n | grep '^default' | awk '{ print $2 }' )

_changeIP="y"

if [[ -z "${DEFAULT_EXT_IP}" ]]; then
    echo "No ip address is set for this interface."
else
    # check for a dhcp leases file for this interface
    if [[ -f "/var/db/dhclient.leases.${EXT_INTERFACE}" ]]; then
        # look for its current ip address within the leases file
        _numLeases=$( grep -E "${DEFAULT_EXT_IP}" "/var/db/dhclient.leases.${EXT_INTERFACE}" | wc -l )
        
        if [[ ${_numLeases} -gt 0 ]]; then
            # found a current lease for this ip address so throw a warning
            echo "========================================================================="
            echo "WARNING! The current IP address ${DEFAULT_EXT_IP} was set using DHCP!"
            echo "It is recommended that this address be changed to be outside of your DHCP pool"
            echo "========================================================================="
        fi
    fi
    echo "This interface currently has an ip address of ${DEFAULT_EXT_IP}."
    echo ''
    read -p "Would you like to change it? (y/n) " _changeIP
fi

if [[ "${_changeIP}" == 'y' ]] || [[ "${_changeIP}" == 'Y' ]]; then
    _user_EXT_IP=''
    while [[ -z "${EXT_IP}" ]]; do
        
        read -p "Please enter an IP address for ${EXT_INTERFACE} [${DEFAULT_EXT_IP}]: " _user_EXT_IP

        # if no input received then use the default
        if [[ -z ${_user_EXT_IP} ]] && [[ -n ${DEFAULT_EXT_IP} ]]; then
            echo "Using default of ${DEFAULT_EXT_IP}"
            EXT_IP="${DEFAULT_EXT_IP}"
        else
            # validate it
            if is_valid_ip4 "${_user_EXT_IP}"; then
                EXT_IP="${_user_EXT_IP}"
            else
                echo "Invalid IP4 Address."
            fi
        fi
    done

    _user_EXT_MASK=''
    while [[ -z "${EXT_MASK}" ]]; do
        read -p "Please enter a netmask for ${EXT_INTERFACE} [${DEFAULT_EXT_MASK}]: " _user_EXT_MASK

        # if no input received then use the default
        if [[ -z ${_user_EXT_MASK} ]] && [[ -n ${DEFAULT_EXT_MASK} ]]; then
            echo "Using default of ${DEFAULT_EXT_MASK}"
            EXT_MASK="${DEFAULT_EXT_MASK}"
        else
            # validate it
            if is_valid_ip4 "${_user_EXT_MASK}"; then
                EXT_MASK="${_user_EXT_MASK}"
            else
                echo "Invalid subnet mask."
            fi
        fi
    done

    _user_EXT_GATEWAY=''
    while [[ -z "${EXT_GATEWAY}" ]]; do
        read -p "Please enter your default gateway for ${EXT_INTERFACE} [${DEFAULT_EXT_GATEWAY}]: " _user_EXT_GATEWAY

        # if no input received then use the default
        if [[ -z ${_user_EXT_GATEWAY} ]] && [[ -n ${DEFAULT_EXT_GATEWAY} ]]; then
            echo "Using default of ${DEFAULT_EXT_GATEWAY}"
            EXT_GATEWAY="${DEFAULT_EXT_GATEWAY}"
        else
            # validate it
            if is_valid_ip4 "${_user_EXT_GATEWAY}"; then
                EXT_GATEWAY="${_user_EXT_GATEWAY}"
            else
                echo "Invalid IP4 Address"
            fi
        fi
    done
else
    # set the variables to the default values
    EXT_IP="${DEFAULT_EXT_IP}"
    EXT_MASK="${DEFAULT_EXT_MASK}"
    EXT_GATEWAY="${DEFAULT_EXT_GATEWAY}"
fi

_user_MY_HOSTNAME=''
while [[ -z "${MY_HOSTNAME}" ]]; do
    read -p "Please enter a hostname for your host [${HOSTNAME}]: " _user_MY_HOSTNAME
    
    # if no input received then use the default
    if [[ -z ${_user_MY_HOSTNAME} ]] && [[ -n ${HOSTNAME} ]]; then
        echo "Using default of ${HOSTNAME}"
        MY_HOSTNAME="${HOSTNAME}"
    else
        # validate it
        if [[ -n "${_user_MY_HOSTNAME}" ]]; then
            MY_HOSTNAME="${_user_MY_HOSTNAME}"
        else
            echo "Invalid Hostname"
        fi
    fi
done

_user_CONTAINER_SUBNET=''
while [[ -z "${CONTAINER_SUBNET}" ]]; do
    read -p "Please enter the private subnet for your containers [${DEFAULT_CONTAINER_SUBNET}]: " _user_CONTAINER_SUBNET

    # if no input received then use the default
    if [[ -z ${_user_CONTAINER_SUBNET} ]] && [[ -n ${DEFAULT_CONTAINER_SUBNET} ]]; then
        echo "Using default of ${DEFAULT_CONTAINER_SUBNET}"
        CONTAINER_SUBNET="${DEFAULT_CONTAINER_SUBNET}"
    else
        # validate it

        # split it into network and cidr
        _user_CONTAINER_SUBNET_NET="$( lcut "${_user_CONTAINER_SUBNET}" '/')"
        _user_CONTAINER_SUBNET_CIDR="$( rcut "${_user_CONTAINER_SUBNET}" '/')"

        if ! is_valid_ip4 "${_user_CONTAINER_SUBNET_NET}" || ! is_valid_cidr "${_user_CONTAINER_SUBNET_CIDR}"; then
            echo "Invalid network address ${_user_CONTAINER_SUBNET}. Please use the format x.x.x.x/y, eg 10.0.0.0/16"
        else
            CONTAINER_SUBNET="${_user_CONTAINER_SUBNET}"
        fi
    fi
done

# extract the net and cidr from the container subnet we are using
CONTAINER_SUBNET_NET="$( lcut "${CONTAINER_SUBNET}" '/')"
CONTAINER_SUBNET_CIDR="$( rcut "${CONTAINER_SUBNET}" '/')"
# Get the default host ip address on the private container network
_hostPrivateIP=$( get_last_usable_ip4_in_network "${CONTAINER_SUBNET_NET}" "${CONTAINER_SUBNET_CIDR}" )

echo ''
echo '============================================'
echo "Setting up host with the following settings:"
echo '============================================'
{
    echo "Hostname:^${MY_HOSTNAME}"
    echo "External Interface:^${EXT_INTERFACE}"
    echo "IP4 (${EXT_INTERFACE}):^${EXT_IP}"
    echo "Subnet Mask (${EXT_INTERFACE}):^${EXT_MASK}"
    echo "Default Gateway:^${EXT_GATEWAY}"
    echo "Container Subnet:^${CONTAINER_SUBNET}"
} | column -ts^
echo '============================================'
echo ''
read -p "Are these settings OK? (y/n) " _userContinueToConfigure

# check if user wanted to continue
if [[ "${_userContinueToConfigure}" != 'y' ]] && [[ "${_userContinueToConfigure}" != 'Y' ]]; then
    echo "Exiting tredly-host..."
    exit 1
fi


# set the networking up for the installer
ifconfig ${EXT_INTERFACE} inet ${EXT_IP} netmask ${EXT_MASK}
if [[ ! $? ]]; then
    echo "Failed to set ip address on ${EXT_INTERFACE}."
fi
route add default ${EXT_GATEWAY}
if [[ ! $? ]]; then
    echo "Failed to add default gateway ${EXT_GATEWAY}."
fi

# Update FreeBSD and install updates
echo "Fetching and Installing FreeBSD Updates"
freebsd-update fetch install | tee -a "${LOGFILE}" 
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# set up pkg
echo "Setting up pkg"
rm /usr/local/etc/pkg.conf
cp ${DIR}/os/pkg.conf /usr/local/etc/
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Install Packages
echo "Installing Packages"
_exitCode=0
pkg install -y vim-lite | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y rsync | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y openntpd | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y bash | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y git | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y nginx | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y unbound | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure /etc/rc.conf
echo "Configuring /etc/rc.conf"
_exitCode=0
rm /etc/rc.conf
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/rc.conf /etc/
_exitCode=$(( ${_exitCode} & $? ))
# change the network information in rc.conf
sed -i '' "s|ifconfig_bce0=.*|ifconfig_${EXT_INTERFACE}=\"inet ${EXT_IP} netmask ${EXT_MASK}\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|defaultrouter=.*|defaultrouter=\"${EXT_GATEWAY}\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|ifconfig_bridge0=.*|ifconfig_bridge0=\"addm ${EXT_INTERFACE} up\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|hostname=.*|hostname=\"${MY_HOSTNAME}\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|hostname=.*|hostname=\"${MY_HOSTNAME}\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|ifconfig_bridge1=.*|ifconfig_bridge1=\"inet ${_hostPrivateIP} netmask $( cidr2netmask "${CONTAINER_SUBNET_CIDR}" )\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Enable the cloned interfaces
echo "Enabling cloned interface(s)"
service netif cloneup
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure IP on Host to communicate with Containers
echo "Configuring bridge1"
ifconfig bridge1 inet ${_hostPrivateIP} netmask $( cidr2netmask "${CONTAINER_SUBNET_CIDR}" )
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure SSH
_exitCode=0
echo "Configuring SSHD"
rm /etc/ssh/sshd_config
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/sshd_config /etc/ssh/sshd_config
_exitCode=$(( ${_exitCode} & $? ))
# change the networking data for ssh
sed -i '' "s|ListenAddress .*|ListenAddress ${EXT_IP}|g" "/etc/ssh/sshd_config"
_exitCode=$(( ${_exitCode} & $? ))
service sshd restart
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure Vim
echo "Configuring vim"
cp ${DIR}/os/vimrc /usr/local/share/vim/vimrc
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure IPFW
echo "Configuring IPFW"
_exitCode=0
mkdir -p /usr/local/etc
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/ipfw.rules /usr/local/etc/ipfw.rules
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/ipfw.layer4 /usr/local/etc/ipfw.layer4
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/ipfw.vars /usr/local/etc/ipfw.vars
_exitCode=$(( ${_exitCode} & $? ))
# update the networking data
sed -i '' "s|eif=.*|eif=\"${EXT_INTERFACE}\"|g" "/usr/local/etc/ipfw.vars"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|eip=.*|eip=\"${EXT_IP}\"|g" "/usr/local/etc/ipfw.vars"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|clsn=.*|clsn=\"${CONTAINER_SUBNET}\"|g" "/usr/local/etc/ipfw.vars"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|p7ip=.*|p7ip=\"${_hostPrivateIP}\"|g" "/usr/local/etc/ipfw.vars"
_exitCode=$(( ${_exitCode} & $? ))

# Removed ipfw start for now due to its ability to disconnect a user from their host
#service ipfw start
#_exitCode=$(( ${_exitCode} & $? ))
if [[ $_exitCode -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi


# Configure OpenNTP
_exitCode=0
echo "Configuring OpenNTP"
rm /usr/local/etc/ntpd.conf
cp ${DIR}/os/ntpd.conf /usr/local/etc/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi


# Configure zfs scrubbing
#vim /etc/periodic.conf

# Change kernel options
echo "Configuring kernel options"
_exitCode=0
rm /boot/loader.conf
cp ${DIR}/os/loader.conf /boot/
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

echo "Configuring sysctl"
rm /etc/sysctl.conf
cp ${DIR}/os/sysctl.conf /etc/
if [[ $? -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure fstab to fix bash bug
if [[ $( grep "/dev/fd" /etc/fstab | wc -l ) -eq 0 ]]; then
    echo "Configuring bash"
    echo "fdesc                   /dev/fd fdescfs rw              0       0" >> /etc/fstab
    if [[ $? -eq 0 ]]; then
        echo "Success"
    else
        echo "Failed"
    fi
else
   echo "Bash already configured"
fi

# Configure HTTP Proxy
echo "Configuring HTTP Proxy" 
_exitCode=0
mkdir -p /usr/local/etc/nginx/access
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/server_name
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/proxy_pass
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/ssl
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/sslconfig
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/upstream
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/proxy/nginx.conf /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${DIR}/proxy/proxy_pass /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${DIR}/proxy/sslconfig /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
service nginx start
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Configure Unbound DNS
echo "Configuring Unbound"
_exitCode=0
mkdir -p /usr/local/etc/unbound/configs
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/dns/unbound.conf /usr/local/etc/unbound/
_exitCode=$(( ${_exitCode} & $? ))
# change the ip address unbound binds to
sed -i '' "s|interface:.*|interface: ${_hostPrivateIP}|g" "/usr/local/etc/unbound/unbound.conf"
_exitCode=$(( ${_exitCode} & $? ))
# change the access control from the default subnet to the new one
sed -i '' "s|access-control: 10.0.0.0/16 allow|access-control: ${CONTAINER_SUBNET} allow|g" "/usr/local/etc/unbound/unbound.conf"
service unbound start
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Get tredly-build and install it
echo "Configuring Tredly-build"
_exitCode=1
cd /tmp 
# if the directory for tredly-build already exists, then delete it and start again
if [[ -d "/tmp/tredly-build" ]]; then
    echo "Cleaning previously downloaded Tredly-build"
    rm -rf /tmp/tredly-build
fi

while [[ ${_exitCode} -ne 0 ]]; do
    git clone ${TREDLY_GIT_URL}
    _exitCode=$?
done

cd /tmp/tredly-build
./tredly.sh install clean
_exitCode=$?
# change the default container subnet
sed -i '' "s|lifNetwork=.*|lifNetwork=${CONTAINER_SUBNET}|g" "/usr/local/etc/tredly/tredly-host.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|wifPhysical=.*|wifPhysical=${EXT_INTERFACE}|g" "/usr/local/etc/tredly/tredly-host.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|dns=.*|dns=${_hostPrivateIP}|g" "/usr/local/etc/tredly/tredly-host.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|httpproxy=.*|httpproxy=${_hostPrivateIP}|g" "/usr/local/etc/tredly/tredly-host.conf"
_exitCode=$(( ${_exitCode} & $? ))
sed -i '' "s|vnetdefaultroute=.*|vnetdefaultroute=${_hostPrivateIP}|g" "/usr/local/etc/tredly/tredly-host.conf"
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# initialise tredly
tredly init

# Setup crontab
echo "Configuring crontab"
_exitCode=0
mkdir -p /usr/local/host/
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/crontab /usr/local/host/
_exitCode=$(( ${_exitCode} & $? ))
crontab /usr/local/host/crontab
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    echo "Success"
else
    echo "Failed"
fi

# Compile the kernel if vimage is not installed
_vimageInstalled=$( sysctl kern.conftxt | grep '^options[[:space:]]VIMAGE$' | wc -l )
if [[ ${_vimageInstalled} -ne 0 ]]; then
    echo "Skipping kernel recompile as this kernel appears to already have VIMAGE compiled."
else
    echo "Recompiling kernel as this kernel does not have VIMAGE built in"
    echo "Please note this will take some time."
    sleep_with_progress 5
    # lets compile the kernel for VIMAGE!

    # check for a kernel source directory
    _downloadSource="y"
    _sourceExists=""
    if [[ -d '/usr/src/sys' ]]; then
        _sourceExists="true"
        echo "It appears that the kernel source files already exist in /usr/src/sys"
        read -p "Do you want to download them again? (y/n) " _downloadSource
    fi
    
    # download the source if the user said yes
    if [[ "${_downloadSource}" == 'y' ]] || [[ "${_downloadSource}" == 'Y' ]]; then
        _thisRelease=$( sysctl -n kern.osrelease | cut -d '-' -f 1 -f 2)
        # download the src file
        fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/${_thisRelease}/src.txz -o /tmp

        # move the old source to another dir if it already exists
        if [[ "${_sourceExists}" == "true" ]]; then
            # clean up the old source
            mv /usr/src/sys /usr/src/sys.old
        fi
        
        # unpack new source
        tar -C / -xzf /tmp/src.txz
    fi

    # copy in the tredly kernel configuration file
    cp ${DIR}/kernel/TREDLY /usr/src/sys/amd64/conf

    cd /usr/src
    
    # work out how many cpus are available to this machine, and use 80% of them to speed up compile
    _availCpus=$( sysctl -n hw.ncpu )
    _useCpus=$( echo "scale=2; ${_availCpus}*0.8" | bc | cut -d'.' -f 1 )
        
    # if we have a value less than 1 then set it to 1
    if [[ ${_useCpus} -lt 1 ]]; then
        _useCpus=1
    fi

    echo "Compiling kernel using ${_useCpus} CPUs..."
    make -j${_useCpus} buildkernel KERNCONF=TREDLY
    
    # only install the kernel if the build succeeded
    if [[ $? -eq 0 ]]; then
        make installkernel KERNCONF=TREDLY
    fi

fi

