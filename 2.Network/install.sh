#!/bin/bash


# Set to "True" to use mirage-firewall for firewall vms
USE_MIRAGE="True"

# Set to "True" to use DispVM for NetVm
NETVM_DISPOSABLE="True"

# Space-separated list of package names [with network cards firmware] to install
FIRMWARE_PACKAGES="firmware-iwlwifi"

# Set to "True" to not require PCI device reset
NET_NO_STRICT_RESET="True"

# sys-net and sys-firewall vm names
SYS_NET="sys-net"
SYS_FIREWALL="sys-firewall"
SYS_WHONIX="sys-whonix"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


. ../.lib/lib.sh
set -e


if ! vm_exists "${VM_CORE}" ; then
    message "ERROR: ${YELLOW}${VM_CORE}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_DVM}" ; then
    message "ERROR: ${YELLOW}${VM_DVM}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_XORG}" ; then
    message "ERROR: ${YELLOW}${VM_XORG}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi
if ! vm_exists "${VM_KEYS}" ; then
    message "ERROR: ${YELLOW}${VM_DVM}${PREFIX} NOT FOUND, PLEASE RUN BASE INSTALL"
    exit 1
fi


message "CONFIGURING ${YELLOW}dom0"
push_from_dir "./default.first" "dom0"


message "CONFIGURING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_from_dir "./default.first" "${VM_CORE}"


if [ x"${USE_MIRAGE}" = x"True" ] ; then  # Mirage firewall

    message "INSTALLING MIRAGE-FIREWALL TO ${YELLOW}dom0"
    push_from_dir "./default.fw-mirage" "dom0"


    if vm_exists "${VM_FW_BASE}" ; then
        message "${YELLOW}${VM_FW_BASE}${PREFIX} ALREADY EXISTS"
    else
        message "CREATING ${YELLOW}${VM_FW_BASE}"
        qvm-create --quiet --class TemplateVM --label "${COLOR_TEMPLATE}" "${VM_FW_BASE}"
    fi
    message "CONFIGURING ${YELLOW}${VM_FW_BASE}"
    qvm-prefs --quiet --set "${VM_FW_BASE}" label "${COLOR_TEMPLATE}"
    qvm-prefs --quiet --set "${VM_FW_BASE}" kernel mirage-firewall
    qvm-prefs --quiet --set "${VM_FW_BASE}" maxmem 0
    qvm-prefs --quiet --set "${VM_FW_BASE}" memory 64
    qvm-prefs --quiet --set "${VM_FW_BASE}" vcpus 1
    qvm-prefs --quiet --set "${VM_FW_BASE}" virt_mode pvh
    VM_LVM="${VM_FW_BASE//-/--}"
    sudo lvresize -fn "/dev/mapper/qubes_dom0-vm--${VM_LVM}--root" -L 4M || true
    sudo lvresize -fn "/dev/mapper/qubes_dom0-vm--${VM_LVM}--private" -L 4M || true


    if ! vm_exists "${VM_FW_DVM}" ; then
        message "CREATING ${YELLOW}${VM_FW_DVM}"
        qvm-create --class AppVM --template "${VM_FW_BASE}" --label "${COLOR_WORKERS}" "${VM_FW_DVM}"
    else
        message "VM ${YELLOW}${VM_FW_DVM}${PREFIX} ALREADY EXISTS"
    fi

    message "CONFIGURING ${YELLOW}${VM_FW_DVM}"
    qvm-prefs --quiet --set "${VM_FW_DVM}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_DVM}" maxmem 0
    qvm-prefs --quiet --set "${VM_FW_DVM}" memory 64
    qvm-prefs --quiet --set "${VM_FW_DVM}" vcpus 1
    qvm-prefs --quiet --set "${VM_FW_DVM}" template_for_dispvms True
    qvm-prefs --quiet --set "${VM_FW_DVM}" virt_mode pvh
    VM_LVM="${VM_FW_DVM//-/--}"
    sudo lvresize -f "/dev/mapper/qubes_dom0-vm--${VM_LVM}--private" -L 4M || true


    if ! vm_exists "${VM_FW_NET}" ; then
        message "CREATING ${YELLOW}${VM_FW_NET}"
        qvm-create --class DispVM --template "${VM_FW_DVM}" --label "${COLOR_WORKERS}" "${VM_FW_NET}"
    else
        message "VM ${YELLOW}${VM_FW_NET}${PREFIX} ALREADY EXISTS"
    fi

    message "CONFIGURING ${YELLOW}${VM_FW_NET}"
    qvm-prefs --quiet --set "${VM_FW_NET}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_NET}" maxmem 0
    qvm-prefs --quiet --set "${VM_FW_NET}" memory 64
    qvm-prefs --quiet --set "${VM_FW_NET}" vcpus 1
    qvm-prefs --quiet --set "${VM_FW_NET}" provides_network True
    qvm-prefs --quiet --set "${VM_FW_NET}" virt_mode pvh


    if ! vm_exists "${VM_FW_TOR}" ; then
        message "CREATING ${YELLOW}${VM_FW_TOR}"
        qvm-create --class DispVM --template "${VM_FW_DVM}" --label "${COLOR_WORKERS}" "${VM_FW_TOR}"
    else
        message "VM ${YELLOW}${VM_FW_TOR}${PREFIX} ALREADY EXISTS"
    fi

    message "CONFIGURING ${YELLOW}${VM_FW_TOR}"
    qvm-prefs --quiet --set "${VM_FW_TOR}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_TOR}" maxmem 0
    qvm-prefs --quiet --set "${VM_FW_TOR}" memory 64
    qvm-prefs --quiet --set "${VM_FW_TOR}" vcpus 1
    qvm-prefs --quiet --set "${VM_FW_TOR}" provides_network True
    qvm-prefs --quiet --set "${VM_FW_TOR}" virt_mode pvh

