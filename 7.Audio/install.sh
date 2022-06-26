#!/bin/bash


# Space-separated list of qubes having access to aoudio playback
QUBES_WITH_SOUND="core-rdp dvm-chrome dvm-chrome-tor my-skype my-games"

# Set to "True" to not require PCI device reset
AUDIO_NO_STRICT_RESET="True"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


. ../.lib/lib.sh
set -e


vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
vm_create "${VM_AUDIO}" "dispvm"
vm_configure "${VM_AUDIO}" "hvm" 192 '' ''


message "CONFIGURING ${YELLOW}${VM_CORE}"
install_packages "${VM_CORE}" pulseaudio pulsemixer qubes-gui-daemon-pulseaudio
push_files "${VM_CORE}"
push_command "${VM_CORE}" "adduser user audio 2>/dev/null 1>&2"


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_AUDIO} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_AUDIO} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalSound" "${VM_AUDIO} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_AUDIO} ${VM_XORG} allow"
add_line dom0 "/etc/qubes-rpc/policy/admin.Events" "${VM_AUDIO} "'\$adminvm allow,target=\$adminvm'
add_line dom0 "/etc/qubes-rpc/policy/admin.vm.List" "${VM_AUDIO} "'\$adminvm allow,target=\$adminvm'
add_line dom0 "/etc/qubes-rpc/policy/admin.vm.property.GetAll" "${VM_AUDIO} "'\$adminvm allow,target=\$adminvm'
for VM in ${QUBES_WITH_SOUND} ; do
    add_line dom0 "/etc/qubes-rpc/policy/admin.Events" "${VM_AUDIO} ${VM} "'allow,target=\$adminvm'
    add_line dom0 "/etc/qubes-rpc/policy/admin.vm.List" "${VM_AUDIO} ${VM} "'allow,target=\$adminvm'
    add_line dom0 "/etc/qubes-rpc/policy/admin.vm.property.GetAll" "${VM_AUDIO} ${VM} "'allow,target=\$adminvm'
    vm_exists "${VM}" && qvm-prefs "${VM}" audiovm "${VM_AUDIO}"
done
dom0_command lq-volume


message "ATTACHING AUDIO DEVICES TO ${YELLOW}${VM_AUDIO}"
for DEVICE in $(qvm-pci | grep -ie Audio -ie Sound | cut -d' ' -f1); do
    [ x"${AUDIO_NO_STRICT_RESET}" = x"True" ] && OPTIONS="--option no-strict-reset=true"
    qvm-pci attach "${VM_AUDIO}" "${DEVICE}" --persistent ${OPTIONS} || true
done


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


#TODO option to autostart qube
#TODO delayed start to minimise cpu impact


message "DONE!"
exit 0
