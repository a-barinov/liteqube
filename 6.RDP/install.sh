#!/bin/bash


# Space-separated remote connection apps to install. Currently TightVNC and xfreerdp2 are supported
REMOTE_APPS="freerdp2-x11 xtightvncviewer"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


. ../.lib/lib.sh
set -e


if ! vm_exists "${VM_CORE}" ; then
    message "ERROR: ${YELLOW}${VM_CORE}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_DVM}" ; then
    message "ERROR: ${YELLOW}${VM_DVM}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_KEYS}" ; then
    message "ERROR: ${YELLOW}${VM_KEYS}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_FW_NET}" ; then
    message "ERROR: ${YELLOW}${VM_FW_NET}${PREFIX} NOT FOUND, PLEASE RUN NETWORK INSTALL"
    exit 1
fi


if ! vm_exists "${VM_RDP}" ; then
    message "CREATING ${YELLOW}${VM_RDP}"
    qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_RDP}"
else
    message "VM ${YELLOW}${VM_RDP}${PREFIX} ALREADY EXISTS"
fi


message "CONFIGURING ${YELLOW}${VM_RDP}"
qvm-prefs --quiet --set "${VM_RDP}" maxmem 0
qvm-prefs --quiet --set "${VM_RDP}" memory 384
qvm-prefs --quiet --set "${VM_RDP}" provides_network True
qvm-prefs --quiet --set "${VM_RDP}" netvm "${VM_FW_NET}"
qvm-prefs --quiet --set "${VM_RDP}" vcpus 1
qvm-prefs --quiet --set "${VM_RDP}" virt_mode pvh


message "CONFIGURING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
push_command "${VM_CORE}" "apt-get -q -y install ${REMOTE_APPS} pulseaudio-qubes"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_RDP}"
push_files "${VM_CORE}"


message "CONFIGURING ${YELLOW}dom0"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_RDP} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_RDP} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitSSH" "${VM_RDP} ${VM_KEYS} ask,default_target=${VM_KEYS}"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitPassword" "${VM_RDP} ${VM_KEYS} ask,default_target=${VM_KEYS}"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitPassword" "${VM_RDP} dom0 ask,default_target=dom0"
dom0_command lq-remote


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "DONE!"
exit 0
