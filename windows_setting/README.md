# Windows development settings

This directory is a self-contained chezmoi source for the Windows host. It
keeps portable text configuration in Git while leaving credentials, SSH keys,
shell history, browser data, extension state, and machine-specific caches
outside the repository.

The managed settings cover:

- Git identity through machine-local chezmoi data, plus portable Git defaults;
- WSL networking, Git Bash, Windows PowerShell 5.1, Windows Terminal, and Yazi;
- the shared cross-platform Doom Emacs configuration and VSCodium preferences;
- domestic registries for Cargo, npm, Bun, pip, Pixi, and uv.

Chezmoi copies ordinary configuration into the user profile. The generated
PowerShell loader sources the tracked profile from this checkout. The Doom
framework and generated package state remain in Emacs' native Windows default,
`%APPDATA%\.emacs.d`, while Doom's default `%APPDATA%\.config\doom` links to
the repository's shared
`dot_config\doom` directory.

## Deploy

From the repository root in Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows_setting\bootstrap.ps1
```

The default command installs chezmoi through an existing Scoop installation if
needed, applies configuration, and connects already-installed PowerShell and
Doom Emacs. It does not bulk-install applications. Git name and email are reused
from the current global Git configuration or requested once; they are written
only to chezmoi's local configuration.

Preview without changing managed files:

```powershell
.\windows_setting\bootstrap.ps1 -DryRun
```

Optional installation is explicit and split by purpose:

```powershell
# Portable command-line development baseline
.\windows_setting\bootstrap.ps1 -InstallCorePackages

# Extra tools useful only for some machines
.\windows_setting\bootstrap.ps1 -InstallOptionalPackages

# VSCodium and Windows Terminal through winget
.\windows_setting\bootstrap.ps1 -InstallWindowsApps

# Curated common and Windows-specific VSCodium extensions
.\windows_setting\bootstrap.ps1 -InstallEditorExtensions
```

The package lists and shared `../vscodium/` extension manifests are
intentionally conservative. Large local models, hardware utilities, game
tools, recovery media, and niche applications are not automatically reproduced.

## UniGetUI integration

UniGetUI remains an optional inventory and recovery layer, not a chezmoi
dependency. Chezmoi owns portable text configuration; UniGetUI can retain the
complete installed-package inventory, per-package install options, ignored
updates, and its existing private cloud backup. Credentials stay in Windows
Credential Manager and are never exported into this repository.

The explicit adapter detects the capabilities of the installed UniGetUI build:

```powershell
.\windows_setting\integrations\unigetui.ps1 -Action Status
```

Portable settings reproduce the current manager choices without importing
window geometry, telemetry identifiers, operation history, local paths, cloud
authentication, or ignored-update state. Import them only on a new machine or
after exporting the current settings, because UniGetUI replaces existing
settings during import:

```powershell
.\windows_setting\integrations\unigetui.ps1 -Action ExportSettings `
    -Path "$HOME\Documents\UniGetUI-settings.json"
.\windows_setting\integrations\unigetui.ps1 -Action ImportPortableSettings
```

When a future/current installation provides the official `uniget.exe` console
launcher, the same adapter exposes local/cloud backup and bundle operations:

```powershell
.\windows_setting\integrations\unigetui.ps1 -Action CreateLocalBackup
.\windows_setting\integrations\unigetui.ps1 -Action ImportBundle `
    -Path "$HOME\Documents\machine.ubundle"
```

Add `-Install` to an import/restore command only when packages should actually
be installed. Builds without the console launcher can still open a bundle in
the GUI with `-Action OpenBundle -Path <file>` for review and manual install.

After the first deployment, normal synchronization is:

```powershell
git pull --ff-only
chezmoi apply
.\windows_setting\install_doom.ps1
```

Chezmoi's generated config records `windows_setting` as its source directory,
so the short `chezmoi apply` command works from any directory. Use
`chezmoi diff` before applying when reviewing upstream changes.

## PowerShell 5.1

`powershell/profile.ps1` provides PSReadLine history search, an optional
oh-my-posh prompt, UTF-8 native-tool I/O, Doom Emacs editor variables, proxy
helpers, and a few small development aliases. It deliberately does not require
PowerShell 7 or modify the execution policy. Chezmoi owns the sole all-hosts
loader at `Documents\WindowsPowerShell\profile.ps1`; host-specific profiles are
left unmanaged.

The proxy helpers default to `127.0.0.1:7890` and can be customized through
`PROXY_HOST`, `PROXY_HTTP_PORT`, and `PROXY_SOCKS_PORT`:

```powershell
proxy
Get-ProxyStatus
nproxy
```

## Doom Emacs

Scoop supplies Emacs, while the official Doom framework checkout and generated
package state stay outside Git in `%APPDATA%\.emacs.d`. The shared private
configuration remains `../dot_config/doom` and is linked at deployment time,
so Windows and Gentoo consume the same reviewed files.

Install, repair, or resynchronize Doom with:

```powershell
.\windows_setting\install_doom.ps1
```

Use `-SkipSync` only when updating the link or origin offline. The installer
refuses to replace unrelated framework or private configuration directories;
`-BackupExisting` preserves them before proceeding. PowerShell and Git Bash use
small wrappers under `~/.local/bin`; Emacs and Doom discover their native
default paths without shell-specific directory overrides.

## Windows Terminal and Yazi

Windows Terminal customizations are intentionally additive. Chezmoi installs a
JSON fragment containing the portable Gruvbox theme and Scoop Git Bash profile,
then merges only the preferences in `terminal/preferences.json` into each
existing Terminal settings file. Generated Azure, Visual Studio, WSL, and other
machine-specific profiles remain local and are never copied into this repository.

Yazi overrides only its `edit` opener and calls the terminal Doom wrapper. It
uses an existing Emacs server when available and otherwise starts Doom in the
current terminal, while remaining independent of a specific Scoop version.

## Gentoo

The repository root is also a safe chezmoi source for Gentoo. Its root
`.chezmoiignore` restricts deployment to portable shell and Doom-related files,
leaving Portage, `doas.conf`, documentation, and Windows files as explicit
system-administration inputs rather than home-directory targets.
