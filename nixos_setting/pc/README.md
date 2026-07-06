# NixOS PC profile

This is the physical-PC counterpart to the WSL development profile. It provides
Plasma 6, SDDM, NetworkManager, PipeWire, printing, Bluetooth, input methods,
desktop applications and the same broad development toolchain. Firmware
updates, periodic SSD trimming, SMART monitoring and Thunderbolt authorization
are enabled to retain the useful hardware-management parts of the Gentoo
laptop profile. Disk swap is replaced by a zstd-compressed zram device sized
at 50% of RAM.

Plasma and SDDM use Wayland explicitly. The standalone Xorg server is disabled,
while XWayland remains enabled for legacy applications. Firefox and
Electron/Chromium applications are directed to their native Wayland backends;
Qt and GTK retain automatic X11 fallback.

The flake follows `nixos-unstable`. Unversioned package attributes such as
`jdk`, `nodejs`, `postgresql` and `python3` move naturally with Nixpkgs.
`flake.lock` remains intentional: it makes a deployment reproducible, while
`nix flake update` advances the complete system as one reviewed snapshot.

## Hardware file is mandatory

`hardware-configuration.nix` is only an evaluation template. Do **not** install
or switch to this PC configuration until it has been replaced with the file
generated on the actual target PC:

```bash
sudo nixos-generate-config --show-hardware-config \
  > hardware-configuration.nix
```

Review its filesystems and confirm that the EFI System Partition is mounted at
`/boot`. Disk layout, storage drivers, CPU microcode and hybrid-GPU PCI bus IDs
must never be guessed from another machine.

## Fresh physical installation

Boot the official NixOS installer in UEFI mode and connect to the network.
Back up every important file first: partitioning always carries a risk of data
loss.

Clone the repository into the live environment and select a profile:

```bash
cd /tmp
nix --extra-experimental-features 'nix-command flakes' \
  shell github:NixOS/nixpkgs/nixos-unstable#git -c \
  git clone https://github.com/Cyberl-ty02/dotfiles.git

cd dotfiles/nixos_setting/pc
sudo ./install.sh pc
# Or: sudo ./install.sh pc-nvidia
# Or: sudo ./install.sh pc-nvidia-cuda
```

The installer keeps storage preparation, installation and Secure Boot as
separate decisions. All continue prompts default to no:

1. whether to enter the interactive storage helper;
2. after reviewing the mounted layout, whether to install NixOS;
3. whether to stage the post-install Lanzaboote Secure Boot workflow.

If storage preparation is declined, mount the root at `/mnt` and its EFI
System Partition at `/mnt/boot` yourself before continuing.

The script then generates the actual machine-specific
`hardware-configuration.nix`, validates the flake, installs the selected
profile, copies the canonical configuration to `/mnt/etc/nixos`, and prompts
for the `lty` password. Its generated hardware file only changes the temporary
installation checkout; commit it later only if you want that machine-specific
data in Git.

## Interactive storage layout

`prepare-btrfs.sh` has no 80 GB policy. It displays every free extent on the
selected GPT disk and lets the user choose one by number. It then asks for the
EFI and Linux sizes:

- `NIXOS_BOOT` is created first as a FAT32 ESP; the default is 1024 MiB and
  the technical minimum is 512 MiB;
- `NIXOS_ROOT` follows as Btrfs and uses the remainder by default, but an
  explicit size may be entered;
- when space remains, it may optionally create a third, unformatted
  `SHARED_DATA` partition. Format that partition as NTFS later using Windows or
  GParted; the installer does not write a data filesystem.

The helper prints partitions sorted by physical start offset. GPT partition
numbers can differ on an existing Windows disk, so the role labels and start
offsets are authoritative rather than assumptions about `p1`, `p2` or `p3`.
It never shrinks an existing volume.

Writing the plan requires the exact disk path and selected range. After
formatting it stops again, prints the resulting layout, and requires
`MOUNT NEW` before it creates `@`, `@home`, `@nix`, `@log`, and `@snapshots`
with `compress=zstd:3,noatime`. Even after mounting, `install.sh` separately
asks whether NixOS should actually be installed.

## Reuse partitions made with GParted

Choose workflow 2 in `prepare-btrfs.sh` when a normal GParted installation or
GParted Live session has already created:

