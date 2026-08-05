# Secure Boot with shim and rEFInd

This laptop has a dedicated EFI System Partition mounted directly at `/boot`.
Its active boot entry points to `\EFI\refind\BOOTX64.EFI`.

The boot chain is:

```text
/boot/EFI/refind/BOOTX64.EFI     Microsoft-signed shim
/boot/EFI/refind/mmx64.efi       MokManager
/boot/EFI/refind/grubx64.efi     locally signed rEFInd payload
/boot/EFI/refind/refind.conf     rEFInd configuration
```

Shim uses the fixed next-stage filename `grubx64.efi`. In this setup that file
is a signed copy of `refind_x64.efi`; GRUB is not installed or used.

The reusable configuration in this directory accompanies the troubleshooting
note [Gentoo 在 Btrfs 与 rEFInd 环境下的启动修复记录](https://kagaranakaki.top/posts/gentoo-refind-btrfs-rescue/).

## Keys

The expected private key/certificate bundle and public enrollment certificate
are:

```text
/etc/kernel/secureboot/MOK.pem
/etc/kernel/secureboot/MOK.cer
```

`MOK.pem` contains the private key. Keep it local, root-owned, mode `0600`, and
never commit or share it. Generate and request enrollment with:

```bash
sudo /etc/kernel/secureboot/generate_mok.sh
sudo /etc/kernel/secureboot/import_mok.sh
```

The certificate Common Name defaults to the privacy-neutral label `kl`. Override
it with an ASCII label when generating a new key:

```bash
sudo env MOK_CN=xxx /etc/kernel/secureboot/generate_mok.sh
```

After reboot, use MokManager to finish enrolling the key.

## Install packages and confirm signing

Install the required packages and copy this directory to
`/etc/kernel/secureboot`:

```bash
sudo emerge --ask sys-boot/refind sys-boot/shim sys-boot/mokutil sys-boot/efibootmgr
findmnt /boot
grep -E '[[:space:]]/boot[[:space:]]' /etc/fstab
```

The `secureboot` USE flag on `sys-boot/refind` tells Portage to sign its EFI
executables with `SECUREBOOT_SIGN_KEY` and `SECUREBOOT_SIGN_CERT`. Verify the
emerge output and the resulting signature instead of assuming that signing
succeeded.

Choose one of the two installation methods below. Do not alternate between
them without first comparing the existing ESP layout and NVRAM entry.

## Method A: refind-install with shim

The Gentoo Shim documentation recommends passing the packaged shim directly to
rEFInd's installer:

```bash
sudo refind-install --shim /usr/share/shim/BOOTX64.EFI
```

This method lets `refind-install` copy rEFInd and the shim support files to the
ESP, prepare the shim-compatible follow-on loader name, and create an NVRAM
entry. Read the full command output: the detected ESP, copied paths, and newly
created boot entry must match this host.

Important details:

- `/boot` should be mounted and represented correctly in `/etc/fstab` before
  running the command. Otherwise `refind-install` may select a different ESP
  path such as `/boot/efi`.
- Shim must start before rEFInd. The packaged shim normally looks for a sibling
  `grubx64.efi`; when installed this way that compatibility filename contains
  rEFInd, not GRUB.
- `refind-install` can create `refind.conf`, an NVRAM entry, and
  `refind_linux.conf`. Review all three before rebooting.
- Run it from the installed Gentoo system whenever possible. Its generated
  Linux options are based on the current `/proc/cmdline` and can inherit LiveCD
  parameters when run from rescue media.

After installation, inspect rather than immediately rebooting:

```bash
sudo efibootmgr -v
find /boot/EFI -maxdepth 3 -type f
find /boot -name refind_linux.conf -print
```

## Method B: repository fixed-layout installer

The existing host uses a fixed `/boot/EFI/refind` layout. To preserve that
layout, run the repository installer instead of Method A:

```bash
sudo /etc/kernel/secureboot/install_bootloader.sh
```

The installer refuses to continue unless `/boot` is mounted. It preserves the
existing `refind.conf`, refreshes shim and MokManager, signs the installed rEFInd
binary with the local MOK, and writes it as
`/boot/EFI/refind/grubx64.efi`, the compatibility filename expected by shim.

Create the firmware entry once, substituting the actual disk and ESP partition:

```bash
sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --loader '\EFI\refind\BOOTX64.EFI' --label 'rEFInd Boot Manager' --unicode
```

Do not copy the example disk or partition number without checking `lsblk` and
`findmnt /boot`.

## Kernel options

`refind-install` or `mkrlconf` may create `/boot/refind_linux.conf` from the
currently running kernel's `/proc/cmdline`. Do not trust an automatically
generated file when working from a LiveCD or unrelated rescue environment.

Start from [`refind_linux.conf.example`](refind_linux.conf.example), then
replace the UUID, Btrfs subvolume and filenames with values verified on the
target host.

## Verify and maintain

Before rebooting, retain a known-good EFI entry or rescue medium. Then inspect:

```bash
mokutil --sb-state
mokutil --test-key /etc/kernel/secureboot/MOK.cer
sudo efibootmgr -v
sbverify --list /boot/EFI/refind/grubx64.efi
find /boot/EFI -maxdepth 3 -type f
```

After booting Gentoo:

```bash
cat /proc/cmdline
findmnt /
uname -r
ls /lib/modules/"$(uname -r)"
```

rEFInd discovers installed kernels directly, so kernel updates do not require a
generated boot menu. After rEFInd or shim updates, rerun
the same installation method originally selected. Re-check `refind_linux.conf`,
because rescue media can contaminate auto-generated kernel options.

References:

- https://wiki.gentoo.org/wiki/REFInd
- https://wiki.gentoo.org/wiki/Shim
- https://www.rodsbooks.com/refind/installing.html
- https://www.rodsbooks.com/refind/secureboot.html
