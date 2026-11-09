#!/bin/sh


# Package to install in template vm for text editing
DEFAULT_EDITOR_PKG="vim"


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################

# dom0 changes:
# installs $VN_BASE template if missing
# creates $VM_CORE and VM_DVM templates
# creates $VM_XORG and VM_KEYS VMs
# installs lq-xterm command to ~/bin
# installs parted, gdisk, e2fsprogs
# creates liteqube polocy file in /etc/qubes/policy.d/

chmod +x ../.lib/lib.sh
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


vm_configure ${VM_CORE} 'pvh' 1024 '' ''

message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
setup_permissions "${VM_CORE}"
setup_permissions "${VM_XORG}"
setup_permissions "${VM_KEYS}"
setup_permissions "${VM_DVM}" "xorg"

[ -x /bin/zenity ] || sudo qubes-dom0-update -y --console --show-output zenity
dom0_command lq-xterm


message "STARTING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"


message "CONFIGURING ${YELLOW}${VM_CORE}${PREFIX} (2/2)"
push_command "${VM_CORE}" "mount / -o rw,remount"
push_command "${VM_CORE}" "sh -c \"rm -rf /root/*\""
#
# These to are needed to fix strange glitch of 4.3
push_command "${VM_CORE}" "apt update && apt -y upgrade"

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
push_command "${VM_CORE}" "apt-get -y install aptitude"

message "FILTERING PACKAGES INSTALLED IN ${YELLOW}${VM_CORE}"
install_packages ${VM_CORE} stterm fonts-terminus-otb haveged kmod localepurge parted qubes-vm-dependencies \
			     whiptail netcat-openbsd openssh-client ca-certificates x11-utils dbus-user-session \
			     vim-tiny qubes-core-agent-passwordless-root

push_command "${VM_CORE}" "apt-get -q -y remove apt-utils cpio cron cron-daemon-common debconf-i18n dirmngr eatmydata gnupg gnupg-l10n gpg gpg-agent gpgconf gpgsm ifupdown iputils-ping less libassuan9:amd64 libbpf1:amd64 libcap2-bin libeatmydata1:amd64 libencode-locale-perl libfdisk1:amd64 libfile-basedir-perl libfile-desktopentry-perl libfile-mimeinfo-perl libgcrypt20:amd64 libgnutls30t64:amd64 libgpg-error0:amd64 libidn2-0:amd64 libipc-system-simple-perl libjansson4:amd64 libksba8:amd64 libldap2:amd64 libmnl0:amd64 libnftables1:amd64 libnftnl11:amd64 libnpth0t64:amd64 libp11-kit0:amd64 libsasl2-2:amd64 libsasl2-modules-db:amd64 libtasn1-6:amd64 libtext-iconv-perl:amd64 libtirpc-common libtirpc3t64:amd64 liburi-perl libutempter0:amd64 libxtables12:amd64 logrotate nano pinentry-curses tasksel tasksel-data vim-tiny xbitmaps"

install_packages ${VM_CORE} ${DEFAULT_EDITOR_PKG}
# x11-server-utils depend on this, but we can still remove
push_command "${VM_CORE}" "apt-mark hold cpp cpp-14 cpp-x86-64-linux-gnu cpp-14-x86-64-linux-gnu"
push_command "${VM_CORE}" "dpkg -r --force-depends cpp cpp-14 cpp-x86-64-linux-gnu cpp-14-x86-64-linux-gnu"
push_command "${VM_CORE}" "aptitude -q -y purge dbus-x11"
push_command "${VM_CORE}" "aptitude -q -y full-upgrade"

message "ENABLING TEMPLATING SERVICE IN ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "systemctl enable liteqube-vm-template >/dev/null 2>&1" >/dev/null 2>&1


message "STOPPING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


message "INSTALLING PARTED AND GDISK TOOLS IN ${YELLOW}dom0"
[ -x /usr/sbin/parted ] || sudo qubes-dom0-update -y --console --show-output parted
[ -x /usr/sbin/gdisk ] || sudo qubes-dom0-update -y --console --show-output gdisk
[ -x /usr/sbin/e2fsck ] || sudo qubes-dom0-update -y --console --show-output e2fsprogs


VM_LVM="${VM_CORE//-/--}"

if [ x"${VM_CORE_CREATED}" = x"true" ] && [ -e "/dev/mapper/${VM_GROUP}--${VM_LVM}--root" ] ; then
    vm_resize_private ${VM_CORE} ${PRIVATE_DISK_MB}
    if [ x"${ROOT_DISK_MB}" != x"" ] && [ x"${ROOT_DISK_MB}" != x"0" ] ; then
        message "RESIZING ROOT FILESYSTEM OF ${YELLOW}${VM_CORE}"
        sudo kpartx -a "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
        sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--root3"
        sudo resize2fs "/dev/mapper/${VM_GROUP}--${VM_LVM}--root3" $(( ${ROOT_DISK_MB}-700 ))M
        sudo kpartx -d "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
        size_sect=$(( ((ROOT_DISK_MB - 300) * 1024 * 1024) / 512))
        start=$(sudo sfdisk -d "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"|tail -1|grep -oP 'start=\s*\K[0-9]+')
        echo "$start,$size_sect"|sudo sfdisk --no-reread -N 3 "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
        echo "y" | sudo lvresize -y -f "/dev/mapper/${VM_GROUP}--${VM_LVM}--root" -L ${ROOT_DISK_MB}M || true
        sudo sgdisk -e "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
        sudo kpartx -a "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
        sudo e2fsck -fy "/dev/mapper/${VM_GROUP}--${VM_LVM}--root3"
        sudo kpartx -d "/dev/mapper/${VM_GROUP}--${VM_LVM}--root"
    fi

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

vm_configure ${VM_DVM} 'pvh' 512 '' ''
qvm-prefs --quiet "${VM_DVM}" template_for_dispvms True
qvm-start --quiet --skip-if-running "${VM_DVM}" || true


if [ x"${VM_DVM_CREATED}" = x"true" ] ; then

    vm_resize_private ${VM_DVM} ${PRIVATE_DISK_MB}
    qvm-start --quiet --skip-if-running "${VM_DVM}" || true

fi


if ! vm_exists "${VM_XORG}" ; then
    message "CREATING ${YELLOW}${VM_XORG}"
    qvm-create --class DispVM --template "${VM_DVM}" --label "${COLOR_WORKERS}" "${VM_XORG}"
else
    message "VM ${YELLOW}${VM_XORG}${PREFIX} ALREADY EXISTS"
fi

vm_configure ${VM_XORG} 'pvh' 512 '' ''

if ! vm_exists "${VM_KEYS}" ; then
    message "CREATING ${YELLOW}${VM_KEYS}"
    qvm-create --class AppVM --template "${VM_CORE}" --label "${COLOR_WORKERS}" "${VM_KEYS}"
    VM_KEYS_CREATED="true"
else
    message "VM ${YELLOW}${VM_KEYS}${PREFIX} ALREADY EXISTS"
    VM_KEYS_CREATED="false"
fi


vm_configure ${VM_KEYS} 'pvh' 160 '' ''
qvm-start --quiet --skip-if-running "${VM_KEYS}"
sleep 3
push_command "${VM_KEYS}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_KEYS}"

if [ x"${VM_KEYS_CREATED}" = x"true" ] ; then

    vm_resize_private ${VM_KEYS} ${PRIVATE_DISK_MB}

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
