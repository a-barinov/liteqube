#!/bin/sh

# Options that are not supposed to be user-configurable
PATH="/bin:/usr/bin"
VM="$(xenstore-read name)"
BASEDIR="$(realpath $(dirname "${0}"))"
DEVICE="/dev/xvdb"
MOUNTPOINT="/mnt"
QUARANTINE_DIR="${MOUNTPOINT}/QUARANTINE"
IFS="
"


### SETTINGS ###
################

# "True", "true", "Yes", "yes", "Y", "y" and "1" enable the option
# Empty or unset, "False", "false", "No", "no", "N", "n" and "0" disable the option

# Enabled
ACTIVE="Yes"

# Debug to syslog
DEBUG="No"

# Shutdown cube on mount failure
POWEROFF="No"

# Quarantine files that fail checks, otherwise delete
QUARANTINE="Yes"

# Allow files that are not listed, otherwise quarantine or delete
ALLOW_ROGUE="No"

# Deploy missing files
DEPLOY_MISSING="Yes"

# Erase /etc/protect when done
OBSCURE="No"

# Load vm-specific settings
[ -f "$BASEDIR/settings.$VM" ] && . "$BASEDIR/settings.$VM"



### SUPPORT FUNCTIONS ###
#########################

# Check if var is active
check(){
    __CHK_VAR__="${1}"
    [ -z "${__CHK_VAR__}" ] && return 1
    case "${__CHK_VAR__}" in
        [Tt]rue|[Yy]es|[Yy1] ) return 0 ;;
        [Ff]alse|[Nn]o|[Nn0] ) return 1 ;;
        * ) error "ERROR: Unknown setting value: ${__CHK_VAR__}" ; return 1 ;;
    esac
}

# Report error to syslog (and dom0)
error(){
    __ERR_MESSAGE__="${1}"
    __ERR_EXIT__="${2}"
    echo "${__ERR_MESSAGE__}"
    #/usr/bin/qrexec-client-vm dom0 "liteqube.Error+${__ERR_MESSAGE__}"
    [ -z "${__ERR_EXIT__}" ] || exit 1
}

# Find file in two dirs, return the first file found
find_file(){
    __FND_FILE__="${1}"
    __FND_DIR1__="${2}"
    __FND_DIR2__="${3}"
    __FND_VAR__="${4}"
    [ -e "${__FND_DIR1__}/${__FND_FILE__}" ] && eval ${__FND_VAR__}="'${__FND_DIR1__}'" && return 0
    [ -e "${__FND_DIR2__}/${__FND_FILE__}" ] && eval ${__FND_VAR__}="'${__FND_DIR2__}'" && return 0
    return 1
}

# Quarantine file
quarantine(){
    __QRN_FILE__="${1}"
    __QRN_TARGET__="${QUARANTINE_DIR}/$(basename "${__QRN_FILE__}")"
    check "$QUARANTINE" || return 1
    if [ ! -d "${QUARANTINE_DIR}" ] ; then
        if ! mkdir -p "${QUARANTINE_DIR}" ; then
            error "ERROR: Failed to quarantine ${__QRN_FILE__}"
            return 1
        fi
    fi
    find "${__QRN_FILE__}" | xargs chattr -d -f -i
    if [ -e "${__QRN_TARGET__}" ] ; then
        if ! mv "${__QRN_TARGET__}" "${__QRN_TARGET__}.$(date +%s%N)" ; then
            error "ERROR: Failed to quarantine ${__QRN_FILE__}"
            return 1
        fi
    fi
    if mv "${__QRN_FILE__}" "${QUARANTINE_DIR}" ; then
        echo "Quarantined ${__QRN_FILE__}"
        return 0
    else
        error "ERROR: Failed to quarantine ${__QRN_FILE__}"
        return 1
    fi
}

