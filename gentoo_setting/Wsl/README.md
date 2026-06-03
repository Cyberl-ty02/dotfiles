# Gentoo WSL profile

Target:

- Windows 11 remains the only real operating system.
- Gentoo inside WSL2 is a Linux development userland.
- No real kernel, GRUB, Secure Boot, SDDM, SonicDE/XLibre, NetworkManager, or NVIDIA kernel module stack.
- Light WSLg support for individual GUI apps only.
- Multilib-aware, but only valid if the selected profile is multilib.

## Main changes from the old WSL config

- Removed `xanmod-kernel`, `linux-firmware`, `grub`, `shim`, `sddm`, `xlibre-server`, `sonic-meta`, and `nvidia-drivers` from the normal WSL world/config.
- Removed global `-flto` and broad desktop USE flags.
- Kept development tools: Git/GPG/SSH, Emacs/Doom, Rust, Python/uv/pixi, Node/pnpm, Java, Typst.
- Added package-level GCC fallbacks for `darts`, `doxygen`, `fmt`, and `spdlog`.

## Apply

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

Do not install `x11-drivers/nvidia-drivers` in WSL. GPU access is provided by the Windows-side NVIDIA driver.
