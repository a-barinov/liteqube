#!/bin/sh

. ../.lib/lib.sh
set -x

qvm-shutdown --quiet --wait --force "${VM_AUDIO}" 2>/dev/null
qvm-remove --force "${VM_AUDIO}" 2>/dev/null

sudo rm -f /etc/qubes-rpc/policy/admin.Events 2>/dev/null
sudo rm -f /etc/qubes-rpc/policy/admin.Events 2>/dev/null
sudo rm -f /etc/qubes-rpc/policy/admin.vm.List 2>/dev/null
sudo rm -f /etc/qubes-rpc/policy/admin.vm.feature.CheckWithTemplate 2>/dev/null
sudo rm -f /etc/qubes-rpc/policy/admin.property.Get 2>/dev/null
sudo rm -f /etc/qubes-rpc/policy/admin.property.GetAll 2>/dev/null

rm -f ~/bin/lq-volume 2>/dev/null
