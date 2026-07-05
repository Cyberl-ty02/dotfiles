# NixOS-WSL development environment

This replaces the former Gentoo WSL profile with a declarative,
development-only NixOS configuration. Windows remains the host operating
system; NixOS-WSL supplies the Linux userland.

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
- https://nixos.org/manual/nixos/stable/
