#!/bin/bash

# Support wireless
NETVM_WIFI="True"

# Set to "True" to use mirage-firewall for firewall vms
USE_MIRAGE="True"
MIRAGE_RELEASE="v0.9.5"
MIRAGE_URL="https://github.com/mirage/qubes-mirage-firewall/releases/download/"
MIRAGE_MEM=64

# Set to "True" to use DispVM for NetVm
NETVM_DISPOSABLE="True"

# Space-separated list of package names [with network cards firmware] to install
FIRMWARE_PACKAGES="firmware-iwlwifi"

# Net vm memory in Mb. Default works fine for intel drivers but you may need to allocate
# more memory if net qube crashes or hangs on start.
# To my exeperience, even if you see plenty of available memory inside the Qube, anything below 384Mb
# may give you random glitches on RPC calls.
#
TOR_VM_MEMORY="256"
NET_VM_MEMORY="384"
FW_VM_MEMORY="184"

# Set to "True" to not require PCI device reset
NET_NO_STRICT_RESET="True"

# Set to "True" if you need to run network diagnostics
#NET_DEBUG="True"

# sys-net and sys-firewall vm names
SYS_NET="sys-net"
SYS_FIREWALL="sys-firewall"
SYS_WHONIX="sys-whonix"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################

# TODO: all firewall VMs are alike, make a function to create them

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh
set -e

vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
vm_fail_if_missing "${VM_XORG}"
vm_fail_if_missing "${VM_KEYS}"

mkdir -p /tmp/liteqube-rollback.2
qvm-shutdown --force --wait "${VM_CORE}"
qvm-volume config "${VM_CORE}:root" revisions_to_keep 10
qvm-volume config "${VM_CORE}:private" revisions_to_keep 10
message "RECORDING SNAPSHOT FOR ${YELLOW}${VM_CORE}"
qvm-volume info "${VM_CORE}:root" revisions|tail -1 >"/tmp/liteqube-rollback.2/snapshot-${VM_CORE}-root.id"
qvm-volume info "${VM_CORE}:private" revisions|tail -1 >"/tmp/liteqube-rollback.2/snapshot-${VM_CORE}-private.id"
message "MAKING ${YELLOW}dom0 ${PREFIX}CONFIG BACKUPS"
qubes-prefs --quiet --get updatevm >/tmp/liteqube-rollback.2/updatevm
cp ${LQ_POLICYFILE} /tmp/liteqube-rollback.2/
[ ! -e /etc/qubes/policy.d/50-config-updates.policy ] || cp /etc/qubes/policy.d/50-config-updates.policy /tmp/liteqube-rollback.2/
cp /etc/yum.repos.d/qubes-dom0.repo /tmp/liteqube-rollback.2
cp /etc/dnf/dnf.conf /tmp/liteqube-rollback.2

message "CONFIGURING ${YELLOW}dom0"
push_from_dir "./default.first" "dom0"


message "CONFIGURING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_from_dir "./default.first" "${VM_CORE}"


