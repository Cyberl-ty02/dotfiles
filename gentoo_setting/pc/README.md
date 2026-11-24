# Gentoo PC：musl／LLVM／OpenRC

这是本仓库默认 PC 配置，已从官方 musl LLVM stage3 安装并真机启动。
“默认”指本仓库的维护选择，不代表 Gentoo 的实验 profile 已转为官方稳定。
WSL 保持独立配置；旧 glibc PC 配置不再并行维护，可从 Git 历史或本地标签
`archive/glibc-pc-before-musl-promotion` 找回。

完整安装、兼容运行库、迁移经过与排错放在博客正文：
[Gentoo musl／LLVM PC 迁移](https://kagaranakaki.top/posts/gentoo-musl-llvm-pc-migration/gentoo-musl-llvm-pc-migration/)。
本目录只维护可复现配置、脚本、补丁和当前验收边界，不保留逐轮缓存报告。

## 配置入口

| 目录／文件 | 用途 |
| --- | --- |
| `portage/` | profile 说明、国内优先镜像、make.conf、包级规则、仓库基线与私有应用集合 |
| `patchsets/README.md` | 补丁顺序、基线、预检入口；各补丁组只说明适用范围与移除条件 |
| `scripts/` | locale、Flatpak、工具链、桌面、用户资料、编辑器及仓库补丁恢复入口 |
| `kernel/`、`dracut.conf.d/`、`modprobe.d/` | 内核、initramfs、签名与 NVIDIA 策略 |
| `desktop/`、`services/` | 字体及服务模板；不包含真实数据库或身份凭据 |
| `world_packages.txt` | 当前原生直接选择清单；先预演，不能跨 ABI 直接照装 |
| `world-migration.tsv` | 原 glibc world 的逐项迁移去向，属于历史审计证据 |

## 新机安装与 chroot

基础 profile 为 `default/linux/amd64/23.0/musl/llvm`。先按博客完成分区、挂载、
官方 stage3 验签、解压、网络和 chroot，再审核本目录配置，不能整棵覆盖 `/etc`。
不把 glibc JDK／应用库加入宿主搜索路径。所有 JVM 均使用 **Dragonwell Standard 21**，
需要 glibc 的应用使用独立私有运行库或 Flatpak；不回退到捆绑的 JDK 25。

在目标 musl 根内、以本目录为工作目录：

```sh
# 默认只检查补丁与当前仓库兼容性；确认后显式添加 --apply。
python3 scripts/restore-repository-patches.py
# 预览可撤销的 Portage xmake 优先入口；审核后使用 --apply。
python3 scripts/configure-portage-xmake.py
# 先预览 locale 配置；musl 不使用 glibc locale-gen。
bash scripts/configure-locale.sh --lang zh_CN.UTF-8 --timezone Asia/Shanghai --dry-run
# 使用脚本的系统级安装模式，适用于 chroot；逐项失败时停止检查。
bash scripts/install-flatpak-apps.sh --system --dry-run
```

Flatpak 主包以 `scripts/flatpak-apps.txt` 为唯一清单；不要把 Flatpak runtime
误当作原生 Portage 依赖，两者管理范围不同。Flatpak 下载和系统配置可以在 chroot
准备，桌面登录、密钥环、音视频与硬件功能必须在真实会话中验收。
Secure Boot 材料在目标机器本地生成，见 `kernel/secureboot/README.md`，不提交私钥。

## 工具链与维护

- Clang／libc++、全局 ThinLTO 与 mold 保持；不默认全局 `~amd64` 或编译缓存。
  内核使用 LLD，GNU-EFI／rEFInd 保留 BFD 例外。
- LLDB 22.1.8 已安装；原生 musl C++ 的断点、变量、表达式、继续至退出0与 Python
  绑定最小检查通过；定向依赖预演确认只删除 GDB 后，GDB 已移除。其配方过滤 LTO，现有 LLVM 静态库含 ThinLTO，因此使用
  `llvm-core/lldb linker-lld`；上游配方／库构建方式改变时重新验证该例外。
- uutils-coreutils、uutils-findutils、Toybox、Dash 已并行安装并通过最小运行检查。
  uutils 使用 `uu-`／`uutils-` 前缀，Toybox 使用自己的入口；没有覆盖系统核心命令
  或替换 `/bin/sh`。另在无系统 PATH 回退的隔离目录，用 Dash 和 uutils 验证了排序、复制、移动、
  stat、日期、哈希、路径解析及 find/xargs 的空字符传递；仍不等于完整 GNU 行为兼容。
- LLVM 的归档和二进制工具已在登录环境生效；`AS="clang -c"` 不改为处理 LLVM IR
  的 `llvm-as`。Bash、GNU make／autotools、binutils 及私有 SDK 的 GNU ABI 依赖
  仍分别保留；无原生 GCC／glibc 不等于整机零 GNU。
- 日常自有 C/C++ 项目优先使用 xmake；Portage 保留各包上游构建系统，
  可用 `scripts/configure-portage-xmake.py --apply` 部署兼容优先入口；
  不设置 `MAKE=xmake`、不覆盖系统 make/gmake，bootstrap 与核心链保留例外。2026-11-24 定向 depclean 预演中，
  GNU Make、BSD make、CMake、Meson、Ninja 均仍被需要，没有卸载项。
  xmake 的 LLVM 项目模板与 Makefile 转接修复见 [xmake 补丁组](patchsets/xmake-trybuild/)。
  本机兼容策略已启用；QtSerialPort 的真实 Portage 暂存 A/B 与两项上游测试、
  tree 的 Make 暂存构建及运行通过。不等同于整个 world 验收，也未证明提速／省空间。
- 日常 emerge 优先复用本机 binpkg，并检查 USE／依赖变化；不默认启用 ccache。
  新补丁及工具链／编译参数变更后的重建显式使用 `--usepkg=n`，不能假定旧包
  自动感知源码补丁或编译参数。普通更新先预演 `--update --deep --newuse @world`，
  不把 `emerge -e` 作为日常维护命令。
- `package.*` 按包原子升序，忽略前导版本运算符；同一选择器与注释保持顺序。
  make.conf 保持依赖分组与国内镜像优先顺序，不按字母全局重排。
- 规则优先按包／slot／受影响版本范围；补丁严格预检，已有相同上游修复时跳过，
  不兼容时停止。同步后先运行补丁恢复脚本预检，不新增另一套 overlay。

## 专项源码重建

`emerge -e` 用于专门的工具链验证，不是日常更新命令。当前配置默认复用本机 binpkg，
专项源构建必须显式关闭复用，并先预演：

```sh
emerge --pretend --emptytree --usepkg=n --getbinpkg=n --with-bdeps=y @world
```

需要验证现有安装而不是顺便升级时，先记录已安装的 CPV、slot、来源仓库和可用配方，
用本轮临时的精确版本／仓库快照约束任务，不把它们写成长期 package.mask 锁。
`@world` 与全部已安装包也不完全相同；缺失配方、上游 mask、旧孤立数据包和二进制
分发包分别处理，不为凑齐计数强行 unmask。虚拟／别名包重装、固件解包以及 Flatpak
运行库不算独立源码编译。

开始前核验 XLibre 实体与兼容虚拟包的 USE 一致性，保留正常 userpriv／沙箱和至少
20GiB 根分区余量。大构建可用独立文件镜像，不能把物理分区直接交给 mkfs。
内核、驱动、签名和实际启动仍执行联合门槛，不混入无人值守的普通包替换。
关键旧工具链可用 quickpkg 备份，显式不含 CONFIG_PROTECT 配置；不把用户凭据或
签名私钥当作可清理缓存。

继续失败任务前先读实际日志，保持同一个任务环境与单个 Portage 写入者；私有挂载
命名空间中的任务不能在普通 shell 随意 `--resume`。`--keep-going` 仅继续独立可构建
项目，不表示会自行修复源码，也不据此宣称已完成。最终分开统计原生 xmake、仅转发
Make／Ninja、无编译阶段和二进制包；源码构建通过不代替运行、硬件和重启验收。

## 当前验收边界

普通软件更新及保留库重建已通过，SonicDE 6.8.2／Qt 6.11.3 已真机启动。
字体、Neomacs、Codex／VSCodium、独立 root Zsh 与 VSCodium 原生 Zsh 入口已验证。
`scripts/configure-root-zsh.py` 默认识别调用者；root／chroot 直接调用时显式传入
`--user` 指定源账户，不假定新机器沿用本机用户名。
CUDA/NVML、NVCC/CMake/CTest 和 GPU 数学回读通过，设备权限保持 root:video 0660。
私有 SDK 内的 Python GPU 环境和专项检查入口见 `patchsets/cuda-13.4/README.md`，
不能在 musl shell 直接激活其中的 glibc 虚拟环境。
VSCodium 启动器同时为 Chromium 和 Node 扩展转发调用 shell 的 HTTP(S) 代理，
按进程启用 `NODE_USE_ENV_PROXY`，不硬编码代理或关闭证书验证。已有编辑器实例
不会因再次运行 codium 而继承新环境；需要完整退出所有窗口后从启用代理的 shell
重新启动。Actions 提交不存在与本机 API 连接超时应分开诊断，不能为消除误报改用浮动 tag。
Sonic Terminal 26.08.3 已回补上游最小化修复，新窗口的最小化／恢复与最大化状态
保持回归通过，见 `patchsets/sonic-terminal/`。旧终端任务不自动关闭，新开独立
窗口可使用 `konsole --separate`；已有进程仍需方便时正常退出后再开。
标签行及页眉／容器边界漏出壁纸的透明间隙也已修复。显示／隐藏标签栏、顶部／
底部与普通／半透明八组 ARGB 检查，以及真实 desktop 启动项和新标签检查通过，
终端内部透明度保留；同样见该补丁组，不全局改为不透明。
不希望开机恢复上次的终端、编辑器和 FlClash 窗口时，以桌面用户运行：

```sh
kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession
```

`desktop/ksmserverrc` 只给出这一项模板，不整文件覆盖已有会话资料。用户已于
2026-11-23 人工确认开机体验正常；不会关闭当前窗口或禁用用户明确设置的自启动服务。

rEFInd 的 Gentoo 菜单由 `scripts/configure-refind-dual-root.py` 显式引用自带的
Gentoo 图标，内核更新后仍保留该设置。可选 Ventoy 卷标图标与来源见
`kernel/refind-icons/`；使用 rEFInd 原生扫描，不修改 USB、Windows 或固件 BootOrder。
图标和菜单已配置，用户已人工确认本机开机体验正常；不将其泛化为任意外接介质
或未知卷标的识别保证。

新系统 PostgreSQL 18.6 的只读元数据核验仅见默认三个数据库，postgres 库用户关系、
自定义函数与大对象计数为零；不能据此代替其他数据库逐库审计或原库恢复验收。

用户已确认 Codium 开发、Java Hello World、音视频日常使用、WPS／微信、PostgreSQL
和 FlClash TUN 暂无异常。本轮还完成 Maven 项目生成／JUnit、完整 Doom／Neomacs GUI 与
插件加载检查；会议共享、休眠唤醒和具体 CUDA 生产负载等按需要单独验收。
2026-11-23 用户另行确认 Windows 配置同步已完成，可选应用日常使用大致正常。
这些属于人工使用反馈，不代替逐项专项测试、归档恢复演练或长期负载验收。
不会自动登录账号、发消息或授予 OAuth 权限。

power-profiles-daemon 已通过官方 OpenRC 脚本启动并加入 default，当前 balanced，
performance／power-saver 可用，SonicDE PowerDevil 的会话服务正常。新机先确认没有
TLP／tuned 等冲突服务，再运行 `rc-service power-profiles-daemon start` 和
`rc-update add power-profiles-daemon default`；不强制切换电源档位。

`services/NetworkManager/30-connectivity.conf` 使用实际可达、不会被常见 Fake-IP
规则替换的标准探测域，保留正文和门户检查。部署前创建 `/etc/NetworkManager/conf.d`，
复制后执行 `nmcli general reload conf`，再用 `nmcli networking connectivity check`
核验。本机已由 limited 恢复 full，不关闭检测、不重启 Wi-Fi，也未放宽防火墙。

Neomacs 使用完整 Doom Emacs 框架，与 Windows 共用 `../../dot_config/doom/` 的
模块和自有配置，配置入口只保留这一处。以目标用户运行
`sh gentoo_setting/scripts/deploy-doom.sh`；root 使用独立、root 所有的框架和插件，
不执行普通用户可写的配置。安装脚本先补齐上游记录的模块子仓库，再同步插件，
不单独追踪模块仓库的新分支。日常更改模块后运行 `doom sync`。

本机完整 `doom sync`、普通用户 GUI／TTY 开始页、SPC／Evil、Corfu／Vertico／
Magit／Org 加载及 root 独立 TTY 验收通过。两边使用相同模块配置，各自生成缓存；
不迁入旧 Doom 字节码或原生缓存，不引入 GCC。Discount 提供 Markdown 预览编译，
ShellCheck 使用官方静态包，两者已实际运行；doctor 仅保留可选 Symbola 字体提示，
现有 Noto／Nerd／中文字体回退保持。详细源码基线和边界见 Neomacs 补丁组 README。
Spacemacs 已不启用，可重新下载的发行版与缓存已清理；少量旧配置与回退资料仅在
本机私有状态目录保留，不进入仓库。安装通过不代表全部可选语言模块或旧插件兼容。

旧系统三份加密归档已完整校验，并于2026-11-23在数据盘的独立 Btrfs 文件镜像中
实际恢复：旧 root／home 接收为只读子卷，boot 解包，恢复文件系统的只读 scrub
通过。测试镜像已卸载、解除 loop 并删除。这验证归档可恢复，没有切换到旧系统启动，
也没有启动恢复出的数据库。用户随后明确决定退役旧恢复来源；三份旧密文及专用恢复
凭据、旧配置备份、旧编辑器副本、历史测试和构建缓存已按逐文件清单清理。
ESP 仅清理旧碎片和过时菜单备份，现用引导文件摘要保持不变。不再安排旧系统回退启动。
当前根／HOME 已为 `@`／`@home`；旧根及旧 HOME 已加密归档退役，旧 Linux 启动入口
已移除。当前数据、签名材料、运行环境和软件包不属于旧迁移缓存。

本机接续先核对私有检查点指定的活进程、启动 ID、任务状态和日志；不从 README
推断仍有授权或构建。保持单个 Portage 写入者和至少20GiB根分区余量，不自动关机。
当前已统一到 main；保留远端已有正文及 Windows 配置。完整报错复盘、退役决定及
新线程接续方法集中在博客正文；这里不维护逐轮日志。博客部署必须得到明确授权。
隐私匿名化已改写历史；其他机器（含 Windows）的旧克隆先保存自有改动和未推送提交，
优先在新目录重新克隆 main 后迁入自有变化，不直接合并新旧历史或重置未保存的工作。
