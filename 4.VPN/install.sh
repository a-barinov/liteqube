#!/bin/bash


# Create ssh vpn, anything except True will skip vm creation
VPN_SSH="True"


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
if ! vm_exists "${VM_XORG}" ; then
    message "ERROR: ${YELLOW}${VM_XORG}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_KEYS}" ; then
    message "ERROR: ${YELLOW}${VM_DVM}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_FW_NET}" ; then
    message "ERROR: ${YELLOW}${VM_FW_NET}${PREFIX} NOT FOUND, PLEASE RUN NETWORK INSTALL"
    exit 1
fi


if [ x"${VPN_SSH}" = x"True" ] ; then

    VM_NAME="${VM_VPN}-ssh"

    if ! vm_exists "${VM_NAME}" ; then
        message "CREATING ${YELLOW}${VM_NAME}"
        qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_NAME}"
    else
        message "VM ${YELLOW}${VM_NAME}${PREFIX} ALREADY EXISTS"
    fi


    message "CONFIGURING ${YELLOW}${VM_NAME}"
    qvm-prefs --quiet --set "${VM_NAME}" maxmem 0
    qvm-prefs --quiet --set "${VM_NAME}" memory 144
    qvm-prefs --quiet --set "${VM_NAME}" provides_network True
    qvm-prefs --quiet --set "${VM_NAME}" netvm "${VM_FW_NET}"
    #qvm-prefs --quiet --set "${VM_NAME}" guivm ''
    qvm-prefs --quiet --set "${VM_NAME}" audiovm ''
    qvm-prefs --quiet --set "${VM_NAME}" vcpus 1
    qvm-prefs --quiet --set "${VM_NAME}" virt_mode pvh


    message "CONFIGURING ${YELLOW}${VM_CORE}"
    qvm-start --quiet --skip-if-running "${VM_CORE}"
    push_command "${VM_CORE}" "apt-get -q -y install redsocks net-tools"
    add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_NAME}"
    push_from_dir "./default.ssh" "${VM_CORE}"
    for SERVICE in redsocks ; do
        push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
        push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    done
    set -- "junk" $(qvm-prefs ${VM_NAME} | grep '^ip ' )
    replace_text "${VM_CORE}" "/etc/redsocks.conf" "512.512.512.512" "${4}"


    message "CONFIGURING ${YELLOW}dom0"
    push_from_dir "./default.ssh" "dom0"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_NAME} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_NAME} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitSSH" "${VM_NAME} ${VM_KEYS} ask,default_target=${VM_KEYS}"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalVPN" "${VM_NAME} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_NAME} ${VM_XORG} allow"

fi # SSH VPN


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


# TODO: block non-tcp traffic except dns for ssh
# TODO: openvpn provider
# TODO: multiple profiles for ssh
#   systemctl start myservice@"arg1 arg2 arg3".service
#   [Service]
#   Environment="SCRIPT_ARGS=%I"
#   ExecStart=/tmp/test.py $SCRIPT_ARGS
#   ExecStart=/tmp/test.py %I
# TODO: proxy dns requests into dns-over-https (dnscrypt-proxy, ideally https-dns-proxy)


message "DONE!"
exit 0
