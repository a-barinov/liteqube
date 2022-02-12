#!/bin/sh

. ../.lib/lib.sh

qvm-shutdown --quiet --wait --force "${VM_VPN}-ssh"
qvm-remove --force "${VM_VPN}-ssh"