else  # Plain linux firewall

    if ! vm_exists "${VM_FW_NET}" ; then
        message "CREATING ${YELLOW}${VM_FW_NET}"
        qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_FW_NET}"
    else
        message "VM ${YELLOW}${VM_FW_NET}${PREFIX} ALREADY EXISTS"
    fi

    message "CONFIGURING ${YELLOW}${VM_FW_NET}"
    qvm-prefs --quiet --set "${VM_FW_NET}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_NET}" maxmem 0
    qvm-prefs --quiet --set "${VM_FW_NET}" memory 512
    qvm-prefs --quiet --set "${VM_FW_NET}" vcpus 1
    qvm-prefs --quiet --set "${VM_FW_NET}" provides_network True
    #qvm-prefs --quiet --set "${VM_FW_NET}" guivm ''
    qvm-prefs --quiet --set "${VM_FW_NET}" audiovm ''


    if ! vm_exists "${VM_FW_TOR}" ; then
        message "CREATING ${YELLOW}${VM_FW_TOR}"
        qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_FW_TOR}"
    else
        message "VM ${YELLOW}${VM_FW_TOR}${PREFIX} ALREADY EXISTS"
    fi


    message "CONFIGURING ${YELLOW}${VM_FW_TOR}"
    qvm-prefs --quiet --set "${VM_FW_TOR}" label "${COLOR_WORKERS}"
    qvm-prefs --quiet --set "${VM_FW_TOR}" maxmem 0
    qvm-prefs --quiet --set "${VM_FW_TOR}" memory 512
    qvm-prefs --quiet --set "${VM_FW_TOR}" vcpus 1
    qvm-prefs --quiet --set "${VM_FW_TOR}" provides_network True
    #qvm-prefs --quiet --set "${VM_FW_TOR}" guivm ''
    qvm-prefs --quiet --set "${VM_FW_TOR}" audiovm ''


    message "CONFIGURING ${YELLOW}dom0"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_FW_NET} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_FW_NET} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_FW_NET} ${VM_XORG} allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_FW_TOR} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_FW_TOR} dom0 allow"
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_FW_TOR} ${VM_XORG} allow"


    message "CONFIGURING ${YELLOW}${VM_CORE}"
    push_from_dir "./default.fw-linux" "${VM_CORE}"

fi


if ! vm_exists "${VM_NET}" ; then
    message "CREATING ${YELLOW}${VM_NET}"
    if [ x"${NETVM_DISPOSABLE}" = x"True" ] ; then
        qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_NET}"
    else
        qvm-create --class AppVM --template "${VM_CORE}" --label "${COLOR_WORKERS}" "${VM_NET}"
        VM_NET_CREATED="true"
    fi
else
    message "VM ${YELLOW}${VM_USB}${PREFIX} ALREADY EXISTS"
    VM_NET_CREATED="false"
fi


