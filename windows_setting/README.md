# Windows host configuration

This directory contains host-side Windows and WSL configuration.

## Neovim

`../dot_config/nvim` is the only tracked Neovim configuration. The installer
creates a directory junction at `%LOCALAPPDATA%\nvim`, so Windows and Gentoo use
the same Git-tracked Lua configuration without copying or maintaining parallel
versions. Windows keeps its plugins and runtime state separately in
`%LOCALAPPDATA%\nvim-data`.

From the repository root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows_setting\install_nvim.ps1
```

If `%LOCALAPPDATA%\nvim` already contains another configuration, the installer
refuses to replace it. Use `-BackupExisting` to rename the existing directory to
a timestamped backup before creating the junction. Use `-SkipValidation` only
when the network is temporarily unavailable and LazyVim cannot bootstrap.

Recommended command-line dependencies can be installed with Scoop:

```powershell
scoop.cmd install git ripgrep fd fzf lazygit tree-sitter stylua shfmt
```

Tree-sitter also needs a C compiler. The shared configuration automatically
selects `clang` on Windows when it is available and `CC` is not already set.

LazyVim follows its upstream `main` branch. It updates automatically at most
once per day; run `:Lazy sync` at any time to update immediately. Set the
process environment variable `LAZYVIM_AUTO_UPDATE=0` when an automatic update
must be temporarily disabled.
