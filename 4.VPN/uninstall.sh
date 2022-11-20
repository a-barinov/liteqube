#!/bin/sh

. ../.lib/lib.sh
. ./settings-installer.sh
#set -x

message "UNSET ${YELLOW}${VM_VPN}${PREFIX} AS NETVM"
if vm_exists "${VM_VPN}" ; then
    qvm-shutdown --quiet --wait --force "${VM_VPN}" 2>/dev/null
    for VM in /var/lib/qubes/appvms/* ; do
        VM="$(basename ${VM})"
        [ x"$(qvm-prefs ${VM} netvm)" = x"${VM_VPN}" ] && qvm-prefs --default "${VM}" netvm
    done
    for VM in /var/lib/qubes/vm-templates/* ; do
        VM="$(basename ${VM})"
        [ x"$(qvm-prefs ${VM} netvm)" = x"${VM_VPN}" ] && qvm-prefs --default "${VM}" netvm
    done
fi
if vm_exists "${VM_VPN}-ssh" ; then
    qvm-shutdown --quiet --wait --force "${VM_VPN}-ssh" 2>/dev/null
    for VM in /var/lib/qubes/appvm/* ; do
        [ x"$(qvm-prefs ${VM} netvm)" = x"${VM_VPN}-ssh" ] && qvm-prefs --default "${VM}" netvm
    done
    for VM in /var/lib/qubes/vm-templates/* ; do
        [ x"$(qvm-prefs ${VM} netvm)" = x"${VM_VPN}-ssh" ] && qvm-prefs --default "${VM}" netvm
    done
fi

message "DELETE ${YELLOW}${VM_VPN}"
vm_exists "${VM_VPN}" && qvm-remove --force "${VM_VPN}" 2>/dev/null
vm_exists "${VM_VPN}-ssh" && qvm-remove --force "${VM_VPN}-ssh" 2>/dev/null

message "CLEANUP ${YELLOW}${VM_CORE}"
push_command "${VM_CORE}" "rm -rf /etc/protect/template.${VM_VPN} 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm -rf /etc/protect/template.${VM_VPN}-ssh 2>/dev/null 1>&2"
push_command "${VM_CORE}" "aptitude -q -y purge dnscrypt-proxy redsocks openvpn"
push_command "${VM_CORE}" "rm /etc/redsocks.conf 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm /etc/dnscrypt-proxy/dnscrypt-proxy.toml 2>/dev/null 1>&2"
push_command "${VM_CORE}" "rm /lib/systemd/system/liteqube-vpn*.service 2>/dev/null 1>&2"
qvm-shutdown --quiet --wait --force "${VM_CORE}" 2>/dev/null

message "CLEANUP ${YELLOW}dom0"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Message" "${VM_VPN}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Error" "${VM_VPN}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_VPN}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitSSH" "${VM_VPN}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SignalVPN" "${VM_VPN}"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Message" "${VM_VPN}-ssh"
cleanup_file "/etc/qubes-rpc/policy/liteqube.Error" "${VM_VPN}-ssh"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitXorg" "${VM_VPN}-ssh"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SplitSSH" "${VM_VPN}-ssh"
cleanup_file "/etc/qubes-rpc/policy/liteqube.SignalVPN" "${VM_VPN}-ssh"
sudo rm -f /etc/qubes-rpc/liteqube.SignalVPN 2>/dev/null
rm -f ~/bin/lq-vpn 2>/dev/null
[ -z "$(ls -A "${HOME}/bin")" ] && rm "${HOME}/bin"

message "DONE"
exit 0
