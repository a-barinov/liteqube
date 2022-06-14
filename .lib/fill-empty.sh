#!/bin/sh

IFS="
"

for DIR in $(find ../ -type d -empty) ; do

echo "# Ignore everything in this directory
*
# Except this file
!.gitignore
" > "${DIR}/.gitignore"

done
