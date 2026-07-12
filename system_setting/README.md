# 系统配置入口

这里汇总当前生效的系统级配置。实际配置保留在各自目录，避免破坏安装脚本、WSL 挂载路径和已有外部引用。

| 使用场景 | 当前系统 | 配置入口 |
| --- | --- | --- |
| 物理 PC / laptop | Gentoo | [`../alternative_setting/gentoo/mylaptop`](../alternative_setting/gentoo/mylaptop) |
| Windows WSL | GNU Guix | [`../guix_setting/wsl`](../guix_setting/wsl) |

共同开发能力与版本策略见 [`development-parity.md`](development-parity.md)。旧 NixOS PC/WSL 配置已删除；它只作为迁移时的能力基线，不再作为可安装目标。
