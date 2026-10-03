-- Apply host-specific compatibility before bootstrapping the shared config.
require("config.platform")

-- Bootstrap lazy.nvim, LazyVim, and local plugin specifications.
require("config.lazy")
