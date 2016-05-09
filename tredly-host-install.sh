#!/usr/local/bin/bash

PREFIX="/usr/local"
MAN=
BINDIR="${PREFIX}/sbin"
LIBDIR="${PREFIX}/lib/tredly-host/lib"

COMMANDSDIR="${PREFIX}/lib/tredly-host/commands"
INSTALL=/usr/bin/install
MKDIR="mkdir"
RM="rm"
BINMODE="500"

SCRIPTS="tredly-host"
SCRIPTSDIR="${PREFIX}/BINDIR"
#set -x
# cleans/uninstalls tredly
function clean() {
    # TODO: remove any installed files
    #${RM} -rf "${FILESDIR}"
    #${RM} -f "${BINDIR}/tredly-host"
    #${RM} -f "${LIBDIR}/"*
    #${RM} -f "${COMMANDSDIR}/"*
    echo ""
}

# returns the directory that the files have been downloaded to
function get_files_source() {
    local TREDLY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    echo "${TREDLY_DIR}"
}


# where the files are located
FILESSOURCE=$( get_files_source )


# loop over the args, looking for clean first
for arg in "$@"; do
    if [[ "${arg}" == "clean" ]]; then
        echo "Cleaning Tredly-Host install"
        clean
    fi
done


# now do it again, but do the install/uninstall
for arg in "$@"; do
    case "${arg}" in
        install)
            echo "Installing Tredly-Host..."
            ${MKDIR} -p "${BINDIR}"
            ${MKDIR} -p "${LIBDIR}"
            ${MKDIR} -p "${COMMANDSDIR}"
            ${INSTALL} -c -m ${BINMODE} "${FILESSOURCE}/${SCRIPTS}" "${BINDIR}/"
            #${INSTALL} -c "${FILESSOURCE}/lib/"* "${LIBDIR}"
            ${INSTALL} -c "${FILESSOURCE}/commands/"* "${COMMANDSDIR}"

            echo "Tredly-Host installed."
            #echo -e "\e[38;5;202mNote: Please modify the files in ${CONFDIR} to suit your environment.\e[39m"
            ;;
        #uninstall)
            #echo "Uninstalling Tredly-Host..."
            # run clean to remove the files
            #clean
            #echo "Tredly-Host Uninstalled."
            #;;
        clean)
            # do nothing, this is just here to prevent clean being handled as *
            ;;
        *)
            echo "Tredly-Host installer"
            echo ""
            echo "Usage:"
            echo "    `basename "$0"` install: install Tredly-Host"
            echo "    `basename "$0"` uninstall: uninstall Tredly-Host"
            echo "    `basename "$0"` install clean: remove all previously installed files and install Tredly-Host"
            ;;
    esac
done
