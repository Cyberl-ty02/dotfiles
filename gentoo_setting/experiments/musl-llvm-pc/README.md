# Gentoo amd64 musl/LLVM 迁移实验暂停记录

记录日期：2026-11-13（Asia/Shanghai）。状态：**阶段性验证已完成，已暂停；尚未通过全新真机安装验收。**

这不是可以直接部署的系统配置目录，不能覆盖现有 `/etc/portage`。没有修改当前系统的内核、驱动、引导和个人桌面配置；同步这些记录不代表已通过全新装机验收。

## 用户约定与暂停点

- 从官方 `stage3-amd64-musl-llvm-openrc-20261108T170107Z` 探索全新安装。
- 尽量复用博客已有的 Btrfs、OpenRC、SonicDE、XLibre、shim/rEFInd、中文字体和输入法方案。
- 优先维护中的上游实现，尽量避免完整 GCC 编译器套件和复杂手动兼容环境。
- 可使用本机临时空间、代理及必要的 Polkit 授权；保留至少 20 GiB 空闲空间作为实验停止线。
- 用户补充：时间较晚，接近账户用量限制（不足 2%）或达到阶段目标时可暂停。代理不能读取账户剩余用量，本次依据阶段里程碑暂停。

Flatpak 原生构建的前 **68/180** 个包完成。第 69 个 `media-libs/speexdsp-1.2.1` 在预设暂停钩子中停止，未合并。日志中的 `User-requested experiment pause checkpoint` 是预期暂停，不应记为该包的编译回归。Portage 退出时还打印了 asyncio pending-task 警告；没有继续运行的实验编译进程。

## 本阶段已验证结果

| 项目 | 结果与边界 |
| --- | --- |
| 官方 LLVM libgcc ABI 库 | `llvm-runtimes/libgcc-22.1.8` 在 musl 中构建、安装成功；主实验根未安装 `sys-devel/gcc` 编译器包 |
| gcompat | GURU 1.1.0、libucontext 1.5.1 构建成功；补齐 amd64 `/lib64/ld-linux-x86-64.so.2` 路径后能运行简单 glibc ELF |
| NVIDIA 620.70.06 计算接口 | musl + gcompat 中 `nvidia-smi`、CUDA Driver API、4 KiB 显存分配和写入读回通过 |
| 已有 GCC/glibc 编译的 CUDA 程序 | 加入经 Alpine 签名验证的约 2.7 MiB musl libstdc++ 运行库后，真实 sm_89 kernel 和结果校验通过；没有安装 GCC 编译器 |
| musl/Clang 原生 CUDA 编译 | 使用官方 CUDA 分组件归档，经 SHA256 校验；Clang 22.1.8 编译和 GPU 执行通过，需要下述八处宿主数学调用修正 |
| 原生 CUDA ELF | 使用 `/lib/ld-musl-x86_64.so.1`；依赖 `libgcompat.so.0`、`libc++.so.1`、`libc++abi.so.1`、`libc.so`，没有 `libstdc++.so.6`；执行时库路径也排除了 Alpine C++ 运行库 |
| NVIDIA 开放内核模块 | musl/Clang 构建五个 `.ko` 成功，版本 620.70.06，vermagic 为 `7.2.14-x64v3 SMP preempt mod_unload`；未安装、未加载、未签名 |
| 中文 | 第一阶段的原生 ICU 已验证中文日期、人民币格式、中文排序与 GB18030；不能据此宣称 libc、Qt/GTK 界面和输入法全部完成验收 |
| Flatpak | 依赖可解，实际构建完成 68 个包后按用户要求暂停；Flatpak 本体、应用安装与 GUI 尚未通过运行验收 |

NVIDIA 模块构建使用了宿主提供的 `.config`、`Module.symvers` 等内核开发资料，并从公开源码补齐构建树。复制的 glibc 构建工具已移除，objtool、modpost 等在 musl 中重新构建。这证明模块编译路径可行，**没有证明从空白磁盘构建并启动新内核成功**。内核开发树仍需按正式 Gentoo/XanMod/CJKTTY 安装流程完整生成。

CUDA 原生测试仅覆盖小型 kernel 编译、执行和数据校验，未验收完整 SDK、NVCC、cuBLAS/cuDNN、PyTorch 或实际生产负载。CUDA 数学补丁尚未完成完整边界值回归，不是已发布的通用兼容补丁。

