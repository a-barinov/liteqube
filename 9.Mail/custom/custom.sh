#!/bin/sh

message "CUSTOMISING ${YELLOW}dom0"
push_custom_files "dom0"

message "CUSTOMISING ${YELLOW}${VM_CORE}"
push_custom_files "${VM_CORE}"
