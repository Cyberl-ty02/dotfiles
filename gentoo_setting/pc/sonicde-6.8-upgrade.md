# SonicDE 6.8 升级与回退

2026-11-07：用户已批准执行，通过 Polkit 获得管理员授权。已创建根目录和
家目录只读快照、备份 Portage/world/EFI 文件，并部署配置。软件源同步、
Portage 3.0.83-r1、桌面阶段 126 个包及图形栈 4 个包均已安装完成。
X11 模块与 preserved-library 重建完成，最终依赖预演为 0 个更新，脚本返回 0。
没有自动重启或重启登录服务。用户随后已重启；新 NVIDIA 驱动和 SonicDE X11
会话的冷启动核验已通过。depclean 预演没有可移除的软件包。

执行入口为 `../scripts/upgrade-sonicde.sh`，默认按桌面、显卡两阶段运行；
还可显式选择 `desktop`、`graphics`，或使用 `--plan [CONFIG_ROOT]` 只读预演。
脚本不自动重启、重启登录服务或执行 depclean，保留内核与引导包；
遇到降级、live 包、systemd 切换、跳过更新或待处理配置更新时停止。
通过 Polkit 启动的命令为：

```bash
pkexec /usr/bin/env SONICDE_PROXY=http://127.0.0.1:7890 \
  /usr/bin/bash /home/lty/source/repos/dotfiles/gentoo_setting/scripts/upgrade-sonicde.sh all
```

首次同步因网络等待而停止，未开始软件合并。经用户授权，全程改用本地代理重试。
gentoo-zh 的 CERNET 入口会重定向到 dumb HTTP 镜像，已改为其 README 指定的
`https://github.com/gentoo-zh/overlay.git` 完成本次同步。升级完成后，按用户的
国内优先偏好，日常配置已恢复为支持 smart HTTP/浅克隆的南京大学镜像
`https://mirror.nju.edu.cn/git/gentoo-zh.git`，其当前 HEAD 与本机一致。
日常 distfiles 顺序为 USTC、华为、阿里、TUNA，最后才是官方 CDN；主树仍为
USTC。PC 升级命令可加 `SONICDE_OFFICIAL_SOURCES=1`，只通过进程环境中的
完整 `PORTAGE_REPOSITORIES` 覆盖主树与 gentoo-zh 地址，并临时使用官方 distfiles。
原有仓库、签名与新鲜度校验均保留；不修改日常配置。
临时覆盖已通过独立进程验证，默认地址恢复与验签配置保持不变也已检查。
实机日常源配置变更前另备份至 `/root/sonicde-domestic-mirrors-20261107-122440/`。未配置可信国内镜像的
GURU/SonicDE/XLibre overlay 继续使用现有上游地址。

```bash
pkexec /usr/bin/env SONICDE_PROXY=http://127.0.0.1:7890 SONICDE_OFFICIAL_SOURCES=1 \
  /usr/bin/bash /home/lty/source/repos/dotfiles/gentoo_setting/scripts/upgrade-sonicde.sh all
```

当前执行日志：`/var/log/sonicde-upgrade/20261107-105956-43131/run.log`。
升级前备份：`/root/sonicde-before-20261107-105552-41509`；快照为
`/.snapshots/sonicde-root-20261107-105552-41509` 和
`/.snapshots/sonicde-home-20261107-105552-41509`。

代理重试还创建了 `/root/sonicde-before-20261107-105956-43131` 和对应时间戳的
root/home 快照。首份备份保留了部署前的 Portage 策略，作为完整回退的首选；
第二份快照已包含新 Portage 策略，但尚未升级软件。

## 本次执行结果

| 组件 | 已安装版本 |
| --- | --- |
| SonicDE meta | 6.8.0 |
| Desktop Interface | 6.8.0.3 |
| Sonic Win | 6.8.0.2 |
| Sonic Workspace | 6.8.0.4 |
| Sonic Login Manager | 6.8.0.3 |
| Sonic Screenlocker | 6.8.0.2 |
| Sonic Print Management | 6.8.0 |
| Sonic Power Management | 6.8.0.1 |
| SonicDE portal | 6.8.0 |
| XLibre Server | 25.1.11-r1 |
| NVIDIA | 620.70.06 |

