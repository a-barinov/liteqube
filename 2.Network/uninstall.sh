#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh
SYS_NET="sys-net"
SYS_FIREWALL="sys-firewall"

#sudo cp ./qubes-dom0.repo /etc/yum.repos.d
#sudo vi /etc/yum.repos.d/qubes-templates.repo

qvm-shutdown --quiet --wait --force "${VM_UPDATE}"
qvm-shutdown --quiet --wait --force "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force "${VM_NET}"
qvm-shutdown --quiet --wait --force "${VM_FW_DVM}"
qvm-shutdown --quiet --wait --force "${VM_FW_BASE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"

qvm-start --quiet --skip-if-running "${SYS_FIREWALL}"
qubes-prefs --quiet --set default_netvm "${SYS_FIREWALL}"
qubes-prefs --quiet --set updatevm "${SYS_WHONIX}"
qubes-prefs --quiet --set clockvm "${SYS_FIREWALL}"

qvm-prefs --set "${SYS_NET}" autostart True
qvm-prefs --set "${SYS_FIREWALL}" autostart True

if [ -d /tmp/liteqube-rollback.2 ] ; then
    [ ! -e /tmp/liteqube-rollback.2/50-config-updates.policy ] || sudo cp /tmp/liteqube-rollback.2/50-config-updates.policy /etc/qubes/policy.d/
    sudo cp /tmp/liteqube-rollback.2/40-config-liteqube.policy /etc/qubes/policy.d/
    qubes-prefs --quiet --set updatevm `cat /tmp/liteqube-rollback.2/updatevm`
    sudo cp /tmp/liteqube-rollback.2/qubes-dom0.repo /etc/yum.repos.d
    qvm-volume revert "${VM_CORE}:root" `cat /tmp/liteqube-rollback.2/snapshot-${VM_CORE}-root.id`
    qvm-volume revert "${VM_CORE}:private" `cat /tmp/liteqube-rollback.2/snapshot-${VM_CORE}-private.id`
else
    message "ROLLBACK DIRECTORY NOT FOUND"
fi

qvm-remove --force "${VM_UPDATE}"
qvm-remove --force "${VM_FW_TOR}"
qvm-remove --force "${VM_TOR}"
qvm-remove --force "${VM_FW_NET}"
qvm-remove --force "${VM_NET}"
qvm-remove --force "${VM_FW_DVM}"
qvm-remove --force "${VM_FW_BASE}"
