#!/bin/sh

SYS_NET="sys-net"
SYS_FIREWALL="sys-firewall"
. ../.lib/lib.sh

set -x

sudo mcedit /etc/yum.repos.d/qubes-dom0.repo
sudo mcedit /etc/yum.repos.d/qubes-templates.repo

qvm-shutdown --quiet --wait --force "${VM_UPDATE}"
qvm-shutdown --quiet --wait --force "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force "${VM_NET}"
qvm-shutdown --quiet --wait --force "${VM_FW_DVM}"
qvm-shutdown --quiet --wait --force "${VM_FW_BASE}"

qvm-start --quiet --skip-if-running "${SYS_FIREWALL}"
qubes-prefs --quiet --set default_netvm "${SYS_FIREWALL}"
qubes-prefs --quiet --set updatevm "${SYS_FIREWALL}"
qubes-prefs --quiet --set clockvm "${SYS_FIREWALL}"

qvm-prefs --set "${SYS_NET}" autostart True
qvm-prefs --set "${SYS_FIREWALL}" autostart True

sudo rm -rf "/etc/qubes-rpc/policy/qubes.UpdatesProxy"

qvm-remove --force "${VM_UPDATE}"
qvm-remove --force "${VM_FW_TOR}"
qvm-remove --force "${VM_TOR}"
qvm-remove --force "${VM_FW_NET}"
qvm-remove --force "${VM_NET}"
qvm-remove --force "${VM_FW_DVM}"
qvm-remove --force "${VM_FW_BASE}"
