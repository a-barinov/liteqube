#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh
SYS_USB="sys-usb"

qvm-shutdown --quiet --wait --force "${VM_USB}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"

qvm-start --quiet --skip-if-running "${SYS_USB}"
qvm-prefs --set "${SYS_USB}" autostart True
qvm-prefs --set "${SYS_USB}" autostart True

if [ -d /tmp/liteqube-rollback.3 ] ; then
    [ ! -e /tmp/liteqube-rollback.3/50-config-input.policy ] || sudo cp /tmp/liteqube-rollback.3/50-config-input.policy /etc/qubes/policy.d/
    [ ! -e /tmp/liteqube-rollback.3/50-config-u2f.policy ] || sudo cp /tmp/liteqube-rollback.3/50-config-u2f.policy /etc/qubes/policy.d/
    sudo cp /tmp/liteqube-rollback.3/40-config-liteqube.policy /etc/qubes/policy.d/
    qvm-volume revert "${VM_CORE}:root" `cat /tmp/liteqube-rollback.3/snapshot-${VM_CORE}-root.id`
    qvm-volume revert "${VM_CORE}:private" `cat /tmp/liteqube-rollback.3/snapshot-${VM_CORE}-private.id`
else
    message "ROLLBACK DIRECTORY NOT FOUND"
fi

for POLICY in /etc/qubes/policy.d/50-config-input.policy /etc/qubes/policy.d/50-config-u2f.policy ; do
    [ ! -e "${POLICY}" ] || sudo sed -i "s/${VM_USB}/${SYS_USB}/g" "${POLICY}"
done
qvm-remove --force "${VM_USB}"
