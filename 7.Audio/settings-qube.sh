#!/bin/sh

# Input and output sound volume in the range of 5-100.
INITIAL_INPUT_VOLUME="100"
INITIAL_OUTPUT_VOLUME="50"

# Non-empty variables will unmute mic/sound on qube start.
# Strongly suggested not to change this setting in case you suspect you might
# become a victim of a targeted attack. Sound output is one of the possible
# information leak channels.
INITIAL_INPUT_UNMUTE=""
INITIAL_OUTPUT_UNMUTE=""
