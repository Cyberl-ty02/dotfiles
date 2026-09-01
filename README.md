# Dotfiles

本仓库用于备份系统、Shell 与开发环境配置。

## Gentoo

- `gentoo_setting/wsl/`：WSL2 Gentoo，使用 GCC，侧重 CLI/开发与 WSLg。
- `gentoo_setting/pc/`：实体 PC Gentoo，使用 Clang/LLVM，并包含桌面、NVIDIA 与 Secure Boot 配置。
- `gentoo_setting/development_mirrors/`：两套 Gentoo 共用的开发工具国内镜像配置。
- `gentoo_setting/private_dot_zshrc`：Gentoo 共用的 Zsh 私有配置。

## 国内开发镜像

Portage 镜像按机器保存在各自的 `portage/` 目录；用户级开发工具镜像的路径
映射、验证方式和官方源恢复方法见
`gentoo_setting/development_mirrors/README.md`。

## Windows

`windows_setting/` 保存 Windows 与 WSL 的宿主侧配置。

## 其他配置

仓库根目录中的 `dot_*` 文件保存通用 Shell 配置。
