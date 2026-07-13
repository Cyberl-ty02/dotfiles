# Secure Boot with shim and GRUB

This laptop has a dedicated EFI System Partition mounted directly at `/boot`.
Its Gentoo boot files therefore live in `/boot/EFI/Gentoo`, not under
`/boot/efi`.

The setup follows the current Gentoo Handbook workflow: `sys-boot/grub` with
the `secureboot` USE flag builds a signed standalone GRUB image. Shim,
MokManager, that image, and its external `grub.cfg` are installed together:

```text
/boot/EFI/Gentoo/shimx64.efi
/boot/EFI/Gentoo/mmx64.efi
/boot/EFI/Gentoo/grubx64.efi
/boot/EFI/Gentoo/grub.cfg
```

Shim loads the sibling `grubx64.efi`; the firmware boot entry must point to
`\EFI\Gentoo\shimx64.efi`.

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

The certificate Common Name defaults to the privacy-neutral label `kl`. It is
only a public certificate label and does not need to contain a legal or personal
name. Override it with an ASCII label such as `xxx` when generating a new key:

证书通用名称（CN）默认为不暴露隐私的标签 `kl`。它只是公开的证书标签，无需填写
真实姓名。生成新密钥时可以用 `xxx` 等 ASCII 标签覆盖：

```bash
sudo env MOK_CN=xxx /etc/kernel/secureboot/generate_mok.sh
```

After reboot, use MokManager to finish enrolling the key.

The laptop `make.conf` points GRUB, kernel, and module signing at `MOK.pem`.

## Install the boot chain

Install the required packages, then copy this directory to
`/etc/kernel/secureboot`. Rebuild GRUB after generating the key so Portage can
produce `/usr/lib/grub/grub-x86_64.efi.signed`:

```bash
sudo emerge --ask sys-boot/grub sys-boot/shim sys-boot/mokutil sys-boot/efibootmgr
sudo emerge --ask --oneshot sys-boot/grub
sudo /etc/kernel/secureboot/install_bootloader.sh
sudo env-update
```

The installer refuses to continue unless the dedicated `/boot` partition is
mounted. It also installs `/etc/env.d/99grub`, which directs
`installkernel[grub]` to update `/boot/EFI/Gentoo/grub.cfg` after kernel
installations.

Create the firmware entry once, substituting the actual Gentoo disk and ESP
partition number:

```bash
sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --loader '\EFI\Gentoo\shimx64.efi' --label 'Gentoo (shim)' --unicode
```

Do not copy the example disk or partition number without checking `lsblk` and
`findmnt /boot`.

## Verify and maintain

After enrollment and enabling Secure Boot:

```bash
mokutil --sb-state
mokutil --test-key /etc/kernel/secureboot/MOK.cer
sudo efibootmgr
```

Kernel updates automatically regenerate the external `grub.cfg`. After a
`sys-boot/grub` or `sys-boot/shim` update, rerun
`install_bootloader.sh` to copy the updated EFI executables.

References:

- https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Bootloader
- https://www.setphaserstostun.org/posts/secure-boot-on-gentoo-with-shim-grub/
