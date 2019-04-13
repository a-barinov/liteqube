#!/bin/bash



# Required vars
VM=$(/usr/bin/xenstore-read name)
DEVICE="/dev/xvdb"
MOUNTPOINT="/mnt"
BASEDIR="/etc/protect"
SAFEDIR="QUARANTINE"
IFS=$'\n'



# Do not operate on dvm templates
[ x"${VM: -3}" = x"dvm" ] && exit 0



# Shutdown cube on mount failure
POWEROFF=No

# Quarantine files that fail checks, otherwise delete
QUARANTINE=Yes

# Allow files that are not listed, otherwise quarantine or delete
ALLOW_ROGUE=No

# Deploy missing files
DEPLOY_MISSING=Yes

# Erase /etc/protect when done
OBSCURE=No

# Load vm-specific settings
[ -f "$BASEDIR/settings.$VM" ] && . "$BASEDIR/settings.$VM"



# Check if var is true
function check(){
    VAL="${1,,}"
    if [ "$VAL" = "true" ] || [ "$VAL" = "yes" ] || [ "$VAL" = "1" ] ; then
        return 0
    else
        return 1
    fi
}

# Report error
function error(){
    echo "$1"
    #/usr/bin/qrexec-client-vm dom0 "alte.Error+$1"
}

# Find file in dirs
function find_file(){
    [ -e "$2"/"$1" ] && SOURCE="$2" && return 0
    [ -e "$3"/"$1" ] && SOURCE="$3" && return 0
    return 1
}

# Quarantine file
function quarantine(){
    if check "$QUARANTINE" ; then
        error "Quarantined $FILE"
        [ -d "$MOUNTPOINT/$SAFEDIR" ] || mkdir -p "$MOUNTPOINT/$SAFEDIR"
        chattr -d -f -i "$MOUNTPOINT/$FILE"
        lsattr -d "$MOUNTPOINT/$FILE"
        lsattr -d "$MOUNTPOINT/$SAFEDIR"
        mv "$MOUNTPOINT/$FILE" "$MOUNTPOINT/$SAFEDIR"
        return 0
    else
        return 1
    fi
}

# Deploy file
function deploy(){
    if [ -e "$MOUNTPOINT/$FILE" ] ; then
        chattr -d -f -i "$MOUNTPOINT/$FILE"
        quarantine "$MOUNTPOINT/$FILE" || rm -f "$MOUNTPOINT/$FILE"
    fi
    error "Deployed $FILE"
    cp -a "$SOURCE/$FILE" "$MOUNTPOINT/$FILE"
}

# Copy permissions
function permissions(){
    if [ "$(ls -ld "$MOUNTPOINT/$FILE" | cut -d" " -f1,3,4)" != "$(ls -ld "$SOURCE/$FILE" | cut -d" " -f1,3,4)" ] ; then
        error "Fixed permissions of $FILE"
        chmod --reference="$SOURCE/$FILE" "$MOUNTPOINT/$FILE"
    fi
}

# Make file immutable
function immutable(){
    [ -f "$MOUNTPOINT/$FILE" ] && [ "$(lsattr -d "$MOUNTPOINT/$FILE" | cut -c5)" = "-" ] && chattr -d -f +i "$MOUNTPOINT/$FILE"
}



# Mount private volume
mkdir -p "$MOUNTPOINT"
if [ -e "$DEVICE" ] && mount -o defaults,discard,noatime "$DEVICE" "$MOUNTPOINT" ; then
    echo "Device mounted"
else
    if head -c 65536 "$DEVICE" | tr -d '\0' | read -n 1 ; then
        error "Mount failed: BAD private volume"
    else
        error "First boot initialization"
    fi
    check $POWEROFF && systemctl poweroff
fi