if [ x"${USE_MIRAGE}" = x"True" ] ; then  # Mirage firewall

    if [[ -e /var/lib/qubes/vm-kernels/mirage-firewall/vmlinuz ]] ; then
        message "MIRAGE-FIREWALL ALREADY INSTALLED IN dom0"
    else
        message "DOWNLOADING MIRAGE-FIREWALL"
        dom0_download "${MIRAGE_URL}/${MIRAGE_RELEASE}/qubes-firewall.xen" \
                      "./default.fw-mirage/dom0/var/lib/qubes/vm-kernels/mirage-firewall/vmlinuz" \
                      "${MIRAGE_URL}/${MIRAGE_RELEASE}/qubes-firewall-release.sha256"
        message "INSTALLING MIRAGE-FIREWALL TO ${YELLOW}dom0"
        push_from_dir "./default.fw-mirage" "dom0"
    fi
    if vm_exists "${VM_FW_BASE}" ; then
        message "${YELLOW}${VM_FW_BASE}${PREFIX} ALREADY EXISTS"
    else
        message "CREATING ${YELLOW}${VM_FW_BASE}"
        qvm-create --quiet --class TemplateVM --label "${COLOR_TEMPLATE}" "${VM_FW_BASE}"
    fi
    vm_configure ${VM_FW_BASE} pvh ${MIRAGE_MEM} "" ""
    qvm-prefs --quiet --set "${VM_FW_BASE}" label "${COLOR_TEMPLATE}"
    qvm-prefs --quiet --set "${VM_FW_BASE}" kernel mirage-firewall
    qvm-prefs --quiet --set "${VM_FW_BASE}" kernelopts ""
    qvm-features "${VM_FW_BASE}" no-default-kernelopts 1
    qvm-features "${VM_FW_BASE}" qubes-firewall 1
    qvm-features "${VM_FW_BASE}" skip-update 1
    VM_LVM="${VM_FW_BASE//-/--}"
    sudo lvresize -fn "/dev/mapper/qubes_dom0-vm--${VM_LVM}--root" -L 4M || true
    sudo lvresize -fn "/dev/mapper/qubes_dom0-vm--${VM_LVM}--private" -L 4M || true


    if ! vm_exists "${VM_FW_DVM}" ; then
        message "CREATING ${YELLOW}${VM_FW_DVM}"
        qvm-create --class AppVM --template "${VM_FW_BASE}" --label "${COLOR_WORKERS}" "${VM_FW_DVM}"
    else
        message "VM ${YELLOW}${VM_FW_DVM}${PREFIX} ALREADY EXISTS"
    fi


    vm_configure ${VM_FW_DVM} pvh ${MIRAGE_MEM} "" ""
    qvm-prefs --quiet --set "${VM_FW_DVM}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_DVM}" template_for_dispvms True
    VM_LVM="${VM_FW_DVM//-/--}"
    sudo lvresize -f "/dev/mapper/qubes_dom0-vm--${VM_LVM}--private" -L 4M || true


    if ! vm_exists "${VM_FW_NET}" ; then
        message "CREATING ${YELLOW}${VM_FW_NET}"
        qvm-create --class DispVM --template "${VM_FW_DVM}" --label "${COLOR_WORKERS}" "${VM_FW_NET}"
    else
        message "VM ${YELLOW}${VM_FW_NET}${PREFIX} ALREADY EXISTS"
    fi

    vm_configure ${VM_FW_NET} pvh ${MIRAGE_MEM} "" ""
    qvm-prefs --quiet --set "${VM_FW_NET}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_NET}" provides_network True
    if cat /var/lib/qubes/vm-kernels/mirage-firewall/vmlinuz | grep Solo5 >/dev/null 2>&1 ; then
        qvm-prefs --quiet --set "${VM_FW_NET}" virt_mode pvh
    else
        qvm-prefs --quiet --set "${VM_FW_NET}" virt_mode pv
    fi

    if ! vm_exists "${VM_FW_TOR}" ; then
        message "CREATING ${YELLOW}${VM_FW_TOR}"
        qvm-create --class DispVM --template "${VM_FW_DVM}" --label "${COLOR_WORKERS}" "${VM_FW_TOR}"
    else
        message "VM ${YELLOW}${VM_FW_TOR}${PREFIX} ALREADY EXISTS"
    fi


    vm_configure ${VM_FW_TOR} pvh ${MIRAGE_MEM} "" ""
    qvm-prefs --quiet --set "${VM_FW_TOR}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_TOR}" provides_network True
    if cat /var/lib/qubes/vm-kernels/mirage-firewall/vmlinuz | grep Solo5 >/dev/null 2>&1 ; then
        qvm-prefs --quiet --set "${VM_FW_TOR}" virt_mode pvh
    else
        qvm-prefs --quiet --set "${VM_FW_TOR}" virt_mode pv
    fi

else  # Plain linux firewall

    vm_create "${VM_FW_NET}" "dispvm"
    vm_configure ${VM_FW_NET} pvh 384 "" ""
    qvm-prefs --quiet --set "${VM_FW_NET}" provides_network True

    vm_create "${VM_FW_TOR}" "dispvm"
    vm_configure ${VM_FW_TOR} pvh 384 "" ""
    qvm-prefs --quiet --set "${VM_FW_TOR}" provides_network True

    message "CONFIGURING ${YELLOW}dom0"
    setup_permissions "${VM_FW_NET}" xorg
    setup_permissions "${VM_FW_TOR}" xorg

    message "CONFIGURING ${YELLOW}${VM_CORE}"
    push_from_dir "./default.fw-linux" "${VM_CORE}"

fi


