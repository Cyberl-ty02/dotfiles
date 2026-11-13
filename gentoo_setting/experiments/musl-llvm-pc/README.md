# Gentoo musl / LLVM PC 迁移实验

**状态：进行中，尚未从新根真机启动。** 本目录是可回退的实验记录，不能当作
已经完成的新机安装教程。现有 `pc/`、`manifests/desktop.txt` 和
`manifests/nvidia.txt` 仍服务于原 glibc 系统；不要整棵复制到 musl stage3。
Windows 配置不在本次变更范围内。

桌面批次通过不代表旧 `world` 已全部迁移。逐项核对清单见
[`world-migration.tsv`](world-migration.tsv)，按批次检查点记录旧系统 91 个直接选择的去向；
“待原生预演”表示尚未补齐，不能理解为不支持 musl。PostgreSQL 18.6、ClamAV 1.5.3、
ClamTk 6.18-r2 已安装，该批次结束时新根已通过 Portage 登记 32 项软件选择。迁移验收期间不运行
`depclean`。PostgreSQL 工具执行通过，未初始化或迁移数据库；ClamAV 自定义无害签名的
正、负样本扫描通过，正式病毒库更新仍待验收。ClamTk 的版本限定中文补丁已重建，
私有显示中标题和各组控件的中文绘制通过。

其余软件已逐项预演，43 项原生软件的合并预演通过，当前正在构建。Firefox／Thunderbird
加入 Gentoo 官方 `llvm-runtimes/libatomic-stub` 后预演不再选择 GCC；大型应用分批构建。
KTorrent 关闭可选内嵌 WebEngine，避免额外的网页引擎构建。QQ、LocalSend、FlClash
的 glibc 预编译界面另行验证，不把通过关键词检查当作 ABI 兼容已经通过。

Bun 官方 musl baseline 归档已按发布资产 SHA256 校验；它另需 musl 版 C++ 运行库。
复用已验签的 Alpine 约 2.7MiB `libstdc++`，在私有目录中通过了 JavaScript、中文
文本和人民币格式化测试，未安装 GCC 编译器或 glibc。此路线尚未打包进 Portage，
不把私有测试通过写成主系统已经安装，也不全局修改 `LD_LIBRARY_PATH`。

## 实验基线与已验证范围

本轮从官方 `stage3-amd64-musl-llvm-openrc-20261108T170107Z.tar.xz` 开始，
已核对发布签名和 SHA512。对应 profile 是
`default/linux/amd64/23.0/musl/llvm`，原生工具链为 Clang/LLVM、LLD 和 libc++。
它仍是实验 profile，stage3 可下载不等于完整桌面已经可用。

| 项目 | 当前结果 |
| --- | --- |
| musl 原生 UTF-8 文件名、内容、中文编码 | 通过 |
| ICU 中文日期、人民币、排序、GB18030 转换 | 独立程序通过 |
| 原生 CUDA 编译和 RTX 4060 计算 | Clang、libc++ 与小补丁通过最小 kernel；不是完整 CUDA SDK/PyTorch 验收 |
| NVIDIA 开源内核模块 | 五个模块在 musl/Clang 下编译通过；尚未安装、签名、加载新模块 |
| NVIDIA 原生图形兼容 | 私有补丁加载器下 EGL 1.5 / OpenGL 4.6 离屏渲染及像素回读通过；未验证桌面、PRIME 或外接显示 |
| Flatpak 1.18.4 | musl 原生构建完成 |
| Flatpak NVIDIA 运行时 | 官方 glibc/NVIDIA 扩展的 CUDA 显存往返、EGL/OpenGL 离屏渲染通过；不代表应用全部 GPU 功能通过 |
| 微信 4.1.13.26 | 中文登录界面显示通过，未登录；输入法、音视频待验证 |
| VSCodium 1.143.17232 | 八个选定扩展激活、中文 notebook 读取、ZeroMQ 原生模块中文消息往返通过 |
| root chroot 系统级 Flatpak 安装 | 无 D-Bus 环境中部署通过，安装后触发器复核通过；重复运行可跳过已安装应用 |
| 全新根安装后检查 | 中文 locale、上海时区、音量界面和系统级 Flatpak 主包通过；新根 VSCodium 实际提交中文通过 |
| SonicDE / XLibre / Rime | 全新根安装及私有显示中的桌面 shell、窗口管理器、中文绘制和 PipeWire 检查通过，尚未真机登录 |
| 中文输入 | 私有 X11 显示中，原生 Qt 6、GTK 3 及 Flatpak VSCodium 均通过 Fcitx 5/Rime 实际键入并提交“你好”；其他应用仍需检查 |
| 全新 stage3 安装基础 | 默认沙箱与 UID 250 下完整桌面安装通过，共 926 个包；Pillow truetype 已恢复，未引入 GCC |
| 真机新根、Secure Boot、回退启动 | 未验证 |

