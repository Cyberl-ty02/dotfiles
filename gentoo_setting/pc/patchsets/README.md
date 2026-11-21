# PC 兼容补丁索引

每个目录对应一个软件或明确版本。`repository/` 修改仓库里的 ebuild 元数据；
`source/` 修改解包后的上游源码。Portage 用户补丁不能补上缺失的 `DEPEND`，
因此这两层分开保存，不再维护一份完整本地 overlay/ebuild 副本。

| 补丁组 | 适用范围 | 当前状态 | 移除条件 |
| --- | --- | --- | --- |
| [Sonic 图像编辑](sonic-quick-image-editor/) | 0.7.0.1；SonicDE overlay `a5e6600f3dbd67b02ca61a095e036c8a908fe0cc` | 全新 musl 根使用配方补丁和用户源码补丁编译安装通过 | 配方声明 Highway，源码改用可用的 CMake 包 |
| [Sonic Terminal 最小化](sonic-terminal/) | 26.08.3；回补上游 75ba4c38 | 源码校验、严格应用／撤回、正常沙箱重建及真机最小化／恢复通过 | 新发布包含等价修复且最小化、恢复回归通过；版本补丁目录自动失效 |
| [Sonic 登录管理器](sonic-login-manager/) | 6.8.0.3／6.8.2 源码验收基线；包级目录不锁版本 | 应用/撤回检查及 musl/Clang 编译安装通过 | 头文件直接包含 POSIX 类型定义 |
| [ClamTk 翻译目录](clamtk-6.18/) | 6.18-r2 源码 | 独立应用/撤回、用户补丁重建和私有显示中文界面通过 | 程序显式绑定正确的 gettext 目录 |
| [KWayland 与 SonicDE ECM](kwayland-sonic-ecm/) | KWayland 6.7.6、SonicDE ECM 6.31.0 验收基线 | Manifest、补丁精确预检、CMake 配置及正常 Portage 沙箱安装通过 | 系统重新提供两个 Wayland 查找模块时自动跳过回退；上游接口修复并重建通过后删除 |
| [lowdown 配置宏](lowdown-3.1.1/) | 3.1.1 源码 | 上游修复回补；应用/撤回及全新根沙箱编译安装通过 | 目标版本包含上游 cc78c692 |
| [ipset 导出表](ipset-7.24/) | 7.24-r1 源码 | 本地补丁；全新根沙箱编译安装及帮助命令通过 | 上游导出表不再要求不存在的符号 |
| [nftables 头文件顺序](nftables-1.1.7/) | 1.1.7 源码，启用 xtables | 本地补丁；全新根沙箱编译安装通过 | 上游解决 libc/UAPI Ethernet 定义的包含顺序 |
| [Bun 私有 musl 运行库](bun-1.4.4/) | 1.4.4 amd64；Gentoo-Zh 固定基线 | 独立 stage3 正常沙箱安装及中文／Intl 通过，SONAME QA 无警告；主根集成与 CLI 也已通过 | 上游提供完整原生 musl 配方与运行库依赖 |
| [mold 的 musl 线程栈](mold-musl-stack/) | mold 2.42.1 配方验收基线，musl 条件分支 | 正常沙箱重建、8MiB 非可执行栈、同对象 curl ThinLTO 重链接及库初始化通过 | 上游提供等效栈保证，撤回后原重现与初始化通过 |
| [Neomacs musl 兼容](neomacs-aacf292/) | 上游 aacf292；Gentoo live 配方 | 编译兼容、栈段测量及配方修复；完整引导、安装、SQLite、GUI 和 Rime 输入通过 | 上游覆盖对应源码与安装修复后，重新验收 |
| [Dragonwell Standard 21 LTS](dragonwell-21.0.13/) | 21.0.13.0.13+9，amd64 musl；现有 Gentoo-Zh/Gentoo 仓库 | 原生安装及编译／中文检查通过；可选同版私有 glibc 构建也由该包管理，不注册第二个 VM，无原生 GCC/glibc | 上游提供等价 Standard musl 配方、Java 21 provider 与所需私有运行时后复验 |
| [Firefox ESR 153.7](firefox-153.7/) | Gentoo 固定基线，官方配方与语言包回补 | 精确应用／撤回与新版无 GCC 依赖预演通过；musl Rust 宿主脚本加载修复后正常沙箱安装及离线中文渲染通过 | 基线含对应安全版本且 Rust／LLVM helper 已统一后复验 |
| [FlClash 私有 glibc 前端](flclash-private-runtime/) | 0.9.3 验收基线，现有 Gentoo-Zh；FDO 26.08／Standard 21 | 正常沙箱安装、受保护 AOT/Core、私有 JNI／托盘、GUI 代理启停和 TUN TCP 隔离验证通过；真机授权及网络仍待 | 上游提供等价 musl 界面／配方及权限路线后复验 |
| [CUDA 数学调用、数据包与托管核心 SDK](cuda-13.4/) | CUDA 13.4 CRT 及已有 Gentoo-Zh 内两个版本固定配方 | 原生 PTX、托管 NVCC/CMake/CTest/GPU 数学通过；新内核已启动，完整数学库/PyTorch 未验收 | 官方支持本目标或已有等价包；按对应路线分别复验撤回 |
| [gcompat 加载器路径](gcompat-1.1.0/) | GURU gcompat 1.1.0 ebuild | 配方草案；对应手工路径已验证，完整 ebuild 未验收 | 配方提供正确的 amd64 加载器路径且完成安装验证 |