message "CONFIGURING ${YELLOW}${VM_NET}"
qvm-prefs --quiet --set "${VM_NET}" maxmem 0
qvm-prefs --quiet --set "${VM_NET}" memory 512
qvm-prefs --quiet --set "${VM_NET}" netvm ''
#qvm-prefs --quiet --set "${VM_NET}" guivm ''
qvm-prefs --quiet --set "${VM_NET}" audiovm ''
qvm-prefs --quiet --set "${VM_NET}" vcpus 1
qvm-prefs --quiet --set "${VM_NET}" virt_mode hvm
qvm-prefs --quiet --set "${VM_NET}" provides_network True


message "READING ACCESSPOINTS FROM ${YELLOW}${SYS_NET}"
OLD_IFS="${IFS}"
IFS="
"
for FILE in $(push_command "${SYS_NET}" "ls -1 /etc/NetworkManager/system-connections/") ; do
    if [ -e "./files/AccessPoints/${FILE}" ] || [ -e "./files/AccessPoints-secure/${FILE}" ] ; then
        echo "Skipping "${FILE}""
    else
        echo "Fetching "${FILE}""
        push_command "${SYS_NET}" "cat '/etc/NetworkManager/system-connections/${FILE}'" > "./files/AccessPoints/${FILE}"
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
push_command "${VM_CORE}" "aptitude -q -y install network-manager python3-gi python3-dbus qubes-core-agent-network-manager qubes-core-agent-dom0-updates tor htpdate ${FIRMWARE_PACKAGES}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_NET}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_TOR}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_UPDATE}"
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
    add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitFile" "${VM_NET} ${VM_KEYS} allow"
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
    qvm-shutdown --quiet --wait --force "${VM_NET}"

    if [ x"${VM_NET_CREATED}" = x"true" ] ; then

        message "RESIZING PRIVATE FILESYSTEM OF ${YELLOW}${VM_NET}"
        VM_LVM="${VM_NET//-/--}"
        sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--private"
        sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" $(( ${PRIVATE_DISK_MB}-200 ))M
        sudo lvresize -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" -L ${PRIVATE_DISK_MB}M || true

        qvm-start --quiet --skip-if-running "${VM_NET}"
        push_command "${VM_NET}" "rm -rf /rw/QUARANTINE"
        sleep 3
        qvm-shutdown --quiet --wait --force "${VM_NET}"

    fi

fi
qvm-shutdown --quiet --wait --force "${VM_KEYS}"


message "DISABLING SERVICES IN ${YELLOW}${VM_CORE}"
for SERVICE in NetworkManager NetworkManager-wait-online qubes-firewall qubes-network-uplink qubes-network qubes-updates-proxy tinyproxy wpa_supplicant tor htpdate ; do
    push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
done
push_command "${VM_CORE}" "systemctl enable NetworkManager-dispatcher" >/dev/null 2>&1 || true
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "CONFIGURING ${YELLOW}dom0"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_NET} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_NET} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_NET} ${VM_XORG} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalWifi" "${VM_NET} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_TOR} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_TOR} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_TOR} ${VM_XORG} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SignalTor" "${VM_TOR} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.TorSetAP" "${VM_NET} ${VM_TOR} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.WifiRequestAP" "${VM_TOR} ${VM_NET} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_UPDATE} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_UPDATE} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_UPDATE} ${VM_XORG} allow"
dom0_command lq-connect


if vm_exists "${SYS_NET}" ; then
    message "ATTACHING ${YELLOW}${SYS_NET}${PREFIX} DEVICES TO ${YELLOW}${VM_NET}"
    qvm-shutdown --quiet --wait --force "${SYS_WHONIX}" 2>/dev/null || true
    qvm-shutdown --quiet --wait --force "${SYS_FIREWALL}" 2>/dev/null || true
    qvm-shutdown --quiet --wait --force "${SYS_NET}" 2>/dev/null || true
    if [ x"${NET_NO_STRICT_RESET}" = x"True" ] ; then
        OPTIONS="--option no-strict-reset=true"
    fi
    qvm-pci | grep "${SYS_NET}" | cut -c-12 | while read DEVICE ; do
        qvm-pci attach "${VM_NET}" "${DEVICE}" --persistent ${OPTIONS} || true
    done
    message "CONFIIGURING ${YELLOW}${VM_NET}"
    qvm-prefs --set "${VM_NET}" autostart True
    qvm-prefs --default "${SYS_NET}" autostart
    qvm-prefs --default "${SYS_FIREWALL}" autostart
else
    if qvm-pci | grep "${VM_NET}" >/dev/null 2>&1 ; then
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


