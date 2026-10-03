# VSCodium synchronization

VSCodium 的可迁移配置由 Git 和 chezmoi 管理，不再依赖编辑器内的第三方
Settings Sync 扩展。Linux/WSL 设置位于
`../dot_config/private_VSCodium/User/settings.json`（`private_` 保持目标目录
权限为 `0700`），Windows 设置位于
`../windows_setting/AppData/Roaming/VSCodium/User/settings.json`。

两端保留相同的格式化、语言、Git、主题、安全和遥测策略。只有确实依赖
平台的终端配置、更新方式和少量运行命令分别维护；账号、登录令牌、扩展
运行状态、工作区历史和 machine ID 不进入仓库。

扩展分为：

- `extensions-common.txt`：Windows、Gentoo PC 与带 GUI 的 WSL 可共用。
- `extensions-linux.txt`：当前没有强制的 Linux 专属扩展。
- `extensions-windows.txt`：Windows PowerShell 与 Remote WSL 支持。

Gentoo 默认只预览扩展差异：

```sh
gentoo_setting/scripts/sync-vscodium.sh
```

确认后安装缺少项并移除旧同步扩展：

```sh
gentoo_setting/scripts/sync-vscodium.sh --apply
```
