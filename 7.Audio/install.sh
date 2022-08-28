#!/bin/sh


. ../.lib/lib.sh
. ./settings-installer.sh
set -e
#set -x


vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
vm_exists "${VM_AUDIO}" && qvm-shutdown --quiet --wait --force "${VM_AUDIO}" || vm_create "${VM_AUDIO}" "dispvm"
vm_configure "${VM_AUDIO}" "hvm" 208 '' ''
qvm-prefs --set "${VM_AUDIO}" autostart True


message "CONFIGURING ${YELLOW}${VM_CORE}"
install_packages "${VM_CORE}" pulseaudio pulsemixer qubes-gui-daemon-pulseaudio
push_files "${VM_CORE}"
push_command "${VM_CORE}" "adduser user audio 2>/dev/null 1>&2"
install_settings "${VM_AUDIO}"


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
add_permission "Message" "${VM_AUDIO}" "dom0" "allow"
add_permission "Error" "${VM_AUDIO}" "dom0" "allow"
add_permission "SplitXorg" "${VM_AUDIO}" "${VM_XORG}" "allow"
add_permission "SignalSound" "${VM_AUDIO}" "dom0" "allow"
add_permission "admin.Events" "${VM_AUDIO}" '\$adminvm' 'allow,target=\$adminvm'
add_permission "admin.vm.List" "${VM_AUDIO}" '\$adminvm' 'allow,target=\$adminvm'
add_permission "admin.vm.property.Get" "${VM_AUDIO}" '\$adminvm' 'allow,target=\$adminvm'
for VM in ${QUBES_WITH_SOUND} ; do
    add_permission "admin.Events" "${VM_AUDIO}" "${VM}" 'allow,target=\$adminvm'
    add_permission "admin.vm.List" "${VM_AUDIO}" "${VM}" 'allow,target=\$adminvm'
    add_permission "admin.vm.property.Get" "${VM_AUDIO}" "${VM}" 'allow,target=\$adminvm'
    vm_exists "${VM}" && qvm-prefs "${VM}" audiovm "${VM_AUDIO}"
done
dom0_install_command lq-volume


message "ATTACHING AUDIO DEVICES TO ${YELLOW}${VM_AUDIO}"
for DEVICE in $(qvm-pci | grep -ie Audio -ie Sound | cut -d' ' -f1); do
    [ x"${AUDIO_NO_STRICT_RESET}" = x"True" ] && OPTIONS="--option no-strict-reset=true"
    qvm-pci attach "${VM_AUDIO}" "${DEVICE}" --persistent ${OPTIONS} || true
done


if [ -x ./custom/custom.sh ] ; then
    message "CUSTOMISING INSTALLATION"
    . ./custom/custom.sh
    message "DONE CUSTOMISING"
fi


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


#TODO: Mic sharing support


message "DONE!"
exit 0
