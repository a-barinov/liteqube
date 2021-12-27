umask 022

unset HISTFILE
HISTCONTROL=ignoreboth
shopt -s cmdhist
HISTSIZE=256
HISTFILESIZE=0

shopt -s autocd
shopt -s checkwinsize
shopt -s dotglob

export LANG=C.UTF-8
export LC_ALL=$LANG
export LANGUAGE=$LANG
