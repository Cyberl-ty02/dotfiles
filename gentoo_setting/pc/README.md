# Gentoo PC：musl／LLVM／OpenRC

这是本仓库默认 PC 配置，已从官方 musl LLVM stage3 安装并真机启动。
“默认”指本仓库的维护选择，不代表 Gentoo 的实验 profile 已转为官方稳定。
WSL 保持独立配置；旧 glibc PC 配置不再并行维护，可从 Git 历史或本地标签
`archive/glibc-pc-before-musl-promotion` 找回。

完整安装、兼容运行库、迁移经过与排错放在博客正文：
[Gentoo musl／LLVM PC 迁移](https://kagaranakaki.top/posts/gentoo-musl-llvm-pc-migration/)。
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
- `package.*` 按包原子升序，忽略前导版本运算符；同一选择器与注释保持顺序。
  make.conf 保持依赖分组与国内镜像优先顺序，不按字母全局重排。
- 规则优先按包／slot／受影响版本范围；补丁严格预检，已有相同上游修复时跳过，
  不兼容时停止。同步后先运行补丁恢复脚本预检，不新增另一套 overlay。

## 当前验收边界

普通软件更新及保留库重建已通过，SonicDE 6.8.2／Qt 6.11.3 已真机启动。
字体、Neomacs、Codex／VSCodium、独立 root Zsh 与 VSCodium 原生 Zsh 入口已验证。
CUDA/NVML、NVCC/CMake/CTest 和 GPU 数学回读通过，设备权限保持 root:video 0660。
VSCodium 启动器同时为 Chromium 和 Node 扩展转发调用 shell 的 HTTP(S) 代理，
按进程启用 `NODE_USE_ENV_PROXY`，不硬编码代理或关闭证书验证。已有编辑器实例
不会因再次运行 codium 而继承新环境；需要完整退出所有窗口后从启用代理的 shell
重新启动。Actions 提交不存在与本机 API 连接超时应分开诊断，不能为消除误报改用浮动 tag。
新系统 PostgreSQL 18.6 的只读元数据核验仅见默认三个数据库，postgres 库用户关系、
自定义函数与大对象计数为零；不能据此代替其他数据库逐库审计或原库恢复验收。

真实课程项目、音视频／会议、休眠唤醒、PR 扩展的额外 OAuth 权限、TUN、完整
CUDA 数学库及旧 Doom 插件仍按需要单独验收。不会自动登录账号、发消息或授予权限。
当前根／HOME 已为 `@`／`@home`；旧根及旧 HOME 已加密归档退役，旧 Linux 启动入口
已移除。恢复需要加密归档与私有凭据，尚未完成实际归档恢复和回退启动验收。

本机接续先核对私有检查点指定的活进程、启动 ID、任务状态和日志；不从 README
推断仍有授权或构建。保持单个 Portage 写入者和至少20GiB根分区余量，不自动关机。
验收后按用户授权整理到 main；保留远端已有正文及 Windows 配置。博客部署单独决定。
