#!/bin/sh

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh

qvm-shutdown --quiet --wait --force "${VM_PRINT}"
qvm-remove --force "${VM_PRINT}"