优先读取各组 README，再决定是否应用。后两组保留原有零上下文补丁内容，不自动
推广到其他版本。NVIDIA 私有加载器／核心库已按现有仓库补丁正常安装并通过普通用户 GPU 检查；完整显示会话仍待验收。

上游同步后先检查本地 `git diff`、目标配方及源码，再检查补丁是否已合入或失效。
不通过降低 patch 校验、强制覆盖或忽略失败维持旧补丁。修改仓库 ebuild 后，后续
`emerge --sync` 可能清除本地差异，需要重新检查；本目录不安装自动重放钩子。

这里保存可审核的基线补丁与应用条件，不保存实验根、私有配方快照或临时运行报告。
musl 已为默认 PC 方案；真实会话、硬件与业务操作的验收边界见 PC 根 README。

[NVIDIA 620.70.06 模块、GSP 与私有核心用户态](nvidia-620.70.06/)分别针对已有 Gentoo／Gentoo-Zh：
五模块公钥验签、四固件载荷校验、私有前缀 EGL/CUDA/NVML 及可选 DDX/GLX 正常安装通过；
无 GPU dummy 会话／加载通过，XLibre 自带 NVIDIA ABI 特例，完整显示与新内核启动仍待验收。

## 随上游升级维护

目录名、固定提交和精确安装命令记录已验收基线，不表示日常配置必须一直停在该版本。
普通关键词／许可／USE 尽量跟随包或 slot；真正只影响旧代码的例外采用受影响范围。
新发布归档仍需新的 Manifest 校验值，不能把固定 URL 改成未经校验的 latest。

在目标仓库或已解包源码目录内，可对每份补丁依次运行（默认只检查）：

```bash
python3 scripts/apply-patch-if-needed.py --root /path/to/source --patch /path/to/fix.patch
python3 scripts/apply-patch-if-needed.py --root /path/to/source --patch /path/to/fix.patch --apply
```

后续补丁会修改前一份涉及的文件时，用多个 `--patch` 按顺序检查完整组：

```bash
python3 scripts/apply-patch-if-needed.py --root /path/to/source \
    --patch /path/to/0001.patch --patch /path/to/0002.patch --apply
```

工具先在临时副本反向识别完整已应用状态，再预检需要的正向差异，最后一次性
应用最终差异。可补齐已应用的前缀；第二份不兼容时不会向真实目标写入第一份。
FlClash 两份补丁、Dragonwell 同仓库的 `0001`／`0003` 已通过完整、部分、
重复及不兼容状态验证；候选根原生 Python 也已验证完整组重复时跳过。
不同仓库的补丁必须分别执行；涉及重命名／符号链接的组停止并要求单独复核。

命令从实验目录执行。检查通过才应用；反向检查通过表示相同修改已经存在，自动跳过。
正反检查都不通过时返回 2、保持文件不变，要求复核上游，绝不强打或忽略失败。
上游采用了不同的等效实现时，需要按各组移除条件人工验证，不能仅凭补丁冲突宣称
已经修复。先前零上下文补丁须按原组说明复核，本工具不会放宽 git apply 校验。

这是升级前检查入口，不是已经接入所有 ebuild 的自动更新器；Portage 原有用户补丁
仍按部署目录匹配版本。同步仓库后逐组检查、部署需要的补丁，再预演和构建。
内核／模块／GSP 的配套版本、签名权限与 Dragonwell Standard 21 策略继续单独管理。


## 同步后恢复仓库配方

2026-11-19 真机复查发现，当前独立仓库已同步到新提交，本地配方补丁未恢复；
安装 VDB 仍在，不能据此认为更新与新机重装路径完整。历史构建提交和当前核验 HEAD
分别保存在 `portage/repository-baseline.tsv`，不回退整仓库或给软件增加永久版本锁。

从实验目录执行：

```sh
python3 scripts/restore-repository-patches.py
# 全部仓库预检通过、审核修改范围后，root/chroot 中显式写入：
python3 scripts/restore-repository-patches.py --apply
emerge --pretend --update --deep --newuse --autounmask=n @world
```

该入口在写入任何仓库前先检查全部有序补丁组；已包含则跳过，不兼容则停止。
它不同步仓库、安装包、启动服务或修改签名材料。新机 chroot 使用相同路径，也可通过
`--repos-root` 指定源码仓库根。Bun Manifest 仅去除已被上游删掉的旧版本上下文，
不改变归档哈希；Neomacs 上游已移除过时 DOCS 并改用新 crate 图标路径时，跳过历史
资源补丁0002，保留 SQLite 调整。其余源码补丁仍由 Portage 解包时校验，live 源码变化
可能使其失效，届时停止复核，不自动锁回旧提交。未验收的 GURU gcompat 配方草案
不在自动恢复范围内。
