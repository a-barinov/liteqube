
# Liteqube puts Qubes OS on a diet

Liteqube was created in 2017 to run Qubes on a rather low-spec GPD Win 2 (Core m3-7Y30, 8Mb RAM). Taking 2Gb of RAM to run dom0 and fully torified set of services, it allowed me to use a device with 8MB of RAM quite comfortably.

5 years further down the road, Liteqube grew wider but not fatter and still pursues the original goals:
 1. Low memory consumption; 1Gb of RAM required to run network, firewall, tor and usb qubes
 2. Services isolation: every service gets a separate qube to minimise damage from potential exploits; to the extent what default Qubes installation cannot offer due to heavy resource consumption of the default system qubes.
 3. Stateless disposable qubes for most of the services interacting with outside world
 4. Easy on ssd: most qubes run with read-only root fs, most volatile folders are kept on tmpfs
 5. Minimal modifications to dom0: Litequbes is generally self-contained, the only requirement is to have several rpc policies for vm-to-vm communications and vm-to-dom0 notifications

To illustrate Liteqube impact on Qubes resource consumption, here is boot time and memory usage of a torified out-of-the-box Qubes 4.1-rc3 install on OneMix 4 (Core i5-1130G7, 16Gb RAM):

    > systemd-analyze
    Startup finished in 6.039s (firmware) + 6.691s (loader) + 8.200s (kernel) + 19.703s (initrd) + 45.331s (userspace) = 1min 25.966s
    graphical.target reached after 45.228s in userspace
    
    > xentop -bfi 1
            NAME     MEM(k) MEM(%)  MAXMEM(k) MAXMEM(%) VCPUS   VBD_RD   VBD_WR  VBD_RSECT  VBD_WSECT
        Domain-0    4177920   25.3    4195328      25.4     4        0        0          0          0
    sys-firewall    4079680   24.7    4097024      24.8     2     5932      964     558692      96832
         sys-net     393260    2.4     410624       2.5     2    14359     6426    1191636     211592
      sys-net-dm     147456    0.9     148480       0.9     1      180        0      34106          0
         sys-usb     290860    1.8     308224       1.9     2    25147     9662    1883740     380312
      sys-usb-dm     147456    0.9     148480       0.9     1      180        0      34106          0
      sys-whonix    4079680   24.7    4097024      24.8     2     6918     1168     620324      69968

Here is the same install with Liteqube taking over network, firewall, tor and usb qubes:

    > systemd-analyze
    Startup finished in 6.148s (firmware) + 8.208s (loader) + 8.226s (kernel) + 17.339s (initrd) + 19.660s (userspace) = 59.583s
    graphical.target reached after 19.636s in userspace
    
    > xentop -bfi 1
           NAME     MEM(k) MEM(%)  MAXMEM(k) MAXMEM(%) VCPUS   VBD_RD   VBD_WR  VBD_RSECT  VBD_WSECT
       Domain-0    4177920   25.3    4195328      25.4     4        0        0          0          0
         fw-net     131136    0.8     132096       0.8     1    10426       53     736694       4672
       core-net     180268    1.1     197632       1.2     1    27959       56    2064342       4856
    core-net-dm     147456    0.9     148480       0.9     1      181        0      34114          0
       core-usb     163884    1.0     181248       1.1     1     8076       53     570918       4672
    core-usb-dm     147456    0.9     148480       0.9     1      181        0      34114          0
       core-tor     147520    0.9     148480       0.9     1    40586       31    3365078        368

You can see significantly reduced memory consumption, boot time and amount of disk writes.

