# Gentoo WSL profile

Target:

- `default/linux/amd64/23.0/desktop`, GCC, and OpenRC.
- Windows 11 remains the only real operating system.
- Gentoo inside WSL2 is a Linux development userland.
- No real kernel, GRUB, Secure Boot, SDDM, SonicDE, NetworkManager, or NVIDIA kernel module stack.
- Light WSLg support for individual GUI apps only.
- XLibre overlay access is enabled for optional WSLg experimentation, without pulling in a full desktop.
- Multilib is **not forced**; the selected profile keeps the normal `ABI_X86="64"` default.

## Configuration Policy

- The `make.conf` baseline:
  - keeps `COMMON_FLAGS="-O2 -pipe"` instead of `-march=native`;
  - keeps `-passwdqc video_cards_d3d12`;
  - keeps the amd64/23.0 binhost in `binrepos.conf/gentoo.conf`;
  - does **not** force global `clang`;
  - does **not** force global `PYTHON_TARGETS`;
  - does **not** force `ABI_X86="64 32"`.
  - keeps Portage's stage3-compatible wget fetch defaults.
- The Gentoo repository uses verified rsync so a fresh stage3 can bootstrap
  before Git is installed; optional overlays use Git after the base setup.
- Signature verification stays enabled for repository sync and official binary
  packages, without globally rebuilding the stage3 solely for `verify-sig` USE.
- WSL remains CLI/dev focused:
  - Git/GPG/SSH, Emacs/Doom, Rust, Python/uv/pixi, Bun, Java, Typst.
- Hardware/full-desktop packages remain masked:
  - kernel, firmware, GRUB, shim, nvidia-drivers, SDDM, and SonicDE.
- Development additions from the active WSL config:
  - mold linker, `bun-bin`, Rust binary toolchain, and XLibre overlay access;
  - clinfo, CUDA tooling, and thefuck remain optional.
- Kept package-level fixes:
  - `darts` uses GCC + C++14;
  - `doxygen` is forced `-clang`;
  - memory-heavy builds use the shared `lowjobs` environment.

Global LTO and a global alternative linker are intentionally disabled. Packages follow
the selected Gentoo profile defaults, matching the laptop configuration policy.

## Apply

For the first import, start the distro as root (`wsl.exe -d Gentoo -u root`),
change to `gentoo_setting/wsl`, and run:

```bash
cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
cp -a portage/. /etc/portage/
install -m 0644 wsl.conf /etc/wsl.conf
```

Then:

```bash
eselect profile show
emerge --sync
emerge -avuDN @world
```

Create the configured default user before restarting WSL if it does not exist:

```bash
useradd -m -s /bin/bash -G wheel,audio,video lty
```

Set a local password with `passwd lty` before relying on the repository's
password-requiring `doas` policy. Root remains reachable with
`wsl.exe -d Gentoo -u root`.

Do not install `x11-drivers/nvidia-drivers` in WSL. GPU access is provided by the Windows-side NVIDIA driver.
