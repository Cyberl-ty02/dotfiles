# Doom Emacs configuration

This is the single private Doom configuration source for Gentoo PC, Gentoo
WSL, and Windows. Gentoo chezmoi deploys it as `~/.config/doom`; the root
deployment helper copies the same reviewed files with root ownership instead
of letting root execute files writable by the regular user. Windows links
`%APPDATA%\.config\doom` to this directory.

Doom itself lives in each account's `~/.config/emacs` checkout of the official
`doomemacs/core` repository so framework, package, cache, and generated state
remain account-local. Run `doom upgrade` to follow upstream and `doom sync`
after changing `init.el` or `packages.el`.

Deploy the regular-user configuration and framework:

```sh
gentoo_setting/scripts/deploy-doom.sh
```

Deploy the same reviewed configuration as root-owned files, with separate
root framework and package state:

```sh
gentoo_setting/scripts/deploy-doom.sh --root
```

Add `--upgrade` to either command to ask Doom to update its own checkout and
managed packages before synchronizing. The helper verifies every managed
private-config file after deployment. Root never executes a regular-user-
writable configuration directory.

On Windows, run `windows_setting/install_doom.ps1`. The framework checkout and
generated state stay in Emacs' default `%APPDATA%\.emacs.d`; the script accepts
both the former `doomemacs/doomemacs` origin and the current official
`doomemacs/core` origin, then normalizes it to the latter. Shell launchers rely
on the native Emacs and Doom defaults and do not redefine `HOME`, `EMACSDIR`,
or `DOOMDIR`.

Terminal editing buffers inherit the terminal emulator's background. GUI
frames and the dashboard keep the selected Doom theme's normal background.

Gentoo PC uses the native musl Neomacs with the same module selection as Windows;
`deploy-doom.sh` selects it for the CLI when available. Current upstream core
stores the full module suite in `sources/doom+`; both platform installers
initialize that tracked submodule before sync. They respect the revision recorded
by core, rather than independently updating its module branch. Rebuild generated
state after changing the runtime or moving the framework; do not copy bytecode,
package builds or environment snapshots between accounts or operating systems.

The PC's normal user GUI/TTY dashboard and core editing, and root's independent
TTY setup, have passed basic acceptance. Markdown preview uses Discount and
shell lint uses the official static ShellCheck package; neither needs GCC/GHC.
The optional Symbola check remains, with existing Unicode fallback fonts in use.
Detailed Neomacs compatibility limits and tested source baselines live in the PC
patchset README. This is not acceptance of every optional Doom language module.
