#!/bin/sh


# Package to install in template vm for text editing
DEFAULT_EDITOR_PKG="nano"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


. ../.lib/lib.sh
set -e


if ! vm_exists "${VM_CORE}" ; then
    if ! vm_exists "${VM_BASE}" ; then
        message "INSTALLING ${YELLOW}${VM_BASE}"
        sudo qvm-template --enablerepo qubes-templates-itl-testing install ${VM_BASE}
    else
        message "VM ${YELLOW}${VM_BASE}${PREFIX} ALREADY INSTALLED"
    fi
    message "CREATING ${YELLOW}${VM_CORE}"
    qvm-clone --class TemplateVM "${VM_BASE}" "${VM_CORE}"
    VM_CORE_CREATED="true"
else
    message "VM ${YELLOW}${VM_CORE}${PREFIX} ALREADY EXISTS"
    VM_CORE_CREATED="false"
fi


message "CONFIGURING ${YELLOW}${VM_CORE}${PREFIX} (1/2)"
qvm-prefs --quiet --set "${VM_CORE}" label "${COLOR_TEMPLATE}"
qvm-prefs --quiet --set "${VM_CORE}" maxmem 0
qvm-prefs --quiet --set "${VM_CORE}" memory 1024
qvm-prefs --quiet --set "${VM_CORE}" netvm ''
qvm-prefs --quiet --set "${VM_CORE}" audiovm ''
qvm-prefs --quiet --set "${VM_CORE}" vcpus 1


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_CORE} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_CORE}1 dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_DVM} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_XORG} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Message" "${VM_KEYS} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_CORE} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_CORE}1 dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_DVM} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_XORG} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.Error" "${VM_KEYS} dom0 allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_DVM} ${VM_XORG} allow"
add_line dom0 "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_KEYS} ${VM_XORG} allow"
[ -x /bin/zenity ] || sudo qubes-dom0-update --console --show-output zenity
dom0_command lq-xterm


message "STARTING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"


message "CONFIGURING ${YELLOW}${VM_CORE}${PREFIX} (2/2)"
push_command "${VM_CORE}" "mount / -o rw,remount"
push_command "${VM_CORE}" "sh -c \"rm -rf /root/*\""
push_files "${VM_CORE}"
push_command "${VM_CORE}" "usermod -a -G qubes user"
push_command "${VM_CORE}" "rm -rf /home.orig"
push_command "${VM_CORE}" "rm -rf /usr/local.orig"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_CORE}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_DVM}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_XORG}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_KEYS}"


message "RESTARTING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
push_command "${VM_CORE}" "mount / -o rw,remount"


message "FILTERING PACKAGES INSTALLED IN ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "apt-get -q -y update"
push_command "${VM_CORE}" "apt-get -q -y install aptitude stterm fonts-terminus-otb"
push_command "${VM_CORE}" "DEBIAN_FRONTEND=noninteractive aptitude -q -y install haveged kmod localepurge parted qubes-vm-dependencies whiptail netcat-openbsd openssh-client ca-certificates x11-utils"
push_command "${VM_CORE}" "aptitude -q -y unhold '~i'"
push_command "${VM_CORE}" "aptitude -q -y unmarkauto aptitude haveged kmod localepurge parted qubes-vm-dependencies stterm whiptail fonts-terminus-otb netcat-openbsd ca-certificates x11-utils"
push_command "${VM_CORE}" "aptitude -q -y markauto '~sadmin !( aptitude | kmod | localepurge | parted | qubes-vm-dependencies )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y markauto '~sfonts !( fonts-terminus-otb )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y markauto '~smisc !( haveged | ca-certificates )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y markauto '~snet !( netcat-openbsd | openssh-client )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y markauto '~sutils !( whiptail )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y markauto '~sx11 !( stterm | x11-utils )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y markauto '( ~seditors | ~sinterpreters | ~slibs | ~slocalization | ~smetapackages | ~sperl | ~sshells | ~stext )'"
push_command "${VM_CORE}" "aptitude -q -y install"
push_command "${VM_CORE}" "aptitude -q -y install dbus-user-session ${DEFAULT_EDITOR_PKG}"
push_command "${VM_CORE}" "aptitude -q -y purge dbus-x11"
push_command "${VM_CORE}" "aptitude -q -y full-upgrade"


message "ENABLING TEMPLATING SERVICE IN ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "systemctl enable liteqube-vm-template >/dev/null 2>&1" >/dev/null 2>&1


message "STOPPING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "INSTALLING PARTED AND GDISK TOOLS IN ${YELLOW}dom0"
[ -x /usr/sbin/parted ] || sudo qubes-dom0-update --console --show-output parted
[ -x /usr/sbin/gdisk ] || sudo qubes-dom0-update --console --show-output gdisk