选定扩展为 Python、debugpy、Jupyter、Jupyter Renderers、Ruff、rust-analyzer、
Tinymist 和 Office。扩展激活不代表 notebook kernel 执行、调试、所有语言服务、
登录凭据或其余扩展全部通过。旧 glibc 版 Ruff、rust-analyzer、Tinymist 在当前
gcompat 下崩溃，不能直接把旧扩展目录复制给原生 musl 编辑器。

原生 musl 版 Ruff 的实际诊断、rust-analyzer/Tinymist 的最小 LSP 请求也已通过。
这条原生工具路线与 Flatpak 内的 glibc 扩展路线分开验证，不混用库路径。

## Flatpak 主包与一键安装

主包清单在 [`scripts/flatpak-apps.txt`](scripts/flatpak-apps.txt)。当前默认：

- `com.tencent.WeChat`
- `com.vscodium.codium`

腾讯会议 `com.tencent.wemeet` 尚待验证。`com.wps.Office` 是国际版，不能当作
现有中文 WPS 12 的等价替代，因此二者暂不进入默认清单。

先在目标系统安装 Flatpak 本体、CA 证书和字体。在博客式 root chroot 内执行：

```bash
bash scripts/install-flatpak-apps.sh --system
```

脚本在 root 下默认选择 `--system`，写入目标系统 `/var/lib/flatpak`，不依赖
目标普通用户已登录桌面。先按安装指南准备 `/proc`、`/sys`、`/dev`、`/dev/pts`、
网络、DNS、系统时间和代理。不要把当前受限测试环境的 bwrap 参数写入正常安装流程。

只想为已登录的普通用户安装时执行：

```bash
bash scripts/install-flatpak-apps.sh --user
```

两种模式都支持 `--dry-run`。默认优先中科大缓存，临时使用官方源加 `--official`；
再次运行默认命令可恢复国内缓存。官方 GPG 校验保持启用，代理沿用调用环境。
已经选择系统级安装的机器，不必再用 `--user` 重复安装相同应用。

全新根也已运行系统级安装脚本并检查两个主包，VSCodium 通过实际 Fcitx/Rime
中文输入。此次先复用了已校验的实验缓存，尚不代表从空缓存下载的全流程测试；
主包部署、输入测试也不代替真实会话中的 Portal、音视频和全部扩展验收。

清单只固定应用 ID。运行时、SDK、Locale、Mesa 和匹配的 NVIDIA 图形扩展由
Flatpak 自动解析，不把本机 `620-70-06` 写成所有新机器的固定版本。
VSCodium 当前采用 Freedesktop SDK 26.08，体积比普通运行时大，可能包含 glibc
开发工具；这不等于向 musl 主系统安装 GCC。Flatpak 的库不能满足宿主 Portage
依赖。此前在同一 musl 根中成功 emerge 的库，由 Portage 按版本、USE 和 ABI 复用。

