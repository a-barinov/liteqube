#!/bin/bash


# Create iSCSI qube, anything except True will skip vm creation
ISCSI_VM="False"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


chmod +x ../.lib/lib.sh
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


message "CONFIGURING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
push_files "${VM_CORE}"
push_command "${VM_CORE}" "apt-get -q -y install lvm2 cryptsetup-bin"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_DECRYPT}"
for SERVICE in dm-event.socket blk-availability lvm2-lvmpolld.socket lvm2-monitor systemd-pstore ; do
    push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
done


message "CONFIGURING ${YELLOW}dom0"
[ -x /bin/dialog ] || sudo qubes-dom0-update --console --show-output dialog
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_DECRYPT} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_DECRYPT} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalStorage" "${VM_DECRYPT} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_DECRYPT} ${VM_XORG} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitPassword" "${VM_DECRYPT} ${VM_KEYS} ask,default_target=${VM_KEYS}"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitPassword" "${VM_DECRYPT} dom0 ask,default_target=dom0"
dom0_command lq-storage


if ! vm_exists "${VM_DECRYPT}" ; then
    message "CREATING ${YELLOW}${VM_DECRYPT}"
    qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_DECRYPT}"
else
    message "VM ${YELLOW}${VM_DECRYPT}${PREFIX} ALREADY EXISTS"
fi


message "CONFIGURING ${YELLOW}${VM_DECRYPT}"
qvm-prefs --quiet --set "${VM_DECRYPT}" maxmem 0
qvm-prefs --quiet --set "${VM_DECRYPT}" memory 1024
qvm-prefs --quiet --set "${VM_DECRYPT}" netvm ''
#qvm-prefs --quiet --set "${VM_DECRYPT}" guivm ''
qvm-prefs --quiet --set "${VM_DECRYPT}" audiovm ''
qvm-prefs --quiet --set "${VM_DECRYPT}" vcpus 1
qvm-prefs --quiet --set "${VM_DECRYPT}" virt_mode pvh


if [ x"${ISCSI_VM}" = x"True" ] ; then

    if ! vm_exists "${VM_FW_NET}" ; then
        message "ERROR: ${YELLOW}${VM_FW_NET}${PREFIX} NOT FOUND, PLEASE RUN NETWORK INSTALL"
        exit 1
    fi

    if ! vm_exists "${VM_ISCSI}" ; then
        message "CREATING ${YELLOW}${VM_ISCSI}"
        qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_ISCSI}"
    else
        message "VM ${YELLOW}${VM_ISCSI}${PREFIX} ALREADY EXISTS"
    fi


    message "CONFIGURING ${YELLOW}${VM_ISCSI}"
    qvm-prefs --quiet --set "${VM_ISCSI}" maxmem 0
    qvm-prefs --quiet --set "${VM_ISCSI}" memory 160
    qvm-prefs --quiet --set "${VM_ISCSI}" netvm "${VM_FW_NET}"
    #qvm-prefs --quiet --set "${VM_ISCSI}" guivm ''
    qvm-prefs --quiet --set "${VM_ISCSI}" audiovm ''
    qvm-prefs --quiet --set "${VM_ISCSI}" vcpus 1
    qvm-prefs --quiet --set "${VM_ISCSI}" virt_mode pvh


    message "CONFIGURING ${YELLOW}${VM_CORE}"
    push_command "${VM_CORE}" "apt-get -q -y install open-iscsi ethtool"
    add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_ISCSI}"
    push_from_dir "./default.iscsi" "${VM_CORE}"
    for SERVICE in open-iscsi iscsid ; do
        push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
        push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    done


    message "CONFIGURING ${YELLOW}dom0"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_ISCSI} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_ISCSI} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalStorage" "${VM_ISCSI} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_ISCSI} ${VM_XORG} allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitFile" "${VM_ISCSI} ${VM_KEYS} ask,default_target=${VM_KEYS}"


    message "CONFIGURING ISCSI SERVICE IN ${YELLOW}${VM_ISCSI}"
    qvm-start --quiet --skip-if-running "${VM_KEYS}"
    ISCSI_DEFAULTS="$(cd ./files/open-iscsi ; find . -name default -type f | tail -n 1 ; cd ../..)"
    checksum_to_vm "./files/open-iscsi/${ISCSI_DEFAULTS}" "${VM_KEYS}" "/home/user/${VM_ISCSI}/default"
    push_command "${VM_CORE}" "chown -R user:user /etc/protect/checksum.${VM_KEYS}/home/user || true"
    tar c -C "./files/open-iscsi" --exclude "default" . | push_command "${VM_CORE}" "tar x -C \"/etc/iscsi\""
    push_command "${VM_CORE}" "chown -R root:root /etc/iscsi 2>/dev/null"
    push_command "${VM_CORE}" "rm -f \"/etc/iscsi/${ISCSI_DEFAULTS}\""
    push_command "${VM_CORE}" "ln -s \"/run/liteqube/iscsi-default\" \"/etc/iscsi/${ISCSI_DEFAULTS}\""
    qvm-shutdown --quiet --wait --force "${VM_KEYS}"

fi # ISCSI


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "DONE!"
exit 0