安装后的检查结果：

- `sonicde-providers` 覆盖范围内，没有残留 `::gentoo` 实现；KDE 包名保留为兼容依赖。
- 实机 world 与仓库 `world_packages.txt` 完全一致，打印管理器显式目标已切换。
- 没有待处理的 `/etc/._cfg*` 配置更新；最终计划无跳过更新、降级或未满足 blocker。
  另外执行了不带 `--exclude` 的完整 `emerge --pretend --verbose --update --deep --newuse
  --backtrack=100 --autounmask=n @world`，返回 0，剩余 0 个包。
- `soniclogin` 保持 started，并在 OpenRC default runlevel；安装后的服务文件不再声明
  `provide xdm display-manager`。
- NVIDIA 模块版本为 620.70.06，vermagic 匹配当前 `7.2.14-x64v3`，具有
  PKCS#7/SHA-512 签名及非空 signer；Secure Boot 仍启用。
- 已检查 `/boot/initramfs-7.2.14-x64v3.img`：没有 NVIDIA 显卡驱动模块；其中的
  HID/USB Type-C NVIDIA 名称属于内核设备驱动，不是 615/620 显卡模块。
  此 initramfs 保留原 2026-11-02 时间戳，无需为本次 NVIDIA 更新重新生成。
- 仓库验证脚本、Portage 策略 atom 校验、升级预演保护规则和补丁检查均通过。

## 重启后核验与清理

用户重启后，当前内核加载的 NVIDIA 已为 620.70.06，`nvidia-smi` 正常，
不存在升级后未重启时的 615/620 版本差异。已核验：

- 当前活动会话为 X11；`Xorg` 由 `xlibre-server` 提供。
- 运行中的 `sonic-win`、`plasmashell`、`soniclogin` 和 SonicDE portal 分别由
  对应 SonicDE 包提供；`Desktop=KDE` 和旧 D-Bus 名称是兼容约定。
- 窗口管理器 D-Bus 返回 6.8.0，Qt 为 6.11.3；OpenGL 合成启用，使用 Intel
  Mesa 渲染，符合本机混合显卡配置。NVIDIA 620 驱动也已正常加载。
- PlasmaShell D-Bus、文件选择 portal、PipeWire/PulseAudio 服务和 Fcitx5 接口响应正常。
  未通过自动化锁定会话或触发实际打印；这些交互仍应由用户实际使用验证。
- XLibre 日志中的 intel/nouveau/nv/fbdev/vesa 缺失是自动探测候选驱动时的记录；
  实际已加载 modesetting/NVIDIA，GLX 初始化正常，不为消除这些探测记录安装多余驱动。
- `emerge --pretend --verbose --depclean` 显示 1391 个已安装包全部被依赖图需要，
  可移除数量为 0；没有强行删除所需 KDE 兼容包或用户显式选择的应用。

清理配置时合并重复的 Plasma mask，移除仅作用于 file-free 兼容包的
`no_lto` 设置，并撤销 `libei` 的临时显式 world/manifest 固定项。
`libei` 继续通过 portal 依赖安装。CMake 模块补丁已确认 6.31 上游仍需要，
从旧版本命名改为 `install-wayland-find-modules.patch`；OpenRC 登录补丁继续保留。

升级前的快照、EFI 和配置备份继续保留。清理时再次备份配置/world，并将
17 份构建日志归档至 `/root/sonicde-cleanup-20261107-121822/`。
`/var/tmp/portage` 下约 10.6 GiB 构建临时文件已移除；这一数值为目录占用，
保留的 Btrfs 快照可能仍引用原数据块，不等同于立即释放的物理磁盘空间。
清理后的 world、preserved-rebuild 和 depclean 预演均返回 0，且无包需要更新、
重建或卸载。实机配置与仓库一致，`libei` 继续作为依赖安装。
详细日志见 `/var/log/sonicde-upgrade/post-reboot-cleanup-20261107-121822/`。

