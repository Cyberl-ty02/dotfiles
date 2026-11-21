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
- `extensions-windows.txt`：仅 Windows Remote WSL；PowerShell 已归入共用列表。

Gentoo 默认只预览扩展差异：

```sh
gentoo_setting/scripts/sync-vscodium.sh
```

确认后安装缺少项并移除旧同步扩展：

```sh
gentoo_setting/scripts/sync-vscodium.sh --apply
```

2026-11-20 已按当前 VSCodium 的有效安装索引重新同步插件列表：49 项共用插件、
1 项 Windows 专属插件。使用不锁版本的插件 ID，不把遗留扩展目录当作已注册插件。
Java 改用 Oracle Java，保留 Dragonwell Standard21 路线；共用清单不再装回要求
更高 JDK 的 Red Hat Java。C/C++ 与 Java 设置中旧插件的固定 formatter 引用已移除，
由当前已安装 provider 选择；Windows 的终端、路径、运行时配置保留。

Linux 设置同步了当前字体和格式化偏好；迁移期间暂停扩展自动更新使用布尔 false，
没有沿用本机曾出现的字符串 off。私有 glibc JDK 路径及 clangd/xmake 本机桥接路径
由迁移安装环境维护，不复制到通用设置或 Windows。未导出令牌、钱包、插件运行状态、
历史、machine ID 或工作区数据。插件清单同步不代表已在 Windows 实机安装验收。


Gentoo PC 的 Flatpak 版终端另有运行环境边界：编辑器内的默认 sh／bash 属于 SDK，
宿主机 musl Zsh 通过包内 `/app/bin/host-spawn` 启动。
`configure-postboot-user.py` 在该应用专用 settings.json 中合并 zsh profile
（参数 `/usr/bin/zsh -l`）并设为 Linux 默认，保留其他 profiles；不把 Flatpak 路径
写入 Linux／WSL 共用配置，也不改 Windows 默认终端。
[Flathub 包说明](https://github.com/flathub/com.vscodium.codium#host-shell)列出该入口。
本机已验证原生 musl、交互 Zsh、TTY／作业控制和 Ctrl+C；主机 Java 仍为
Dragonwell Standard21，编辑器的私有 glibc JDK 设置保持。设置对新建终端生效，
恢复出来的旧 sh 会话保留；不删除终端历史或强制重启编辑器。
