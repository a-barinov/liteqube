#!/bin/sh

# COMMON SETTINGS #
###################

# Private partition size of template and dvm template vms
PRIVATE_DISK_MB=512

# Name os the LVM volume group that holds vm data
VM_GROUP="qubes_dom0-vm"


# VM NAMES & COLORS #
#####################

VM_BASE="debian-11-minimal"
VM_CORE="debian-core"
VM_DVM="core-dvm"
VM_XORG="core-xorg"
VM_KEYS="core-keys"
VM_USB="core-usb"
VM_NET="core-net"
VM_TOR="core-tor"
VM_VPN="core-vpn"
VM_UPDATE="core-update"
VM_FW_BASE="fw-base"
VM_FW_DVM="fw-dvm"
VM_FW_NET="fw-net"
VM_FW_TOR="fw-tor"

COLOR_TEMPLATE="black"
COLOR_WORKERS="gray"


# Support functions #
#####################

PREFIX="$(tput setaf 7)$(tput bold)"
YELLOW="$(tput setaf 3)$(tput bold)"
POSTFIX="$(tput sgr0)"
TAB="$(echo -e '\t')"

message()
{
    echo "${PREFIX}${1}${POSTFIX}"
}

vm_exists()
{
    if [ -d "/var/lib/qubes/vm-templates/${1}" ] || [ -d "/var/lib/qubes/appvms/${1}" ] ; then
        return 0
    else
        return 1
    fi
}

push_command()
{
    qrexec-client -d "${1}" root:"${2}"
}

push_xterm()
(
    qrexec-client -d "${1}" root:"/etc/qubes-rpc/liteqube.Xterm \"${2}\"" >/dev/null 2>&1
)

push_files_to_domain()
{
    DOMAIN="${1}"
    SOURCE="${5}"
    TARGET="${5//\.\/$DOMAIN/}"
    P_USER="${2:1:3}"
    P_GROUP="${2:4:3}"
    P_OTHER="${2:7:3}"
    P_USER="${P_USER//-/}"
    P_GROUP="${P_GROUP//-/}"
    P_OTHER="${P_OTHER//-/}"
    if [ -L "${SOURCE}" ] ; then
        SOURCE="$(readlink ${SOURCE})"
        if [ x"${DOMAIN}" = x"dom0" ] ; then
            sudo rm -rf "${TARGET}" >/dev/null 2>&1
            sudo ln --symbolic "${SOURCE}" "${TARGET}"
        else
            qrexec-client -d "${DOMAIN}" root:"rm -rf ${TARGET} ; ln --symbolic ${SOURCE} ${TARGET}" </dev/null
        fi
        return
    fi
    if [ -d "${SOURCE}" ] ; then
        if [ x"${DOMAIN}" = x"dom0" ] ; then
            if ! sudo test -d "${TARGET}" ; then
                sudo rm -f "${TARGET}" >/dev/null 2>&1
                sudo mkdir "${TARGET}"
            fi
            sudo chown "${3}:${4}" "${TARGET}"
            sudo chmod "u=${P_USER},g=${P_GROUP},o=${P_OTHER}" "${TARGET}"
        else
            qrexec-client -d "${DOMAIN}" root:"if ! [ -d ${TARGET} ] ; then rm -f ${TARGET} ; mkdir ${TARGET} ; fi ; chown ${3}:${4} ${TARGET} ; chmod u=${P_USER},g=${P_GROUP},o=${P_OTHER} ${TARGET}" </dev/null
        fi
        return
    fi
    if [ -f "${SOURCE}" ] ; then
        if [ x"${DOMAIN}" = x"dom0" ] ; then
            sudo rm -f "${TARGET}" >/dev/null 2>&1
            sudo cp "${SOURCE}" "${TARGET}"
            sudo chown "${3}:${4}" "${TARGET}"
            sudo chmod "u=${P_USER},g=${P_GROUP},o=${P_OTHER}" "${TARGET}"
        else
            qrexec-client -d "${DOMAIN}" root:"rm -f ${TARGET} ; cat > ${TARGET} ; chown ${3}:${4} ${TARGET} ; chmod u=${P_USER},g=${P_GROUP},o=${P_OTHER} ${TARGET}" <"${SOURCE}"
        fi
        return
    fi
    message "UNKNOWN TYPE OF ${YELLOW}${SOURCE}${PREFIX}, EXITING"
    exit 1
}

push_from_dir()
{
    DOMAIN="${2}"
    cd "${1}"
    if [ -e "./permissions" ] ; then
        cat "./permissions" | grep "${TAB}./${DOMAIN}" | while IFS= read -r LINE ; do
            push_files_to_domain "${DOMAIN}" $LINE
        done
    else
        message "PERMISSIONS FILE ${YELLOW}${1}/permissions${PREFIX} NOT FOUND, EXITING"
        exit 1
    fi
    cd ..
}

push_files()
{
    push_from_dir "./default" "${1}"
}

push_custom_files()
{
    push_from_dir "./custom" "${1}"
}

add_line()
{
    VM="${1}"
    FILE="${2}"
    LINE="${3}"
    if [ x"${VM}" = x"dom0" ] ; then
        if ! sudo cat "${FILE}" | grep "${LINE}" >/dev/null 2>&1 ; then
            sudo /bin/sh -c "echo \"${LINE}\" >> \"${FILE}\""
        fi
    else
        qrexec-client -d "${VM}" root:"if ! cat \"${FILE}\" | grep \"${LINE}\" >/dev/null 2>&1 ; then echo \"${LINE}\" >> \"${FILE}\" ; fi"
    fi
}

replace_text()
{
    VM="${1}"
    FILE="${2}"
    FIND="${3}"
    REPLACE="${4}"
    if [ x"${VM}" = x"dom0" ] ; then
        sudo sed -i "s/${FIND}/${REPLACE}/g" "${FILE}"
    else
        qrexec-client -d "${VM}" root:"sed -i \"s/${FIND}/${REPLACE}/g\" \"${FILE}\""
    fi
}

dom0_command()
{
    FILE="${1}"
    if ! [ -d ~/bin ] ; then
        mkdir ~/bin
    fi
    cp "./files/${FILE}" ~/bin
}

checksum_to_vm()
{
    LOCALFILE="${1}"
    VM="${2}"
    REMOTEFILE="${3}"
    cat "${LOCALFILE}" | push_command "${VM}" "mkdir -p -m 700 \"$(dirname ${REMOTEFILE})\" ; chattr -i \"${REMOTEFILE}\" ; cat > \"${REMOTEFILE}\""
    SHA256="$(sha256sum -b "${LOCALFILE}" | cut -d' ' -f1)"
    SHA512="$(sha512sum -b "${LOCALFILE}" | cut -d' ' -f1)"
    push_command "${VM_CORE}" "mkdir -p -m 700 /etc/protect/checksum.${VM}$(dirname ${REMOTEFILE}) ; rm -f \"/etc/protect/checksum.${VM}${REMOTEFILE}\" ; echo -e \"${SHA256}\n${SHA512}\" > \"/etc/protect/checksum.${VM}${REMOTEFILE}\""
}

file_to_vm()
{
    LOCALFILE="${1}"
    VM="${2}"
    REMOTEFILE="${3}"
    cat "${LOCALFILE}" | push_command "${VM}" "cat > \"${REMOTEFILE}\""
}