## 已验证范围

预演使用当前 `/etc/portage` 的独立副本，叠加本仓库 PC 配置，保留
`make.profile`、`postsync.d`、`savedconfig` 和本机 `profile` 设置。
当时 Gentoo 为 `3d5af35677728d11439cacc1ca2165f39b1eaa3d`，
SonicDE overlay 为 `a5e6600f3dbd67b02ca61a095e036c8a908fe0cc`。
同步之后必须重新预演，不能沿用旧结果直接安装。

桌面阶段的完整 world 图预演返回 0：127 个包（112 升级、10 新装、5 重装），
下载 897083 KiB；55 个 soft blocker 全部由图内更新满足。没有 Qt 降级，
没有退回 SonicDE 6.7，也不拉入 systemd。该阶段暂缓 XLibre 和 NVIDIA。
预演证明依赖可解，尚未证明源码可构建、服务可启动或桌面可正常登录。

包含 XLibre/NVIDIA 的完整更新也已预演通过：显式设置输入驱动重装后，
131 个包（115 升级、10 新装、6 重装），下载 1465675 KiB，
55 个 blocker 全部满足，未跳过更新。仍建议分阶段安装，便于定位故障。

主要变化：

- 放行 SonicDE 6.8；Gentoo Plasma 6.8+ 继续按 `::gentoo` 屏蔽。
- 对 overlay 已有替代的 KDE 包选择 SonicDE 兼容包，保留没有替代的应用。
  `sonicde-providers` 是审核时的包名单；overlay 增删替代包后需重新审核。
- 接受 `qtvirtualkeyboard ~amd64`，避免新增依赖将整套 Qt 6.11.3 降级。
- 对齐电源管理兼容包的 `filecaps` 和 Frameworks 的 QML/ACL 开关。
- 将打印管理器 world 目标改成 `sonic-print-management`，修正 desktop manifest
  中的旧 Sonic 包名，并为已有 Clang 构建例外补上 Sonic 包名。
- 保留 rEFInd 所需的 `gnu-efi <4`；只放行当前 XanMod 7.2.14 提供的
  dist-kernel 虚拟包。升级 XanMod 时应同时调整 mask/unmask。
- 登录管理器 OpenRC 补丁已对上游 6.8.0.3 的服务文件执行
  `patch --dry-run --fuzz=0`；启动验证仍需实际安装后进行。

