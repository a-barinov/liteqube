umask 022

unset HISTFILE
HISTCONTROL=ignoreboth
shopt -s cmdhist
HISTSIZE=256
HISTFILESIZE=0

shopt -s autocd
shopt -s checkwinsize
shopt -s dotglob
