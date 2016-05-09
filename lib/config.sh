#!/usr/bin/env bash

# associative arrays
declare -A _CONF_INSTALL
declare -A _CONF_COMMON


# Validates a common config file, for example tredly-host.conf
function common_conf_validate() {

    if [[ -z "${1}" ]]; then
        exit_with_error "common_conf_validate() cannot be called without passing at least 1 required field."
    fi

    ## Use 'required' from the common config to construct the required array
    local -a required
    IFS=',' read -a required <<< "${1}"

    ## Check for required fields
    for p in "${required[@]}"
    do
        # handle specific entries
        case "${p}" in
            dns)
                if [[ ${#_CONF_COMMON_DNS[@]} -eq 0 ]]; then
                    exit_with_error "'${p}' is missing or empty and is required. Check config"
            fi
            ;;
            *)
                if [ -z "${_CONF_COMMON[${p}]}" ]; then
                    exit_with_error "'${p}' is missing or empty and is required. Check config"
                fi
            ;;
        esac
    done

    return ${E_SUCCESS}
}

## Reads conf/{context}.conf, parsing it and storing each key/value pair
## in `_CONF_COMMON`. Path is built using _TREDLY_DIR, which is the directory
## that tredly script is running from.
## Arguments:
##      1. String. context. This must match the name of a config file (*.conf)
##
## Return:
##     - exits with error message if conf/{context}.conf does not exist
##
function common_conf_parse() {

    if [[ -z "${1}" ]]; then
        exit_with_error "common_conf_parse() cannot be called without providing a command as context"
    fi

    local context="${1}"

    if [ ! -e "${_TREDLY_DIR_CONF}/${context}.conf" ]; then
        e_verbose "No configuration found for \`${context}\`. Skipping."
        return ${E_SUCCESS}
    fi

    # empty our arrays
    _CONF_COMMON_DNS=()

    ## Read the data in
    local regexp="^[^#\;]*="

    while read line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[^#\;]*= ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # strip anything after a comment
            value=$( lcut "${value}" '#' )

            # strip any whitespace
            local strippedValue=$(strip_whitespace "${value}")

            # handle some lines specifically
            case "${key}" in
                lifNetwork)
                    # split it up
                    [[ ${value#*=} =~ ^(.+)/(.+)$ ]]

                    # assign the values
                    _CONF_COMMON[lifNetwork]=${BASH_REMATCH[1]}
                    _CONF_COMMON[lifCIDR]=${BASH_REMATCH[2]}
                    ;;
                dns)
                    _CONF_COMMON_DNS+=("${value}")
                    ;;
                *)
                    _CONF_COMMON[${key}]="${value}"
                    ;;
            esac
        fi
    done < "${_TREDLY_DIR_CONF}/${context}.conf"

    return ${E_SUCCESS}
}


# Validates a common config file, for example tredly-host.conf
function install_conf_validate() {

    if [[ -z "${1}" ]]; then
        exit_with_error "common_conf_validate() cannot be called without passing at least 1 required field."
    fi

    ## Use 'required' from the common config to construct the required array
    local -a required
    IFS=',' read -a required <<< "${1}"

    ## Check for required fields
    for p in "${required[@]}"; do
        # check if it is not populated
        if [[ -z "${_CONF_INSTALL[${p}]}" ]]; then
            exit_with_error "'${p}' is missing or empty and is required. Check config"
        fi
    done
    
    # match versions
    #if ! versionCheck "${_CONF_INSTALL[versionNumber]}" "${VERSIONNUMBER}"; then
        #exit_with_error "Install config file does not match version ${VERSIONNUMBER}"
    #fi

    return ${E_SUCCESS}
}

## Reads conf/{context}.conf, parsing it and storing each key/value pair
## in `_CONF_INSTALL`. Path is built using _TREDLY_DIR, which is the directory
## that tredly script is running from.
## Arguments:
##      1. String. context. This must match the name of a config file (*.conf)
##
## Return:
##     - exits with error message if conf/{context}.conf does not exist
##
function install_conf_parse() {

    if [[ -z "${1}" ]]; then
        exit_with_error "install_conf_parse() cannot be called without providing a command as context"
    fi

    local context="${1}"

    if [ ! -f "${DIR}/conf/${context}.conf" ]; then
        return ${E_ERROR}
    fi

    ## Read the data in
    local regexp="^[^#\;]*="

    while read line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[^#\;]*= ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # strip anything after a comment
            value=$( lcut "${value}" '#' )

            # strip any whitespace
            local strippedValue=$(strip_whitespace "${value}")

            _CONF_INSTALL[${key}]="${value}"
        fi
    done < "${DIR}/conf/${context}.conf"
    
    install_conf_validate "tredlyBuildGit,tredlyBuildBranch,tredlyApiGit,tredlyApiBranch,downloadKernelSource"

    return ${E_SUCCESS}
}