# Deploy file
deploy(){
    __DPL_SOURCE__="${1}"
    __DPL_TARGET__="${2}"
    if [ -e "${__DPL_TARGET__}" ] ; then
        if ! quarantine "${__DPL_TARGET__}" ; then
            find "${__DPL_TARGET__}" | xargs chattr -d -f -i
            if ! mv "${__DPL_TARGET__}" "${__DPL_TARGET__}.${date +%s%N}" ; then
                error "ERROR: Failed to deploy ${__DPL_TARGET__}"
                return
            fi
        fi
    fi
    if cp -a "${__DPL_SOURCE__}" "${__DPL_TARGET__}" ; then
        echo "Deployed ${__DPL_TARGET__}"
    else
        error "ERROR: Failed to deploy ${__DPL_TARGET__}"
    fi
}

# Copy permissions
permissions(){
    __PRM_SOURCE__="${1}"
    __PRM_TARGET__="${2}"
    [ "$(ls -ld "${__PRM_TARGET__}" | cut -d" " -f1,3,4)" != "$(ls -ld "${__PRM_SOURCE__}" | cut -d" " -f1,3,4)" ] || return
    [ "$(lsattr -d "${__PRM_TARGET__}" | cut -c5)" != "-" ] && chattr -d -f -i "${__PRM_TARGET__}"
    if  chmod --reference="${__PRM_SOURCE__}" "${__PRM_TARGET__}" && chown --reference="${__PRM_SOURCE__}" "${__PRM_TARGET__}" ; then
        echo "Fixed permissions of ${__PRM_TARGET__}"
    else
        error "ERROR: Failed to fix permissions of ${__PRM_TARGET__}"
    fi
}

# Make file immutable
immutable(){
    __IMT_FILE__="${1}"
    if [ -f "${__IMT_FILE__}" ] && [ x"$(lsattr -d "${__IMT_FILE__}" | cut -c5)" = x"-" ] ; then
        if chattr -d -f +i "${__IMT_FILE__}"; then
            echo "File ${__IMT_FILE__} is now immutable"
        else
            error "ERROR: Failed to immute ${__IMT_FILE__}"
        fi
    fi
}



### MAIN ###
############

# We shouldn't operate on this template
check "${ACTIVE}" || exit 0

# Turn on debug if required
check "${DEBUG}" && set -x

# Mount private volume
[ -b "${DEVICE}" ] || error "ERROR: Block device ${DEVICE} not found" exit
[ -d "${MOUNTPOINT}" ] || mkdir -p "${MOUNTPOINT}" || error "ERROR: Cannot create mountpoint ${MOUNTPOINT}" exit
if mount -o defaults,discard,noatime "${DEVICE}" "${MOUNTPOINT}" ; then
    echo "Device ${DEVICE} mounted"
else
    if head -c 65536 "${DEVICE}" | tr -d '\0' | read -n 1 ; then
        error "ERROR: Mounting ${DEVICE} failed"
        check ${POWEROFF} && systemctl poweroff
        exit 1
    else
        echo "First boot initialization"
        check ${POWEROFF} && shutdown +1
        exit 0
    fi
fi


