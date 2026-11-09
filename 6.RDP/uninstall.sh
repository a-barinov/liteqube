#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh

if [ -d /tmp/liteqube-rollback.6 ] ; then
    message "ROLLBACK DIRECTORY FOUND, RESTORING STATE"
    qvm-shutdown --force --wait ${VM_CORE}
    sudo cp /tmp/liteqube-rollback.6/40-config-liteqube.policy /etc/qubes/policy.d/
    qvm-volume revert "${VM_CORE}:root" `cat /tmp/liteqube-rollback.6/snapshot-${VM_CORE}-root.id`
    qvm-volume revert "${VM_CORE}:private" `cat /tmp/liteqube-rollback.6/snapshot-${VM_CORE}-private.id`
else
    message "ROLLBACK DIRECTORY NOT FOUND"
fi

qvm-shutdown --quiet --wait --force "${VM_RDP}"
qvm-remove --force "${VM_RDP}"
