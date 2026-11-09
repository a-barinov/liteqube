#!/bin/sh

. ../.lib/lib.sh
. ./settings-installer.sh
# set -x

message "SET ${YELLOW}${ORIGINAL_VM_AUDIO}${PREFIX} AS AUDIO VM"
for VM in ${QUBES_WITH_SOUND} ; do
    vm_exists "${VM}" && qvm-prefs "${VM}" audiovm "${ORIGINAL_VM_AUDIO}"
done

message "DELETE ${YELLOW}${VM_AUDIO}"
qvm-shutdown --quiet --wait --force "${VM_AUDIO}" 2>/dev/null
qvm-remove --force "${VM_AUDIO}" 2>/dev/null

message "CLEANUP ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "rm -rf /etc/protect/template.${VM_AUDIO} 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm /etc/modprobe.d/liteqube-sound.conf 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm /etc/qubes-rpc/liteqube.SoundVolume 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm /lib/systemd/system/liteqube-pulseaudio-*.service 2>/dev/null 1>&2"
push_command "${VM_CORE}" "aptitude -q -y purge pulseaudio pulsemixer qubes-gui-daemon-pulseaudio"
qvm-shutdown --quiet --wait --force "${VM_CORE}" 2>/dev/null

message "CLEANUP ${YELLOW}dom0"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Message" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Error" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SignalSound" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/admin.Events" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/admin.vm.List" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/admin.vm.feature.CheckWithTemplate" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/admin.vm.property.Get" "${VM_AUDIO}"
cleanup_file "/etc/qubes-rpc/policy/admin.vm.property.GetAll" "${VM_AUDIO}"
sudo rm -f /etc/qubes-rpc/liteqube.SignalSound 2>/dev/null
rm -f ~/bin/lq-volume 2>/dev/null
[ -z "$(ls -A "${HOME}/bin")" ] && rm "${HOME}/bin"

if [ -d /tmp/liteqube-rollback.7 ] ; then
    message "ROLLBACK DIRECTORY FOUND, RESTORING STATE"
    qvm-shutdown --force --wait ${VM_CORE}
    sudo cp /tmp/liteqube-rollback.7/40-config-liteqube.policy /etc/qubes/policy.d/
    qvm-volume revert "${VM_CORE}:root" `cat /tmp/liteqube-rollback.7/snapshot-${VM_CORE}-root.id`
    qvm-volume revert "${VM_CORE}:private" `cat /tmp/liteqube-rollback.7/snapshot-${VM_CORE}-private.id`
else
    message "ROLLBACK DIRECTORY NOT FOUND"
fi

message "DONE"
exit 0
