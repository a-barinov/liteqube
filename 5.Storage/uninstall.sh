#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh

qvm-shutdown --quiet --wait --force "${VM_ISCSI}" 2>/dev/null
qvm-shutdown --quiet --wait --force "${VM_DECRYPT}" 2>/dev/null

qvm-remove --force "${VM_ISCSI}" 2>/dev/null
qvm-remove --force "${VM_DECRYPT}" 2>/dev/null
