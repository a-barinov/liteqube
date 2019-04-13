#!/usr/bin/python3

from systemd import journal
import os

reader = journal.Reader()
reader.this_boot()
reader.this_machine()
reader.log_level(journal.LOG_INFO)
reader.add_match(SYSLOG_IDENTIFIER = 'Tor')
os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalTor+200 1>/dev/null 2>&1')
while True:
    reader.wait(-1)
    message = ''
    for event in reader:
        if event['MESSAGE'].startswith('Bootstrapped') or event['MESSAGE'].startswith('Interrupt'):
            message = event['MESSAGE']
    if message.startswith('Bootstrapped'):
        state = message[message.find(' ') + 1:message.find('%')]
        os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalTor+%s 1>/dev/null 2>&1'%state)
        if state == '100':
            os.system('/bin/sh /etc/qubes-rpc/alte.SetTime')
    if message.startswith('Interrupt'):
        os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalTor+200 1>/dev/null 2>&1')
