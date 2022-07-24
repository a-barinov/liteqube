#!/bin/sh

NEWLINE="
"
OLD_IFS="${IFS}"
IFS="${NEWLINE}"
for FILE in $(find /etc/systemd/system -mindepth 2 | grep -v -e qubes-sync-time.timer -e xendriverdomain.service -e qubes-mount-dirs.service -e qubes-misc-post.service -e qubes-qrexec-agent.service -e systemd-pstore.service -e liteqube-vm-template.service -e qubes-sysinit.service -e qubes-db.service -e getty@tty1.service) ; do
    IFS="${OLD_IFS}"
    SERVICE="$(basename ${FILE})"
    rm -f "${FILE}"
    if [ "${SERVICE}" = "cron.service" ] || [ "${SERVICE}" = "qubes-meminfo-writer.service" ] || [ "${SERVICE}" = "remote-fs.service" ] || [ "${SERVICE}" = "systemd-timesyncd.service" ] || [ "${SERVICE}" = "systemd-fsck-root.service" ] || [ "${SERVICE}" = "systemd-jornal-flush.service" ] || [ "${SERVICE}" = "systemd-update-umtp.service" ] || [ "${SERVICE}" = "systemd-tmpfiles-clean.service" ] || [ "${SERVICE}" = "dev-xvdc1-swap.service" ] || [ "${SERVICE}" = "systemd-update-umtp-runlevel.service" ] || [ "${SERVICE}" = "systemd.rfkill.service" ] ; then
        systemctl mask "${SERVICE}" 2>/dev/null
    fi
    IFS="${NEWLINE}"
done

IFS="${OLD_IFS}"
for SERVICE in "cron.service" "qubes-mminfo-writer.service" "remote-fs.service" "systemd-timesyncd.service" "systemd-fsck-root.service" "systemd-jornal-flush.service" "systemd-update-umtp.service" "systemd-tmpfiles-clean.service" "dev-xvdc1-swap.service" "systemd-update-umtp-runlevel.service" "systemd-rfkill.service" "htpdate.service" ; do
    [ -e "/etc/systemd/system/${SERVICE}" ] || systemctl mask "${SERVICE}" 2>/dev/null
done

IFS="${NEWLINE}"
for TIMER in $(systemctl list-units | grep '\.timer' | cut -d' ' -f3 | grep -v "qubes-sync-time.timer") ; do
    systemctl stop "${TIMER}" 2>/dev/null
    systemctl disable "${TIMER}" 2>/dev/null
    systemctl mask "${TIMER}" 2>/dev/null
done
IFS="${OLD_IFS}"

for AUTOSTART in /etc/xdg/autostart/* ; do
    NAME="$(basename "${AUTOSTART}")"
    case "$NAME" in
        qrexec-policy-agent.desktop)
            continue
            ;;
        qubes-qrexec-fork-server.desktop)
            continue
            ;;
        *)
            if ! [ -e "/etc/protect/template.ALL/home/user/.config/autostart/${NAME}" ] ; then
                cp "${AUTOSTART}" "/etc/protect/template.ALL/home/user/.config/autostart/${NAME}"
                sed -i 's/^Exec/;Exec/g' "/etc/protect/template.ALL/home/user/.config/autostart/${NAME}"
            fi
            ;;
    esac
done

if ! grep "qubes-gui-agent" < "/usr/bin/qubes-set-monitor-layout" >/dev/null 2>&1 ; then
    sed -i '3igrep qubes-gui-agent </rw/config/rc.local >/dev/null 2>/dev/null || exit 0' "/usr/bin/qubes-set-monitor-layout"
fi

if [ -e /lib/systemd/system/NetworkManager.service.d/30_qubes.conf ] ; then
    rm -f /lib/systemd/system/NetworkManager.service.d/30_qubes.conf >/dev/null 2>&1
fi

fstrim --quiet /

exit 0