# Iterate over /rw files
for FILE in $(cd "$MOUNTPOINT" && find . | cut -d'/' -f 2-) ; do
    [ "$FILE" = "." ] || [[ "$FILE" == $SAFEDIR* ]] && continue

    # Templates
    if find_file "$FILE" "$BASEDIR/template.$VM" "$BASEDIR/template.ALL" ; then
        # Symbolic link
        if [ -L "$SOURCE/$FILE" ] ; then
            if [ ! -L "$MOUNTPOINT/$FILE" ] || [ "$(readlink "$MOUNTPOINT/$FILE")" != "$(readlink "$SOURCE/$FILE")" ] ; then
                deploy
            fi
        # Directory
        elif [ -d "$SOURCE/$FILE" ] ; then
            if [ -d "$MOUNTPOINT/$FILE" ] ; then
                permissions
            else
                deploy
            fi
            immutable
        # Socket
        elif [ -S "$SOURCE/$FILE" ] ; then
            if [ -S "$MOUNTPOINT/$FILE" ] ; then
                permissions
            else
                deploy
            fi
        # Regular file
        elif [ -f "$SOURCE/$FILE" ] ; then
            if [ -f "$MOUNTPOINT/$FILE" ] && diff "$SOURCE/$FILE" "$MOUNTPOINT/$FILE" 1>/dev/null 2>&1 ; then
                permissions
            else
                deploy
            fi
            immutable
        fi

    # Checksums
    elif find_file "$FILE" "$BASEDIR/checksum.$VM" "$BASEDIR/checksum.ALL" ; then
        # Regular files
        if [ -f "$SOURCE/$FILE" ] ; then
            if [ -f "$MOUNTPOINT/$FILE" ] && [ "$(head -n 1 < "$SOURCE/$FILE")" = "$(sha256sum "$MOUNTPOINT/$FILE" | cut -d" " -f1)" ] && [ "$(tail -n 1 < "$SOURCE/$FILE")" = "$(sha512sum "$MOUNTPOINT/$FILE" | cut -d" " -f1)" ] ; then
                permissions
                immutable
            else
                quarantine
            fi
        # Dirs
        elif [ -d "$SOURCE/$FILE" ] ; then
            [ -d "$MOUNTPOINT/$FILE" ] && permissions || quarantine
        fi

    # Whitelisted files and dirs in whitelisted paths
    elif find_file "$FILE" "$BASEDIR/whitelist.$VM" "$BASEDIR/whitelist.ALL" ; then
        [ -f "$SOURCE/$FILE" -a -f "$MOUNTPOINT/$FILE" ] || [ -d "$SOURCE/$FILE" -a -d "$MOUNTPOINT/$FILE" ] && permissions || quarantine

    # Anything in whitelisted dirs
    elif find_file "$(dirname "$FILE")" "$BASEDIR/whitelist.$VM" "$BASEDIR/whitelist.ALL" ; then
        DIR=$(dirname "$FILE")
        #[ "$(ls -A "$SOURCE/$DIR")" ] && quarantine

    # Anything in dirs in whitelisted dirs
    elif find_file "$(dirname $(dirname "$FILE"))" "$BASEDIR/whitelist.$VM" "$BASEDIR/whitelist.ALL" ; then
        DIR=$(dirname $(dirname "$FILE"))

    # Anything else
    else
        check "$ALLOW_ROGUE" || quarantine
    fi

done



# Iterate over template files
if check $DEPLOY_MISSING ; then
    for FILE in $( [ -d "$BASEDIR/template.$VM" ] && cd "$BASEDIR/template.$VM" && find . ; [ -d "$BASEDIR/template.ALL" ] && cd "$BASEDIR/template.ALL" && find . | sort | uniq | cut -d'/' -f 2-) ; do
        [ "$FILE" = "." ] && continue
        find_file "$FILE" "$BASEDIR/template.$VM" "$BASEDIR/template.ALL"
        [ -e "$MOUNTPOINT/$FILE" ] || deploy
    done
fi



# Remove /etc/protect
check $OBSCURE && rm -rf /etc/protect



# Unmount private volume
umount -lf $MOUNTPOINT
echo "Unmounted device"



exit 0
