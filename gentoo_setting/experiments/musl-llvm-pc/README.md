# Gentoo musl / LLVM PC 迁移实验

**状态：进行中，尚未从新根真机启动。** 本目录是可回退的实验记录，不能当作
已经完成的新机安装教程。现有 `pc/`、`manifests/desktop.txt` 和
`manifests/nvidia.txt` 仍服务于原 glibc 系统；不要整棵复制到 musl stage3。
Windows 配置不在本次变更范围内。

接续任务先阅读仓库根的 [`AGENTS.md`](../../../AGENTS.md)，再核对本页、world 清单、
仓库基线及相关补丁组。当前结论与尚未完成项以这些现有文件为准；本机运行中的
任务、私有日志和实验根身份记录在本机检查点，不能由公开清单推断进程仍然存活。

桌面批次通过不代表旧 `world` 已全部迁移。逐项核对清单见
[`world-migration.tsv`](world-migration.tsv)，按批次检查点记录旧系统 91 个直接选择的去向；
“待原生预演”表示尚未补齐，不能理解为不支持 musl。PostgreSQL 18.6、ClamAV 1.5.3、
ClamTk 6.18-r2 已安装，软件选择已通过 Portage 登记。迁移验收期间不运行
`depclean`。PostgreSQL 工具执行通过，未初始化或迁移数据库；ClamAV 自定义无害签名的
正、负样本扫描通过，正式病毒库更新仍待验收。ClamTk 的版本限定中文补丁已重建，
私有显示中标题和各组控件的中文绘制通过。

其余软件已逐项预演；软件补齐批次连同旧功能恢复，共 48 个直接选择项已安装通过，
包括 PostgreSQL LLVM/JIT、NetworkManager iwd、Btrfs udev 和 XLibre Xvfb，
四项功能开关已核对。lowdown 3.1.1 的 musl 配置宏冲突已回补上游
修复，并通过全新根沙箱编译安装，见[补丁组](patchsets/lowdown-3.1.1/)。Firefox／Thunderbird
加入 Gentoo 官方 `llvm-runtimes/libatomic-stub` 后原生预演不再选择 GCC；
Thunderbird 现已选择官方 ESR Flatpak，Firefox 的原生 ESR 构建及离线中文渲染检查已通过。
KTorrent 关闭可选内嵌 WebEngine，避免额外的网页引擎构建。QQ 和 LocalSend 已通过
Flatpak 界面检查；FlClash 的 glibc 界面、Helper/TUN 和 OpenRC 集成仍待验证。

下载默认沿用调用环境的代理；当前批次使用已恢复的本地代理。国内直连只在
网络确实可达且已核验速度时临时启用；
默认镜像顺序仍是国内优先。路由调整不关闭 Manifest 或二进制包签名校验。

Bun 官方 musl baseline 归档已按发布资产 SHA256 校验；它另需 musl 版 C++ 运行库。
复用已验签的 Alpine 约 2.7MiB `libstdc++` 后，独立官方 stage3 中已通过正常
Portage 沙箱安装、JavaScript、中文与人民币格式化，且 SONAME QA 无未解析依赖。
未安装 GCC 编译器或 glibc，也不全局修改库路径。配方已整理为
[补丁组](patchsets/bun-1.4.4/)；主桌面实验根的集成安装和 CLI 检查也已通过，
原生 musl Bun 完整博客构建已在普通用户、隔离网络和独立源码副本中通过，
包含类型、测试、内容、runtime、Hexo 和生成物检查；复用现有只读 node_modules，
不是新机空缓存依赖安装证明。原博客源码与依赖哈希保持不变。

截至 2026-11-15 的 Firefox 批次复核，旧系统 91 项 world 选择中，77 项已有同名原生安装，Telegram
以原生源码包替代，GNU Emacs 以原生 Neomacs 替代，JDK 改为 Dragonwell Standard
21 LTS；微信、VSCodium、LocalSend、Thunderbird ESR 与 QQ 使用 Flatpak；
mold 按方案排除。
剩余为一项普通应用（FlClash），以及 WPS、腾讯会议、
NVIDIA 用户态和 CUDA 运行链四项专项集成。
这些是直接选择的核对数量，不是总依赖包数量，也不表示全部 GUI 和旧数据验收通过。

