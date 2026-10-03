-- Let the terminal provide the background on every platform. Reapply after a
-- colorscheme change because themes reset highlight groups when they load.
local transparent_groups = {
  "EndOfBuffer",
  "FloatBorder",
  "FloatTitle",
  "FoldColumn",
  "LazyNormal",
  "MasonNormal",
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "Normal",
  "NormalFloat",
  "NormalNC",
  "SignColumn",
  "SnacksNormal",
  "SnacksNormalNC",
  "StatusLine",
  "StatusLineNC",
  "TabLine",
  "TabLineFill",
  "TabLineSel",
  "TelescopeBorder",
  "TelescopeNormal",
  "WhichKeyNormal",
  "WinBar",
  "WinBarNC",
}

local function apply_transparent_background()
  for _, group in ipairs(transparent_groups) do
    vim.cmd(("highlight %s guibg=NONE ctermbg=NONE"):format(group))
  end
end

local function refresh_transparent_background()
  apply_transparent_background()
  vim.schedule(apply_transparent_background)
end

local transparent_background = vim.api.nvim_create_augroup("transparent_background", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = transparent_background,
  callback = refresh_transparent_background,
})
vim.api.nvim_create_autocmd("VimEnter", {
  group = transparent_background,
  once = true,
  callback = refresh_transparent_background,
})
vim.api.nvim_create_autocmd("User", {
  group = transparent_background,
  pattern = "VeryLazy",
  once = true,
  callback = refresh_transparent_background,
})

refresh_transparent_background()

-- Update LazyVim and all managed plugins from their configured branches at
-- most once per day. Set LAZYVIM_AUTO_UPDATE=0 to disable this temporarily.
if vim.env.LAZYVIM_AUTO_UPDATE ~= "0" then
  vim.schedule(function()
    local stamp = vim.fn.stdpath("state") .. "/lazyvim-auto-update"
    local stat = vim.uv.fs_stat(stamp)
    local last_update = stat and stat.mtime.sec or 0

    if os.time() - last_update < 86400 then
      return
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyUpdate",
      once = true,
      callback = function()
        vim.fn.mkdir(vim.fn.fnamemodify(stamp, ":h"), "p")
        vim.fn.writefile({ tostring(os.time()) }, stamp)
      end,
    })

    require("lazy").update({ show = false })
  end)
end