Here is how this level of efficiency is achieved:
 - Minimised Debian template is used to run the service qubes, spinned off from debian-11-minimal. It does not have a single package installed that's not required for the setup to work. Base system takes around 800Mb of disk space, it then goes up as additional services (e.g. tor, network-manager) are installed. This is the only template qube used so keeping the whole setup up-to-date is easy.
 - Most services run in disposable qubes ensuring these qubes are completely stateless. Notable exceptions are tor qube that needs to update guard nodes, and mail-receiving qube that needs to keep what's received in case power fails, Qubes OS crashes, or any other disaster occurs.
 - To initialise disposable qubes based on single template, a qube templating & boot-time check mechanism is used, inspired by vm-boot-protect project.
 - Qubes that don't need xorg for operation (most of them, really) run headless. A custom split-xorg setup is used in case you need an emergency shell.
 - Valuable stuff (files, passwords, ssh and gpg keys) are stored in a separate offline qube that provides key material to qubes that need it.
 - Existing Qubes install (both dom0 and user qubes) remains untouched. Liteqube will install a few packages to dom0 (if not installed already): qubes-template-debian-11-minimal, parted and gdisk, zenity and dialog, . The first three can be removed after the installation completes. Some rpc scripts and policies will be installed into `/etc/qubes-rpc`, all named `liteqube.xxx` so auditing them is easy. Some optional but helpful scripts will be put into `~/bin` folder with `lq-xxx` naming pattern.

