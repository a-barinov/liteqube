### Split-smartcard and split-u2f support for Alex Barinov's liteqube

See install.sh; I did not really test installing to a qube separate from
core-usb but I hope it works, you are free to try and fix.

Don't forget to whitelist your tokens / smartcard readers in usbguard settings.
Also, A LOT of gnome programs try to access smart card on init just because
this is the way they work. Better use a whitelist (see pkcs11.conf(5))

