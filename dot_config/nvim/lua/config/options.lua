-- Options are loaded before lazy.nvim starts.
local options = {
  breakindent = true,
  cursorline = true,
  expandtab = true,
  ignorecase = true,
  mouse = "a",
  number = true,
  relativenumber = true,
  shiftwidth = 2,
  signcolumn = "yes",
  smartcase = true,
  splitbelow = true,
  splitright = true,
  tabstop = 2,
  termguicolors = true,
  undofile = true,
  updatetime = 250,
}

for name, value in pairs(options) do
  vim.opt[name] = value
end

local has_clipboard_provider = vim.fn.has("win32") == 1
  or vim.fn.has("mac") == 1
  or vim.fn.executable("xclip") == 1
  or vim.fn.executable("xsel") == 1
  or vim.fn.executable("wl-copy") == 1

if has_clipboard_provider then
  vim.opt.clipboard = "unnamedplus"
end