# Iterate over /rw files
EXCUDE="$(basename "${QUARANTINE_DIR}")"
for FILE in $(cd "${MOUNTPOINT}" && find -P . -mindepth 1 -path "./${EXCUDE}" -prune -o -print | cut -d'/' -f 2-) ; do

    # Templates
    if find_file "${FILE}" "${BASEDIR}/template.${VM}" "${BASEDIR}/template.ALL" "SOURCE" ; then
        # Symbolic link
        if [ -L "${SOURCE}/${FILE}" ] ; then
            if [ ! -L "${MOUNTPOINT}/${FILE}" ] || [ "$(readlink "${MOUNTPOINT}/${FILE}")" != "$(readlink "${SOURCE}/${FILE}")" ] ; then
                deploy "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            fi
        # Directory
        elif [ -d "${SOURCE}/${FILE}" ] ; then
            if [ -d "${MOUNTPOINT}/${FILE}" ] ; then
                permissions "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            else
                deploy "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            fi
            immutable "${MOUNTPOINT}/${FILE}"
        # Socket
        elif [ -S "${SOURCE}/${FILE}" ] ; then
            if [ -S "${MOUNTPOINT}/${FILE}" ] ; then
                permissions "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            else
                deploy "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            fi
        # Regular file
        elif [ -f "${SOURCE}/${FILE}" ] ; then
            if [ -f "${MOUNTPOINT}/${FILE}" ] && diff "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}" 1>/dev/null 2>&1 ; then
                permissions "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            else
                echo "ERROR: ${MOUNTPOINT}/${FILE} is different, here is the log:"
                diff -Naur "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
                deploy "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            fi
            immutable "${MOUNTPOINT}/${FILE}"
        fi

    # Checksums
    elif find_file "${FILE}" "${BASEDIR}/checksum.${VM}" "${BASEDIR}/checksum.ALL"  "SOURCE" ; then
        # Regular files
        if [ -f "${SOURCE}/${FILE}" ] ; then
            if [ -f "${MOUNTPOINT}/${FILE}" ] && [ "$(head -n 1 < "${SOURCE}/${FILE}")" = "$(sha256sum "${MOUNTPOINT}/${FILE}" | cut -d" " -f1)" ] && [ "$(tail -n 1 < "${SOURCE}/${FILE}")" = "$(sha512sum "${MOUNTPOINT}/${FILE}" | cut -d" " -f1)" ] ; then
                permissions "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
                immutable "${MOUNTPOINT}/${FILE}"
            else
                quarantine "${MOUNTPOINT}/${FILE}"
            fi
        # Dirs
        elif [ -d "${SOURCE}/${FILE}" ] ; then
            if [ -d "${MOUNTPOINT}/${FILE}" ] ; then
                permissions "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
            else
                quarantine "${MOUNTPOINT}/${FILE}"
            fi
        fi

    # Explicitly whitelisted files and dirs
    elif find_file "${FILE}" "${BASEDIR}/whitelist.${VM}" "${BASEDIR}/whitelist.ALL" "SOURCE" ; then
        if [ -f "${SOURCE}/${FILE}" -a -f "${MOUNTPOINT}/${FILE}" ] || [ -d "${SOURCE}/${FILE}" -a -d "${MOUNTPOINT}/${FILE}" ] ; then
            permissions "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
        else
            quarantine "${MOUNTPOINT}/${FILE}"
        fi

    else
        DIR="$(dirname ${FILE})"

        # Files in dirs with .any_file
        if [ -f "${MOUNTPOINT}/${FILE}" ] && find_file "${DIR}/.any_file" "${BASEDIR}/whitelist.$VM" "${BASEDIR}/whitelist.ALL" "SOURCE" ; then
            continue
        fi

        # Dirs in dirs with .any_dir
        if [ -d "${MOUNTPOINT}/${FILE}" ] && find_file "${DIR}/.any_dir" "${BASEDIR}/whitelist.$VM" "${BASEDIR}/whitelist.ALL" "SOURCE" ; then
            continue
        fi

        # Anything in dirs above with .any_dir
        until [ "${DIR}" = "." ] ; do
            DIR="$(dirname ${DIR})"
            find_file "${DIR}/.any_dir" "${BASEDIR}/whitelist.$VM" "${BASEDIR}/whitelist.ALL" "SOURCE" && continue 2
        done

        # Anything else
        check "${ALLOW_ROGUE}" || quarantine "${MOUNTPOINT}/${FILE}"
    fi

done

# Iterate over template files
if check "${DEPLOY_MISSING}" ; then
    for FILE in $( [ -d "${BASEDIR}/template.${VM}" ] && cd "${BASEDIR}/template.${VM}" && find . -mindepth 1 ; [ -d "${BASEDIR}/template.ALL" ] && cd "${BASEDIR}/template.ALL" && find . -mindepth 1 | sort | uniq | cut -d'/' -f 2-) ; do
        find_file "${FILE}" "${BASEDIR}/template.${VM}" "${BASEDIR}/template.ALL" "SOURCE"
        [ -e "${MOUNTPOINT}/${FILE}" ] || deploy "${SOURCE}/${FILE}" "${MOUNTPOINT}/${FILE}"
    done
fi

# Remove /etc/protect if requested
check "${OBSCURE}" && rm -rf "${BASEDIR}"

# Unmount private volume
if umount -lf "${MOUNTPOINT}" ; then
    echo "Unmounted ${MOUNTPOINT}"
else
    error "ERROR: Filed to unmount ${MOUNTPOINT}" exit
fi

# We're done
exit 0