更新时按所选范围执行 `flatpak update --system` 或 `flatpak update --user`。
首次登录后检查应用入口、文件选择、字体、Fcitx、音频、摄像头、共享屏幕和 GPU。
安装脚本不在 chroot 中启动这些服务或 GUI。

## locale 与时区

目标 Gentoo 根内以 root 执行，支持 musl 和 glibc 两种 profile：

```bash
bash scripts/configure-locale.sh --dry-run
bash scripts/configure-locale.sh --lang zh_CN.UTF-8 --timezone Asia/Shanghai
```

脚本备份旧配置到 `/var/backups/locale-setup/`，配置 `/etc/env.d/02locale`、
`/etc/timezone`、`/etc/localtime`，再执行 `env-update`。glibc 分支生成 locale，
musl 分支不调用 `locale-gen`，也不复制 glibc 的 locale archive。
该脚本已分别在真实 musl/glibc 根的独立配置夹中测试，随后也在全新 musl 根
实际配置通过，不改当前桌面的语言。

切换本机登录默认语言为英文仍可保留上海时区：

```bash
bash scripts/configure-locale.sh --lang en_US.UTF-8 --timezone Asia/Shanghai
unset LC_ALL
source /etc/profile
```

重登后桌面和用户 D-Bus 才会继承新环境。仅对一个命令切换语言：

```bash
env LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 date
LC_ALL=C.UTF-8 emerge --sync
```

不要把上面的临时 `LC_ALL` 写进所有登录会话。已有 SonicDE 用户配置
`~/.config/plasma-localerc` 也可能覆盖系统默认语言；在新系统的目标普通用户下
检查系统设置中的区域与语言，不直接覆盖共享旧家目录。必要时先备份该文件，
再按系统实际提供的 `kwriteconfig6` 修改对应组：

```bash
kwriteconfig6 --file plasma-localerc --group Formats --key LANG zh_CN.UTF-8
kwriteconfig6 --file plasma-localerc --group Translations --key LANGUAGE zh_CN:en_US
```

切换前可先用 `cp -a ~/.config/plasma-localerc ~/.config/plasma-localerc.before-musl`
保存已有用户配置；文件不存在时跳过备份。若要切换英文桌面，将上面两项分别改为
`en_US.UTF-8` 和 `en_US`，然后退出桌面重新登录。系统脚本的备份只覆盖系统文件，
不会代替这份用户配置备份。若语言仍不符合预期，检查 `locale` 输出中的 `LC_*`、
shell 启动文件中的 `LANG` / `LANGUAGE`，以及系统设置中各项格式覆盖。

首次登录检查：

```bash
locale
date +'%F %T %Z'
fc-match 'sans-serif:lang=zh-cn'
fc-match emoji
flatpak run --command=sh com.vscodium.codium -c 'locale -a; locale'
```

`LANG=zh_CN.UTF-8` 被接受不代表 musl 拥有 glibc 同等的日期、货币、排序或
iconv 数据。当前原生 libc 的中文格式化和 GB18030 转换存在缺口，ICU 独立验证
通过；应用是否使用 ICU、输入法是否实际输入中文，仍须逐项检查。
Flatpak 内的 glibc locale 单独维护；正常安装脚本以 `extra-languages` 补充中文和
英文，不手工指定语言扩展子路径。它的中文分片是 `/zh`，不是 `/zh_CN`。

## LLVM 构建与补丁边界

[`portage/`](portage/) 中的 Darts 配置只给旧版本选择 Clang C++14，以兼容其
`std::random_shuffle`，不回退 GCC。先合并到目标 Portage 配置，避免覆盖自定义文件。

`package.use/native-desktop` 还记录两项已验证调整：Fcitx 5.1.21 在本轮 X11
目标下关闭自身 Wayland 后端；LevelDB 关闭 tcmalloc。后者避免 Fcitx 动态加载
Rime 时触发 musl initial-exec TLS 错误，不使用全局 `LD_PRELOAD` 绕过问题。