if [ x"${VM_CORE_CREATED}" = x"true" ] ; then

    message "RESIZING PRIVATE FILESYSTEM OF ${YELLOW}${VM_CORE}"
    VM_LVM="${VM_CORE//-/--}"
    sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--private"
    sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" $(( ${PRIVATE_DISK_MB}-200 ))M
    sudo lvresize -y -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" -L ${PRIVATE_DISK_MB}M || true


    message "RESIZING ROOT FILESYSTEM OF ${YELLOW}${VM_CORE}"
    VM_LVM="${VM_CORE//-/--}"
    sudo kpartx -a "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
    sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--root3"
    sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--root3" $(( ${ROOT_DISK_MB}-700 ))M
    sudo kpartx -d "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
    sudo parted "/dev/mapper/${VM_GROUP}--${VM_LVM}--root" resizepart 3 $(( ${ROOT_DISK_MB}-300 ))M
    echo "y" | sudo lvresize -y -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--root" -L ${ROOT_DISK_MB}M || true
    echo -e "e\nr\ne\nY\nw\nY" | sudo gdisk "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
    sudo kpartx -a "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
    sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--root3"
    sudo kpartx -d "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"

fi


message "DELETING INSTALLATION FILES IN ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "mount / -o rw,remount"
push_command "${VM_CORE}" "rm -rf /lost+found"
push_command "${VM_CORE}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


if ! vm_exists "${VM_DVM}" ; then
    message "CREATING ${YELLOW}${VM_DVM}"
    qvm-create --class AppVM --template "${VM_CORE}" --label "${COLOR_WORKERS}" "${VM_DVM}"
    VM_DVM_CREATED="true"
else
    message "VM ${YELLOW}${VM_DVM}${PREFIX} ALREADY EXISTS"
    VM_DVM_CREATED="false"
fi


message "CONFIGURING ${YELLOW}${VM_DVM}"
qvm-prefs --quiet --set "${VM_DVM}" maxmem 0
qvm-prefs --quiet --set "${VM_DVM}" memory 512
qvm-prefs --quiet --set "${VM_DVM}" netvm ''
qvm-prefs --quiet --set "${VM_DVM}" audiovm ''
qvm-prefs --quiet --set "${VM_DVM}" vcpus 1
qvm-prefs --quiet "${VM_DVM}" template_for_dispvms True
qvm-start --quiet --skip-if-running "${VM_DVM}" || true


if [ x"${VM_DVM_CREATED}" = x"true" ] ; then

    message "RESIZING PRIVATE FILESYSTEM OF ${YELLOW}${VM_DVM}"
    qvm-start --quiet --skip-if-running "${VM_DVM}"
    qvm-shutdown --quiet --wait --force "${VM_DVM}"
    VM_LVM="${VM_DVM//-/--}"
    sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--private"
    sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" $(( ${PRIVATE_DISK_MB}-200 ))M
    sudo lvresize -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" -L ${PRIVATE_DISK_MB}M || true
    qvm-start --quiet --skip-if-running "${VM_DVM}" || true

fi


if ! vm_exists "${VM_XORG}" ; then
    message "CREATING ${YELLOW}${VM_XORG}"
    qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_XORG}"
else
    message "VM ${YELLOW}${VM_XORG}${PREFIX} ALREADY EXISTS"
fi


message "CONFIGURING ${YELLOW}${VM_XORG}"
qvm-prefs --quiet --set "${VM_XORG}" maxmem 0
qvm-prefs --quiet --set "${VM_XORG}" memory 512
qvm-prefs --quiet --set "${VM_XORG}" netvm ''
qvm-prefs --quiet --set "${VM_XORG}" audiovm ''
qvm-prefs --quiet --set "${VM_XORG}" vcpus 1


if ! vm_exists "${VM_KEYS}" ; then
    message "CREATING ${YELLOW}${VM_KEYS}"
    qvm-create --class AppVM --template "${VM_CORE}" --label "${COLOR_WORKERS}" "${VM_KEYS}"
    VM_KEYS_CREATED="true"
else
    message "VM ${YELLOW}${VM_KEYS}${PREFIX} ALREADY EXISTS"
    VM_KEYS_CREATED="false"
fi


message "CONFIGURING ${YELLOW}${VM_KEYS}"
qvm-prefs --quiet --set "${VM_KEYS}" maxmem 0
qvm-prefs --quiet --set "${VM_KEYS}" memory 128
qvm-prefs --quiet --set "${VM_KEYS}" netvm ''
#qvm-prefs --quiet --set "${VM_KEYS}" guivm ''
qvm-prefs --quiet --set "${VM_KEYS}" audiovm ''
qvm-prefs --quiet --set "${VM_KEYS}" vcpus 1
qvm-start --quiet --skip-if-running "${VM_KEYS}"
sleep 3
push_command "${VM_KEYS}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_KEYS}"

if [ x"${VM_KEYS_CREATED}" = x"true" ] ; then

    message "RESIZING PRIVATE FILESYSTEM OF ${YELLOW}${VM_KEYS}"
    qvm-start --quiet --skip-if-running "${VM_KEYS}"
    qvm-shutdown --quiet --wait --force "${VM_KEYS}"
    VM_LVM="${VM_KEYS//-/--}"
    sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--private"
    sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" $(( ${PRIVATE_DISK_MB}-200 ))M
    sudo lvresize -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--private" -L ${PRIVATE_DISK_MB}M || true

fi

qvm-start --quiet --skip-if-running "${VM_KEYS}"
sleep 3
push_command "${VM_KEYS}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_KEYS}"



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


message "DONE!"
exit 0
