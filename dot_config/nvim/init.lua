vim.g.mapleader = " "
vim.g.maplocalleader = " "

local options = {
  breakindent = true,
  clipboard = "unnamedplus",
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

vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Write file" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
