-- Keep host-specific compatibility small so the rest of the configuration
-- remains identical across Windows, Gentoo, and WSL.
if vim.fn.has("win32") == 1 and vim.env.CC == nil and vim.fn.executable("clang") == 1 then
  -- LazyVim's Windows tree-sitter check recognizes an explicit CC but does not
  -- currently auto-detect clang. Reuse the installed LLVM toolchain.
  vim.env.CC = "clang"
end
