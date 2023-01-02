#!/bin/sh

. ../.lib/lib.sh
. ./settings-installer.sh

#set -x

message "DELETE ${YELLOW}MAIL QUBES"
qvm-shutdown --quiet --wait --force "${VM_GETMAIL}" "${VM_SENDMAIL}" 2>/dev/null
vm_exists "${VM_GETMAIL}" && qvm-remove --force "${VM_GETMAIL}" 2>/dev/null
vm_exists "${VM_SENDMAIL}-ssh" && qvm-remove --force "${VM_SENDMAIL}" 2>/dev/null

message "CLEANUP ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "rm -rf /etc/protect/template.${VM_GETMAIL} 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm -rf /etc/protect/template.${VM_SENDMAIL} 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm -rf /etc/protect/whitelist.${VM_GETMAIL} 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm -rf /etc/protect/whitelist.${VM_SENDMAIL} 2>/dev/null 1>&2"
push_command "${VM_CORE}" "aptitude -q -y purge getmail msmtp"
qvm-shutdown --quiet --wait --force "${VM_CORE}" 2>/dev/null

message "CLEANUP ${YELLOW}${MAIL_QUBE}"
push_command "${MAIL_QUBE}" "rm -r /home/user/.mail 2>/dev/null" || true
qvm-shutdown --quiet --wait --force "${MAiL_QUBE}" 2>/dev/null

message "CLEANUP ${YELLOW}dom0"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Message" "${VM_GETMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Error" "${VM_GETMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_GETMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitPassword" "${VM_GETMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SignalMail" "${VM_GETMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.MailReceive" "dom0" "${VM_GETMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.MailDownload" "${MAIL_QUBE}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Message" "${VM_SENDMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Error" "${VM_SENDMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_SENDMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitPassword" "${VM_SENDMAIL}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.MailSend" "${MAIL_QUBE}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitGPG" "${MAIL_QUBE}"
rm -f ~/bin/lq-mail 2>/dev/null
systemctl --user stop liteqube-checkmail 2>/dev/null
systemctl --user disable liteqube-checkmail 2>/dev/null
sudo rm /lib/systemd/user/liteqube-checkmail.service
sudo rm -f /etc/qubes-rpc/liteqube.SignalMail 2>/dev/null

message "DONE"
exit 0
