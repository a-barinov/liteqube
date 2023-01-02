#!/bin/sh


. ../.lib/lib.sh
. ./settings-installer.sh
set -e
#set -x


RETURN="
"

vm_fail_if_missing "${VM_CORE}"
vm_fail_if_missing "${VM_DVM}"
vm_fail_if_missing "${VM_KEYS}"

message "CONFIGURING ${YELLOW}${VM_CORE}"
qvm-start --quiet --skip-if-running "${VM_CORE}"
push_files "${VM_CORE}"
install_packages "${VM_CORE}" getmail msmtp
add_line "${VM_CORE}" "/etc/hosts" "127.0.0.1 ${VM_GETMAIL}"
add_line "${VM_CORE}" "/etc/hosts" "127.0.0.1 ${VM_SENDMAIL}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"

message "CONFIGURING ${YELLOW}dom0"
push_files "dom0"
add_permission "Message" "${VM_GETMAIL}" "dom0" "allow"
add_permission "Error" "${VM_GETMAIL}" "dom0" "allow"
add_permission "SplitXorg" "${VM_GETMAIL}" "${VM_XORG}" "allow"
add_permission "SplitPassword" "${VM_GETMAIL}" "${VM_KEYS}" "ask,default_target=${VM_KEYS}"
add_permission "SignalMail" "${VM_GETMAIL}" "dom0" "allow"
add_permission "MailReceive" "dom0" "${VM_GETMAIL}" "allow"
add_permission "MailDownload" "${MAIL_QUBE}" "${VM_GETMAIL}" "allow"
add_permission "Message" "${VM_SENDMAIL}" "dom0" "allow"
add_permission "Error" "${VM_SENDMAIL}" "dom0" "allow"
add_permission "SplitXorg" "${VM_SENDMAIL}" "${VM_XORG}" "allow"
add_permission "SplitPassword" "${VM_SENDMAIL}" "${VM_KEYS}" "ask,default_target=${VM_KEYS}"
add_permission "MailSend" "${MAIL_QUBE}" "${VM_SENDMAIL}" "ask,default_target=${VM_SENDMAIL}"
add_permission "SplitGPG" "${MAIL_QUBE}" "${VM_KEYS}" "ask,default_target=${VM_KEYS}"
dom0_install_command lq-mail
dom0_install_command lq-addkey
if [ -n "$MAIL_CHECK_INTERVAL" ] ; then
    cat "./dom0-scripts/liteqube-checkmail.service" | sed "s/XXX/$MAIL_CHECK_INTERVAL/g" | sudo tee /lib/systemd/user/liteqube-checkmail.service >/dev/null
    systemctl --user enable liteqube-checkmail 2>/dev/null
fi

vm_exists "${VM_GETMAIL}" && qvm-shutdown --quiet --wait --force "${VM_GETMAIL}" || ( vm_create "${VM_GETMAIL}" "appvm" ; VM_GETMAIL_CREATED="True" )
vm_configure "${VM_GETMAIL}" "pvh" 320 "${VM_FW_TOR}" ''
vm_exists "${VM_FW_TOR}"|| qvm-prefs --quiet --default "${VM_GETMAIL}" netvm
push_command "${VM_GETMAIL}" "rm -rf /rw/QUARANTINE"
push_files "${VM_GETMAIL}"
qvm-shutdown --quiet --wait --force "${VM_GETMAIL}"
[ -z "${VM_GETMAIL_CREATED}" ] || vm_resize_private "${VM_GETMAIL}" 512

for I in 1 2 3 4 5 6 7 8 9 10 ; do
    eval RECEIVER=\"\$RECEIVER_${I}\"
    [ -n "${RECEIVER}" ] || continue
    set -- junk ${RECEIVER}
    if [ -z "${2}" -o -z "${3}" -o -z "${4}" -o -z "${5}" -o -z "${6}" ] ; then
        message "RECEIVER_${1} has incorrect format"
        exit 1
    fi
    push_command "${VM_GETMAIL}" "mkdir /home/user/getmail/${2}" || true
    push_command "${VM_GETMAIL}" "chmod 0700 /home/user/getmail/${2}"
    echo "[retriever]${RETURN}type = Simple${5}Retriever${RETURN}server = ${3}${RETURN}port = ${4}${RETURN}username = ${6}${RETURN}password_command = ('cat',)${RETURN}${RETURN}[destination]${RETURN}type = Mboxrd${RETURN}path = /home/user/getmail/mailbox.mbox${RETURN}${RETURN}[options]${RETURN}verbose = 0${RETURN}read_all = True${RETURN}delete = False${RETURN}delivered_to = False${RETURN}" | \
    push_command "${VM_GETMAIL}" "tee -a '/home/user/getmail/${2}/getmailrc'" >/dev/null
    push_command "${VM_GETMAIL}" "chmod 0600 /home/user/getmail/${2}/getmailrc"
    push_command "${VM_GETMAIL}" "chown -R user:user /home/user/getmail/${2}"
done

push_command "${VM_GETMAIL}" "rm -rf /rw/QUARANTINE"
qvm-shutdown --quiet --wait --force "${VM_GETMAIL}"

vm_exists "${VM_SENDMAIL}" && qvm-shutdown --quiet --wait --force "${VM_SENDMAIL}" || vm_create "${VM_SENDMAIL}" "dispvm"
vm_configure "${VM_SENDMAIL}" "pvh" 256 "${VM_FW_TOR}" ''
vm_exists "${VM_FW_TOR}"|| qvm-prefs --quiet --default "${VM_SENDMAIL}" netvm

for I in 1 2 3 4 5 6 7 8 9 10 ; do
    eval SENDER=\"\$SENDER_${I}\"
    [ -n "${SENDER}" ] || continue
    set -- junk ${SENDER}
    if [ -z "${2}" -o -z "${3}" -o -z "${4}" -o -z "${5}" -o -z "${6}" ] ; then
        message "SENDER_${1} has incorrect format"
        exit 1
    fi
    echo "account ${2}${RETURN}host ${3}${RETURN}port ${4}${RETURN}auth on${RETURN}user ${5}${RETURN}from ${6}${RETURN}passwordeval /usr/bin/qrexec-client-vm core-keys liteqube.SplitPassword+${2}${RETURN}tls on${RETURN}tls_trust_file /etc/ssl/certs/ca-certificates.crt${RETURN}syslog on${RETURN}${RETURN}" | \
    push_command "${VM_CORE}" "tee -a '/etc/protect/template.core-sendmail/home/user/.msmtprc'" >/dev/null
done

message "CONFIGURING ${YELLOW}${MAIL_QUBE}"
qvm-start --quiet --skip-if-running "${MAIL_QUBE}"
push_command "${MAIL_QUBE}" "mkdir /home/user/.mail" || true
cat ./mail-scripts/lq-mailer | push_command "${MAIL_QUBE}" "tee -a /home/user/.mail/lq-mailer >/dev/null"
push_command "${MAIL_QUBE}" "chmod 0775 /home/user/.mail/lq-mailer"
push_command "${MAIL_QUBE}" "chown -R user:user /home/user/.mail"
qvm-shutdown --quiet --wait --force "${MAIL_QUBE}" 2>/dev/null

if [ -x ./custom/custom.sh ] ; then
    message "CUSTOMISING INSTALLATION"
    . ./custom/custom.sh
    message "DONE CUSTOMISING"
fi

message "TERMINATING ${YELLOW}${VM_CORE}"
qvm-shutdown --quiet --wait --force "${VM_CORE}"

message "DONE!"
exit 0
