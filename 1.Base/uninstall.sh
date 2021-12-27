#!/bin/sh

. ../.lib/lib.sh

set -x

qvm-shutdown --quiet --wait --force "${VM_XORG}"
qvm-shutdown --quiet --wait --force "${VM_KEYS}"
qvm-shutdown --quiet --wait --force "${VM_DVM}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"

sudo rm -rf /etc/qubes-rpc/policy/liteqube.*
sudo rm -rf /etc/qubes-rpc/liteqube.*
sudo rm -rf ~/bin/lq-*

qvm-remove --force "${VM_XORG}"
qvm-remove --force "${VM_KEYS}"
qvm-remove --force "${VM_DVM}"
qvm-remove --force "${VM_CORE}"
