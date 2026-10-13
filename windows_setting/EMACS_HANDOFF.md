# Windows Emacs migration handoff

Windows 的目标编辑器是 Scoop 安装的 Emacs，并复用仓库根目录
`dot_config/doom/` 中的 Doom 私有配置。当前工作树中的 Neovim 文件只是等待
Windows 实机迁移的过渡输入，不再作为目标方案；验收后应只存在于 Git 历史。

此迁移应由能够直接访问 Windows 主机的 Codex 线程完成和验证。Linux 线程不
应猜测 Scoop shim、Windows Emacs 可执行文件名或 Yazi 的参数转义规则。

## Required changes

1. 核实 Scoop 当前 `emacs` manifest 及实际 shim，再将
   `packages/scoop-core.txt` 中的 `neovim` 替换为 `emacs`。
2. 为当前 Windows 用户建立独立的官方 `doomemacs/core` checkout；不要把
   Doom 框架、包 checkout、缓存或生成文件提交到本仓库。
3. 让 Windows 部署脚本从仓库根目录的 `dot_config/doom/` 部署
   `config.el`、`custom.el`、`init.el`、`packages.el` 和 `README.md`。
   遇到无关的既有配置必须先备份或停止，不得静默覆盖。
4. 将 PowerShell、Git Bash、Git 和 Yazi 的编辑器入口切换到经过实机验证的
   Emacs/Emacs Client 命令；涉及等待编辑完成的调用必须验证阻塞行为。
5. 删除 `install_nvim.ps1`、`dot_config/nvim/`、Neovim profile/Yazi 入口及
   其他只为 LazyVim 保留的包。不要删除用户数据，除非用户另行明确授权。
6. 保持平台差异最小化。确有需要时在共享 Emacs Lisp 中使用 Windows 条件，
   不复制出第二份完整 Doom 配置。

## Acceptance checks

- `emacs --batch -Q` 能启动，Scoop 更新不会覆盖私有 Doom 配置；
- Doom checkout 的 `origin` 指向官方 `https://github.com/doomemacs/core`；
- `doom sync --env` 与 `doom doctor` 完成，缺失依赖得到明确处理；
- GUI 与终端启动页、主题、字体和插件均经过实际启动检查；
- 修改共享 `dot_config/doom/` 后，Windows 部署预览只显示预期差异；
- `rg -i 'neovim|nvim|lazyvim' windows_setting dot_config README.md` 不再发现
  活跃配置引用；必要的迁移说明可保留；
- Git diff 不含用户名、主目录、token、SSH/GPG 私钥或机器专属缓存。

完成上述验收后，Windows 线程应更新 `windows_setting/README.md`，删除本交接
文件中已经完成的临时说明，并将最终配置正常提交、同步到远程。