软件与配置批次串行操作同一新根。Portage 配置已归并并核对有效设置；
启动载荷批次复核后新根有 1,208 个依赖包、92 个 world 选择，Neomacs 已安装并选为默认编辑器。
未知报错保留日志处理，不自动切换引导、迁移数据库或清理原系统。
34 项对齐操作已完成（21 个新依赖、13 项 USE 重建），包括 LLVM SPIR-V translator、
libclc、Mesa CLC 和 cargo-c；随后又安装 Firefox 的五项较小前置。最终
`@world --update --deep --newuse` 预演没有待合并项，未引入 GCC/glibc。
官方 stage3 的 platformdirs 4.12.4 通过精确关键词保留，避免非必要降版。
Firefox 已按 [153.7 ESR 配方](patchsets/firefox-153.7/)正常沙箱构建安装，Node 和中文
语言包已装。Firefox 专用 rustc wrapper 修复了静态 musl 宿主脚本无法动态加载
libclang 的问题；普通用户、隔离网络、空白 profile 的中文页面渲染及截图目检通过，
未验收 GPU、输入法、旧 profile 或 Widevine DRM。构建临时目录位于独立 Linux
文件系统，根分区保留 20GiB 底线。

CUDA 的[最小数据包补丁](patchsets/cuda-13.4/)已完成正常 Portage 安装，并以安装后的
头文件和 libdevice 通过普通用户变量 sinf 的 sm_89 PTX 编译验证。它只提供 Clang device-only 头文件和 libdevice，
另一个 Portage 包 `dev-util/cuda-sdk-flatpak-13.4.1` 提供官方 NVCC／核心 cudart 的压缩归档和 `cuda-sdk` 入口，复用现有 Freedesktop SDK 26.08。普通用户 NVCC 编译、CMake／CTest 与 RTX 4060 数学计算通过，无原生 GCC／glibc 依赖；SDK 内实际使用已有 GCC 16.2，产物为 glibc ELF。完整数学库、PyTorch、原生 NVIDIA 显示及新内核硬件启动仍未验收。


## 实验基线与已验证范围

本轮从官方 `stage3-amd64-musl-llvm-openrc-20261108T170107Z.tar.xz` 开始，
已核对发布签名和 SHA512。对应 profile 是
`default/linux/amd64/23.0/musl/llvm`，原生工具链为 Clang/LLVM、LLD 和 libc++。
它仍是实验 profile，stage3 可下载不等于完整桌面已经可用。

| 项目 | 当前结果 |
| --- | --- |
| musl 原生 UTF-8 文件名、内容、中文编码 | 通过 |
| ICU 中文日期、人民币、排序、GB18030 转换 | 独立程序通过 |
| 原生 CUDA 编译和 RTX 4060 计算 | Clang／libc++ musl 程序结合静态 cudart、gcompat 和小补丁通过最小 kernel；不是完整 SDK/PyTorch 验收 |
| 托管 CUDA 核心 SDK | NVCC 13.4、CMake／CTest、32 个 sinf GPU 回读通过；使用 Flatpak SDK 内现有 GCC 16.2，不代表完整数学库或新内核启动 |
| NVIDIA 开源内核模块 | 五个开源模块以 UID250 编译安装，匹配新内核并逐个公钥验签；GSP 已由 Portage 安装，尚未真实加载 |
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

## Neomacs 与默认编辑器

Neomacs 0.0.20 已在真正 musl 根安装，固定上游
`aacf29294ab30aed5736e1eabcb3b83122593fce`，未引入 GCC 或 glibc。
[补丁组](patchsets/neomacs-aacf292/)分别维护 musl 编译兼容、栈段测量修复、
SQLite 特性和安装资源路径。栈增长对照证实原实现跨栈段保留旧测量值，导致申请
不断增大；修复后完成完整 Lisp 引导及安装。本次复用已有编译缓存，不等于全新
源码、空缓存重建已经通过。

