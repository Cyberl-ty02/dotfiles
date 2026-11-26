# Gentoo WSL profile

Target:

- `default/linux/amd64/23.0/desktop`, Clang/LLVM preferred with GCC fallbacks, and OpenRC.
- Windows 11 remains the only real operating system.
- Gentoo inside WSL2 is a Linux development userland.
- No real kernel, GRUB, Secure Boot, SDDM, SonicDE/XLibre desktop stack,
  NetworkManager, or NVIDIA kernel module stack.
- Light WSLg support for individual GUI apps only.
- Multilib is **not forced**; the selected profile keeps the normal `ABI_X86="64"` default.

## Configuration Policy

- The `make.conf` baseline:
  - keeps portable `COMMON_FLAGS="-O2 -pipe"` instead of `-march=native`, with
    ThinLTO for Clang C/C++ and standard LTO for GCC Fortran;
  - keeps `-passwdqc video_cards_d3d12`;
  - keeps the amd64/23.0 binhost in `binrepos.conf/gentoo.conf`;
  - selects Clang/LLVM globally while retaining package-level GCC fallbacks;
  - does **not** force global `PYTHON_TARGETS`;
  - does **not** force `ABI_X86="64 32"`.
  - keeps Portage's stage3-compatible wget fetch defaults.
- The Gentoo repository uses the USTC Git mirror for shallow clones and routine
  incremental sync. CERNET is the first fallback, but some participating mirrors
  only provide Git dumb HTTP; enabling it also requires `sync-depth = 0` and a
  large full-history clone. The official Git mirror precedes TUNA so queued TUNA
  syncs cannot delay routine recovery. A fresh stage3 can bootstrap with rsync
  before Git is installed; optional overlays use Git after the base setup.
- Git sync verifies commit signatures with the packaged local Gentoo Release
  Key, keeps Portage's key refresh enabled to detect revocations, and rejects
  repository timestamps older than three days. The official binary package
  repository still verifies signatures, and package Manifest checks remain enabled.
- WSL remains CLI/dev focused:
  - Git/GPG/SSH, Doom Emacs, Rust, Python/uv/pixi, Bun, Java, Typst.
- Hardware/full-desktop packages remain masked:
  - kernel, firmware, GRUB, shim, nvidia-drivers, SDDM, and SonicDE;
  - the XLibre overlay is registered for parity and package metadata, but its
    server is not selected in world. WSLg supplies the display stack, while
    individual applications may still use Xwayland.
- Development additions from the active WSL config:
  - the mold package (enabled after a Clang ThinLTO link test), `bun-bin`,
    and the Rust binary toolchain;
  - clinfo, CUDA tooling, and thefuck are included in `world_packages.txt`.
- Kept package-level fixes:
  - `darts` uses GCC + C++14;
  - `doxygen` is forced `-clang`;
  - memory-heavy builds use the shared `lowjobs` environment.

Global ThinLTO is enabled and mold is the default linker, with the commented lld
line retained as a fallback. Sensitive packages use the existing compatibility
environments where required, and glibc
remains on GCC because its Clang mode is experimental.
`COMMON_FLAGS`, `CLANG_LTO_FLAGS` and `FORTRAN_LTO_FLAGS` are independent knobs;
GCC compatibility environments use their own LTO and language-standard flags.

## Apply

For the first import, start the distro as root (`wsl.exe -d Gentoo -u root`).
Initialize the main tree, select `default/linux/amd64/23.0/desktop`, and install Git,
Clang, LLD, LLVMgold, and mold with the stage4 settings. From this repository root:

```sh
python3 gentoo_setting/scripts/deploy-portage.py wsl repos
python3 gentoo_setting/scripts/deploy-portage.py wsl repos --apply
LC_ALL=C.UTF-8 emerge --sync
python3 gentoo_setting/scripts/deploy-portage.py wsl config
python3 gentoo_setting/scripts/deploy-portage.py wsl config --apply
emerge --pretend --verbose --update --deep --newuse @world
```

The helper checks the target profile, keeps the existing main tree sync method,
and backs up `/etc/portage` before writing. WSL has its own Portage policy and
receives no musl patches. Use `xargs -a gentoo_setting/wsl/world_packages.txt emerge
--pretend --verbose --noreplace` to review the optional world selection, then
install the selected atoms with `emerge --ask`. Follow the
[WSL setup notes](https://kagaranakaki.top/posts/gentoo-wsl-migration-notes/gentoo-wsl-migration-notes/)
for the initial import sequence and the desktop/GPU boundaries.

The repository's `wsl.conf` uses `kl` as an anonymous public-template identity.
Set the actual default account in the target's `/etc/wsl.conf`.

For a new public-template installation, create the anonymous default user before
restarting WSL if it does not exist:

```bash
useradd -m -s /bin/bash -G wheel,audio,video kl
```

Set a local password with `passwd kl` before relying on the repository's
password-requiring `doas` policy. Root remains reachable with
`wsl.exe -d Gentoo -u root`.

Do not install `x11-drivers/nvidia-drivers` in WSL. GPU access is provided by the Windows-side NVIDIA driver.
