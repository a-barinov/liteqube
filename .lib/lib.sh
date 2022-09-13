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
VM_PRINT="core-print"
VM_GETMAIL="core-getmail"
VM_SENDMAIL="core-sendmail"
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
ENTER="
"

message()
{
    echo "${PREFIX}${1}${POSTFIX}"
}

vm_exists()
{
    _VMEX_VM="${1}"

    if [ -d "/var/lib/qubes/vm-templates/${_VMEX_VM}" ] || [ -d "/var/lib/qubes/appvms/${_VMEX_VM}" ] ; then
        return 0
    else
        return 1
    fi
}

vm_create()
{
    _VMC_VM="${1}"
    _VMC_TYPE="${2}"

    if vm_exists "${_VMC_VM}" ; then
        message "VM ${YELLOW}${_VMC_VM}${PREFIX} ALREADY EXISTS"
    else
        message "CREATING ${YELLOW}${_VMC_VM}"
        case ${_VMC_TYPE} in
            dispvm)
                qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${_VMC_VM}"
                ;;
            *)
                message "ERROR: UNKNOWN VM TYPE ${YELLOW}${_VMC_TYPE}${PREFIX} FOR ${YELLOW}${_VMC_VM}${PREFIX}"
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
    _ADL_VM="${1}"
    _ADL_FILE="${2}"
    _ADL_LINE="${3}"

    if [ x"${_ADL_VM}" = x"dom0" ] ; then
        sudo cat "${_ADL_FILE}" | grep "${_ADL_LINE}" >/dev/null 2>&1 || sudo /bin/sh -c "echo \"${_ADL_LINE}\" >> \"${_ADL_FILE}\""
    else
        qrexec-client -d "${_ADL_VM}" root:"cat \"${_ADL_FILE}\" | grep \"${_ADL_LINE}\" >/dev/null 2>&1 || echo \"${_ADL_LINE}\" >> \"${_ADL_FILE}\""
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

# TODO: deprecate
dom0_command()
{
    _FILE="${1}"

    [ -d ~/bin ] || mkdir ~/bin
    cp "./files/${_FILE}" ~/bin
}

dom0_install_command()
{
    _DIC_FILE="${1}"

    [ -d ~/bin ] || mkdir ~/bin
    cp "./files/${_DIC_FILE}" ~/bin
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

add_permission()
{
    _ADP_PERMISSION_NAME="${1}"
    _ADP_VM_FROM="${2}"
    _ADP_VM_TO="${3}"
    _ADP_PERMISSION="${4}"
    if [ -e "/etc/qubes-rpc/${_ADP_PERMISSION_NAME}" ] ; then
        add_line dom0 "/etc/qubes-rpc/policy/${_ADP_PERMISSION_NAME}" "${_ADP_VM_FROM} ${_ADP_VM_TO} ${_ADP_PERMISSION}"
    else
        add_line dom0 "/etc/qubes-rpc/policy/liteqube.${_ADP_PERMISSION_NAME}" "${_ADP_VM_FROM} ${_ADP_VM_TO} ${_ADP_PERMISSION}"
    fi
}

vm_find_template()
{
    _FIT_VM="${1}"
    while qvm-prefs --get "${_FIT_VM}" template 1>/dev/null 2>&1 ; do
        _FIT_VM="$(qvm-prefs --get "${_FIT_VM}" template)"
    done
    echo "${_FIT_VM}"
}

vm_type()
{
    _VMT_VM="${1}"
    case "${_VMT_VM}" in
        *[Dd]ebian*)
            echo "debian" ;;
        *[Ff]edora*)
            echo "fedora" ;;
        *)
            qvm-start --quiet --skip-if-running "${_VMT_VM}"
            case "$(qrexec-client -d "${_VMT_VM}" root:"cat /etc/*release")" in
                *[Dd]ebian*)
                    echo "debian" ;;
                *[Ff]edora*)
                    echo "fedora" ;;
                *)
                    echo "unknown" ;;
            esac
            ;;
    esac
}

cleanup_file()
{
    _CLNF_FILE="${1}"
    _CLNF_STRING="${2}"
    if [ -f "${_CLNF_FILE}" ] ; then
        sudo sed -i "/${_CLNF_STRING}/d" "${_CLNF_FILE}"
        [ -z "$(sudo cat ${_CLNF_FILE})" ] && sudo rm "${_CLNF_FILE}" || true
    fi
}

install_settings()
{
    _INSTS_VM="${1}"
    _INSTS_TARGET="/etc/protect/template.${_INSTS_VM}/config/liteqube-settings"
    file_to_vm "./settings-qube.sh" "${VM_CORE}" "${_INSTS_TARGET}"
    push_command "${VM_CORE}" "chmod 755 ${_INSTS_TARGET}"
}
