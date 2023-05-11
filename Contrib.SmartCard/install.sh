#!/bin/bash


# Space-separated list of qubes having access to smartcards
QUBES_SMARTCARD_CLIENTS="Office Dev"
SMARTCARD_MODCONFIG="
#disable-in: gnome-calculator gnome-terminal
enable-in: openssh-agent
"

VM_SC=core-usb

#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################

chmod +x ../.lib/lib.sh
. ../.lib/lib.sh
set -e

vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"

message "CONFIGURING ${YELLOW}${VM_SC}"
vm_exists "${VM_SC}" || ( vm_create "${VM_SC}" "dispvm" && vm_configure "${VM_SC}" "pvh" 256 '' '' )

vm_fail_if_missing "${VM_SC}"

message "CONFIGURING ${YELLOW}${VM_CORE}"
install_packages "${VM_CORE}" p11-kit pcscd opensc opensc-pkcs11 qubes-u2f
push_files "${VM_CORE}"
push_command "${VM_CORE}" "systemctl daemon-reload" 
push_command "${VM_CORE}" "systemctl enable pcscd.service" 
push_command "${VM_CORE}" "systemctl enable liteqube-pkcs11.service"
qvm-service -e ${VM_SC} liteqube-pkcs11

message "CONFIGURING ${YELLOW}dom0"
sudo qubes-dom0-update --console --show-output qubes-u2f-dom0
push_files "dom0"
for VM in ${QUBES_SMARTCARD_CLIENTS} ; do
    add_permission "pkcs11" "${VM}" "${VM_SC}" "allow,target=${VM_SC}"
    # legacy non-litqube name here
    add_line dom0 "/etc/qubes-rpc/policy/u2f.Authenticate" "${VM} ${VM_SC} allow,user=root"
    add_line dom0 "/etc/qubes-rpc/policy/u2f.Register" "${VM} ${VM_SC} allow,user=root"
done
#dom0_install_command lq-smartcards

message "INSTALLING ${YELLOW}p11-kit${PREFIX} TO TEMPLATES"
TEMPLATES_MODIFIED=""
for VM in ${QUBES_SMARTCARD_CLIENTS} ; do
    qvm-service -e ${VM} remote-pkcs11
    qvm-service -e ${VM} qubes-u2f-proxy
    TEMPLATE="$(vm_find_template "${VM}")"
    if ! echo "${TEMPLATES_MODIFIED}" | grep "^${VM}$$" >/dev/null 2>&1 ; then
        TEMPLATE_TYPE="$(vm_type "${TEMPLATE}")"
        case "${TEMPLATE_TYPE}" in
            debian)
                push_command "${TEMPLATE}" "apt-get install p11-kit ncat"
                push_command "${TEMPLATE}" "systemctl enable qubes-u2fproxy@${VM_SC}"
		cp "./files/remote-pkcs11.module.in" "./files/remote-pkcs11.module"
		echo ${SMARTCARD_MODCONFIG} >>"./files/remote-pkcs11.module"
                file_to_vm "./files/remote-pkcs11.module" "${TEMPLATE}" "/usr/share/p11-kit/modules/remote-pkcs11.module"
                file_to_vm "./files/remote-pkcs11@.service" "${TEMPLATE}" "/lib/systemd/user/remote-pkcs11@.service"
                file_to_vm "./files/remote-pkcs11@.socket" "${TEMPLATE}" "/lib/systemd/user/remote-pkcs11@.socket"
                push_command "${TEMPLATE}" "systemctl enable --global remote-pkcs11@${VM_SC}.socket"
                ;;
            fedora)
                push_command "${TEMPLATE}" "dnf install p11-kit nmap-ncat"
                push_command "${TEMPLATE}" "systemctl enable qubes-u2fproxy@${VM_SC}"
                file_to_vm "./files/remote-pkcs11.module" "${TEMPLATE}" "/usr/share/p11-kit/modules/remote-pkcs11.module"
                file_to_vm "./files/remote-pkcs11@.service" "${TEMPLATE}" "/usr/lib/systemd/user/remote-pkcs11@.service"
                file_to_vm "./files/remote-pkcs11@.socket" "${TEMPLATE}" "/usr/lib/systemd/user/remote-pkcs11@.socket"
                push_command "${TEMPLATE}" "systemctl enable --global remote-pkcs11@${VM_SC}.socket"
                ;;
            *)
                message "ERROR: DON'T KNOW HOW TO HANDLE ${YELLOW}${TEMPLATE_TYPE}"
                ;;
        esac
        qvm-shutdown --quiet --wait --force "${TEMPLATE}"
        TEMPLATES_MODIFIED="${TEMPLATES_MODIFIED}${ENTER}${VM}"
    fi
done


message "CUSTOMISING INSTALLATION"
if [ -x ./custom/custom.sh ] ; then
    . ./custom/custom.sh
fi
message "DONE CUSTOMISING"


message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"

message "[RE-]STARTING ${YELLOW}${VM_SC}"
qvm-shutdown --quiet --wait --force "${VM_SC}"
qvm-start "${VM_SC}"

message "DONE!"
exit 0
