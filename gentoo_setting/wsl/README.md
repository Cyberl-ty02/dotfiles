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
- WSL remains CLI/dev focused:
  - Git/GPG/SSH, Emacs/Doom, Rust, Python/uv/pixi, Bun, Java, Typst.
- Hardware/full-desktop packages remain masked:
  - kernel, firmware, GRUB, shim, nvidia-drivers, SDDM, and SonicDE.
- Development additions from the active WSL config:
  - mold linker, Bun, Rust binary toolchain, and XLibre overlay access;
  - clinfo, CUDA tooling, and thefuck remain optional.
- Kept package-level fixes:
  - `darts` uses GCC + C++14;
  - `doxygen` is forced `-clang`;
  - memory-heavy builds use the shared `lowjobs` environment.

Global LTO and a global alternative linker are intentionally disabled. Packages follow
the selected Gentoo profile defaults, matching the laptop configuration policy.

## Apply

From `gentoo_setting/wsl`, back up the active configuration and replace it directly:

```bash
doas cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
doas rsync -a --delete --exclude=make.profile portage/ /etc/portage/
doas install -m 0644 wsl.conf /etc/wsl.conf
```

Then:

```bash
eselect profile show
doas emerge --sync
doas emerge -avuDN @world
```

Do not install `x11-drivers/nvidia-drivers` in WSL. GPU access is provided by the Windows-side NVIDIA driver.
