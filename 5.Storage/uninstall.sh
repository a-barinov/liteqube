#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh

qvm-shutdown --quiet --wait --force "${VM_ISCSI}" 2>/dev/null
qvm-shutdown --quiet --wait --force "${VM_DECRYPT}" 2>/dev/null

qvm-remove --force "${VM_ISCSI}" 2>/dev/null
qvm-remove --force "${VM_DECRYPT}" 2>/dev/null

if [ -d /tmp/liteqube-rollback.5 ] ; then
    message "ROLLBACK DIRECTORY FOUND, RESTORING STATE"
    qvm-shutdown --force --wait ${VM_CORE}
    sudo cp /tmp/liteqube-rollback.5/40-config-liteqube.policy /etc/qubes/policy.d/
    qvm-volume revert "${VM_CORE}:root" `cat /tmp/liteqube-rollback.5/snapshot-${VM_CORE}-root.id`
    qvm-volume revert "${VM_CORE}:private" `cat /tmp/liteqube-rollback.5/snapshot-${VM_CORE}-private.id`
else
    message "ROLLBACK DIRECTORY NOT FOUND"
fi