[`patchsets/`](patchsets/) 按软件、适用版本及修改层级保存补丁，不维护完整本地
overlay 副本。各组记录了验证状态、应用检查和上游修复后的移除条件：

- gcompat amd64 加载器路径修正：手工路径已验证，完整 ebuild 草案尚未单独验收。
- CUDA 13.4 宿主数学调用：原生最小 kernel 通过，尚未覆盖完整 SDK 和数学边界。
- Sonic 图像编辑 0.7.0.1：补充 Highway 配方依赖并改用标准 `hwy` CMake Config，
  等效修正已在 musl/Clang 下编译安装通过。
- Sonic 登录管理器 6.8.0.3：为 POSIX ID 类型补充标准头文件；全新根正常沙箱构建通过。

配方元数据补丁与源码用户补丁分开：`/etc/portage/patches/` 不能补齐缺失的
`DEPEND`。新根已通过图像编辑组件的补丁组安装路径，来源保持 `sonicde`。
旧实验根的私有配方快照仅作对照，切换时避免重复应用源码补丁。

桌面 meta 的 `pulseaudio` 选项用于选择音量界面；音频服务端仍由
`media-video/pipewire[sound-server]` 提供。合并配置时移除旧的冲突 `-pulseaudio`
条目，不因使用 PipeWire 而漏装该界面，也不重复启用独立 PulseAudio daemon。

gcompat 不是完整 glibc。NVIDIA 计算、原生图形库、PRIME 和外接显示分别验收；
不能从 `nvidia-smi` 或最小 CUDA kernel 通过推导整个显示栈通过。