if ! vm_exists "${VM_NET}" ; then
    message "CREATING ${YELLOW}${VM_NET}"
    if [ x"${NETVM_DISPOSABLE}" = x"True" ] ; then
        vm_create "${VM_NET}" "dispvm"
    else
        vm_create "${VM_NET}" "appvm"
    fi
    VM_NET_CREATED="true"
else
    message "VM ${YELLOW}${VM_NET}${PREFIX} ALREADY EXISTS"
    VM_NET_CREATED="false"
fi


vm_configure ${VM_NET} hvm ${NET_VM_MEMORY} "" ""
qvm-prefs --quiet --set "${VM_NET}" provides_network True
# need to set this early, otherwise xen virtual bridge interfaces won't properly propagate
#
qvm-prefs --quiet --set "${VM_FW_NET}" netvm "${VM_NET}"


  
if [ x"${NETVM_WIFI}" = x"True" ] ; then

    message "READING ACCESSPOINTS FROM ${YELLOW}${SYS_NET}"
    OLD_IFS="${IFS}"
    IFS="
    "
    for FILE in $(push_command "${SYS_NET}" "ls -1 /etc/NetworkManager/system-connections/") ; do
     if [ -e "./files/AccessPoints/${FILE}" ] || [ -e "./files/AccessPoints-secure/${FILE}" ] ; then
            echo "Skipping "${FILE}""
         else
            echo "Fetching "${FILE}""
            push_command "${SYS_NET}" "cat '/etc/NetworkManager/system-connections/${FILE}'" |grep -v "^interface-name=" > "./files/AccessPoints/${FILE}"
            if grep "psk=" < "./files/AccessPoints/${FILE}" >/dev/null 2>&1 ; then
                 if ! [ -e "./files/AccessPoints-secure/${FILE}" ] ; then
                    echo "Safeguarding ${FILE}"
                    mv "./files/AccessPoints/${FILE}" "./files/AccessPoints-secure/"
                 fi
            fi
         fi
    done
    IFS="${OLD_IFS}"

    message "CONFIGURING ${YELLOW}${VM_CORE}"
    message "PLEASE PUT:"
    message "    ANY ADDITIONAL NETWORKMANAGER ACCESSPOINT FILES INTO ${YELLOW}files/AccessPoints${PREFIX} FOLDER"
    if [ x"${NETVM_DISPOSABLE}" = x"True" ] ; then
        message "    PUT NETWORKMANAGER ACCESSPOINT FILES CONTAINING PASSWORDS INTO ${YELLOW}files/AccessPoints-secure${PREFIX} FOLDER"
    fi
    message "    NETWORKMANAGER RANDOM SEED (512 BYTES) IN ${YELLOW}files/RandomSeed${PREFIX} FILE, SKIP FOR AUTO-GENERATION"
    message "    FIRMWARE IN ${YELLOW}files/Firmware${PREFIX} FOLDER IF NEEDED"
    message "PRESS ENTER WHEN READY"
    read INPUT
    qvm-start --quiet --skip-if-running "${VM_KEYS}"
    push_command "${VM_CORE}" "apt update && apt -y upgrade"
    install_packages ${VM_CORE} python3-gi python3-dbus network-manager wpasupplicant qubes-core-agent-dom0-updates tor apt-transport-tor htpdate tinyproxy qubes-core-agent-networking ${FIRMWARE_PACKAGES}
    for FW in ./files/Firmware/* ; do
        if [ -e "${FW}" ] ; then
            NAME="$(basename "${FW}")"
            push_command "${VM_CORE}" "mkdir /lib/firmware >/dev/null 2>&1 || true"
            file_to_vm "${FW}" "${VM_CORE}" "/lib/firmware/${NAME}"
        fi
    done
    if ! [ x"$(du -b ./files/RandomSeed | cut -f1)" = x"512" ] ; then
        dd if=/dev/urandom of=./files/RandomSeed bs=512 count=1
    fi
    if [ x"${NETVM_DISPOSABLE}" = x"True" ] ; then
        checksum_to_vm "./files/RandomSeed" "${VM_KEYS}" "/home/user/${VM_NET}/secret_key"
        push_from_dir "./default.net-dispvm" "${VM_CORE}"
        push_from_dir "./default.net-dispvm" "dom0"
        push_command "${VM_CORE}" "/usr/lib/qubes/qubes-fix-nm-conf.sh"
        for AP in ./files/AccessPoints/* ; do
            if [ -e "${AP}" ] ; then
                NAME="$(basename "${AP}")"
                file_to_vm "${AP}" "${VM_CORE}" "/etc/protect/template.${VM_NET}/bind-dirs/etc/NetworkManager/system-connections/${NAME}"
            fi
        done
        for AP in ./files/AccessPoints-secure/* ; do
            if [ -e "${AP}" ] ; then
                 NAME="$(basename "${AP}")"
                 checksum_to_vm "${AP}" "${VM_KEYS}" "/home/user/${VM_NET}/${NAME//[. ]/_}"
                 push_command "${VM_CORE}" "rm -f \"/etc/protect/template.${VM_NET}/bind-dirs/etc/NetworkManager/system-connections/${NAME}\" ; ln -s \"/run/liteqube/${NAME}\" \"/etc/protect/template.${VM_NET}/bind-dirs/etc/NetworkManager/system-connections/${NAME}\""
            fi
        done
        push_command "${VM_CORE}" "chmod 0600 /etc/NetworkManager/system-connections/* || true"
        push_command "${VM_CORE}" "chown -R user:user /etc/protect/checksum.${VM_KEYS}/home/user || true"
    else
        qvm-start --quiet --skip-if-running "${VM_NET}"
        sleep 3
        qvm-shutdown --quiet --wait --force "${VM_NET}"
        cat ./files/RandomSeed > "default.net-appvm/core-net/rw/bind-dirs/var/lib/NetworkManager/secret_key"
        sha256sum -b ./files/RandomSeed | cut -d' ' -f1 > "default.net-appvm/debian-core/etc/protect/checksum.core-net/bind-dirs/var/lib/NetworkManager/secret_key"
        sha512sum -b ./files/RandomSeed | cut -d' ' -f1 >> "default.net-appvm/debian-core/etc/protect/checksum.core-net/bind-dirs/var/lib/NetworkManager/secret_key"
        push_from_dir "./default.net-appvm" "${VM_CORE}"
        push_command "${VM_CORE}" "/usr/lib/qubes/qubes-fix-nm-conf.sh"
        qvm-start --quiet --skip-if-running "${VM_NET}"
        push_from_dir "./default.net-appvm" "${VM_NET}"
        push_command "${VM_NET}" "rm -rf /rw/QUARANTINE"
        push_command "${VM_NET}" "mkdir -p /rw/bind-dirs//etc/NetworkManager/system-connections || true"
        for AP in ./files/AccessPoints/* ; do
            if [ -e "${AP}" ] ; then
                NAME="$(basename "${AP}")"
                file_to_vm "${AP}" "${VM_NET}" "/rw/bind-dirs/etc/NetworkManager/system-connections/${NAME}"
            fi
        done
        for AP in ./files/AccessPoints-secure/* ; do
           if [ -e "${AP}" ] ; then
                NAME="$(basename "${AP}")"
                file_to_vm "${AP}" "${VM_NET}" "/rw/bind-dirs/etc/NetworkManager/system-connections/${NAME}"
           fi
        done
        push_command "${VM_NET}" "chmod 0600 /rw/bind-dirs/etc/NetworkManager/system-connections/* >/dev/null 2>&1"
        sleep 50
    fi
    push_command "${VM_CORE}" "systemctl enable NetworkManager-dispatcher" >/dev/null 2>&1 || true
else
    if [ x"${NETVM_DISPOSABLE}" = x"True" ] ; then
        push_from_dir "./default.wired-dispvm" "${VM_CORE}"
    else
        push_from_dir "./default.wired-appvm" "${VM_CORE}"
        qvm-start --quiet --skip-if-running "${VM_NET}"
        push_command "${VM_NET}" "rm -rf /rw/QUARANTINE"
    fi
    message "CONFIGURING ${YELLOW}${VM_CORE} for wired network"
    push_command "${VM_CORE}" "apt update && apt -y upgrade"
    install_packages ${VM_CORE} iproute2 libcap2-bin ifupdown2 isc-dhcp-client qubes-core-agent-networking python3-gi python3-dbus tinyproxy apt-transport-tor  qubes-core-agent-dom0-updates tor htpdate
fi

if [ x"${NET_DEBUG}" = x"True" ] ; then
    install_packages ${VM_CORE} tcpdump bind9-dnsutils iputils-ping traceroute ethtool
fi

add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_NET}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_TOR}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_UPDATE}"

qvm-shutdown --quiet --wait --force "${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_NET}"

if [ x"${VM_NET_CREATED}" = x"true" ]  && [ x"${NETVM_DISPOSABLE}" != x"True" ] ; then

    vm_resize_private ${VM_NET} ${PRIVATE_DISK_MB}
    qvm-start --quiet --skip-if-running "${VM_NET}"
    push_command "${VM_NET}" "rm -rf /rw/QUARANTINE"
    sleep 3
    qvm-shutdown --quiet --wait --force "${VM_NET}"
fi

qvm-shutdown --quiet --wait --force "${VM_KEYS}"

push_command "${VM_CORE}" "rm -rf /etc/network/interfaces.d ; ln -sf /run/interfaces.d /etc/network/interfaces.d"

message "DISABLING SERVICES IN ${YELLOW}${VM_CORE}"
for SERVICE in qubes-network-uplink qubes-network systemd-resolved qubes-updates-proxy tinyproxy wpa_supplicant tor htpdate ; do
    push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
done
push_command "${VM_CORE}" "systemctl enable qubes-firewall"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "CONFIGURING ${YELLOW}dom0"
setup_permissions "${VM_NET}" xorg file
add_permission "SignalWifi" "${VM_NET}" "dom0" "allow"
setup_permissions "${VM_TOR}" xorg
add_permission "SignalTor" "${VM_TOR}" "dom0" "allow"
add_permission "TorSetAP" "${VM_NET}" "${VM_TOR}" "allow"
add_permission "WifiRequestAP" "${VM_TOR}" "${VM_NET}" "allow"
setup_permissions "${VM_UPDATE}" xorg
dom0_command lq-connect


if vm_exists "${SYS_NET}" ; then
    message "ATTACHING ${YELLOW}${SYS_NET}${PREFIX} DEVICES TO ${YELLOW}${VM_NET}"
    qvm-shutdown --quiet --wait --force "${SYS_WHONIX}" 2>/dev/null || true
    qvm-shutdown --quiet --wait --force "${SYS_FIREWALL}" 2>/dev/null || true
    qvm-shutdown --quiet --wait --force "${SYS_NET}" 2>/dev/null || true
    if [ x"${NET_NO_STRICT_RESET}" = x"True" ] ; then
        OPTIONS="--option no-strict-reset=true"
    fi
    qvm-pci list --assignments | grep "${SYS_NET}" | cut -f 1 -d " " | uniq| while read DEVICE ; do
        message "ATTACHING ${DEVICE}"
        qvm-pci attach "${VM_NET}" "${DEVICE}" --persistent ${OPTIONS} || true
    done
    message "CONFIGURING ${YELLOW}${VM_NET}"
    qvm-prefs --set "${VM_NET}" autostart True
    qvm-prefs --default "${SYS_NET}" autostart
    qvm-prefs --default "${SYS_FIREWALL}" autostart
else
    if qvm-pci list --assignments| grep "${VM_NET}" >/dev/null 2>&1 ; then
        message "STARTING ${YELLOW}${VM_NET}"
        qvm-prefs --set "${VM_NET}" autostart True
        qvm-start --quiet --skip-if-running "${VM_NET}"
        push_command "${VM_NET}" "rm -rf /rw/QUARANTINE"
    else
        message "NO DEVICES ATTACHED TO ${YELLOW}${VM_NET}${PREFIX}, PLEASE ATTACH AND START ${YELLOW}${VM_NET} MANUALY"
    fi
fi


if ! vm_exists "${VM_TOR}" ; then
    message "CREATING ${YELLOW}${VM_TOR}"
    qvm-create --class AppVM --template "${VM_CORE}" --label "${COLOR_WORKERS}" "${VM_TOR}"
    VM_TOR_CREATED="true"
else
    message "VM ${YELLOW}${VM_TOR}${PREFIX} ALREADY EXISTS"
    VM_TOR_CREATED="false"
fi


vm_configure ${VM_TOR} pvh 512 ${VM_FW_NET} ""
qvm-prefs --quiet --set "${VM_TOR}" provides_network True
qvm-prefs --quiet --set "${VM_FW_TOR}" netvm "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-start --quiet --skip-if-running "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"

if [ x"${VM_TOR_CREATED}" = x"true" ] ; then

    vm_resize_private ${VM_TOR} ${PRIVATE_DISK_MB}

fi

qvm-start --quiet --skip-if-running "${VM_TOR}"
sleep 10 
push_command "${VM_TOR}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_TOR}"


message "CONFIGURING ${YELLOW}dom0"
if vm_exists "${SYS_WHONIX}" ; then
    qvm-shutdown --quiet --wait --force "${SYS_WHONIX}"
    qvm-prefs --default "${SYS_WHONIX}" autostart
fi

vm_create ${VM_UPDATE} dispvm
vm_configure ${VM_UPDATE} pvh 4096 ${VM_FW_TOR} ""
qvm-prefs --quiet --set "${VM_UPDATE}" vcpus 2
# Stupid but this is to keep qubes-global-config happy
qvm-prefs --quiet --set "${VM_UPDATE}" provides_network True

message "CONFIGURING ${YELLOW}dom0"
sudo truncate -s 0 "/etc/qubes/policy.d/50-config-updates.policy"
add_line dom0 "/etc/qubes/policy.d/50-config-updates.policy" "qubes.UpdatesProxy	*	@tag:whonix-updatevm	@default	allow target=${VM_UPDATE}"
add_line dom0 "/etc/qubes/policy.d/50-config-updates.policy" "qubes.UpdatesProxy	*	@type:TemplateVM	@default	allow target=${VM_UPDATE}"


message "SHUTTING DOWN NETWORK QUBES"
qvm-shutdown --quiet --wait --force "${SYS_FIREWALL}"
qvm-shutdown --quiet --wait --force "${SYS_NET}"
qvm-shutdown --quiet --wait --force "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force "${VM_NET}"
sleep 3


message "SETTING DEFAULT NETVM, CLOCKVM AND UPDATEVM"
qvm-prefs --quiet --set "${VM_FW_NET}" netvm "${VM_NET}"
qvm-start --quiet --skip-if-running "${VM_FW_NET}"
qubes-prefs --quiet --set default_netvm "${VM_FW_NET}"
qubes-prefs --quiet --set updatevm "${VM_UPDATE}"
qubes-prefs --quiet --set clockvm "${VM_TOR}"
dom0_command lq-update


message "TORIFYING ${YELLOW}dom0${PREFIX} UPDATES"
push_from_dir "./default.torify" "dom0"


message "TORIFYING ${YELLOW}${VM_CORE}${PREFIX} UPDATES"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "rm /etc/apt/sources.list.d/qubes-r4.list"
push_from_dir "./default.torify" "${VM_CORE}"
IP="$(qvm-prefs ${VM_TOR} | grep '^ip ' | cut -c26-)"
replace_text "${VM_CORE}" "/etc/tor/torrc" "512.512.512.512" "${IP}"
#add_line ${VM_CORE} "/etc/tinyproxy/tinyproxy-updates.conf" "Upstream socks5 ${IP}:9050"
add_line dom0 "/etc/dnf/dnf.conf" "proxy=socks5h://${IP}:9050"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_CORE}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_UPDATE}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_TOR}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_NET}"
qvm-start --quiet --skip-if-running "${VM_NET}"
sleep 60
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "aptitude update" || true
push_command "${VM_CORE}" "aptitude update" || true
push_command "${VM_TOR}" "rm -rf /rw/QUARANTINE"

qvm-service --enable whonix-workstation-18 skip-torified-updates-proxy-check
qvm-service --enable whonix-gateway-18 skip-torified-updates-proxy-check

message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
qvm-shutdown --quiet --wait --force "${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_CORE}"
message "DONE CUSTOMISING"


message "ADJUSTING MEMORY REQUIREMENTS"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_UPDATE}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_TOR}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force --timeout 60 "${VM_NET}"
if [ x"${USE_MIRAGE}" != x"True" ] ; then  
    qvm-prefs --quiet --set "${VM_FW_NET}" memory "${FW_VM_MEMORY}"
    qvm-prefs --quiet --set "${VM_FW_TOR}" memory "${FW_VM_MEMORY}"
fi
qvm-prefs --quiet --set "${VM_NET}" memory "${NET_VM_MEMORY}"
qvm-prefs --quiet --set "${VM_TOR}" memory "${TOR_VM_MEMORY}"
qvm-start --quiet --skip-if-running "${VM_NET}"
sleep 2
qvm-start --quiet --skip-if-running "${VM_FW_NET}"


# TODO recover Tor connection after sleep (adjust time)
# TODO terminate firewalls and tor after X minutes of having no clients connected
# TODO suggest saving AP on new connection


message "DONE!"
exit 0
