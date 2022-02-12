#!/bin/sh

message "CUSTOMISING ${YELLOW}dom0"
push_custom_files "dom0"

message "CUSTOMISING ${YELLOW}${VM_CORE}"
push_custom_files "${VM_CORE}"

message "PUSHING SSH KEYS TO ${YELLOW}${VM_KEYS}"
qvm-start --quiet --skip-if-running "${VM_KEYS}"
for FILE in ./custom/keys/* ; do
    checksum_to_vm "${FILE}" "${VM_KEYS}" "/home/user/.ssh/$(basename "$FILE")"
done
push_command "${VM_KEYS}" "chmod 0600 /home/user/.ssh/*"
push_command "${VM_KEYS}" "chown user:user /home/user/.ssh/*"
push_command "${VM_CORE}" "chmod 0600 /etc/protect/checksum.${VM_KEYS}/home/user/.ssh/*"
push_command "${VM_CORE}" "chown user:user /etc/protect/checksum.${VM_KEYS}/home/user/.ssh/*"
qvm-shutdown --quiet --wait --force "${VM_KEYS}"
