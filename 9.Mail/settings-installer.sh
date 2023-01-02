#!/bin/sh

# Qube where MUA (e.g. Thunderbird) that will use mail qubes is installed
MAIL_QUBE="personal"

# Install systemd service in dom0 to check mail every X seconds. Do not set to disable.
MAIL_CHECK_INTERVAL="1800"

# List all the receiving accounts in RECEIVER_N variables
# N shoulld be from 1 to 10
# Each item is in "Name Server Port Protocol Username" format, separated by spaces
#   Name: account name, any unique text sring
#   Server: server address
#   Port: server posr, usually 995 for POP3 over SSL and 993 for IMAP over SSL
#   Protocol: POP3SSL, IMAPSSL, POP3, IMAP
#   Username: login name, often email address
# Password will be asked during the first connection and saved in core-keys
RECEIVER_1='gmail pop.gmail.com 995 POP3SSL your.address@gmail.com'
RECEIVER_2='hotmail pop-mail.outlook.com 995 POP3SSL another.address@homail.com'

# List all the sending accounts in SENDER_N variables
# N shoulld be from 1 to 10
# Each item is in "Name Server Protocol Username Email" format, separated by spaces
#   Name: account name, any unique text sring; name 'default' has a special meaning and is used
#   if account cannot be determined from sender address
#   Server: server address
#   Port: server posr, usually 465 or 587 for SMTP
#   Username: login name, often email address
#   Email: email address
# Password will be asked during the first connection and saved in core-keys
SENDER_1='gmail smtp.gmail.com 465 your.address@gmail.com your.address@gmail.com'
SENDER_2='hotmail smtp-mail.oulook.com 587 another.address@homail.com another.address@homail.com'
