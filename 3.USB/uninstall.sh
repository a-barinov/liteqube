#!/bin/sh

SYS_USB="sys-usb"
. ../.lib/lib.sh

qvm-shutdown --quiet --wait --force "${VM_USB}"

qvm-start --quiet --skip-if-running "${SYS_USB}"
qvm-prefs --set "${SYS_USB}" autostart True
qvm-prefs --set "${SYS_USB}" autostart True

qvm-remove --force "${VM_USB}"
