#!/bin/bash


# Set to "True" if you will be connecting input devices to usb vm
USB_INPUT_DEVICES="True"

# Set to "True" to not require PCI device reset
USB_NO_STRICT_RESET="True"

# Set to "True" if you want to enable u2f and pkcs11
USB_SMARTCARD="True"

# Workaround for p11-glue client/server version mismatch
# typically it is not needed, but sometimes they break things and remote protocol stops working,
# so we fall back to ugly socket forwarding
PKCS11_SOCKET="True"

# sys-usb vm name
SYS_USB="sys-usb"

USB_VM_MEMORY=256

#
# Space-separated list of qubes having access to smartcards
QUBES_SMARTCARD_CLIENTS="personal work"
SMARTCARD_MODCONFIG="
disable-in: gnome-calculator gnome-terminal
#enable-in: openssh-agent
"

#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################


chmod +x ../.lib/lib.sh
. ../.lib/lib.sh
set -e

vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
vm_fail_if_missing "${VM_XORG}"

mkdir -p /tmp/liteqube-rollback.3
qvm-shutdown --force --wait "${VM_CORE}"
qvm-volume config "${VM_CORE}:root" revisions_to_keep 10
qvm-volume config "${VM_CORE}:private" revisions_to_keep 10
message "RECORDING SNAPSHOT FOR ${YELLOW}${VM_CORE}"
qvm-volume info "${VM_CORE}:root" revisions|tail -1 >"/tmp/liteqube-rollback.3/snapshot-${VM_CORE}-root.id"
qvm-volume info "${VM_CORE}:private" revisions|tail -1 >"/tmp/liteqube-rollback.3/snapshot-${VM_CORE}-private.id"
message "MAKING ${YELLOW}dom0${PREFIX} CONFIG BACKUPS"
[ ! -e /etc/qubes/policy.d/50-config-input.policy ] || cp /etc/qubes/policy.d/50-config-input.policy /tmp/liteqube-rollback.3/
[ ! -e /etc/qubes/policy.d/50-config-u2f.policy ] || cp /etc/qubes/policy.d/50-config-u2f.policy /tmp/liteqube-rollback.3/
cp ${LQ_POLICYFILE} /tmp/liteqube-rollback.3/

vm_create "${VM_USB}" dispvm
vm_configure ${VM_USB} hvm ${USB_VM_MEMORY} '' '' ''

message "STARTING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"


message "CONFIGURING ${YELLOW}${VM_CORE}"
push_command ${VM_CORE} "apt update" 
install_packages ${VM_CORE} usbguard qubes-usb-proxy
add_line "${VM_CORE}" "/etc/hosts" "127.0.1.1       ${VM_USB}"
push_files "${VM_CORE}"
for SERVICE in usbguard usbguard-dbus ; do
    push_command "${VM_CORE}" "systemctl stop ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
    push_command "${VM_CORE}" "systemctl disable ${SERVICE} >/dev/null 2>&1" >/dev/null 2>&1 || true
done


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
sudo qubes-dom0-update -y --console --show-output qubes-usb-proxy-dom0
setup_permissions "${VM_USB}" xorg
add_permission "SignalStorage" "${VM_USB}" "dom0" "allow"

if [ x"${USB_INPUT_DEVICES}" = x"True" ] ; then
    message "CONFIGURING USB INPUT IN ${YELLOW}${VM_CORE}"
    install_packages "${VM_CORE}" "qubes-input-proxy-sender"
    message "CONFIGURING USB INPUT IN ${YELLOW}dom0"
    sudo qubes-dom0-update --console --show-output -y qubes-input-proxy
else
    sudo rm -f /etc/qubes/policy.d/50-config-input.policy
fi

qvm-ls --class TemplateVM --fields NAME|tail -n +2|while read TEMPLATE; do
    push_command "${TEMPLATE}" "systemctl is-enabled qubes-ctappoxy@${SYS_USB}" && (
    echo "Found ctap proxy on ${TEMPLATE} to ${SYS_USB}, redirecting to ${VM_SC}";
    push_command "${TEMPLATE}" "systemctl disable qubes-ctappoxy@${SYS_USB}";
    push_command "${TEMPLATE}" "systemctl enable qubes-ctappoxy@${VM_SC}"; )
    qvm-shutdown --quiet --wait --force "${TEMPLATE}"
done