SQLite 中文读写、私有 X11 GUI 及 Fcitx5/Rime 实际键入保存“你好”均通过。
实验根已选为默认编辑器，尚未验收真机 GPU 或旧 Doom 配置。新机安装并验收后，
在目标根以 root 执行：

```bash
eselect editor set neomacs
eselect editor list
eselect editor show
source /etc/profile
```

eselect 的 editor 模块支持按程序名或绝对路径设置自定义编辑器，设置成功后也会
列出当前选择，无需修改模块或伪装成 `emacs`。文件须已安装到 `/usr/bin/neomacs`。
共享 Bash/Zsh 配置已改为尊重继承的编辑器选择；未设置时优先已安装 Neomacs。
原 glibc 默认及独立 Windows 配置保留。Git 的 `core.editor` 等额外设置仍需在隔离
用户配置中核对；仅设置 eselect 不代表 GUI、中文输入或原 Doom 配置已经兼容。

## Dragonwell 与其他二进制软件的包管理

Dragonwell **Standard 21 LTS** 21.0.13.0.13+9 已通过正常 Portage 安装和
`eselect java-vm` 登记；不使用 Extended，不安装 GCC 或 glibc。实际安装产物以
普通用户通过 javac、中文读写、人民币格式、上海时区、CJK 字体及系统证书库检查。
[补丁组](patchsets/dragonwell-21.0.13/)包含现有 Gentoo-Zh 中新增配方与 Gentoo
Java 21 虚拟依赖调整，两份补丁分别应用到各自仓库，不新增 overlay。

其他尚无配方的软件也优先用固定版本和 Manifest 的二进制 ebuild 管理，程序及
专用兼容库放在版本化 `/opt`，由 Portage 跟踪文件、依赖、升级及卸载。AppImage
可以按相同方式解包管理；不需要为解包安装强制引入 FUSE。兼容库由程序私有
RPATH 或启动脚本引用，不全局修改库路径。Flatpak 的应用和运行时继续由 Flatpak
管理，本仓库只维护主包清单与脚本，避免两个包管理器共同管理同一组文件。

