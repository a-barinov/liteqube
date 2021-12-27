#!/bin/sh

if [ -z "${1}" ] ; then
    echo "Usage: ${0} STAGE"
    exit 1
fi

cd "${1}"

cd ./default
find -P . -mindepth 2 | xargs ls -Adl | awk -v OFS="\t" '$1=$1' | cut -d$'\t' -f1,3,4,9 > ./permissions
cd ..

cd ./custom
find -P . -mindepth 2 | xargs ls -Adl | awk -v OFS="\t" '$1=$1' | cut -d$'\t' -f1,3,4,9 > ./permissions
cd ..

cd ..