if [ x"${USB_SMARTCARD}" = x"True" ] ; then
    vm_exists "${VM_SC}" || ( vm_create "${VM_SC}" "dispvm" && vm_configure "${VM_SC}" "pvh" 256 '' '' )
    vm_fail_if_missing "${VM_SC}"
    install_packages "${VM_CORE}" p11-kit pcscd opensc opensc-pkcs11 gnutls-bin python3-fido2 qubes-ctap
    add_line "${VM_CORE}" "/usr/lib/systemd/system/pcscd.service" "WantedBy=smartcard.target"
    push_command "${VM_CORE}" "systemctl daemon-reload" 
    push_command "${VM_CORE}" "systemctl enable pcscd.service" 
    qvm-service -e ${VM_SC} liteqube-pkcs11
    for VM in ${QUBES_SMARTCARD_CLIENTS} ; do
        if ! vm_exists "${VM}" ; then
            message "QUBE ${YELLOW}${VM}${PREFIX} NOT FOUND, SKIPPING SMARTCARD SETUP FOR IT"
            continue
        fi
        add_permission "pkcs11" "${VM}" "${VM_SC}" "allow target=${VM_SC}"
    done
    message "INSTALLING ${YELLOW}p11-kit${PREFIX} TO TEMPLATES"
    sed -e "s/TARGET/${VM_SC}/" <"./files/remote-pkcs11.module.in" >"./files/remote-pkcs11.module"
    echo "${SMARTCARD_MODCONFIG}" >>"./files/remote-pkcs11.module"
    TEMPLATES_MODIFIED=""
    for VM in ${QUBES_SMARTCARD_CLIENTS} ; do
        vm_exists "${VM}" || continue
        qvm-service -e ${VM} remote-pkcs11
        qvm-service -e ${VM} qubes-ctapproxy
        TEMPLATE="$(vm_find_template "${VM}")"
        if ! echo "${TEMPLATES_MODIFIED}" | grep -qxF "${TEMPLATE}" ; then
            TEMPLATE_TYPE="$(vm_type "${TEMPLATE}")"
       	    case "${TEMPLATE_TYPE}" in
       	    debian)
       	        push_command "${TEMPLATE}" "apt-get install p11-kit ncat"
                push_command "${TEMPLATE}" "systemctl disable qubes-ctapproxy@${SYS_USB}"
                push_command "${TEMPLATE}" "systemctl enable qubes-ctapproxy@${VM_SC}"
                file_to_vm "./files/remote-pkcs11.module" "${TEMPLATE}" "/usr/share/p11-kit/modules/remote-pkcs11.module"
            ;;
            fedora)
                push_command "${TEMPLATE}" "dnf install qubes-ctap p11-kit nmap-ncat"
                push_command "${TEMPLATE}" "systemctl disable qubes-ctapproxy@${SYS_USB}"
                push_command "${TEMPLATE}" "systemctl enable qubes-ctapproxy@${VM_SC}"
                file_to_vm "./files/remote-pkcs11.module" "${TEMPLATE}" "/usr/share/p11-kit/modules/remote-pkcs11.module"
            ;;
            *)
                message "ERROR: DON'T KNOW HOW TO HANDLE ${YELLOW}${TEMPLATE_TYPE}"
            ;;
            esac
            qvm-shutdown --quiet --wait --force "${TEMPLATE}"
            TEMPLATES_MODIFIED="${TEMPLATES_MODIFIED}${ENTER}${TEMPLATE}"
        fi
    done
fi


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "RESTARTING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
sleep 3
push_command "${VM_CORE}" "rm -rf /rw/QUARANTINE >/dev/null 2>&1"
qvm-shutdown --quiet --wait --force "${VM_CORE}"


if vm_exists "${SYS_USB}" ; then
    message "ATTACHING ${YELLOW}${SYS_USB}${PREFIX} DEVICES TO ${YELLOW}${VM_USB}"
    qvm-shutdown --quiet --wait --force "${SYS_USB}"
    if [ x"${USB_NO_STRICT_RESET}" = x"True" ] ; then
        OPTIONS="--option no-strict-reset=true"
    fi
    qvm-pci list --assignments | grep "${SYS_USB}" | cut -f 1 -d " " | uniq| while read DEVICE ; do
        message "ATTACHING ${DEVICE}"
        qvm-pci attach "${VM_USB}" "${DEVICE}" --persistent ${OPTIONS} || true
    done

    message "STARTING ${YELLOW}${VM_USB}"
    qvm-prefs --set "${VM_USB}" autostart True
    qvm-prefs --default "${SYS_USB}" autostart
    sleep 5
    qvm-start --quiet --skip-if-running "${VM_USB}"
else
    if qvm-pci | grep "${VM_USB}" >/dev/null 2>&1 ; then
        message "STARTING ${YELLOW}${VM_USB}"
        qvm-prefs --set "${VM_USB}" autostart True
        qvm-start --quiet --skip-if-running "${VM_USB}" || true
    else
        message "NO DEVICES ATTACHED TO ${YELLOW}${VM_USB}${PREFIX}, PLEASE ATTACH AND START ${YELLOW}${VM_USB}"
    fi
fi

if [ -e "/etc/qubes/policy.d/50-config-input.policy" ] ; then
    replace_text dom0 "/etc/qubes/policy.d/50-config-input.policy" "${SYS_USB}" "${VM_USB}" 
else
    message "Input policy file not found!"
fi
if [ -e "/etc/qubes/policy.d/50-config-u2f.policy" ] ; then
    replace_text dom0 "/etc/qubes/policy.d/50-config-u2f.policy" "${SYS_USB}" "${VM_USB}"
else
    message "U2F policy file not found!"
fi
message "DONE!"
exit 0
