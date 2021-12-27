#!/bin/bash

message "CONFIGURING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
push_command "${VM_CORE}" "mount / -o rw,remount"
push_custom_files "${VM_CORE}"


message "CONFIGURING ${YELLOW}dom0"
push_custom_files "dom0"
