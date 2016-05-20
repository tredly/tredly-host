#!/usr/local/bin/bash

set -o pipefail

_VERSIONNUMBER="0.10.4"
_VERSIONDATE="May 20 2016"

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

# check if the install config file exists
if [[ ! -f "${DIR}/conf/install.conf" ]]; then
    exit_with_error "Could not find conf/install.conf"
fi

# load the config file
install_conf_parse "install"

_configOptions[0]=''
# check if some values are set, and if they arent then consult the host for the details
if [[ -z "${_CONF_INSTALL[externalInterface]}" ]]; then
    _configOptions[1]="${_externalInterfaces[0]}"
else
    _configOptions[1]="${_CONF_INSTALL[externalInterface]}"
fi

if [[ -z "${_CONF_INSTALL[externalIP]}" ]]; then
    _configOptions[2]="$( getInterfaceIP "${_externalInterfaces[0]}" )/$( getInterfaceCIDR "${_externalInterfaces[0]}" )"
else
    _configOptions[2]="${_CONF_INSTALL[externalIP]}"
fi

if [[ -z "${_CONF_INSTALL[externalGateway]}" ]]; then
    _configOptions[3]="$( getDefaultGateway )"
else
    _configOptions[3]="${_CONF_INSTALL[externalGateway]}"
fi

if [[ -z "${_CONF_INSTALL[hostname]}" ]]; then
    _configOptions[4]="${HOSTNAME}"
else
    _configOptions[4]="${_CONF_INSTALL[hostname]}"
fi

if [[ -z "${_CONF_INSTALL[containerSubnet]}" ]]; then
    _configOptions[5]="10.99.0.0/16"
else
    _configOptions[5]="${_CONF_INSTALL[containerSubnet]}"
fi

if [[ -z "${_CONF_INSTALL[apiWhitelist]}" ]]; then
    _configOptions[6]=""
else
    _configOptions[6]="${_CONF_INSTALL[apiWhitelist]}"
fi

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

# check if we are doing an unattended installation or not
if [[ "${_CONF_INSTALL[unattendedInstall]}" != "yes" ]]; then
    # run the menu
    tredlyHostMenuConfig
fi

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

if [[ -z "${_CONF_INSTALL[tredlyApiGit]}" ]]; then
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
        git clone -b "${_CONF_INSTALL[tredlyApiBranch]}" "${_CONF_INSTALL[tredlyApiGit]}"
        _exitCode=$?
    done
    
    cd /tmp/tredly-api
    
    # install the API and extract the random password so we can present this to the user at the end of install
    apiPassword="$( ./install.sh | grep "^Your API password is: " | cut -d':' -f 2 | sed -e 's/^[ \t]*//' )"
    
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
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
    git clone -b "${_CONF_INSTALL[tredlyBuildBranch]}" "${_CONF_INSTALL[tredlyBuildGit]}"
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
    if [[ "$( str_to_lower "${_CONF_INSTALL[downloadKernelSource]}" )" == 'yes' ]] || [[ ! -d '/usr/src/sys' ]]; then
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
    
    cd /usr/src
    
    # clean up any previously failed builds
    if [[ $( ls -1 /usr/obj | wc -l ) -gt 0 ]]; then
        chflags -R noschg /usr/obj/usr
        rm -rf /usr/obj/usr
        make cleandir
        make cleandir
    fi

    # copy in the tredly kernel configuration file
    cp ${DIR}/kernel/TREDLY /usr/src/sys/amd64/conf

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

# delete the src.txz file from /tmp
if [[ -f "/tmp/src.txz" ]]; then
    rm -f /tmp/src.txz
fi

##########
# use tredly to set network details
tredly-host config container subnet "${_configOptions[5]}"

tredly-host config host network "${_configOptions[1]}" "${_configOptions[2]}" "${_configOptions[3]}"

tredly-host config host hostname "${_configOptions[4]}"


# if tredly api is enabled then add to whitelist
if [[ -n "${_CONF_INSTALL[tredlyApiGit]}" ]]; then
    e_note "Whitelisting IP addresses for API"
    
    # clear the whitelist in case of old entries
    tredly-host config firewall clearAPIwhitelist > /dev/null
    
    IFS=',' read -ra _whitelistArray <<< "${_CONF_INSTALL[apiWhitelist]}"
    ip
    _exitCode=0
    for ip in ${_whitelistArray[@]}; do
        tredly-host config firewall addAPIwhitelist "${ip}" > /dev/null
        _exitCode=$(( ${_exitCode} & $? ))
    done
    
    if [[ ${_exitCode} -eq 0 ]]; then
        e_success "Success"
    else
        e_error "Failed"
    fi
fi

# echo out confirmation message to user
e_header "Install Complete"
echo -e "${_colourOrange}${_formatBold}"
echo "**************************************"
echo "Your API Password is: ${apiPassword}"
echo -e "**************************************${_formatReset}"

echo -e "${_colourMagenta}"
echo "Please make note of this password so that you may access the API"
echo ""
echo "To change this password, please run the command 'tredly-host config api'"
echo "To whitelist addresses to access the API, please run the command 'tredly-host config firewall addAPIwhitelist <ip address>'"
echo ""
echo "Please note that the SSH port has changed, use the following to connect to your host after reboot:"
echo "ssh -p 65222 tredly@$( lcut "${_configOptions[2]}" "/" )"
echo ""
echo "Please reboot your host for the new kernel and settings to take effect."
echo -e "\e[39m"
