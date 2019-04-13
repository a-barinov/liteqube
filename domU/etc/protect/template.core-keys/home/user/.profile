if [ "$BASH" ]; then
    . ~/.bashrc
fi

#TODO move to service?

if [ x"$SSH_AGENT_PID" = x ] ; then
    eval `ssh-agent -s` 1>/dev/null
    ssh-add 1>/dev/null 2>&1
fi