FlClash 上游[暂不计划提供 Flathub 包](https://github.com/chen08209/FlClash/issues/1190)，
理由涉及 Helper、TUN 与系统代理所需的系统权限。不能把同名社区包或仅提供本地
代理的封装算作完整等价替代。当前仍保留它的兼容与 OpenRC 验证任务。

### Java IDE 同样使用 Standard 21

新环境统一 **Dragonwell Standard 21**，不使用 Java 25。Portage 已显式屏蔽其他
OpenJDK provider 与 Dragonwell 22+，阻止后续依赖自动引入不同家族／主版本；宿主只有一个
`dragonwell-bin-21` 系统 VM；Flatpak 内 Java 工具使用同一版本的私有 **glibc**
构建，宿主使用 **musl** 构建，不混用进程内 JNI，也不注册第二个宿主默认 VM。

当前 Red Hat Java 1.58 要求 JDK 25，不能只把路径改为 21。独立 profile 中已验证
[Oracle Java 扩展 27](https://github.com/oracle/javavscode/releases/tag/v27.0.0)
搭配 Standard 21：激活、符号、补全、中文编译运行及真实 DAP 断点／求值通过，
调试目标报告 Alibaba／21。27 是扩展版本；扩展不捆绑 JDK。两项官方资产及哈希见
[`java21-ide-assets.json`](scripts/java21-ide-assets.json)。它记录实验接受基线，
不是已经运行过的用户配置迁移安装器。后续升级先复核 Java 21 支持和安全更新。

原微软 Java Debug/Test/Project Manager 配置、Maven/Gradle/JUnit 和真实项目仍待
迁移验收；原用户扩展保持原样。目标 profile 不启用要求 25 的扩展，不能用冻结
旧版本冒充仍受维护的兼容路线。

## Flatpak 主包与一键安装

主包清单在 [`scripts/flatpak-apps.txt`](scripts/flatpak-apps.txt)。当前默认：

- `com.tencent.WeChat`
- `com.vscodium.codium`
- `org.localsend.localsend_app`
- `org.mozilla.thunderbird_esr`
- `com.qq.QQ`

Thunderbird 使用官方 ESR 渠道；QQ 是社区封装，程序来自腾讯固定地址并核对
extra-data 哈希。二者的隔离中文界面启动通过；QQ 测试为离线错误界面，不等于
登录或服务连接成功。旧邮件／账户数据、插件、音视频均未迁移或验收。

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

全新根已运行系统级安装脚本检查微信和 VSCodium，随后系统级安装 LocalSend 1.18.2；
LocalSend 私有 X11 中文界面通过，真实局域网发现／文件传输尚待验收。VSCodium 通过实际 Fcitx/Rime
中文输入。此次先复用了已校验的实验缓存，尚不代表从空缓存下载的全流程测试；
主包部署、输入测试也不代替真实会话中的 Portal、音视频和全部扩展验收。

清单只固定应用 ID。运行时、SDK、Locale、Mesa 和匹配的 NVIDIA 图形扩展由
Flatpak 自动解析。可选 `--system --cuda-sdk` 为本候选内核显式部署 SDK 26.08 和 NVIDIA 620-70-06 扩展，避免 chroot 按安装介质驱动选择错误版本；其他机器或驱动升级须先修改该选项中的精确版本，不能直接照搬。详见 [CUDA 补丁组](patchsets/cuda-13.4/)。
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

## 用户、对话与 IDE 数据迁移准备

当前只完成分类与隔离测试，**尚未迁入真实目标 home、创建真实用户或新子卷**。
保留 UID/GID、附加组和最终 home 路径，先核对目标冲突；服务用户由已安装软件包
建立，不能复制整个旧 passwd/shadow 或把隔离映射中显示的 nobody 当作真实属主。

| 数据 | 迁移方式与当前边界 |
| --- | --- |
| 对话 sessions、索引、SQLite | SQLite 有活跃 WAL；在线 backup 只能做单库预复制，最终应用停写后做一致性快照／增量核对 |
| VSCodium User、工作区、WebStorage／Local Storage | 后两者是混合状态，私有保留后逐项验收，不当普通缓存删除；不将认证内容灌入测试 profile |
| 用户配置、项目与个人文件 | 保留符号链接及相同 home 路径；venv、`.node`、ELF、`.eln` 分别检查 ABI，生成缓存按需重建 |
| 用户身份与本机网络等配置 | 保留数字身份、组与权限；网络、蓝牙、钱包及凭据在对应受限步骤迁移和会话验收 |
| PostgreSQL 与其他服务数据 | 不属于 home 快照；采用一致性备份及经过验证的逻辑恢复，不直接搬物理 PGDATA |

VSCodium 实际源清单为 **56 项**：冻结前／副本／冻结后哈希与版本一致，隔离测试
33 项 active、6 项声明式注册、17 项因 Java 政策、在线、远端或硬件等延期。
11 项最小功能探针通过；注册不代表完整工作流。Makefile/debugpy 的首次只读夹具
错误经独立可写执行副本复验解决；Xmake 经候选根私有 `flatpak-spawn --host`
桥接后，用现有 Clang/libc++ 实际构建并运行中文 C++。源目录和 OS 沙箱保持。
Oracle Java 21 是另一份独立 profile 验收，不混入上述 56 项计数。

Neomacs 已通过 Doom 2.2.4 core 源码加载及 early-init 最小非交互初始化；未复制
旧包缓存、`.eln` 或笔记，不代表全套 Doom 模块／插件及交互界面已经兼容。

PostgreSQL 18.6 合成测试通过 UTF8/ICU 中文排序、约束、索引、逻辑 dump/restore，
并由宿主 glibc pg_dump 对私有 musl 测试服务器导出、musl pg_restore 恢复验证。
LLVM JIT 也实际执行通过。原数据库、角色密码与服务没有读取或迁移。

正式数据切换先建立原 `@home` 的回退基线及独立写入测试树，避免两套系统共用
可写旧配置；应用停写后再固定最终快照，核对权限、哈希及工作流。当前未执行
快照、子卷改名或真实用户数据切换。详细边界集中在博客迁移文章和本机检查点。

## LLVM 构建与补丁边界

新根的六类配置已按原顺序归并为各自的 `desktop` 文件，保留来源注释。
整理前后比较 1,158 个已安装包的有效设置，差异为零；替换前快照保留在本地实验区，
未包含私有 GPG 目录。仓库的 [`portage/`](portage/) 同步这份已复核的配置、环境片段、
国内优先镜像及固定仓库提交清单；源码补丁仍只在 `patchsets/` 维护，避免重复副本。

这不是整目录覆盖 `/etc/portage` 的安装器。新机按 `profile.txt` 选择 profile，
核对 `repository-baseline.tsv`，再合并各配置组并按补丁组说明部署源码／配方修复。
`make.conf` 是本轮 stage3 的基线，核对目标 Python、LLVM、硬件与 USE 后再用；
内核已构建签名，仅模块 NVIDIA 与 GSP 数据包已验收；配置不含签名私钥，真实
启动和用户态驱动仍未完成。
仓库暂设 `auto-sync = no` 以冻结实验基线，后续更新须复核补丁，不能长期跳过更新。

Darts 配置只给旧版本选择 Clang C++14，以兼容其
`std::random_shuffle`，不回退 GCC。先合并到目标 Portage 配置，避免覆盖自定义文件。

`package.use/desktop` 还记录两项已验证调整：Fcitx 5.1.21 在本轮 X11
目标下关闭自身 Wayland 后端；LevelDB 关闭 tcmalloc。后者避免 Fcitx 动态加载
Rime 时触发 musl initial-exec TLS 错误，不使用全局 `LD_PRELOAD` 绕过问题。

软件补齐批次还为 Yakuake 26.04.3 关闭可选 Wayland 后端，避免拉入与 SonicDE
ECM 不兼容的 KWayland；已正常编译安装。Gwenview 26.04.3
通过版本限定的 `package.env` 使用上游 `GWENVIEW_NO_WAYLAND_GESTURES=ON`，
仅关闭 Wayland 专用手势协议。只读挂载真实 musl 根的独立 CMake 检查中，默认配置
因缺少 WaylandProtocols 失败，X11 配置成功；随后正常 Portage 编译安装、隔离 CLI
版本检查通过，完整 GUI 操作仍待验收。环境文件使用 Portage 可解析的字面量设置。
这些应用配置保留全局 Qt/Wayland 客户端库，不修改 SonicDE ECM 或 Qt 提供的模块。

[`patchsets/`](patchsets/) 按软件、适用版本及修改层级保存补丁，不维护完整本地
overlay 副本。各组记录了验证状态、应用检查和上游修复后的移除条件：

- gcompat amd64 加载器路径修正：手工路径已验证，完整 ebuild 草案尚未单独验收。
- CUDA 13.4：原生 device-only 数据包安装及 PTX 通过；Portage 管理的 Flatpak SDK 核心 NVCC／cudart 路线也已通过普通用户 CMake 和 GPU 数学测试。完整数学库、RDC、PyTorch 和真实项目仍待验收。
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

目标根已静态登记 `elogind`（boot），以及 `dbus`、`NetworkManager`、`soniclogin`、
`firewalld`、`sysklogd`、`chronyd`（default）；未实际启动服务。Sonic 登录器自身
提供 display-manager，不另启 xdm；iwd 由 D-Bus 激活，PipeWire 保持用户会话启动。
XanMod 和 virtual/dist-kernel 已在独立实验根安装并登记更新；新内核的签名、
CJK 检查通过。通用设备固件、Intel 微码、rEFInd 和 shim 已用官方配方正常安装；rEFInd 的 musl／Clang 修复直接复用上游，无新增 overlay 或本地配方补丁。
NVIDIA 五模块与同版本 GSP 的[补丁组](patchsets/nvidia-620.70.06/)已通过正常安装
和载荷／签名检查；尚未完成用户态、真实模块加载或显示验收。批次使用同一写锁与已测试的
子进程清理机制，签名材料限于只读源文件，私钥副本仅保留在新根的 root 私有目录。
用户已选择普通动态抢占的 `preempt=full`；候选 `/etc/kernel/cmdline` 目前仅登记这一项，尚不是完整可启动命令行。确定根 UUID／子卷后须与原有必要参数合并到新启动入口，首次启动再检查实际抢占模式；这不启用 PREEMPT_RT，也未改变当前运行内核。
真实 EFI 分区未写入；fstab、完整根启动参数、真实用户与回退启动仍未完成，当前不能切换启动。

本候选的可复用启动配置为 [`dracut.conf.d/50-musl-migration.conf`](dracut.conf.d/50-musl-migration.conf)
及 [`modprobe.d/50-nvidia-migration.conf`](modprobe.d/50-nvidia-migration.conf)。
前者使用通用根发现、不捕获当前宿主命令行，加入 NVMe、i915、Wi-Fi／蓝牙、有线网和
五个 NVIDIA 模块，省略 nouveau；后者配置 nouveau 黑名单和 NVIDIA DRM modeset。
`linux-firmware` 采用 zstd 压缩，与实际内核压缩固件支持匹配；关闭其和 Intel 微码包的
独立 initramfs 安装动作，由 dracut 统一组装。Intel 微码保留 split-ucode，镜像早期归档
中已确认包含本 CPU `0x000b0671` 的修订 `0x0137`，并未在线更新当前 CPU。

新机须先生成自己的签名材料、安装模块与固件、复核此处目标版本及驱动选择；
候选签名环境文件只指定路径，不含密钥，也不关闭普通软件的 userpriv／沙箱。在目标
root chroot 中，从本实验目录安装配置后重建（以下命令不部署 EFI）：

```bash
emerge --ask sys-kernel/linux-firmware sys-firmware/intel-microcode sys-boot/refind sys-boot/shim
install -Dm644 dracut.conf.d/50-musl-migration.conf /etc/dracut.conf.d/50-musl-migration.conf
install -Dm644 modprobe.d/50-nvidia-migration.conf /etc/modprobe.d/50-nvidia-migration.conf
# 替换为自己已安装、已签名且模块匹配的目标版本，不能使用安装介质的 uname -r
kernel=7.2.14-musl-x64v3
dracut --force --kver "$kernel" "/boot/initramfs-$kernel.img"
lsinitrd "/boot/initramfs-$kernel.img"
```

本轮约 173MiB 的最终镜像已解包检查 NVMe、核显、Wi-Fi、NVIDIA／GSP 和早期 Intel
微码；镜像内两项 NVMe 模块及五项 NVIDIA 模块以预期公开证书通过实际 CMS 验签。
10 个 UEFI 载荷（含 rEFInd、Btrfs 驱动和 MokManager）通过本机证书验证，但不代表
主板／shim 信任链已验证。私钥目录未进入镜像，小型文件的私钥标记扫描也通过。
受限实验进程内 dracut 的五条 mknod 权限警告已保留：已确认镜像 init 有 devtmpfs
挂载逻辑且内核启用 DEVTMPFS；最终行为仍以真机启动为准，不为消除警告放宽宿主权限。
不要在本阶段运行 `refind-install` 或沿用原 glibc 脚本硬编码的 `/usr/lib64/refind`；
本 musl 根实际载荷位于 `/usr/lib/refind`。


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
自动同步，以避免构建基线漂移。XanMod/CJKTTY 已完成新根构建、签名及存储驱动检查，
仍未从新根启动。Secure Boot 工具所需的 GNU binutils、LLVM 的 libgcc ABI 库
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

本轮不安装 GNU Emacs，实验根已使用 Neomacs；旧 Doom 配置仍待验收，现有系统和
Windows 的 Emacs 配置保留。若最终保留独立 glibc 根，应明确它需要单独创建、更新、配置用户
与会话接口，不是安装一个 chroot 软件包便自动完成。

## 资料

- [Gentoo musl 项目](https://wiki.gentoo.org/wiki/Project:Musl)
- [Flatpak 基本概念](https://docs.flatpak.org/en/latest/basic-concepts.html)
- [中科大 Flathub 缓存](https://mirrors.ustc.edu.cn/help/flathub.html)
- [Chimera NVIDIA/musl 研究](https://chimera-linux.org/news/2026/11/musl-nvidia.html)
- [Neomacs](https://github.com/eval-exec/neomacs)
