# Gentoo PC Clang/LLVM 配置

目标：amd64、OpenRC、Clang/LLVM 主工具链、XLibre + SonicDE、NVIDIA、rEFInd 与 Secure Boot。
少数无法可靠使用 Clang/libc++ 构建的软件通过 `portage/env/gcc_generic` 回退到 GCC。

## 桌面包策略

SonicDE 6.7.3 替换 Plasma 的桌面核心：`plasma-desktop`、
`kwin`、`plasma-workspace` 和 `kinfocenter` 分别由
`sonic-desktop`、`sonic-win`、`sonic-workspace` 和
`sonic-system-info` 提供。SonicDE overlay 的同名 dummy 包用于满足仍引用
KDE 包名的依赖；其他 KDE Frameworks、Plasma 组件和 KDE 应用继续使用
Gentoo ebuild。

XLibre 是与 SonicDE 配套使用的 X11 显示服务器，但不是 SonicDE 的硬依赖。
本配置同时启用两个 overlay：`x11-base/xlibre-server` 替代 Gentoo 的
X.Org Server，`x11-base/xorg-server::xlibre` 是满足旧包名依赖的 dummy，
并非第二套显示服务器；`xlibre-server[xorg]` 会拉入
`x11-base/xlibre-drivers`。`x11-base/xwayland` 是独立兼容服务器且仍被
`sonic-win` 依赖，因此保留。

以下 KDE 应用没有被 SonicDE 替换，继续作为显式 world 包保留：
`ark`、`dolphin`、`filelight`、`gwenview`、`kwalletmanager`、`yakuake`、
`discover` 和 `print-manager`。`sddm` 已由 `sonic-meta` 和
`silver-sddm` 依赖，不再重复写入 world。

## 应用

先备份并安装 Portage 配置，然后同步所有仓库：

```bash
doas cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
doas rsync -a --delete --exclude=make.profile portage/ /etc/portage/
doas emerge --sync
```

首次从 Gentoo X.Org Server 切换到 XLibre 时，两者会发生文件冲突。完成上述
同步后，先执行一次以下迁移：

```bash
doas emerge -f x11-base/xlibre-server
doas emerge -C x11-base/xorg-server x11-base/xorg-drivers
doas emerge -av1 x11-base/xlibre-server x11-base/xorg-server::xlibre
doas emerge @x11-module-rebuild
doas emerge @preserved-rebuild
```

最后安装 world 并检查完整依赖图：

```bash
doas xargs emerge -av --noreplace < world_packages.txt
doas emerge -pvuDN @world
doas emerge -avuDN @world
```

本配置以 `stage3-amd64-llvm-openrc` 及其
`default/linux/amd64/23.0/llvm` profile 为基础；Clang、LLVM binutils、
libc++、compiler-rt、llvm-libunwind 和 lld 均沿用 profile 默认值，
`make.conf` 不再重复声明工具链变量。GCC 仅供已记录的包级回退使用。
基础优化、Clang ThinLTO 与 Fortran LTO 分别由 `COMMON_FLAGS`、
`CLANG_LTO_FLAGS` 和 `FORTRAN_LTO_FLAGS` 控制；兼容环境显式使用
`-fno-lto`，无需重写其他语言或工具链设置。

应用前请阅读 [`kernel/secureboot/README.md`](kernel/secureboot/README.md)。当前
启动链为 shim + rEFInd，不再使用 GRUB。私钥不会保存在本仓库中。

对应排错笔记：

- [rEFInd、Btrfs 与 LiveCD 启动修复](https://kagaranakaki.top/posts/gentoo-refind-btrfs-rescue/)
- [字体、KDE 托盘与 PipeWire](https://kagaranakaki.top/posts/gentoo-openrc-desktop-troubleshooting/)
- [chrony、时区与 PostgreSQL 18](https://kagaranakaki.top/posts/gentoo-chrony-timezone-postgresql/)
- [旧 LLVM 阻塞 Firefox/CUDA 构建](https://kagaranakaki.top/posts/gentoo-llvm-firefox-cuda-build-failure/)
