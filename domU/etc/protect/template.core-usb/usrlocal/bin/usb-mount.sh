#!/bin/sh

log()
{
    /usr/bin/logger -t usb-mount.sh -s "$@"
    /usr/bin/qrexec-client-vm dom0 alte.Message+"$@" 1>/dev/null 2>&1
}

error()
{
    /usr/bin/logger -t usb-mount.sh -s "$@"
    /usr/bin/qrexec-client-vm dom0 alte.Error+"$@" 1>/dev/null 2>&1
}

mount_volume()
{
    eval $(/sbin/blkid -o udev "$1")
    OPTS="rw,noatime,nodev,nosuid,noexec,sync"

    case x"${ID_FS_TYPE}" in
    x"vfat")
        OPTS="${OPTS},uid=1000,gid=1000,umask=000,shortname=mixed,utf8=1,flush"
        ;;
    x"ext4")
        OPTS="${OPTS},nocheck,discard"
        ;;
    *)
        return 1
        ;;
    esac

    NAME="$(/usr/bin/basename $2)"
    if /bin/mount -o "${OPTS}" "$1" "$2"; then
        log "Mounted ${NAME}"
        /bin/chmod 0777 "$2"
        /usr/bin/qrexec-client-vm dom0 "alte.SignalUsb+M-${NAME}" 1>/dev/null 2>&1
        return 0
    else
        error "Error mounting ${NAME}"
        /bin/rmdir "$2" || error "Failed to remove $2"
        return 1
    fi
}


if [ $# -ne 2 ]; then
    error "Wrong parameters"
    exit 1
fi


DEV_NAME="$2"
DEV_PATH="/dev/${DEV_NAME}"
MOUNT_BASE="/media"
eval $(/sbin/blkid -o udev "${DEV_PATH}")
LVM="lvm-${DEV_NAME}"


do_mount()
{
    # Decide if we want to proceed with mount
    if ! ( [ x"${ID_FS_TYPE}" = x"vfat" ] || [ x"${ID_FS_TYPE}" = x"ext4" ] || [ x"${ID_FS_TYPE}" = x"crypto_LUKS" ] ) ; then
        if ! ( [ x"${ID_PART_TABLE_TYPE}" != x"" ] ) ; then
            [ x"${ID_FS_TYPE}" = x"" ] && ID_FS_TYPE="Unknown filesystem" || ID_FS_TYPE="Filesystem ${ID_FS_TYPE}"
            error "${ID_FS_TYPE} on ${DEV_NAME} not supported"
        fi
        exit 1
    fi

    # Check if already mounted
    if /bin/grep "${DEV_PATH}" /etc/mtab 1>/dev/null 2>&1 ; then
        error "${DEV_NAME} is already mounted"
        exit 1
    fi

    # Find a mount point to use
    for TRY in "${ID_FS_LABEL}" "${ID_FS_PARTLABEL}" "${DEV_NAME}" "$(/bin/mktemp --dry-run --tmpdir=${MOUNT_BASE} ${DEV_NAME}-XXXX)" ; do
        if [ ! -e "${MOUNT_BASE}/${TRY}" ] ; then
            MOUNT_POINT="${MOUNT_BASE}/${TRY}"
            /bin/mkdir -p ${MOUNT_POINT}
            break
        fi
    done
    if ! [ x"${MOUNT_POINT}" != x"" ] && [ -d "${MOUNT_POINT}" ] ; then
        error "Failed to create mount point for ${DEV_NAME}"
        exit 1
    fi

    # LVM on clyptoLuks
    if [ x"${ID_FS_TYPE}" = x"crypto_LUKS" ]; then
        systemctl enable lvm2-monitor
        systemctl start lvm2-monitor
        if /usr/bin/qrexec-client-vm core-keys alte.SplitPassword+"${ID_FS_UUID}" | /sbin/cryptsetup luksOpen "${DEV_PATH}" "${LVM}" - ; then
            VG="$(/sbin/vgscan | tail -n 1 | cut -d\" -f2)"
            if [ x"${VG}" = x"  Reading volume groups from cache." ] ; then
                mount_volume "/dev/mapper/${LVM}" "${MOUNT_POINT}"
            else
                for VOLUME in /dev/${VG}/* ; do
                    VOLUME="$(/usr/bin/basename ${VOLUME})"
                    if mkdir -p "${MOUNT_POINT}/${VOLUME}" ; then
                        mount_volume "/dev/${VG}/${VOLUME}" "${MOUNT_POINT}/${VOLUME}"
                    else
                        error "Failed to create mount point for ${VOLUME}"
                    fi
                done
            fi
        else
            error "Failed to unlock ${DEV_NAME}"
            exit 1
        fi
    # Normal block device
    else
        mount_volume ${DEV_PATH} ${MOUNT_POINT} || exit 1
    fi
}


do_unmount()
{
    if [ x"${ID_FS_TYPE}" = x"crypto_LUKS" ]; then
        VG="$(/sbin/vgscan | tail -n 1 | cut -d\" -f2)"
        if [ x"${VG}" = x"  Reading volume groups from cache." ] ; then
            MOUNT_POINT=$(mount | grep ${LVM} | awk '{ print $3 }')
            NAME="$(/usr/bin/basename ${MOUNT_POINT})"
            /bin/umount -fl "/dev/mapper/${LVM}" && log "Unmounted ${DEV_NAME}" || error "Failed to unmount ${DEV_NAME}"
            /usr/bin/qrexec-client-vm dom0 "alte.SignalUsb+U-${NAME}" 1>/dev/null 2>&1
            /bin/rmdir "${MOUNT_POINT}" || error "Failed to remove ${MOUNT_POINT}"
        else
            for VOLUME in /dev/${VG}/* ; do
                if /bin/grep "${VOLUME}" /etc/mtab 1>/dev/null ; then
                    /bin/umount -fl "${VOLUME}" && log "Unmounted ${VOLUME}" || error "Failed to unmount ${VOLUME}"
                    NAME="$(/usr/bin/basename ${VOLUME})"
                    /usr/bin/qrexec-client-vm dom0 "alte.SignalUsb+U-${NAME}" 1>/dev/null 2>&1
                    /bin/rmdir "${VOLUME}" || error "Failed to remove ${VOLUME}"
                fi
            done
            /bin/rmdir "${MOUNT_BASE}/${DEV_NAME}" || error "Failed to remove ${MOUNT_BASE}/${DEV_NAME}"
            /sbin/lvchange -a n "${VG}" || error "Failed to deactivate ${VG}"
            /sbin/cryptsetup luksClose "${LVM}" || error "Failed to close ${LVM}"
            systemctl stop lvm2-monitor
            systemctl disable lvm2-monitor
        fi
    else
        MOUNT_POINT=$(mount | grep ${DEV_PATH} | awk '{ print $3 }')
        if [ x"${MOUNT_POINT}" = x"" ]; then
            error "${DEV_PATH} is not mounted"
            exit 0
        fi
        /bin/umount -fl ${DEV_PATH} && log "Unmounted ${DEV_NAME}" || error "Failed to unmount ${DEV_NAME}"
        NAME="$(/usr/bin/basename ${MOUNT_POINT})"
        /usr/bin/qrexec-client-vm dom0 "alte.SignalUsb+U-${NAME}" 1>/dev/null 2>&1
        /bin/rmdir "${MOUNT_POINT}" || error "Failed to remove ${MOUNT_POINT}"
    fi
}

case "$1" in
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
    *)
        error "Unknown action"
        exit 1
        ;;
esac
