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
