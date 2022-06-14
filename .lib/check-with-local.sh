#/bin/sh

ENTER="$(printf "\n\b")"
TAB="$(printf "\t")"

INTERACTIVE="Yes"
STARTED_QUBES=""
ERRORS=""
CACHE="/tmp/liteqube-cache"

mkdir -p "${CACHE}"

IFS="${ENTER}"
for MODULE in $(find ../. -mindepth 1 -maxdepth 1 -type d -name "[0-9]*" -printf "%f\n") ; do
    for SUBMODULE in $(find "../${MODULE}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n") ; do
        FILESLIST="../${MODULE}/${SUBMODULE}/permissions"
        if [ -f "${FILESLIST}" ] ; then
            QUBE="<none>"
            for LINE in $(cat "${FILESLIST}" | sort) ; do
                # Find what we are looking at
                IFS="${TAB}" ; set -- "junk${TAB}"${LINE} ; FILE="${4}"
                IFS="/" ; set -- "junk\\"${FILE} ; NEW_QUBE="${2}" ; FILE_IN_QUBE="${FILE#./${NEW_QUBE}}"
                IFS="${ENTER}"
                # Start qube if needed
                if ! [ x"${NEW_QUBE}" = x"${QUBE}" ] ; then
                    if ! [ -e "/run/qubes/qrexec.${NEW_QUBE}" ] && ! [ x"${NEW_QUBE}" = x"dom0" ] ; then
                        qvm-start --quiet --skip-if-running "${NEW_QUBE}"
                        STARTED_QUBES="${STARTED_QUBES} ${NEW_QUBE}"
                    fi
                    QUBE="${NEW_QUBE}"
                fi
                # Check if file exists
                if ! [ -e "../${MODULE}/${SUBMODULE}/${FILE}" ] && ! [ -L "../${MODULE}/${SUBMODULE}/${FILE}" ] ; then
                    echo "Missing ${MODULE}/${SUBMODULE}/${FILE#./}"
                    IFS="${ENTER} ${TAB}"
                    [ -z "${STARTED_QUBES}" ] || qvm-shutdown --quiet --wait --timeout 60 ${STARTED_QUBES}
                    [ -z "${ERRORS}" ] && rm -rf "${CACHE}"
                    exit 1
                fi
                # Directory
                if [ -d "../${MODULE}/${SUBMODULE}/${FILE}" ] ; then
                    if ( ! [ x"${QUBE}" = x"dom0" ] && qrexec-client -d "${QUBE}" root:"test ! -d \"${FILE_IN_QUBE}\"" ) ||
                       ( [ x"${QUBE}" = x"dom0" ] && sudo /bin/sh -c "test ! -d \"${FILE_IN_QUBE}\"" ) ; then
                        echo -n "${MODULE}/${SUBMODULE}/${FILE#./} is not a dir in ${QUBE}. Continue?"
                        [ -z "${INTERACTIVE}" ] && echo || read INPUT
                    fi
                fi
                # Symbolic link
                if [ -L "../${MODULE}/${SUBMODULE}/${FILE}" ] ; then
                    LOCAL_TO="$(readlink -f "../${MODULE}/${SUBMODULE}/${FILE}")"
                    if ( ! [ x"${QUBE}" = x"dom0" ] && ! qrexec-client -d "${QUBE}" root:"test -L \"${FILE_IN_QUBE}\"" ) ||
                       ( [ x"${QUBE}" = x"dom0" ] && ! sudo /bin/sh -c "test -L \"${FILE_IN_QUBE}\"" ) ; then
                        echo -n "${MODULE}/${SUBMODULE}/${FILE#./} is not a link in ${QUBE}. Continue?"
                        [ -z "${INTERACTIVE}" ] && echo || read INPUT
                    elif ( ! [ x"${QUBE}" = x"dom0" ] && ! [ x"${LOCAL_TO}" = x"$(qrexec-client -d "${QUBE}" root:"readlink -f \"${FILE_IN_QUBE}\"")" ] ) ||
                         ( [ x"${QUBE}" = x"dom0" ] && ! [ x"${LOCAL_TO}" = x"$(sudo /bin/sh -c "readlink -f \"${FILE_IN_QUBE}\"")" ] ) ; then
                            echo -n "${MODULE}/${SUBMODULE}/${FILE#./} doesn't match in ${QUBE}. Continue?"
                            [ -z "${INTERACTIVE}" ] && echo || read INPUT
                    fi
                fi
                # Regular file
                if [ -f "../${MODULE}/${SUBMODULE}/${FILE}" ] ; then
                    if ( ! [ x"${QUBE}" = x"dom0" ] && ! qrexec-client -d "${QUBE}" root:"test -f \"${FILE_IN_QUBE}\"" ) ||
                       ( [ x"${QUBE}" = x"dom0" ] && ! sudo /bin/sh -c "test -f \"${FILE_IN_QUBE}\"" ) ; then
                        echo -n "${MODULE}/${SUBMODULE}/${FILE#./} file is missing in ${QUBE}. Continue?"
                        [ -z "${INTERACTIVE}" ] && echo || read INPUT
                    else
                        mkdir -p "$(dirname "${CACHE}/${MODULE}/${SUBMODULE}/${FILE}")"
                        if [ x"${QUBE}" = x"dom0" ] ; then
                            sudo cp "${FILE_IN_QUBE}" "${CACHE}/${MODULE}/${SUBMODULE}/${FILE}"
                            sudo chown user:user "${CACHE}/${MODULE}/${SUBMODULE}/${FILE}"
                        else
                            qrexec-client -d "${QUBE}" root:"cat \"${FILE_IN_QUBE}\"" > "${CACHE}/${MODULE}/${SUBMODULE}/${FILE}"
                        fi
                        if ! cmp --quiet "../${MODULE}/${SUBMODULE}/${FILE}" "${CACHE}/${MODULE}/${SUBMODULE}/${FILE}" ; then
                            ERRORS="yes"
                            echo -n "${MODULE}/${SUBMODULE}/${FILE#./} differs in ${QUBE}. Continue?"
                            [ -z "${INTERACTIVE}" ] && echo || read INPUT
                        fi
                    fi
                fi
            done
        fi
    done
done

IFS="${ENTER} ${TAB}"
[ -z "${STARTED_QUBES}" ] || qvm-shutdown --quiet --wait --timeout 60 ${STARTED_QUBES}
[ -z "${ERRORS}" ] && rm -rf "${CACHE}"

exit 0
