# Dotfiles

本仓库使用 chezmoi 管理可跨机器复用的用户配置，并单独保存 Gentoo 系统策略。
仓库根目录是 Gentoo PC/WSL 的 chezmoi source；Windows 使用
`windows_setting/` 作为独立 source。

## Gentoo

- `gentoo_setting/wsl/`：WSL2 Gentoo，使用 GCC，侧重 CLI/开发与 WSLg。
- `gentoo_setting/pc/`：实体 PC Gentoo，使用 Clang/LLVM，并包含桌面、NVIDIA 与 Secure Boot 配置。
- `gentoo_setting/manifests/`：按角色拆分的可选软件清单，不会自动安装。
- `gentoo_setting/scripts/`：只做显式预览、部署和验证的小型辅助脚本。

配置边界、排除项和分阶段恢复流程见 `gentoo_setting/README.md`。

## 国内开发镜像

Portage 镜像按机器保存在各自的 `portage/` 目录；Bun、Cargo、Go、npm、pip、
Pixi 与 uv 的用户级镜像由根目录 chezmoi source 直接管理。镜像说明和官方源
恢复方法见 `gentoo_setting/development_mirrors/README.md`。

## Windows

`windows_setting/` 保存 Windows 与 WSL 的宿主侧配置，并提供独立的 Windows
Neovim 部署脚本。Linux 侧默认编辑器使用 Doom Emacs；Windows 现有 Neovim
配置不由 Gentoo 的 chezmoi 部署。

VSCodium 的可迁移用户设置由各端 chezmoi source 部署；通用与平台扩展清单
集中在 `vscodium/`，避免依赖编辑器内的第三方 Settings Sync 插件。

## 其他配置

仓库根目录中的 `dot_*` 文件保存 Gentoo PC/WSL 共用的 Shell、Git 通用选项与
开发工具配置；`dot_config/doom/` 保存 PC、WSL 与 root 共用的 Doom Emacs
私有配置。`dot_config/nvim/` 仅供现有 Windows 部署使用。Git 身份、SSH 密钥
和主机凭据不受管理。

先预览用户配置，不会写入 `$HOME`：

```sh
gentoo_setting/scripts/bootstrap-user.sh
```

确认差异后再交互式应用：

```sh
gentoo_setting/scripts/bootstrap-user.sh --apply
```
