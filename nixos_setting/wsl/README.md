# NixOS-WSL development environment

This replaces the former Gentoo WSL profile with a declarative,
development-only NixOS configuration. Windows remains the host operating
system; NixOS-WSL supplies the Linux userland.

The flake follows `nixos-unstable`, and language runtimes use the unversioned
Nixpkgs package names. `flake.lock` records a reproducible snapshot rather than
permanently fixing tool versions; `nix flake update` advances the whole
environment to a newly tested upstream snapshot.

## Scope

The default configuration keeps:

- Git, GnuPG, SSH, Emacs, Zsh, direnv and common CLI tools;
- GCC, LLVM/Clang, CMake, Ninja, Xmake, mold and debuggers;
- Rust, Python with uv/pixi, Node.js with pnpm/Bun, Java and Typst;
- PostgreSQL development tools without enabling a database service;
- `nix-ld` for editor extensions and third-party development binaries.

It intentionally omits:

- a Linux desktop, display manager and full WSLg application stack;
- Linux kernel, bootloader, firmware and hardware-management configuration;
- Gentoo Portage profiles, USE flags, compiler exceptions and overlays;
- server daemons that are not required for local development.

CUDA compiler/runtime tools are retained as the optional `nixos-wsl-cuda`
configuration because they add a large closure and require unfree packages.
The Windows driver bridge is already enabled through `wsl.useWindowsDriver`.
WSLg supplies both Wayland and X11 compatibility sockets. Firefox and
Electron/Chromium applications prefer native Wayland, while WSLg's existing
`DISPLAY` socket remains available for XWayland fallback; NixOS does not start
a second display server inside WSL.

## Apply

The target is the existing `NixOS` WSL distribution. Run the deployment script
from this directory inside NixOS-WSL:

```bash
sudo ./install.sh
```

The script copies the canonical flake to `/etc/nixos`, validates it, and creates
the next boot generation. Subsequent rebuilds can be run from any directory:

```bash
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos-wsl
sudo nixos-rebuild switch --flake /etc/nixos#nixos-wsl
```

Use `/etc/nixos#nixos-wsl-cuda` instead when CUDA development tools should be
installed.

If the repository is stored on Windows, enter it through `/mnt/c/...` first.
For better filesystem performance during daily development, keep source trees
under `/home/lty`.

## Fresh WSL installation from GitHub

First install the current `nixos.wsl` image from the NixOS-WSL releases. With
WSL 2.4.4 or newer, PowerShell can import the downloaded image directly:

```powershell
wsl --install --from-file .\nixos.wsl --name NixOS
wsl -d NixOS
```

Inside the new distribution, clone and stage this configuration:

```bash
cd /tmp
nix --extra-experimental-features 'nix-command flakes' \
  shell github:NixOS/nixpkgs/nixos-unstable#git -c \
  git clone https://github.com/Cyberl-ty02/dotfiles.git

cd dotfiles/nixos_setting/wsl
sudo ./install.sh
exit
```

Because the image initially uses `nixos` while this flake changes the default
user to `lty`, activate the boot generation using this sequence in PowerShell:

```powershell
wsl --terminate NixOS
wsl -d NixOS --user root -- true
wsl --terminate NixOS
wsl -d NixOS
```

The first `lty` Zsh login asks for a password. Afterward, `/etc/nixos` is
self-contained and rebuilds do not depend on the temporary Git clone.

## User and password

The sole regular user is `lty` (UID 1000), with `/home/lty` as its home
directory and Zsh as its login shell.

On the first interactive Zsh login, the configuration checks whether the
password is still locked and automatically runs `sudo passwd lty`. Nothing is
echoed while the new password is entered. It can also be run manually:

```bash
sudo passwd lty
```

Alternatively, set it directly from PowerShell as root:

```powershell
wsl -d NixOS --user root -- passwd lty
```

Verify the active account:

```bash
whoami
echo "$HOME"
id
sudo -v
```

## Update and verify

```bash
nix flake update
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos-wsl
sudo nixos-rebuild switch --flake /etc/nixos#nixos-wsl

nixos-version
whoami
git --version
gcc --version
rustc --version
python --version
node --version
```

References:

- https://github.com/nix-community/NixOS-WSL
- https://nix-community.github.io/NixOS-WSL/install.html
- https://nix-community.github.io/NixOS-WSL/how-to/change-username.html
- https://nixos.org/manual/nixos/stable/
