#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh

qvm-shutdown --quiet --wait --force "${VM_RDP}"
qvm-remove --force "${VM_RDP}"