## 其他发行版方案的比较

- **Alpine gcompat**：是小型、可打包的实际兼容路线，本机已取得 NVIDIA 计算接口的正面结果。它不等于完整 glibc，也不能由计算接口通过推导出 OpenGL/GLX/Vulkan 通过。[Alpine gcompat 包](https://pkgs.alpinelinux.org/package/edge/main/x86_64/gcompat)
- **Alpine libstdc++**：只取签名验证的运行库可供部分现有二进制使用，不需要整套 GCC。它在本阶段是对照测试，尚未选为 Gentoo 默认跨发行版依赖；原生 Clang CUDA 路线不需要它。[Alpine 运行库](https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/libstdc%2B%2B)
- **Flatpak**：优先用于减少闭源桌面应用的手工兼容配置。微信、腾讯会议、WPS 都有维护中的 Flathub 清单，但仍需核对具体版本和权限、输入法、音视频、屏幕共享。Flathub WPS 当前为国际 11.x，不能视为已等价保留现有中文 WPS 12.x。[微信](https://github.com/flathub/com.tencent.WeChat)、[腾讯会议](https://github.com/flathub/com.tencent.wemeet)、[WPS](https://github.com/flathub/com.wps.Office)
- **Distrobox**：可简化应用环境集成，但其 NVIDIA 自动集成明确不支持非 glibc 宿主，不能直接作为本机一键 NVIDIA 方案。[上游说明](https://distrobox.it/usage/distrobox-create/)
- **Chimera**：NVIDIA 图形路线涉及 musl IFUNC、TLS 和用户态适配，仍是 Draft/WIP；暂未把这些 libc 修改引入实验基础。[上游 PR](https://github.com/chimera-linux/cports/pull/6531)
- **Void**：其 musl 移植经验可借鉴；共享内核的独立 glibc 根仍是通用回退思路，不能自动解决 musl 进程加载 glibc 图形库的问题。[Void musl 文档](https://docs.voidlinux.org/installation/musl.html)
- **HarmonyOS/OpenHarmony**：公开文档描述其 musl、locale 和加载器扩展，尚未找到能直接作为 Gentoo amd64 Linux 闭源应用兼容包使用的成熟实现，不移植整套系统 libc。[官方说明](https://developer.huawei.com/consumer/en/doc/harmonyos-references/musl/)
- **sgerrand glibc APK**：核对到最新 release 为 2023-04-13 的 2.35-r1；未作为 2026 桌面的默认更新基础，也未安装它。[发布记录](https://github.com/sgerrand/alpine-pkg-glibc/releases)

## 小补丁与可复用部分

- [CUDA 宿主数学补丁](patches/cuda-13.4-musl-host-math.patch)：仅在宿主实现区替换八处 `__isnan` / `__isinf` 调用为 Clang 内建函数。已通过原始归档上的无 fuzz dry-run，以及本次原生 CUDA 编译运行。
- [gcompat 打包草案](patches/gcompat-amd64-loader.patch)：基于 GURU ebuild，补上 amd64 加载器别名、默认可选兼容依赖。路径修正已手工验证，但该 ebuild 草案尚未单独构建验收，不是可发布 overlay。

已有博客方案仍可复用安装分阶段思路、Btrfs 子卷、OpenRC 服务、SonicDE 登录补丁、Portal 路由、字体和 Secure Boot 操作边界。不能直接复制其 glibc profile、multilib、GCC fallback、完整 nvidia-drivers atom 或 glibc binhost。musl 需要独立候选配置和经过验证的 NVIDIA 模块/用户态拆分打包。

## glibc 根环境的状态

第一阶段建立的独立 glibc stage3 仍保留作回退对照。它需要单独建立、更新、配置 locale 和用户会话接口；不是安装一个 chroot 软件包便自动完成。第二阶段已有无需它的计算验证，但尚不能宣布完整桌面可完全取消它。若最终仍需要它，正式安装说明必须明确这部分额外配置、空间和更新责任。

## 持久化位置与恢复顺序

完整实验区保留在 `/var/tmp/musl-pc-lab-20261113`，没有把约十余 GiB 的根目录或源码提交进仓库。旧 `/tmp/musl-pc-lab-20261113` 仅作为兼容别名。`/var/tmp` 通常跨重启保留，但仍受本机清理策略影响。

主要证据位于实验区的 `phase2/logs/`：`compat-install.log`、`gcompat-gpu-probe.log`、`alpine-runtime-signatures.log`、`cuda-native-clang-build.log`、`cuda-native-clang-run.log`、`nvidia-musl-modules-build.log`、`flatpak-install.log`。

恢复时先检查：

1. 实验目录、源码与日志仍存在；确认没有活动实验 emerge。
2. 如旧 `/tmp` 别名因重启消失，恢复指向上述 `/var/tmp` 路径的符号链接。当前实验辅助脚本仍引用旧路径，正式安装脚本不应使用这些硬编码路径。
3. 确认空间、Portage 包数据库和暂停日志；实验主根有 root 所有的文件，不能再假定纯非特权用户命名空间可以执行全部包维护。
4. 仅在继续实验时移除 `phase2/PAUSE_REQUESTED`。`root/etc/portage/bashrc` 会在 setup/unpack/preinst 检查该标记，并保留 20 GiB 空间检查。
5. 在与上次相同的隔离根内重新解析 `sys-apps/flatpak`，复用已完成的 68 个依赖，再继续构建。无需重新解压 stage3 或重编全部依赖。

实验为运行在 Bubblewrap 中的构建临时调整了 Portage 用户和嵌套沙箱设置；正式 LiveCD chroot 应恢复正常 Portage 用户、权限与沙箱，不能照抄实验根中的 `PORTAGE_USERNAME=root`、沙箱禁用或 `/lab` 路径。

下一阶段仍需：完成 Flatpak、验证闭源应用与中文交互；实现并验收包含正确 GSP 固件、udev/设备节点、版本配套及签名流程的 NVIDIA 拆分包；实际构建和登录 SonicDE；最终从新根完成内核、initramfs、Secure Boot 与真机启动。全部通过前，不能对外宣称“从此 stage3 全新安装已经可靠成功”。

暂停时安装包清单见 [installed-at-pause.txt](installed-at-pause.txt)。公开资料不应包含 MOK 私钥、用户会话认证文件或应用账户数据。

## 本机后续迁移布局与数据验收

用户要求先同步记录，次日早上继续；本次同步不恢复构建，也不创建定时任务。

当前 Gentoo 位于 `/dev/nvme1n1p2` 的 Btrfs 文件系统中，根和家目录分别使用 `@`、`@home` 子卷。候选迁移是在同一个文件系统中新建 `@musl` 根子卷并配置独立引导入口，保留原 glibc 根和可启动入口。无需为此重新分区或格式化现有分区。

设备 `/dev/nvme1n1p2` 是磁盘分区标识，不是子卷名称；`@musl` 不会重命名成这个设备路径。子卷可一直叫 `@musl`。若最终希望沿用 `@`，应在维护环境中先将旧根另名保留，再重命名新根，并核对 fstab、引导参数和 initramfs。不能仅改名字而继续引用旧的 `rootflags=subvol=...`。

第一次启动成功不足以删除旧根。正式切换前需完成多次启动、桌面和应用使用、更新及回退验证，并明确确认旧根清理范围；当前没有授权或执行旧根删除。

家目录不能不加区分地与两个系统同时读写。先为测试用户准备隔离配置，保留原始用户数据的快照或备份，再按应用迁移需要的数据。最终是否沿用 `@home` 或另建测试 home 子卷，待空间与数据清单核对后决定。

VSCodium 验收至少包括：

- 用户设置、快捷键、工作区、代码片段和项目数据完整。
- 扩展清单、启用状态、必要的扩展存储与凭据能正常使用；凭据不得写入公开实验记录。
- 实际运行 Extension Host、语言服务器、调试适配器、终端和所需原生扩展。扩展目录存在不代表扩展能加载；原有 glibc 二进制扩展可能需要重装兼容版本或在选定 glibc 运行时内执行。
- 若选择 Flatpak/其他封装，核对应用 ID 对应的数据路径、项目目录权限、外部工具调用、输入法和 GPU 行为，不直接覆盖旧 VSCodium 配置目录。

上述过程仍是候选迁移方案。当前保留的是隔离实验根，尚未创建可启动的 `@musl` 子卷。
