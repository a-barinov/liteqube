#!/bin/sh

if [ -z "${1}" ] ; then
    echo "Usage: ${0} STAGE"
    exit 1
fi

set_permissions()
{
    echo "${4}"
    P_USER="${1:1:3}"
    P_GROUP="${1:4:3}"
    P_OTHER="${1:7:3}"
    P_USER="${P_USER//-/}"
    P_GROUP="${P_GROUP//-/}"
    P_OTHER="${P_OTHER//-/}"
    sudo chown "${2}:${3}" "${4}"
    sudo chmod "u=${P_USER},g=${P_GROUP},o=${P_OTHER}" "${4}"
}

cd "${1}"

cd ./default
    while IFS= read -r LINE ; do
        set_permissions $LINE
    done < ./permissions
cd ..

cd ./custom
    while IFS= read -r LINE ; do
        set_permissions $LINE
    done < ./permissions
cd ..

cd ..