message "CONFIGURING ${YELLOW}${VM_TOR}"
qvm-prefs --quiet --set "${VM_TOR}" maxmem 0
qvm-prefs --quiet --set "${VM_TOR}" memory 512
qvm-prefs --quiet --set "${VM_TOR}" netvm "${VM_FW_NET}"
#qvm-prefs --quiet --set "${VM_TOR}" guivm ''
qvm-prefs --quiet --set "${VM_TOR}" audiovm ''
qvm-prefs --quiet --set "${VM_TOR}" vcpus 1
qvm-prefs --quiet --set "${VM_TOR}" virt_mode pvh
qvm-prefs --quiet --set "${VM_TOR}" provides_network True
qvm-prefs --quiet --set "${VM_FW_TOR}" netvm "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-start --quiet --skip-if-running "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"

if [ x"${VM_TOR_CREATED}" = x"true" ] ; then

    message "RESIZING PRIVATE FILESYSTEM OF ${YELLOW}${VM_TOR}"
    VM_LVM="${VM_TOR//-/--}"
    sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--private"
    sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" $(( ${PRIVATE_DISK_MB}-200 ))M
    sudo lvresize -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" -L ${PRIVATE_DISK_MB}M || true

fi

qvm-start --quiet --skip-if-running "${VM_TOR}"
push_command "${VM_TOR}" "rm -rf /rw/QUARANTINE"
sleep 3
qvm-shutdown --quiet --wait --force "${VM_TOR}"


message "CONFIGURING ${YELLOW}dom0"
if vm_exists "${SYS_WHONIX}" ; then
    qvm-shutdown --quiet --wait --force "${SYS_WHONIX}"
    qvm-prefs --default "${SYS_WHONIX}" autostart
fi


if ! vm_exists "${VM_UPDATE}" ; then
    message "CREATING ${YELLOW}${VM_UPDATE}"
    qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_UPDATE}"
else
    message "VM ${YELLOW}${VM_UPDATE}${PREFIX} ALREADY EXISTS"
fi


message "CONFIGURING ${YELLOW}${VM_UPDATE}"
qvm-prefs --quiet --set "${VM_UPDATE}" maxmem 0
qvm-prefs --quiet --set "${VM_UPDATE}" memory 1024
qvm-prefs --quiet --set "${VM_UPDATE}" netvm "${VM_FW_TOR}"
#qvm-prefs --quiet --set "${VM_UPDATE}" guivm ''
qvm-prefs --quiet --set "${VM_UPDATE}" audiovm ''
qvm-prefs --quiet --set "${VM_UPDATE}" vcpus 2
qvm-prefs --quiet --set "${VM_UPDATE}" virt_mode pvh


message "CONFIGURING ${YELLOW}dom0"
sudo touch "/etc/qubes-rpc/policy/qubes.UpdatesProxy"
add_line dom0 "/etc/qubes-rpc/policy/qubes.UpdatesProxy" '\$type:TemplateVM \$default allow,target='"${VM_UPDATE}"
add_line dom0 "/etc/qubes-rpc/policy/qubes.UpdatesProxy" '\$anyvm \$anyvm deny'


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
push_from_dir "./default.torify" "${VM_CORE}"
IP="$(qvm-prefs ${VM_TOR} | grep '^ip ' | cut -c26-)"
replace_text "${VM_CORE}" "/etc/tor/torrc" "10.137.0.1" "${IP}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_UPDATE}"
qvm-shutdown --quiet --wait --force "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force "${VM_NET}"
qvm-start --quiet --skip-if-running "${VM_NET}"
sleep 60
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "aptitude update" || true
push_command "${VM_CORE}" "aptitude update" || true
push_command "${VM_TOR}" "rm -rf /rw/QUARANTINE"


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
qvm-shutdown --quiet --wait --force "${VM_UPDATE}"
qvm-shutdown --quiet --wait --force "${VM_FW_TOR}"
qvm-shutdown --quiet --wait --force "${VM_TOR}"
qvm-shutdown --quiet --wait --force "${VM_FW_NET}"
qvm-shutdown --quiet --wait --force "${VM_NET}"
qvm-prefs --quiet --set "${VM_FW_NET}" memory 128
qvm-prefs --quiet --set "${VM_FW_TOR}" memory 128
qvm-prefs --quiet --set "${VM_NET}" memory 192
qvm-prefs --quiet --set "${VM_TOR}" memory 144
qvm-start --quiet --skip-if-running "${VM_NET}"


message "DONE!"
exit 0
