#!/bin/sh

# Can be one of 'ssh', 'ssh-dns' or 'ovpn'. Leave empty to not initialise vpn
# connection on qube start.
VPN_TYPE=""

# For 'ssh' and 'ssh-dns', private key from core-keys will be used.
# The following vars must be set:
#  SSH_USER: username
#  SSH_SERVER: server to connect to
#  SSH_PORT: port to connect to
SSH_USER=""
SSH_SERVER=""
SSH_PORT=""

# For 'ovpn', password will be fetched from core-keys. 'profile.zip' (where
# 'profile' is profile name as defined below) will be fetched from core-keys
# as well, unpacked and used for openvpn configuration.
# The following vars must be set:
#  OVPN_USER: username
#  OVPN_PROFILE: server to connect to
OVPN_USER=""
OVPN_PROFILE=""