- an unmounted FAT EFI System Partition;
- a different unmounted Btrfs Linux partition on the same selected disk.

The helper validates both filesystem types and parent disk. If the FAT
partition lacks the GPT ESP flag, setting it requires a separate exact
confirmation. It then mounts that partition read-only to display up to the
first few entries, does not delete its contents, and requires
`MOUNT EXISTING`.

The Btrfs top level must either be completely empty or contain exactly
`@`, `@home`, `@nix`, `@log`, and `@snapshots` as real subvolumes. An empty
filesystem receives that layout automatically. Any unrelated top-level data,
partial layout or ordinary directory with a reserved subvolume name causes a
refusal rather than an overwrite.

No disk swap partition is created in either workflow; `zramSwap` supplies
compressed swap in memory.

## Profiles

- `.#pc`: open-source/default graphics stack.
- `.#pc-nvidia`: current Nixpkgs NVIDIA production driver.
- `.#pc-nvidia-cuda`: NVIDIA driver plus CUDA development tools.
- Append `-secureboot` to any of the above after completing one successful
  normal systemd-boot startup.

For a hybrid Intel/NVIDIA laptop, add the detected PRIME bus IDs to
`nvidia.nix` before installation. The generic NVIDIA profile assumes a
single-GPU or firmware-managed system.

## XLibre and dual boot

XLibre and OpenBSD Xenocara are not currently packaged as supported NixOS
display-server replacements by the pinned Nixpkgs snapshot. A third-party
overlay is intentionally not injected into the base system: native Wayland
plus the maintained XWayland compatibility server is the smaller and safer
fallback.

systemd-boot remains the bootloader. It detects Windows automatically when
both systems use the same EFI System Partition. With this laptop's independent
Windows and Linux EFI partitions, select Windows from the firmware boot menu;
systemd-boot cannot directly launch an EFI executable on another ESP. GRUB is
therefore not needed for the independent-disk layout.

Other Gentoo-only choices are also intentionally not copied: SonicDE is not
available in Nixpkgs and the generic NixOS kernel is safer than assuming XanMod
on unknown hardware.

## Optional Secure Boot

Secure Boot uses the pinned Lanzaboote v1.1.0 module and a machine-local sbctl
key bundle. Private keys live under `/var/lib/sbctl` and never in this
repository.

Do not install a `-secureboot` profile initially. Lanzaboote requires the
machine to boot normally with systemd-boot first. If Secure Boot was selected
during installation, the installer prints the next command; it may also be
run later:

```bash
sudo /etc/nixos/enable-secureboot.sh pc
# Or use pc-nvidia / pc-nvidia-cuda.
```

The helper verifies UEFI and systemd-boot, requires the phrase
`PREPARE SECURE BOOT`, creates local keys if necessary, switches to the matching
Lanzaboote profile, and runs `sbctl verify`. It intentionally does not change
firmware state or enroll keys. Follow its printed steps to enter firmware
Setup Mode and then enroll with Microsoft certificates retained:

```bash
sudo sbctl enroll-keys --microsoft
```

Firmware implementations vary and a mistake can leave the system unbootable.
Keep the NixOS installer available and read the Lanzaboote instructions for the
specific motherboard before changing Setup Mode. Retain the Windows BitLocker
recovery key as firmware trust changes may trigger a recovery check.

## Build and apply

Test before switching:

```bash
nix flake check
sudo nixos-rebuild build --flake .#pc
sudo nixos-rebuild test --flake .#pc
sudo nixos-rebuild switch --flake .#pc
```

Set the local password from the installer before rebooting:

```bash
sudo nixos-enter --root /mnt -c 'passwd lty'
```

Update as a coherent upstream snapshot:

```bash
nix flake update
sudo nixos-rebuild build --flake .#pc
sudo nixos-rebuild switch --flake .#pc
```

References:

- https://nixos.org/manual/nixos/stable/
- https://wiki.nixos.org/wiki/NixOS_system_configuration
- https://wiki.nixos.org/wiki/Dual_Booting_NixOS_and_Windows
- https://wiki.nixos.org/wiki/Systemd/boot
- https://arch.icekylin.online/guide/rookie/basic-install
- https://nix-community.github.io/lanzaboote/
- https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html
