# Gentoo WSL profile, stage4-aligned

Target:

- Windows 11 remains the only real operating system.
- Gentoo inside WSL2 is a Linux development userland.
- No real kernel, GRUB, Secure Boot, SDDM, SonicDE/XLibre, NetworkManager, or NVIDIA kernel module stack.
- Light WSLg support for individual GUI apps only.
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
  - kernel, firmware, GRUB, shim, nvidia-drivers, SDDM, SonicDE/XLibre.
- Kept package-level fixes:
  - `darts` uses GCC + C++14;
  - `doxygen` is forced `-clang` and built with GCC;
  - `libfmt/spdlog/doxygen` use GCC fallback to avoid C++ ABI mixing.

## Apply

From the archive root:

```bash
sudo ./scripts/apply_wsl_config.sh
```

Then:

```bash
eselect profile show
./wsl/scripts/check_multilib.sh
sudo emerge --sync
sudo emerge -avuDN @world
```

If you later confirm that this Gentoo WSL stage4 uses a multilib profile and `gcc -m32` works, you may uncomment in `make.conf`:

```bash
ABI_X86="64 32"
```

Do not install `x11-drivers/nvidia-drivers` in WSL. GPU access is provided by the Windows-side NVIDIA driver.
