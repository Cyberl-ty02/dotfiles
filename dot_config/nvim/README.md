# LazyVim configuration

This directory is based on the official LazyVim Starter and is shared by the
Gentoo PC and WSL profiles.

- `LazyVim/LazyVim` follows its `main` branch.
- lazy.nvim checks and applies plugin updates at most once every 24 hours when
  Neovim starts.
- Set `LAZYVIM_AUTO_UPDATE=0` before starting Neovim to skip automatic updates.
- Each account keeps its own plugins and state below its own XDG data/state
  directories. Never share those writable directories between the regular user
  and root.

The root account runs plugin code with full privileges. Review configuration
changes as the regular user first, and use the disable switch when recovering
from an upstream regression.