最新图形实验参考 Chimera 的 [NVIDIA 草案 PR](https://github.com/chimera-linux/cports/pull/6531)，
固定到 `c26532983c3b811c2d6b310058761bba39491bbe`，仅在私有目录构建带 IFUNC/TLS
补丁的 musl 加载器、gcompat 和兼容 shim，并修改驱动库的实验副本。
原系统及实验根的默认 libc 均未替换。在本机 RTX 4060 / 620.70.06 上，创建
EGL 1.5 / OpenGL 4.6 上下文、离屏清屏与像素回读通过；对照组仍报不支持的
重定位类型 37。这个上游实现仍是草案，本地也尚未打包成可维护的安装方案。
该结果不覆盖 XLibre 驱动加载、显示输出、PRIME、休眠恢复或 Vulkan。

## 新根与回退

现有实验根曾非特权解压，并调整过 Portage 用户和嵌套沙箱，仅用于验证。
正式新根要从已验签 stage3 以正确权限重新建立，恢复标准 Portage 用户、目录归属
和沙箱，再复用已审核配置与受控本地构建包，不直接把实验目录改名后启动。

独立全新根现已建立：63,870 个归档条目的属主、权限与符号链接核验一致，
282 个 stage3 基础包保持原样。随后在默认 `sandbox`、`userpriv`、`usersandbox`、
`ipc-sandbox`、`network-sandbox`、`pid-sandbox` 配置下，源码安装官方 hello 通过，
编译日志确认 UID/GID 250:250，安装后程序输出正确，未引入 GCC 或 glibc。
这验证了安装基础，不表示完整桌面、新内核或真机启动已经通过。

从这个全新根预演完整桌面时，仍会出现 GLib → docutils → Pillow → HarfBuzz →
GLib 的引导循环。候选方案先临时设置 `dev-python/pillow -truetype`，安装
GLib/HarfBuzz 后移除该临时设置，再按最终 USE 重建 Pillow。关闭后完整依赖预演
通过，未计划引入 GCC、glibc、GNU Emacs 或 QtWebEngine。随后两阶段引导已在
该新根实际完成，Pillow 已恢复 `truetype`，临时开关已删除，默认沙箱保留。
随后完整桌面安装通过，已安装 926 个包，图像编辑组件来自 SonicDE 上游配方加
补丁组；新内核与真机启动仍待验收。不能把带临时开关的配置当作最终配置直接复制。

全新根随后也通过独立 Xvfb、私有 D-Bus 和隔离用户配置下的桌面运行检查，
窗口管理器与 shell 的进程、总线接口、中文绘制及 PipeWire 兼容套接字均通过。
测试使用软件 QML、关闭合成，没有真实硬件设备或系统总线；不代表音频播放、
登录管理器、Portal、显卡输出已经通过。新根的音量界面已补齐，保留 PipeWire
服务端；中文 locale、上海时区和系统级 Flatpak 主包的安装后检查均已通过。
针对构建日志的 libc++ 提示，也在私有显示中实际右键打开面板菜单，窗口管理器
与 shell 保持运行；当前组合未复现该操作导致的崩溃，不据此保证其他菜单与会话稳定性。

启动准备时已补齐新根自己的五个仓库副本，固定到已验证版本，profile 不再依赖
测试进程的临时仓库挂载。国内镜像优先及 Gentoo 同步签名检查保留；验收期间暂不
自动同步，以避免构建基线漂移。XanMod/CJKTTY 的内核依赖预演通过，尚未完成
新内核构建与签名。Secure Boot 工具所需的 GNU binutils、LLVM 的 libgcc ABI 库
与 GNU GCC 编译器套件是不同的软件包，不通过删掉必要依赖来伪造 LLVM 安装结果。

NVIDIA 620.70.06 的开源 `nvidia-modprobe` 也已从官方源码、按固定 Gentoo Manifest
校验后在全新根用 Clang/musl 编译，版本与帮助运行通过，只依赖原生 `libc.so`。
目前未安装、未设置 setuid、未用它加载模块；这项结果不代表驱动拆包与显示集成完成。

Gentoo musl profile 已屏蔽 `kde-plasma/powerdevil[filecaps]`。SonicDE 实现与
兼容包也须保持一致，即 `sonicde-base/sonic-power-management -filecaps` 和
`kde-plasma/powerdevil -filecaps`；这与是否以 root 解压 stage3 是两回事。

Btrfs 候选布局是在原文件系统中新增 `@musl`，保留原 `@`、`@home` 和原引导入口。
子卷不是磁盘分区，不能把它重命名为 `/dev/nvme1n1p2`。先使用隔离用户配置，完成
多次启动、桌面使用、更新、备份与回退验证，再单独决定旧根清理范围。

最终布局按原安装教程统一根子卷名：验收通过后，从救援环境挂载 Btrfs 顶层，
将旧 `@` 改名为 `@glibc-backup`，将新 `@musl` 改名为 `@`。同步修正两套系统的
`fstab`、rEFInd 根参数及按名称引用子卷的备份任务；如果 initramfs 固化了旧路径，
也要重新生成。分别验证新根启动和旧根回退后，再决定何时删除旧根。
改名后不会留下另一份 `@musl`，无需删除额外分区，也不改分区 UUID。新机全新安装
可直接使用 `@`、`@home`；迁移期间的临时名字不必长期保留。

本轮不默认安装 GNU Emacs。Neomacs 仍是待验证候选；现有系统和 Windows 的
Emacs 配置保留。若最终保留独立 glibc 根，应明确它需要单独创建、更新、配置用户
与会话接口，不是安装一个 chroot 软件包便自动完成。

## 资料

- [Gentoo musl 项目](https://wiki.gentoo.org/wiki/Project:Musl)
- [Flatpak 基本概念](https://docs.flatpak.org/en/latest/basic-concepts.html)
- [中科大 Flathub 缓存](https://mirrors.ustc.edu.cn/help/flathub.html)
- [Chimera NVIDIA/musl 研究](https://chimera-linux.org/news/2026/11/musl-nvidia.html)
- [Neomacs](https://github.com/eval-exec/neomacs)
