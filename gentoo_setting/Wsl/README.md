# Gentoo WSL profile, stage4-aligned

Target:

- Windows 11 remains the only real operating system.
- Gentoo inside WSL2 is a Linux development userland.
- No real kernel, GRUB, Secure Boot, SDDM, SonicDE, NetworkManager, or NVIDIA kernel module stack.
- Light WSLg support for individual GUI apps only.
- XLibre overlay access is enabled for optional WSLg experimentation, without pulling in a full desktop.
- Multilib is **not forced**. The uploaded original stage4 `make.conf` did not set `ABI_X86`, so this config keeps it commented until the profile is confirmed.

## What changed from the previous WSL config

- Rebased `make.conf` on the uploaded Gentoo WSL stage4 original:
  - keeps `COMMON_FLAGS="-O2 -pipe"` instead of `-march=native`;
  - keeps `-passwdqc video_cards_d3d12`;
  - keeps the stage4 binhost in `binrepos.conf/gentoo.conf`;
  - does **not** force global `clang`;
  - does **not** force global `PYTHON_TARGETS`;
  - does **not** force `ABI_X86="64 32"`.
- WSL remains CLI/dev focused:
  - Git/GPG/SSH, Emacs/Doom, Rust, Python/uv/pixi, Node/pnpm, Java, Typst.
- Hardware/full-desktop packages remain masked:
  - kernel, firmware, GRUB, shim, nvidia-drivers, SDDM, and SonicDE.
- Optional development additions from the active WSL config:
  - mold linker, bun-bin, clinfo, CUDA tooling, Rust binary toolchain, thefuck, and XLibre overlay access.
- Kept package-level fixes:
  - `darts` uses GCC + C++14;
  - `doxygen` is forced `-clang` and built with GCC;
  - `libfmt/spdlog/doxygen` use GCC fallback to avoid C++ ABI mixing.

## Apply

From `gentoo_setting/wsl`, back up the active configuration and replace it directly:

```bash
sudo cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
sudo rsync -a --delete portage/ /etc/portage/
sudo install -m 0644 wsl.conf /etc/wsl.conf
```

Then:

```bash
eselect profile show
sudo emerge --sync
sudo emerge -avuDN @world
```

If you later confirm that this Gentoo WSL stage4 uses a multilib profile and a manual `gcc -m32` smoke test works, you may uncomment in `make.conf`:

```bash
ABI_X86="64 32"
```

Do not install `x11-drivers/nvidia-drivers` in WSL. GPU access is provided by the Windows-side NVIDIA driver.