### How to install:
 1. Download liteqube-0.92.tar.gz [here:](https://github.com/a-barinov/liteqube/releases/tag/0.92).
 2. Transfer it to dom0 and unpack to a folder of your choice.
 3. Go to '1.Base' folder, review, edit / change settings as needed and run `install.sh` script there.
 4. Once base system is installed, proceed with installation of the components you need from other folders.
 5. All components have `uninstall.sh` script to remove all the qubes created. The uninstall scripts are to be run in the reverse order with base uninstall to be run last, it will remove any remmants of Liteqube.
 6. All components have `custom` folder that allows you to automate installation customisation. There is a `README.md` file is these folders helping you to create a custom install overlay.

Here is a detailed description of the installation process (if needed) and qubes installed by each of the components.

### Base
The foundation of Liteqube is debian-core qube. This is the only TemplateVM used, which makes system updates easy by limiting it to a single qube update. debian-core has a minimised package set (smaller than debian-minimal) and therefore minimal footprint and attack surface.

Liteqube uses custom qube templating service called 'liteqube-vm-template', it is heavily inspired by [vm-boot-protect](https://github.com/tasket/Qubes-VM-hardening). This service recreates specified qube configuration early at boot stage, as described in `/etc/protect` folder, and also quarantines (to `/rw/QUARANTINE`) or deletes any files not fitting the described configuration. In case of quarantine you will see a 'Files quarantined' notification during qube start.

Most qubes based on debian-core run headless. To run a shell when needed, a qube called core-xorg is created and other qubes can use it to show graphical apps (mainly terminal) to the user using split-xorg mechanism. `lq-xterm` script is put into dom0 to seamlessly run a terminal in any of Liteqube vms, headless or not.

To support creation of disposable qubes, a template qube called core-dvm is created. It has no function and if run it will remove any files from its private storage (therefore ensuring a blank starting point) and then immediately shut down.

core-keys qube is installed to avoid storing confidential information required by disposable qubes inside debian-core or core-dvm. Base install does not need this qube but many other components will.

A few installation notes:
 - You will need to respond 'Yes' once during the install as partition table changes in gdisk are not fully scriptable.
 - You will get one 'debian-core: files quarantined during boot' error message and one 'core-keys: files quarantined during boot' error message. This is normal and happens when templating mechanism gets rolled out first time.
 - There are two serious qubes backup bugs, [#5393](https://github.com/QubesOS/qubes-issues/issues/5393) and [#7176](https://github.com/QubesOS/qubes-issues/issues/7176). First one leaves you with corrupt backups, second with inability to restore. You've been warned!

### Network
This script will create two firewalls (fw-net and fw-tor, equivalent of sys-firewall), network qube (core-net, equivalent of sys-net), tor qube (core-tor, equivalent of whonix-gw) and a separate qube to handle system updates (core-update).

Two firewall options are offered, linux-based firewall and mirage-firewall, with mirage-firewall installed by default. Two firewalls are created by default: fw-net shields the whole system from core-net and fw-tor shields torified qubes from core-tor. That's extra-secure setup, fw-tor is not strictly necessary and can be deleted, in which case you need to set core-tor as network vm for core-update. Once firewall is set up you can set fw-tor (or core-tor) as net vm for any qube you want to torify.

Network qube core-net is disposable by default, it can be switched to normal appvm in the installation script settings. Disposable core-net makes it more secure but also means any new access points will not be saved automatically. You will need to manually add any newly added access points to either debian-core or core-keys, more on this below.

One of the security problems with disposable core-net is that your wifi passwords need to be stored in the template qube (debian-core). This makes your passwords available in many insecure qubes which are lucrative attack targets (e.g. core-usb, core-print). To mitigate this risk, 'cold' storage of access points containing passwords is used, provided by core-keys qube. This qube stores files (as well as passwords, ssh and gpg keys) and provides it to other qubes in a reasonably secure fashion. File provisioning is handled by `liteqube.SplitFile` service.

core-net uses wifi mac randomisation on a per-accesspoint basis. The randomisation is driven by 512b `secret_key` file located in `/var/lib/NetworkManager`. Note that anyone who has this key can de-anonymise your device on public wifi networks. Similarly, core-tor uses per-accesspoint list of guardian nodes, making your device de-anonimisation on public networks even harder.

core-tor also acts as clockvm, synchronising time with several onion services via [htpdate](https://github.com/iridium77/htpdate). [Sdwdate](https://www.whonix.org/wiki/Sdwdate) is not used as its approach to portability is a joke, deb package depends on full gcc toolchain and compiles the package in place. I'm not ready to keep full gcc toolchain installed just for time synchronisation, therefore htpdate is used despite sdwdate being vastly superior.

During the installation, your dom0 update source will be changed to onion Qubes OS site. I hope you don't mind.

### USB
This will create core-usb disposable qube and assign all sys-usb devises to it. [Usbguard](https://usbguard.github.io/) is deployed by default and is configured to only accept usb disks. To allow other device types (input devices, usb hubs, cameras, etc) you will need to tweak `/etc/usbguard/rules.conf` in debian-core.

If USB_INPUT_DEVICES is set to True in the installation script (it is by default) then `/etc/qubes-rpc/qubes.Input*` files will be installed, allowing dom0 input to come from USB devices. This is a security risk, you've been warned.

### VPN
The intent is to create a fire-and-forget qube that connects to VPN server once started and routes and acts as netvm for any connected qubes, routing all traffic through VPN.
Only redirection of traffic through SSH connection is supported at this time, the qube is called core-vpn-ssh. This was created out of necessity as network I was on was not allowing any external udp traffic, and I wanted to have secure access to my home network. SSH keys are obtained from core-keys. Look at the `custom` dir inside installation dir, it shows how to put your ssh keys into core-keys automatically.

### Storage
This creates a set of qubes that provide secure and transparent access to encrypted storage devices like usb sticks. The approach is based on 3 layers, separating device access, decryption and working with decrypted filesystem:
 1. Storage device qubes, either usb qube for external devices or disposable network-connected qube fo online storage.
 2. Disposable qube (core-decrypt) that accesses encrypted device, gets decryption password from core-keys qube and decrypts. Currently only luks/luks2 encryption is supported.
 3. Disposable qube that mounts decrypted filesystem and lets you work with the files. This qube is *not* created during install as you likely want it to be based on a more functional template than debian-core,

In addition, core-iscsi qube can be created, allowing to use NAS for data storage in a secure fashion, including support for secure online backups.

### RDP
Disposable VM to run remote desktop sessions. RDP (full support, including sound) and VNC (experimental) are currently supported. Passwords are obtained from core-keys.

### Audio
This creates audio qube called core-sound, that can then be set as audiovm for other qubes.  It generally follows Qubes approach to audio service provisioning, except using tiny custom shell script to run `pacat-simple-vchan` for each qube requiring sound service instead of default monstrous python script with runtime x.org dependency. `lq-volume` script is provided in dom0 to fine-tune pulseaudio volume.

### Print
Creates printing qube called core-print. This qube has two modes of operation, with and without preview of file to be printed:
 - Without preview, any pdf file sent via qvm-copy will be automatically sent to default printer. Nice for small home printers that don't really have printing options.
 - With preview enabled, any file sent to print qube will be opened in pdf previewer (zathura-pdf-poppler by default), you can then print it from there to any installed printer and with any options.
In addition to creating core-print qube, setup script can create "Qubes Printer" for selected qubes, that is based on cups-pdf. You can then print to this printer, and resulting pdf will be sent to core-print automatically. In case you don't enable print file preview, this creates almost seamless printing experience with printer shared across multiple qubes.

### Templating mechanism
This is the key service allowing Liteqube to run different disposable qubes off the same template. It runs very early on boot and checks private partition to ensure it contains only the files needed. Any file not fitting the configuration is put into quarantine or deleted.
Setup is driven by `/etc/protect` folder that has 4 components:
 - Main script `vm-boot-protect.sh`, and per-vm `settings.<vm name>` is where you can set global or vm-specific settings. Main script is reasonably well-documented.
 - File dispatcher: `template.ALL` and `template.<qube name>` hold files that shall be present in `/rw` folder. Permissions and content of the files/folders will be set exactly as in `/etc/protect` folder. Qube-specific files take precedence over `template.ALL` files.
 - File checker: `checksum.ALL` and `checksum.<vm name>` hold checksums of the files that shall be present in `/rw` folder but cannot be held in debian-core for confidentiality reasons. Permissions of the files/folders will be set exactly as in `/etc/protect` folder. Each checksum file contains 2 lines, sha256 and sha512 checksum. Vm-specific files take precedence over `checksum.ALL` files.
 - In case you need to ignore a file, it shall be put into `whitelist.<vm name>`. To ignore all files or all dirs in a certain dir, put `.any_file` or `.any_dir` file into a dir.

### Using 'core-keys' for key or password storage
As of Liteqube 0.91, core-keys supports providing files, passwords and ssh keys to other qubes on request.
- Files: You need to save a file under `/home/user/<qube name>/<filename>`, this file can then be requested only by that qube through `liteqube.SplitFile` service. Don't forget that this file needs to be added to `/etc/protect` dir (either as checksum or whitelist) otherwise it will be quarantined during the next boot.
- Passwords: `/home/user` dir contains `password-<qube name>` scripts, receiving token (e.g. username) as command line option and printing password to stdout. It is called by `liteqube.SplitPassword` service that can be used by other qubes for password provisioning. If there is no password present in core-keys, a qube can call `liteqube.SplitPassword` in dom0, you will then be prompted for password and also prompted if it shall be saved into core-keys. Have a look at core-decrypt or core-rdp scripts to see how this works.
- SSH keys: this is based on ability of ssh-agent to run on a different machine. You store your ssh keys in core-keys in `/home/user/.ssh` as you would do normally. In a qube that needs to use these keys you should start `liteqube-split-ssh.socket` and you should *not* start local ssh-agent. Have a look at core-vpn-ssh scripts to see how this works. 
- GPG support: similar to ssh-agent, this is based on gpg-agent being able to work over network. Done in preparation for mail qubes integration.

### Further development
I use the following components in my daily work, installer scripts will be made available in the coming months:
 - Mail: a couple of qubes that allow mail to be received and sent while keeping your Thunderbird (or any other mail app) offline. Instructions for this one were published [here](https://www.reddit.com/r/Qubes/comments/9q76f2/splitmail_setup/) a few years back.
 - VPN: add openvpn support
 - RDP/VNC: polish vnc support
 
The following improvements will be made to further enhance security and stability of the setup:
 - Improve security of Liteqube systemd services using builtin systemd tools.
 - Use SELinux (preferred but very difficult due to lack of default profiles) or AppArmour (easier but possibly less secure) to improve security of the apps (networkmanager, tor, exim, getmail, etc) used.
 - Create minimal tray applet to monitor network, tor state and sound volume.
 - Add accelerated (see #[130](https://github.com/mirage/qubes-mirage-firewall/issues/130)) mirage firewall.
 - Move from shell scripts to Salt. Liteqube for Qubes 4.1 was started as a set of salt scripts but I switched to pure shell once I realised I spend more time fighting with salt formulas than improving Liteqube.

### Changelog

25 December 2021, version 0.90 'Bare Essentials':
 - Initial relese
 - Includes base system, network and usb components
 
12 February 2022, version 0.91 'Almost There':
 - All changes to debian-core are now persistent and survive system updates
 - Added vpn, storage, vnc/rdp and audio qubes

26 June 2022, version 0.92
 - Added printing support
 - Added mirage firewall working on Qubes 4.1, switched to mirage firewall by default
 - Fixed empty folders not pulled into git repo, ruining the installation
