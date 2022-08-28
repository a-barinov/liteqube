#!/bin/sh

# This si a smaple customisation file
# Adjust the script (or file to be pushed) as needed and
# make it executable to enable customisations during install

message "CUSTOMISING ${YELLOW}${VM_CORE}"
push_custom_files "${VM_CORE}"