上游参考：[Gentoo overlay](https://github.com/sonicde-gentoo/portage)、
[SonicDE 安装说明](https://sonicde.org/installing)。

## 安装前备份

下列命令以仓库的 `gentoo_setting/pc/` 为当前目录，使用 Bash。
应在持久终端中执行编译，保留可用 TTY 和 LiveCD。

当前 `/` 为 Btrfs `@`，`/home` 为独立的 `@home`，因此两个子卷分别备份。
嵌套子卷和独立挂载点不在父快照内；应先检查 `findmnt` 与
`btrfs subvolume list /`。快照不能替代其他磁盘上的备份。

```bash
upgrade_stamp=$(date +%Y%m%d-%H%M%S)
upgrade_backup="/root/sonicde-before-$upgrade_stamp"
doas install -d -m 700 "$upgrade_backup"
doas cp -a /etc/portage "$upgrade_backup/portage"
doas cp -a /var/lib/portage/world "$upgrade_backup/world"
doas cp -a /var/lib/portage/world_sets "$upgrade_backup/world_sets"
doas install -d -m 700 /.snapshots
doas btrfs subvolume snapshot -r / "/.snapshots/sonicde-root-$upgrade_stamp"
doas btrfs subvolume snapshot -r /home "/.snapshots/sonicde-home-$upgrade_stamp"
```

`world_sets` 若不存在可跳过该条备份。记录这两个快照的确切路径。
根快照包含 `/var/db/pkg` 和 `/var/lib/portage` 的前提是它们没有独立挂载
或独立子卷。现有内核与 EFI 文件继续保留。

也可以先用 `quickpkg @installed` 保存全部已安装软件的二进制包；这会占用
额外磁盘空间，且默认不保存受保护的配置文件，不能代替上述配置和家目录备份。
已有 `buildpkg` 只保证新包留档，不保证旧版回退包完整。

## 部署和再次预演

先审核仓库与真实配置差异。这里不使用 `--delete`，保留本机专用文件：

```bash
doas rsync -ani --chown=root:root --exclude=make.profile portage/ /etc/portage/
doas rsync -ai --chown=root:root --exclude=make.profile portage/ /etc/portage/
LC_ALL=C.UTF-8 doas emerge --sync
doas eselect news read
```

先更新 Portage 本身，然后处理它产生的配置更新，再执行以下桌面阶段预演。
将 `>=sonicde-meta-6.8.0` 作为显式要求，避免求解器跳过桌面升级后仍返回成功。

```bash
doas emerge --oneshot --verbose sys-apps/portage
doas emerge --pretend --verbose --update --deep --newuse \
  --backtrack=100 --autounmask=n \
  --exclude='x11-base/xlibre-server x11-base/xorg-server x11-drivers/nvidia-drivers' \
  @world '>=sonicde-base/sonicde-meta-6.8.0' sonicde-base/sonic-print-management
```

必须检查没有 skipped updates、未满足 blocker、Qt 降级或 systemd 切换。
后续确认安装时，使用同一参数，将 `--pretend` 改为 `--ask`，并增加
`--oneshot --keep-going=n`；首次迁移遇错即停，便于定位和恢复。
`--oneshot` 避免把带版本的迁移约束写入 world。

## 桌面安装后

完成所有包的安装并审核 `/etc` 配置更新后，再切换会话验证。
不要在编译中重启 soniclogin，也不要在此阶段执行 depclean。

```bash
doas emerge --ask --noreplace sonicde-base/sonic-print-management
doas emerge --deselect kde-plasma/print-manager
doas emerge --ask @preserved-rebuild
```

从 TTY 确认 `rc-service soniclogin status` 和 `rc-update show`，再测试重新登录、
锁屏与解锁、网络、音量、中文输入、文件管理器、打印管理器及 portal 文件选择。
冷启动登录通过后，才能考虑清理旧包。

XLibre/NVIDIA 单独安排；XLibre subslot 变化时应显式重装输入驱动：

```bash
doas emerge --pretend --verbose --update --deep --newuse \
  --backtrack=100 --autounmask=n \
  --reinstall-atoms=x11-drivers/xf86-input-libinput @world
```

确认该图后再安装，并执行 `@x11-module-rebuild`、`@preserved-rebuild`。
NVIDIA 模块签名与内核对应关系按现有 Secure Boot 文档检查；
保留旧内核，确认新驱动和登录正常后再清理。

## 失败后的恢复

仅依赖求解或下载失败、尚未开始合并软件时，可从 `$upgrade_backup/portage`
恢复配置；world 未变则无需恢复。恢复前先检查期间是否有需保留的配置修改。

已经合并软件后，仅恢复 `/etc/portage` 不足以回退。编译失败可先检查日志，
修复后继续相同的目标图；禁止用忽略依赖、批量卸载 KDE 或 depclean 处理 blocker。
无法可靠续装时，退出图形会话，从 LiveCD 恢复根快照，使软件文件、VDB 和
world 一起退回。如果后续改写过独立 `/boot`，还需审核并恢复备份中的对应
内核/initramfs 文件，确保与回退后的模块一致。若新桌面已改写用户配置，再决定是否恢复 home 快照；
先备份升级后新增的文件。

LiveCD 恢复时，挂载 Btrfs 顶层（`subvolid=5`），将原 `@` 改名保留，
从 `@` 中保存的只读根快照创建新的可写 `@`。家目录需要回退时对 `@home`
同样操作。核实实际设备、子卷路径和 `/etc/fstab` 后再操作，不直接删除原子卷。
这次迁移不需要更换 rEFInd 或重建 EFI 启动链。
