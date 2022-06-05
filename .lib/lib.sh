#!/bin/sh

# COMMON SETTINGS #
###################

# Root partidion size of template vm in Mb
ROOT_DISK_MB=2560

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
VM_ISCSI="core-iscsi"
VM_DECRYPT="core-decrypt"
VM_UPDATE="core-update"
VM_RDP="core-rdp"
VM_AUDIO="core-sound"
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
    _VM="${1}"

    if [ -d "/var/lib/qubes/vm-templates/${_VM}" ] || [ -d "/var/lib/qubes/appvms/${_VM}" ] ; then
        return 0
    else
        return 1
    fi
}

vm_create()
{
    _VM="${1}"
    _TYPE="${2}"

    if vm_exists "${_VM}" ; then
        message "VM ${YELLOW}${_VM}${PREFIX} ALREADY EXISTS"
    else
        message "CREATING ${YELLOW}${_VM}"
        case ${_TYPE} in
            dispvm)
                qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_AUDIO}"
                ;;
            *)
                message "ERROR: UNKNOWN VM TYPE ${YELLOW}${_TYPE}${PREFIX} FOR ${YELLOW}${_VM}${PREFIX}"
                exit 1
                ;;
        esac
    fi
}

vm_configure()
{
    _VM="${1}"

    message "CONFIGURING ${YELLOW}${_VM}"
    qvm-prefs --quiet --set "${_VM}" virt_mode "${2}"
    qvm-prefs --quiet --set "${_VM}" maxmem 0
    qvm-prefs --quiet --set "${_VM}" memory "${3}"
    qvm-prefs --quiet --set "${_VM}" netvm "${4}"
    #qvm-prefs --quiet --set "${_VM}" guivm "${5}"
    qvm-prefs --quiet --set "${_VM}" audiovm ''
    qvm-prefs --quiet --set "${_VM}" vcpus 1
}

vm_fail_if_missing()
{
    _VM="${1}"

    vm_exists "${_VM}" && return
    message "ERROR: ${YELLOW}${_VM}${PREFIX} NOT FOUND, PLEASE INSTALL IT FIRST"
    exit 1
}

push_command()
{
    qvm-start --quiet --skip-if-running "${1}"
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
    cd "${1}"
    _VM="${2}"
    [ x"${_VM}" = x"dom0" ] || qvm-start --quiet --skip-if-running "${_VM}"
    if [ -e "./permissions" ] ; then
        cat "./permissions" | grep "${TAB}./${_VM}" | while IFS= read -r LINE ; do
            push_files_to_domain "${_VM}" $LINE
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
    _VM="${1}"
    _FILE="${2}"
    _LINE="${3}"

    if [ x"${_VM}" = x"dom0" ] ; then
        if ! sudo cat "${_FILE}" | grep "${_LINE}" >/dev/null 2>&1 ; then
            sudo /bin/sh -c "echo \"${_LINE}\" >> \"${_FILE}\""
        fi
    else
        qrexec-client -d "${_VM}" root:"if ! cat \"${_FILE}\" | grep \"${_LINE}\" >/dev/null 2>&1 ; then echo \"${_LINE}\" >> \"${_FILE}\" ; fi"
    fi
}

replace_text()
{
    _VM="${1}"
    _FILE="${2}"
    _FIND="${3}"
    _REPLACE="${4}"

    if [ x"${_VM}" = x"dom0" ] ; then
        sudo sed -i "s/${_FIND}/${_REPLACE}/g" "${_FILE}"
    else
        qrexec-client -d "${_VM}" root:"sed -i \"s/${_FIND}/${_REPLACE}/g\" \"${_FILE}\""
    fi
}

dom0_command()
{
    _FILE="${1}"

    [ -d ~/bin ] || mkdir ~/bin
    cp "./files/${_FILE}" ~/bin
}

file_to_vm()
{
    _LOCALFILE="${1}"
    _VM="${2}"
    _REMOTEFILE="${3}"

    cat "${_LOCALFILE}" | push_command "${_VM}" "cat > \"${_REMOTEFILE}\""
}

dir_to_vm()
{

    _LOCALDIR="${1}"
    _VM="${2}"
    _REMOTEDIR="${3}"

    tar c -C "${_LOCALDIR}" . | push_command "${_VM}" "tar x -C \"${_REMOTEDIR}\""
}

checksum_to_vm()
{
    _LOCALFILE="${1}"
    _VM="${2}"
    _REMOTEFILE="${3}"

    cat "${_LOCALFILE}" | push_command "${_VM}" "mkdir -p -m 700 \"$(dirname ${_REMOTEFILE})\" ; chattr -i \"${_REMOTEFILE}\" ; cat > \"${_REMOTEFILE}\""
    _SHA256="$(sha256sum -b "${_LOCALFILE}" | cut -d' ' -f1)"
    _SHA512="$(sha512sum -b "${_LOCALFILE}" | cut -d' ' -f1)"
    push_command "${VM_CORE}" "mkdir -p -m 700 /etc/protect/checksum.${_VM}$(dirname ${_REMOTEFILE}) ; rm -f \"/etc/protect/checksum.${_VM}${_REMOTEFILE}\" ; echo -e \"${_SHA256}\n${_SHA512}\" > \"/etc/protect/checksum.${_VM}${_REMOTEFILE}\""
}

install_packages()
{
    _VM="${1}"

    shift
    if [ x"${_VM}" = x"dom0" ] ; then 
        echo "NOT IMPLEMENTED"
    else
        qvm-start --quiet --skip-if-running "${_VM}"
        for _PACKAGE in $@ ; do
            qrexec-client -d "${_VM}" root:"[ -e /var/lib/dpkg/info/${_PACKAGE}.list ]" || _PACKAGES_TO_INSTALL="${_PACKAGES_TO_INSTALL} ${_PACKAGE}"
        done
        [ -z "${_PACKAGES_TO_INSTALL}" ] || qrexec-client -d "${_VM}" root:"aptitude -q -y install ${_PACKAGES_TO_INSTALL}"
    fi
}
