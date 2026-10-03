# LazyVim configuration

This directory is based on the official LazyVim Starter and is the single
configuration source shared by Windows, the Gentoo PC, and Gentoo WSL.

- `LazyVim/LazyVim` follows its `main` branch.
- lazy.nvim checks and applies plugin updates at most once every 24 hours when
  Neovim starts.
- Run `:Lazy sync` to synchronize with upstream immediately.
- Set `LAZYVIM_AUTO_UPDATE=0` before starting Neovim to skip automatic updates.
- Editor, dashboard, sidebar, floating-window, and status-line backgrounds are
  transparent, so Neovim inherits each terminal's existing background.
- Windows maps `%LOCALAPPDATA%\nvim` to this directory with a directory junction;
  run `windows_setting/install_nvim.ps1` from the repository root to create it.
- On Windows, an available `clang` is selected through `CC` for tree-sitter
  parser builds when no compiler has already been selected by the user.
- Each platform and account keeps plugins, cache, and state in its own Neovim
  data/state directories. Never share those writable directories between
  Windows and Gentoo, or between the regular user and root.

The root account runs plugin code with full privileges. Review configuration
changes as the regular user first, and use the disable switch when recovering
from an upstream regression.
