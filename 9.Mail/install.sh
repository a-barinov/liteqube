#!/bin/bash


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################
. ../.lib/lib.sh
set -e


vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
message "CREATING ${YELLOW}${VM_SENDMAIL}"
vm_create "${VM_SENDMAIL}" "dispvm"
vm_configure "${VM_SENDMAIL}" "pvh" 256 'fw-tor' 'dom0'
if ! vm_exists "${VM_GETMAIL}" ; then
    vm_create "${VM_GETMAIL}" "appvm"
    vm_resize_private "${VM_GETMAIL}" 512
fi
vm_configure "${VM_GETMAIL}" "pvh" 256 'fw-tor' 'dom0'


message "CONFIGURING ${YELLOW}${VM_CORE}"
install_packages "${VM_CORE}" getmail msmtp
push_files "${VM_CORE}"


message "CONFIGURING ${YELLOW}getmail ${PREFIX}AND ${YELLOW}msmtp"
message "PLEASE PUT:"
message "  - ${YELLOW}getmail account files (one per account)${PREFIX} into ${YELLOW}files/getmail${PREFIX} folder"
message "  - ${YELLOW}msmtp account files (one per account)${PREFIX} into ${YELLOW}files/msmtp${PREFIX} folder"
message "PRESS ENTER WHEN READY"
read INPUT
[ -f "./files/printers.conf" ] && file_to_vm "./files/printers.conf" "${VM_CORE}" "/etc/cups/printers.conf"
for PPD in ./files/ppd/* ; do
    [ -f "${PPD}" ] || continue
    NAME="$(basename "${PPD}")"
    file_to_vm "${PPD}" "${VM_CORE}" "/etc/cups/ppd/${NAME}"
done


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
add_permission "Message" "${VM_PRINT}" "dom0" "allow"
add_permission "Error" "${VM_PRINT}" "dom0" "allow"
add_permission "SplitXorg" "${VM_PRINT}" "dom0" "allow"
for VM in ${QQUBES_ALLOWED_TO_PRINT} ; do
    add_permission "PrintFile" "${VM}" "${VM_PRINT}" "ask,default_target=${VM_PRINT}"
done
dom0_install_command lq-getmail
# Cron job to run every 30 min


if [ -x ./custom/custom.sh ] ; then
    message "CUSTOMISING INSTALLATION"
    . ./custom/custom.sh
    message "DONE CUSTOMISING"
fi


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "DONE!"
exit 0
