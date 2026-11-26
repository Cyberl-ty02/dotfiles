# Gentoo configuration layout

本目录保存不能由用户级 chezmoi 直接部署的 Gentoo 系统策略，以及用于重建
机器的说明和角色清单。仓库根目录才是 PC/WSL 共用的 chezmoi source。

PC 默认方案现为 [`pc/`](pc/) 中的 **musl／LLVM／OpenRC** 配置，已经真机启动。
旧 glibc PC 配置不再并行维护，可从 Git 历史或本地归档标签
`archive/glibc-pc-before-musl-promotion` 找回；恢复配置不等于恢复旧系统数据。
WSL 配置独立保留，不能把 musl PC 配置直接应用到 WSL。
安装与迁移正文统一在博客，目录说明只保留部署入口、补丁边界和验收状态。

## 软件源同步的 locale

PC/WSL 各自的 `eix-sync.conf` 部署到 `/etc/eix-sync.conf`。其中的 eix
初始化钩子给同步进程设置 `LC_ALL=C.UTF-8`，使 `su`、`doas` 和直接 root
执行 `eix-sync -a` 时均可解析 Gentoo 的英文 Git 时间戳。已有配置应合并
此钩子，避免覆盖其他自定义钩子。此设置不改变桌面或登录 shell 的语言。

直接使用 Portage 同步时运行 `LC_ALL=C.UTF-8 emerge --sync`；eix 配置不会
影响绕过 eix 的命令。升级 Portage 后可重新检查其日期解析是否已消除
locale 依赖，签名校验及时间戳新鲜度校验保持启用。

## 配置边界

| 类别 | 示例 | 管理方式 |
| --- | --- | --- |
| A. 跨平台用户配置 | Doom Emacs、Git 通用选项 | 根目录 chezmoi |
| B. Gentoo 共用用户配置 | zsh、Zim、开发镜像 | 根目录 chezmoi |
| C. PC 系统配置 | Portage、桌面、NVIDIA、引导 | `pc/`，人工审核后部署 |
| D. WSL 系统配置 | Portage、WSLg、`wsl.conf` | `wsl/`，人工审核后部署 |
| E. 角色清单 | 核心、开发、桌面、硬件 | `manifests/`，仅供选择和预演 |
| F. 主机运行状态 | KDE 布局、会话、缓存、数据库 | 不纳入仓库 |
| G. 私密资料 | 密钥、token、密码、真实身份 | 不纳入仓库 |

Git 的姓名与邮箱继续留在未托管的 `~/.gitconfig`；仓库只部署
`~/.config/git/config` 中与身份无关的默认项。Secure Boot 私钥、SSH/GPG
私钥、浏览器和桌面会话状态均不得复制进来。

## 分阶段恢复

1. 安装 Gentoo，建立普通用户和网络；不要直接复制旧机器的 `/etc`。
2. 安装 Git、chezmoi、doas 与基础 shell 工具。
3. 克隆本仓库，运行 `scripts/bootstrap-user.sh` 预览用户配置。
4. 新装时按 [musl](pc/#新机安装与-chroot) 或 [WSL](wsl/#apply) 说明预览并部署
   Portage。glibc 实体机从自己的 stage3 配置开始，见 [glibc 安装指南](https://kagaranakaki.top/posts/gentoo-glibc/gentoo-glibc/)。
5. PC 使用 `pc/world_packages.txt` 作为当前原生选择入口，先预演并按硬件取舍；
   WSL／共用角色再从 `manifests/` 选择。旧角色清单不能整套代替 musl PC 配置。
   清单本身不会自行安装软件。
6. PC 再单独配置服务、桌面、显卡和引导。Secure Boot 必须在目标机器
   本地生成密钥，步骤见 `pc/kernel/secureboot/README.md`。
7. 运行 `scripts/verify.sh pc` 或 `scripts/verify.sh wsl`，确认差异后才应用
   chezmoi 或系统配置。

常规更新不应把 `/etc/portage` 整棵覆盖回仓库。应逐项检查真实生效配置、
保留注释语义，并排除生成文件、临时 workaround 与主机凭据。
