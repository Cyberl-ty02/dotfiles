# 开发环境能力对照

## 统一策略

- Gentoo 跟随 stable profile 和仓库更新；Guix 跟随官方 `master` channel，由 `guix pull` 产生可回滚 generation。
- 配置使用不带版本号的包名，不锁死某个历史版本。Java、Node、Rust 等由发行版维护的默认稳定别名前进；更新前先查看计划并保留旧 generation。
- WSL 只放开发、调试和命令行工具。显卡驱动、桌面、Secure Boot、内核与 Btrfs 工具属于 Gentoo PC，不在 WSL 中重复安装。
- Guix 系统 profile 保持小而可恢复；开发工具位于 `lty` 的 manifest profile。

## 共有开发能力

| 类别 | Gentoo PC | Guix WSL |
| --- | --- | --- |
| Shell/配置 | zsh、chezmoi、direnv | zsh、chezmoi、direnv |
| 日常 CLI | bat、btop、eza、fastfetch、fd、fzf、jq、ripgrep、rsync | 同左 |
| C/C++ | GCC、CMake、Ninja、pkgconf、mold；按需 LLVM | GCC、CMake、Ninja、pkg-config、mold、LLVM/Clang/LLD/LLDB |
| Rust | Gentoo `rust-bin`、rust-analyzer、rustfmt | Guix `rust`、`rust-cargo`、rust-analyzer；项目可通过 Cargo 管理依赖 |
| JavaScript | Gentoo 可选 `bun-bin` | Guix 提供滚动的 `node-lts`；Bun 使用上游默认用户级安装机制 |
| Java | Gentoo/上游 JDK | Guix 的无版本 `openjdk` 稳定别名 |
| Python | Python、uv、pixi | Python、uv；pixi 使用上游用户级安装机制 |
| 数据库/文档 | PostgreSQL、Typst | PostgreSQL、Typst |
| 编辑器 | Emacs、VSCodium | Emacs；Windows 编辑器可通过 Remote WSL 使用 |

## 未强行打包的工具

当前官方 Guix channel 不提供 Bun、Pixi 和 yazi 的精确包名。本配置不为这些工具加入来源不明的第三方 channel，也不在自动安装脚本里执行 `curl | sh`。需要时按各项目官方文档安装到 `lty` 的用户目录；它们不会污染 Guix system generation。uv 与 xmake 已由当前官方 channel 提供并纳入 manifest。

CUDA、NVIDIA、Vulkan、桌面与存储维护仅保留在 Gentoo PC。WSL 使用 Windows/WSLg 提供的宿主能力，避免重复驱动和不必要的系统包。
