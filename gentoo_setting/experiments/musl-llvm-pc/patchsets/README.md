# 迁移补丁组索引

每个目录对应一个软件或明确版本。`repository/` 修改仓库里的 ebuild 元数据；
`source/` 修改解包后的上游源码。Portage 用户补丁不能补上缺失的 `DEPEND`，
因此这两层分开保存，不再维护一份完整本地 overlay/ebuild 副本。

| 补丁组 | 适用范围 | 当前状态 | 移除条件 |
| --- | --- | --- | --- |
| [Sonic 图像编辑](sonic-quick-image-editor/) | 0.7.0.1；SonicDE overlay `a5e6600f3dbd67b02ca61a095e036c8a908fe0cc` | 全新 musl 根使用配方补丁和用户源码补丁编译安装通过 | 配方声明 Highway，源码改用可用的 CMake 包 |
| [Sonic 登录管理器](sonic-login-manager/) | 6.8.0.3 源码 | 应用/撤回检查及 musl/Clang 编译安装通过 | 头文件直接包含 POSIX 类型定义 |
| [ClamTk 翻译目录](clamtk-6.18/) | 6.18-r2 源码 | 独立应用/撤回、用户补丁重建和私有显示中文界面通过 | 程序显式绑定正确的 gettext 目录 |
| [lowdown 配置宏](lowdown-3.1.1/) | 3.1.1 源码 | 上游修复回补；应用/撤回及全新根沙箱编译安装通过 | 目标版本包含上游 cc78c692 |
| [ipset 导出表](ipset-7.24/) | 7.24-r1 源码 | 本地补丁；全新根沙箱编译安装及帮助命令通过 | 上游导出表不再要求不存在的符号 |
| [nftables 头文件顺序](nftables-1.1.7/) | 1.1.7 源码，启用 xtables | 本地补丁；全新根沙箱编译安装通过 | 上游解决 libc/UAPI Ethernet 定义的包含顺序 |
| [Bun 私有 musl 运行库](bun-1.4.4/) | 1.4.4 amd64；Gentoo-Zh 固定基线 | 独立 stage3 正常沙箱安装及中文／Intl 通过，SONAME QA 无警告；主根集成与 CLI 也已通过 | 上游提供完整原生 musl 配方与运行库依赖 |
| [Neomacs musl 兼容](neomacs-aacf292/) | 上游 aacf292；Gentoo live 配方 | 编译兼容、栈段测量及配方修复；完整引导、安装、SQLite、GUI 和 Rime 输入通过 | 上游覆盖对应源码与安装修复后，重新验收 |
| [Dragonwell Standard 21 LTS](dragonwell-21.0.13/) | 21.0.13.0.13+9，amd64 musl；现有 Gentoo-Zh/Gentoo 仓库 | 正常沙箱安装、eselect、Java 编译及中文／字体／证书检查通过；无 GCC/glibc | 上游提供等价 Standard musl 配方与 Java 21 provider 后复验 |
| [Firefox ESR 153.7](firefox-153.7/) | Gentoo 固定基线，官方配方与语言包回补 | 精确应用／撤回与新版无 GCC 依赖预演通过；musl Rust 宿主脚本加载修复后正常沙箱安装及离线中文渲染通过 | 基线含对应安全版本且 Rust／LLVM helper 已统一后复验 |
| [CUDA 数学调用与最小数据包](cuda-13.4/) | CUDA 13.4 CRT 及已有 Gentoo-Zh 内版本固定数据配方 | 旧最小 kernel 依赖静态 cudart／gcompat；数据包正常 Portage 安装及安装后 PTX 通过，完整 SDK 未验收 | 头文件不再依赖这些 glibc 私有数学入口，或官方支持本目标 |
| [gcompat 加载器路径](gcompat-1.1.0/) | GURU gcompat 1.1.0 ebuild | 配方草案；对应手工路径已验证，完整 ebuild 未验收 | 配方提供正确的 amd64 加载器路径且完成安装验证 |

优先读取各组 README，再决定是否应用。后两组保留原有零上下文补丁内容，不自动
推广到其他版本。NVIDIA 私有 musl/兼容 shim 仍在本地实验区研究，尚未列为可安装
补丁组；不会把未验收的配方顺便注册到目标系统。

上游同步后先检查本地 `git diff`、目标配方及源码，再检查补丁是否已合入或失效。
不通过降低 patch 校验、强制覆盖或忽略失败维持旧补丁。修改仓库 ebuild 后，后续
`emerge --sync` 可能清除本地差异，需要重新检查；本目录不安装自动重放钩子。

原实验根保留已验证的私有配方快照作对照，不是本仓库的交付形式；全新根已通过
图像编辑组件的补丁组安装路径。完整桌面、登录和硬件启动仍按迁移验收项继续验证。

[NVIDIA 620.70.06 模块与 GSP](nvidia-620.70.06/)分别针对已有 Gentoo／Gentoo-Zh：
五模块正常编译安装与公钥验签、四固件载荷校验通过；用户态及硬件启动仍待验收。
