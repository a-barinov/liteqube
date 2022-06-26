#!/bin/bash


# Space-separated list of qubes having access to printing
QUBES_ALLOWED_TO_PRINT="fedora-34 debian-11-minimal"

# PDF previewer package (and command)
PDF_PREVIEW="zathura-pdf-poppler"

# Space-separated list of printer drivers packages to install
PRINTER_DRIVERS=""


#########################################################################
#       Do not edit code below unless you know what you are doing       #
#########################################################################
. ../.lib/lib.sh
set -e


vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
vm_create "${VM_PRINT}" "dispvm"
vm_configure "${VM_PRINT}" "pvh" 1024 'fw-net' 'dom0'


message "CONFIGURING ${YELLOW}${VM_CORE}"
install_packages "${VM_CORE}" cups qubes-usb-proxy "${PDF_PREVIEW}" ${PRINTER_DRIVERS}
push_files "${VM_CORE}"


message "CONFIGURING ${YELLOW}cups"
message "PLEASE PUT:"
message "  - ${YELLOW}printers.conf${PREFIX} into ${YELLOW}files${PREFIX} folder"
message "  - any ppd files into ${YELLOW}files/ppd${PREFIX} folder"
message "PRESS ENTER WHEN READY"
read INPUT
[ -f "./files/printers.conf" ] && file_to_vm "./files/printers.conf" "${VM_CORE}" "/etc/cups/printers.conf"
for PPD in ./files/ppd/* ; do
    [ -f "${PPD}" ] || continue
    NAME="$(basename "${PPD}")"
    file_to_vm "${PPD}" "${VM_CORE}" "/etc/cups/ppd/${NAME}"
done


message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
add_permission "Message" "${VM_PRINT}" "dom0" "allow"
add_permission "Error" "${VM_PRINT}" "dom0" "allow"
add_permission "SplitXorg" "${VM_PRINT}" "dom0" "allow"
for VM in ${QQUBES_ALLOWED_TO_PRINT} ; do
    add_permission "PrintFile" "${VM}" "${VM_PRINT}" "ask,default_target=${VM_PRINT}"
done
dom0_install_command lq-printers
#TODO: create script for easy usb device sharing
#dom0_install_command lq-usb


message "INSTALLING ${YELLOW}cups-pdf${PREFIX} TO TEMPLATES"
TEMPLATES_MODIFIED=""
for VM in ${QUBES_ALLOWED_TO_PRINT} ; do
    TEMPLATE="$(vm_find_template "${VM}")"
    if ! echo "${TEMPLATES_MODIFIED}" | grep "^${VM}$$" >/dev/null 2>&1 ; then
        TEMPLATE_TYPE="$(vm_type "${TEMPLATE}")"
        case "${TEMPLATE_TYPE}" in
            debian)
                push_command "${TEMPLATE}" "apt-get install printer-driver-cups-pdf"
                push_command "${TEMPLATE}" "lpadmin -p Qubes_Printer -v cups-pdf:/ -E -P /usr/share/ppd/cups-pdf/CUPS-PDF_opt.ppd"
                push_command "${TEMPLATE}" "lpoptions -p Qubes_Printer -o PostProcessing=/usr/bin/liteqube-print"
                push_command "${TEMPLATE}" "lpadmin -d Qubes_Printer"
                file_to_vm "./files/liteqube-print" "${TEMPLATE}" "/usr/bin/liteqube-print"
                ;;
            fedora)
                push_command "${TEMPLATE}" "dnf install cups-pdf"
                push_command "${TEMPLATE}" "lpadmin -p Qubes_Printer -v cups-pdf:/ -E -P /usr/share/ppd/cupsfilters/Generic-PDF_Printer-PDF.ppd"
                push_command "${TEMPLATE}" "lpoptions -p Qubes_Printer -o PostProcessing=/usr/bin/liteqube-print"
                push_command "${TEMPLATE}" "lpadmin -d Qubes_Printer"
                file_to_vm "./files/liteqube-print" "${TEMPLATE}" "/usr/bin/liteqube-print"
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


message "DONE!"
exit 0
