#!/bin/sh

# Space-separated list of qubes having access to aoudio playback
QUBES_WITH_SOUND="core-rdp dvm-chrome dvm-chrome-tor my-games"

# Set to "True" to not require PCI device reset
AUDIO_NO_STRICT_RESET="True"

# Qube that currently provides audio service
ORIGINAL_VM_AUDIO="dom0"
