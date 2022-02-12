#!/bin/bash


# Set to "True" if you will be connecting input devices to usb vm
USB_INPUT_DEVICES="True"

# Set to "True" to not require PCI device reset
USB_NO_STRICT_RESET="True"

# sys-usb vm name
SYS_USB="sys-usb"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


. ../.lib/lib.sh
set -e


if ! vm_exists "${VM_CORE}" ; then
    message "ERROR: ${YELLOW}${VM_CORE}${PREFIX} NOT FOUND"
    exit 1
fi
if ! vm_exists "${VM_DVM}" ; then
    message "ERROR: ${YELLOW}${VM_DVM}${PREFIX} NOT FOUND"
    exit 1
fi
if ! vm_exists "${VM_XORG}" ; then
    message "ERROR: ${YELLOW}${VM_XORG}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi


if ! vm_exists "${VM_USB}" ; then
    message "CREATING ${YELLOW}${VM_USB}"
    qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_USB}"
else
    message "VM ${YELLOW}${VM_USB}${PREFIX} ALREADY EXISTS"
fi


message "CONFIGURING ${YELLOW}${VM_USB}"
qvm-prefs --quiet --set "${VM_USB}" maxmem 0
qvm-prefs --quiet --set "${VM_USB}" memory 176
qvm-prefs --quiet --set "${VM_USB}" netvm ''
#qvm-prefs --quiet --set "${VM_USB}" guivm ''
qvm-prefs --quiet --set "${VM_USB}" audiovm ''
qvm-prefs --quiet --set "${VM_USB}" vcpus 1
qvm-prefs --quiet --set "${VM_USB}" virt_mode hvm


message "STARTING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"


message "CONFIGURING ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "apt-get -q -y install usbguard qubes-usb-proxy"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_USB}"
push_files "${VM_CORE}"
for SERVICE in usbguard usbguard-dbus ; do
    push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
done


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
sudo qubes-dom0-update --console --show-output qubes-usb-proxy-dom0
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_USB} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_USB} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_USB} ${VM_XORG} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalStorage" "${VM_USB} dom0 allow"


if [ x"${USB_INPUT_DEVICES}" = x"True" ] ; then
    message "CONFIGURING USB INPUT IN ${YELLOW}${VM_CORE}"
    push_command "${VM_CORE}" "apt-get install -q -y qubes-input-proxy-sender"
    message "CONFIGURING USB INPUT IN ${YELLOW}dom0"
    sudo qubes-dom0-update --console --show-output qubes-input-proxy
else
    sudo rm -f /etc/qubes-rpc/policy/qubes.Input*
fi


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "RESTARTING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "rm -rf /rw/QUARANTINE >/dev/null 2>&1"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


if vm_exists "${SYS_USB}" ; then
    message "ATTACHING ${YELLOW}${SYS_USB}${PREFIX} DEVICES TO ${YELLOW}${VM_USB}"
    qvm-shutdown --quiet --wait --force "${SYS_USB}"
    if [ x"${USB_NO_STRICT_RESET}" = x"True" ] ; then
        OPTIONS="--option no-strict-reset=true"
    fi
    qvm-pci | grep "${SYS_USB}" | cut -c-12 | while read DEVICE ; do
        qvm-pci attach "${VM_USB}" "${DEVICE}" --persistent ${OPTIONS} || true
    done
    message "STARTING ${YELLOW}${VM_USB}"
    qvm-prefs --set "${VM_USB}" autostart True
    qvm-prefs --default "${SYS_USB}" autostart
    sleep 5
    qvm-start --quiet --skip-if-running "${VM_USB}"
else
    if qvm-pci | grep "${VM_USB}" >/dev/null 2>&1 ; then
        message "STARTING ${YELLOW}${VM_USB}"
        qvm-prefs --set "${VM_USB}" autostart True
        qvm-start --quiet --skip-if-running "${VM_USB}" || true
    else
        message "NO DEVICES ATTACHED TO ${YELLOW}${VM_USB}${PREFIX}, PLEASE ATTACH AND START ${YELLOW}${VM_USB}"
    fi
fi


message "DONE!"
exit 0
