#!/usr/local/bin/bash

set -o pipefail

_VERSIONNUMBER="0.10.3"
_VERSIONDATE="May 13 2016"

# where to send the logfile
LOGFILE="/var/log/tredly-install.log"

# load some bash libraries
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

# load the libs
for f in ${DIR}/lib/*.sh; do source $f; done

# make sure this script is running as root
cmn_assert_running_as_root

# get a list of external interfaces
IFS=$'\n' declare -a _externalInterfaces=($( getExternalInterfaces ))

# Check if VIMAGE module is loaded
_vimageInstalled=$( sysctl kern.conftxt | grep '^options[[:space:]]VIMAGE$' | wc -l )

###############################
declare -a _configOptions
# set some defaults
_configOptions[0]=''
_configOptions[1]="${_externalInterfaces[0]}"
_configOptions[2]="$( getInterfaceIP "${_externalInterfaces[0]}" )/$( getInterfaceCIDR "${_externalInterfaces[0]}" )"
_configOptions[3]="$( getDefaultGateway )"
_configOptions[4]="${HOSTNAME}"
_configOptions[5]="10.99.0.0/16"
# TODO: remove hard coded ip and subtract from the given container subnet
API_GUI_CONTAINER="10.99.0.253"


# check if the install config file exists
if [[ ! -f "${DIR}/conf/install.conf" ]]; then
    exit_with_error "Could not find conf/install.conf"
fi

# load the config file
install_conf_parse "install"

# set locations from the file
_configOptions[6]="${_CONF_INSTALL[tredlyBuildGit]}"
_configOptions[7]="${_CONF_INSTALL[tredlyBuildBranch]}"
_configOptions[8]="${_CONF_INSTALL[tredlyApiGit]}"
_configOptions[9]="${_CONF_INSTALL[tredlyApiBranch]}"
_configOptions[10]=$( str_to_lower "${_CONF_INSTALL[downloadKernelSource]}" )

# check for a dhcp leases file for this interface
#if [[ -f "/var/db/dhclient.leases.${_configOptions[1]}" ]]; then
    # look for its current ip address within the leases file
    #_numLeases=$( grep -E "${DEFAULT_EXT_IP}" "/var/db/dhclient.leases.${_configOptions[1]}" | wc -l )

    #if [[ ${_numLeases} -gt 0 ]]; then
        # found a current lease for this ip address so throw a warning
        #echo -e "${_colourMagenta}=============================================================================="
        #echo -e "${_formatBold}WARNING!${_formatReset}${_colourMagenta} The current IP address ${DEFAULT_EXT_IP} was set using DHCP!"
        #echo "It is recommended that this address be changed to be outside of your DHCP pool"
        #echo -e "==============================================================================${_colourDefault}"
    #fi
#fi

# run the menu
tredlyHostMenuConfig

# extract the net and cidr from the container subnet we are using
CONTAINER_SUBNET_NET="$( lcut "${_configOptions[5]}" '/')"
CONTAINER_SUBNET_CIDR="$( rcut "${_configOptions[5]}" '/')"
# Get the default host ip address on the private container network
_hostPrivateIP=$( get_last_usable_ip4_in_network "${CONTAINER_SUBNET_NET}" "${CONTAINER_SUBNET_CIDR}" )

####
e_header "Tredly Installation"

##########

# Configure /etc/rc.conf
e_note "Configuring /etc/rc.conf"
_exitCode=0
rm /etc/rc.conf
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/rc.conf /etc/
_exitCode=$(( ${_exitCode} & $? ))
# change the network information in rc.conf
sed -i '' "s|ifconfig_bridge0=.*|ifconfig_bridge0=\"addm ${_configOptions[1]} up\"|g" "/etc/rc.conf"
_exitCode=$(( ${_exitCode} & $? ))
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# if vimage is installed, enable cloned interfaces
if [[ ${_vimageInstalled} -ne 0 ]]; then
    e_note "Enabling Cloned Interfaces"
    service netif cloneup
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi

##########

if [[ -z "${_configOptions[8]}" ]]; then
    e_note "Skipping Tredly-API"
else
    # set up tredly api
    e_note "Configuring Tredly-API"
    _exitCode=1
    cd /tmp
    # if the directory for tredly-api already exists, then delete it and start again
    if [[ -d "/tmp/tredly-api" ]]; then
        echo "Cleaning previously downloaded Tredly-API"
        rm -rf /tmp/tredly-api
    fi

    while [[ ${_exitCode} -ne 0 ]]; do
        git clone -b "${_configOptions[9]}" ${_configOptions[8]}
        _exitCode=$?
    done

    cd /tmp/tredly-api
    ./install.sh
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi

##########

# Update FreeBSD and install updates
e_note "Fetching and Installing FreeBSD Updates"
freebsd-update fetch install | tee -a "${LOGFILE}"
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# set up pkg
e_note "Configuring PKG"
rm /usr/local/etc/pkg.conf
cp ${DIR}/os/pkg.conf /usr/local/etc/
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Install Packages
e_note "Installing Packages"
_exitCode=0
pkg install -y vim-lite | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y rsync | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y openntpd | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
pkg install -y git | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -ne 0 ]]; then
    exit_with_error "Failed to download git"
fi
pkg install -y nginx | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -ne 0 ]]; then
    exit_with_error "Failed to download Nginx"
fi
pkg install -y unbound | tee -a "${LOGFILE}"
_exitCode=$(( ${PIPESTATUS[0]} & $? ))
if [[ ${_exitCode} -ne 0 ]]; then
    exit_with_error "Failed to download Unbound"
fi
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure SSH
_exitCode=0
e_note "Configuring SSHD"
rm /etc/ssh/sshd_config
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/sshd_config /etc/ssh/sshd_config
_exitCode=$(( ${_exitCode} & $? ))
# change the networking data for ssh
sed -i '' "s|ListenAddress .*|ListenAddress ${_configOptions[2]}|g" "/etc/ssh/sshd_config"
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure Vim
e_note "Configuring VIM"
cp ${DIR}/os/vimrc /usr/local/share/vim/vimrc
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure IPFW
e_note "Configuring IPFW"
_exitCode=0
mkdir -p /usr/local/etc
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/ipfw.rules /usr/local/etc/ipfw.rules
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/ipfw.layer4 /usr/local/etc/ipfw.layer4
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/ipfw.vars /usr/local/etc/ipfw.vars
_exitCode=$(( ${_exitCode} & $? ))

# Removed ipfw start for now due to its ability to disconnect a user from their host
#service ipfw start
#_exitCode=$(( ${_exitCode} & $? ))
if [[ $_exitCode -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure OpenNTP
_exitCode=0
e_note "Configuring OpenNTP"
rm /usr/local/etc/ntpd.conf
cp ${DIR}/os/ntpd.conf /usr/local/etc/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure zfs scrubbing
#vim /etc/periodic.conf

##########

# Change kernel options
e_note "Configuring kernel options"
_exitCode=0
rm /boot/loader.conf
cp ${DIR}/os/loader.conf /boot/
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

e_note "Configuring Sysctl"
rm /etc/sysctl.conf
cp ${DIR}/os/sysctl.conf /etc/
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure fstab to fix bash bug
if [[ $( grep /dev/fd /etc/fstab | wc -l ) -eq 0 ]]; then
    e_note "Configuring Bash"
    echo "fdesc                   /dev/fd fdescfs rw              0       0" >> /etc/fstab
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
else
   e_note "Bash already configured"
fi

##########

# Configure HTTP Proxy
e_note "Configuring Layer 7 (HTTP) Proxy"
_exitCode=0
mkdir -p /usr/local/etc/nginx/access
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/server_name
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/proxy_pass
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/ssl
_exitCode=$(( ${_exitCode} & $? ))
mkdir -p /usr/local/etc/nginx/upstream
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/proxy/nginx.conf /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${DIR}/proxy/proxy_pass /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
cp -R ${DIR}/proxy/tredly_error_docs /usr/local/etc/nginx/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Configure Unbound DNS
e_note "Configuring Unbound"
_exitCode=0
mkdir -p /usr/local/etc/unbound/configs
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/dns/unbound.conf /usr/local/etc/unbound/
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########
e_note "Installing Tredly-Host"

# install tredly-host
${DIR}/tredly-host-install.sh clean install
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

##########

# Get tredly-build and install it
e_note "Installing Tredly-Build"
_exitCode=1
cd /tmp
# if the directory for tredly-build already exists, then delete it and start again
if [[ -d "/tmp/tredly-build" ]]; then
    echo "Cleaning previously downloaded Tredly-Build"
    rm -rf /tmp/tredly-build
fi

while [[ ${_exitCode} -ne 0 ]]; do
    git clone -b "${_configOptions[7]}" ${_configOptions[6]}
    _exitCode=$?
done

cd /tmp/tredly-build
./tredly.sh install clean
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

# initialise tredly
tredly init

##########

# Setup crontab
e_note "Configuring Crontab"
_exitCode=0
mkdir -p /usr/local/host/
_exitCode=$(( ${_exitCode} & $? ))
cp ${DIR}/os/crontab /usr/local/host/
_exitCode=$(( ${_exitCode} & $? ))
crontab /usr/local/host/crontab
_exitCode=$(( ${_exitCode} & $? ))
if [[ ${_exitCode} -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

if [[ ${_vimageInstalled} -ne 0 ]]; then
    e_success "Skipping kernel recompile as this kernel appears to already have VIMAGE compiled."
else
    e_note "Recompiling kernel as this kernel does not have VIMAGE built in"
    e_note "Please note this will take some time."

    # lets compile the kernel for VIMAGE!

    # fetch the source if the user said yes or the source doesnt exist
    if [[ "${_configOptions[10]}" == 'yes' ]] || [[ ! -d '/usr/src/sys' ]]; then
        _thisRelease=$( sysctl -n kern.osrelease | cut -d '-' -f 1 -f 2 )
        
        # download manifest file to validate src.txz
        fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/${_thisRelease}/MANIFEST -o /tmp
        
        # if we have downlaoded src.txz for tredly then use that
        if [[ -f /tredly/downloads/${_thisRelease}/src.txz ]]; then
            e_note "Copying pre-downloaded src.txz"
            
            cp /tredly/downloads/${_thisRelease}/src.txz /tmp
        else
            # otherwise download the src file
            fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/${_thisRelease}/src.txz -o /tmp
        fi
        
        # validate src.txz against MANIFEST
        _upstreamHash=$( cat /tmp/MANIFEST | grep ^src.txz | awk -F" " '{ print $2 }' )
        _localHash=$( sha256 -q /tmp/src.txz )

        if [[ "${_upstreamHash}" != "${_localHash}" ]]; then
            # remove it as it is of no use to us
            rm -f /tmp/src.txz
            # exit and print error
            exit_with_error "Validation failed on src.txz. Please try installing again."
        else
            e_success "Validation passed for src.txz"
        fi
        
        if [[ $? -ne 0 ]]; then
            exit_with_error "Failed to download src.txz"
        fi

        # move the old source to another dir if it already exists
        if [[ -d "/usr/src/sys" ]]; then
            # clean up the old source
            mv /usr/src/sys /usr/src/sys.`date +%s`
        fi

        # unpack new source
        tar -C / -xzf /tmp/src.txz
        if [[ $? -ne 0 ]]; then
            exit_with_error "Failed to unpack src.txz"
        fi
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

    e_note "Compiling kernel using ${_useCpus} CPUs..."
    make -j${_useCpus} buildkernel KERNCONF=TREDLY

    # only install the kernel if the build succeeded
    if [[ $? -eq 0 ]]; then
        make installkernel KERNCONF=TREDLY
        
        if [[ $? -ne 0 ]]; then
            exit_with_error "Failed to install kernel"
        fi
    else
        exit_with_error "Failed to build kernel"
    fi

fi

##########
# use tredly to set network details
e_note "Setting Container Subnet"
tredly-host config container subnet "${_configOptions[5]}"
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

e_note "Setting Host Network"
tredly-host config host network "${_configOptions[1]}" "${_configOptions[2]}" "${_configOptions[3]}"
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

e_note "Setting Host Hostname"
tredly-host config host hostname "${_configOptions[4]}"
if [[ $? -eq 0 ]]; then
    e_success "Success"
else
    e_error "Failed"
fi

# if tredly api is enabled then add to whitelist
if [[ -n "${_configOptions[8]}" ]]; then
    e_note "Whitelisting IP addresses for API"
    tredly-host config firewall addAPIwhitelist ${API_GUI_CONTAINER}
    
    if [[ $? -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi

#####
# TODO: start services? This fails at the moment due to bridge1 not existing
