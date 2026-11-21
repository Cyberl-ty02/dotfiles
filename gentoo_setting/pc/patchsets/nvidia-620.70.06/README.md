# NVIDIA 620.70.06：开源模块与 GSP 数据包

**状态：正常 Portage 沙箱编译安装、五个模块的密码学验签及四个 GSP 固件哈希
检查通过；现已在新 musl 内核加载并通过原生 CUDA/NVML 与托管 SDK GPU 运算。
完整显示／PRIME／功耗及下一次启动权限策略仍待验收。** 不新增 overlay。

## 两个目标仓库

| 顺序 | 补丁 | 目标与固定基线 |
| --- | --- | --- |
| 1 | `repository/0001-modules-only.patch` | Gentoo `3d5af35677728d11439cacc1ca2165f39b1eaa3d` |
| 2 | `repository/0002-gsp-data.patch` | Gentoo-Zh `73b502777b071c0cb934f4ad0053eec6c54a2139` |

第一份只给既有 `nvidia-drivers-620.70.06` 增加版本限定的 `modules-only` 分支。
620 已默认使用开源模块，没有可另选的 `kernel-open` 开关。原模式的依赖和行为
保留；仅模块模式跳过用户态组件、GCC/glibc/Python 依赖和硬件探测，沿用
`linux-mod-r1` 的编译、安装、签名及目标 depmod，不加载当前系统模块。

新内核安装后，必须先检查 `/lib/modules/7.2.14-musl-x64v3/build` 的真实构建树、
生成头文件、Module.symvers、native helper 和 kernel.release。已有 Gentoo-Zh
`virtual/linux-sources-3-r13` 支持 XanMod，直接复用；不需要额外 provider 补丁，
也不使用 `--nodeps` 或再拉一套 gentoo-sources。

第二份在已有 Gentoo-Zh 新增 `sys-firmware/nvidia-gsp-firmware-620.70.06`。
它复用 Gentoo 官方固定 Manifest 中约 549.8MB 的 NVIDIA `.run` 归档，由成熟
`unpacker` eclass 提取载荷，**不执行 nvidia-installer**；只登记版本目录下的
`gsp_ga10x.bin`、`ucodes_ga10x.bin`、`gsp_tu10x.bin`、`ucodes_tu10x.bin`。
归档由 Portage 校验 BLAKE2B/SHA512，四份安装载荷另验固定 SHA256，保留 NVIDIA-2025
许可，不把它们当作普通主机 ELF 剥离。新机器可从同一厂商来源重建，不依赖旧根固件。

## 配置与新机安装顺序

先完成带正确 build tree 的 XanMod 内核；分别核对两仓库基线、补丁 dry-run、
应用结果，再预演下列精确包。关键字、unmask、USE 和 env 的参考值已合并到
[`portage`](../../portage/)；它们不是整目录覆盖安装器。

```bash
emerge --pretend --verbose --autounmask=n \
  =x11-drivers/nvidia-drivers-620.70.06::gentoo \
  =sys-firmware/nvidia-gsp-firmware-620.70.06::gentoo-zh
```

模块只使用 `modules-only modules modules-sign`，关闭 X、tools、32 位 ABI、
persistenced、powerd、static-libs、wayland 和 dist-kernel。专用 env 明确目标
`KERNEL_DIR` 和签名路径；编译仍是普通 Portage UID 250，仅安装签名阶段读取 root
私有签名材料，不沿用内核的 root 编译例外。公开配置不含密钥；新机器须使用自己
生成并登记的签名材料，保证内核内置信任与模块证书匹配。

## 实际验收与限制

正常预演只引入 pahole、既有 sources virtual 和五模块包，没有 GCC/glibc；新内核
版本为 `7.2.14-musl-x64v3`。五个驱动所属 `video/` 模块的 vermagic 匹配，PKCS#7
签名使用预期公开证书逐一由 OpenSSL CMS 验证。实验根 kmod 未启用可选 OpenSSL
解析，可能不显示 signer 名称；不能把显示字段当作密码学验签的替代。

四个固件正常安装并逐一核对载荷哈希，完整 world 预演无待合并项。没有复制旧的
未签名模块，没有调用 modprobe/insmod，也没有触碰真实 EFI 或原系统模块。

这只完成模块和匹配 GSP 的包管理。核心用户态随后已按下述私有前缀路线安装验收；完整显示集成、PRIME、
显示输出、休眠和真实负载仍未验收。现有 linux-firmware 20261019 不含 620 GSP；
本包也不能代替 Wi-Fi、蓝牙、集显等其他设备固件。布局确定后仍须重建并检查目标
initramfs，再进行真实启动与回退验证。

## 升级与撤回

升级时先比较上游是否已有 modules-only 或等价拆分，以及固件的官方来源、布局、
许可与哈希；重新验证目标内核接口和签名。上游提供等价实现后移除本地分支，不将
此固定补丁静默套到新版本。卸载由 Portage 管理并保留旧系统回退；不能手删已登记
模块或固件，也不能把仍在使用的模块包切回完整 glibc 驱动而跳过依赖复核。


## 私有 musl 加载器和核心用户态

`repository/0003-private-musl-compat.patch` 与 `0004-private-userspace.patch`
分别向同一 Gentoo-Zh 基线新增 `sys-libs/nvidia-musl-compat-1.2.6_p20261115` 和
`x11-drivers/nvidia-userspace-musl-620.70.06`。按编号应用、先检查已有同名包；
不新建 overlay。两包和所需 libucontext 已以正常 Portage 沙箱安装，未关闭 userpriv。

加载器采用 [Chimera 草案 PR 6531](https://github.com/chimera-linux/cports/pull/6531)
的 IFUNC／TLS 补丁与 libnvcompat。此前验证提交为
`c26532983c3b811c2d6b310058761bba39491bbe`；本轮复核当前草案
`7b121686e15cc1d06ee1ee16968665004519d8a4`，使用的两份补丁、C 文件和符号映射
逐字相同。上游仍是草案，不能当作其已支持完整 Gentoo 桌面的承诺。musl 和
Adélie gcompat 固定源码归档已重新下载并核对 SHA256，Manifest 固定 BLAKE2B／SHA512；
NVIDIA 使用前述同一经 Gentoo Manifest 核对的官方归档。保留各源码及 Chimera 许可证说明。

安装路径只有 `/usr/libexec/nvidia-musl` 和专用 `nvidia-musl-run` 入口。
其中包含私有加载器、gcompat／nvcompat、核心 EGL／GLES／GLX／CUDA／NVML 库，
驱动载荷约 293MiB。原始 musl 的文件仍匹配 Portage 登记哈希；不替换默认 libc、
解释器或系统符号链接，也不全局注册 EGL／Vulkan、启动服务或加载模块。

在目标 root chroot 中准备好仓库补丁及本实验的关键词、许可后安装：

```bash
emerge --ask =sys-libs/nvidia-musl-compat-1.2.6_p20261115::gentoo-zh \
  =x11-drivers/nvidia-userspace-musl-620.70.06::gentoo-zh
```

真实运行须有匹配的 620.70.06 内核模块和 GPU 权限；普通用户、候选根中可用：

```bash
nvidia-musl-run /usr/bin/python3.14 -c 'import ctypes; print(ctypes.CDLL("libcuda.so.1").cuInit(0))'
```

这里只接受一个 x86-64 动态 musl ELF。启动器通过显式加载器参数设置私有库与预加载，
清除外部 LD_PRELOAD／LD_LIBRARY_PATH，仅为该程序选择 NVIDIA EGL 和 PRIME 环境。
glibc ELF 请走 `cuda-sdk`；脚本、会话和子进程不会自动转换解释器，尚未验收，不能
据此修改 Sonic 登录器、XLibre 默认启动方式或现有服务。原核心包未包含 XLibre 的 nvidia_drv；补丁 0006 现提供可选私有模块。
服务与睡眠脚本、Vulkan 或完整视频／数学库仍不在包中。

**安装后实测：**普通 UID 1000、只读候选根、独立 HOME、无网络、签名密钥隐藏的测试中，
默认加载器对照报重定位 37，私有加载器加载通过；EGL 1.5／OpenGL 4.6 创建上下文、
离屏清屏和像素回读通过；CUDA 64 字节显存填充／回读以及 NVML 驱动版本查询通过。
使用的是重启后当前宿主的 620.70.06 模块，新 musl 内核仍未启动。原生 XLibre 显示、
PRIME 实际呈现、外接屏、休眠恢复、桌面合成及完整应用负载继续单独验收。

升级时核对私有 musl 与头文件 ABI、TLS／IFUNC 补丁、gcompat、符号映射、驱动／GSP／
模块版本，重新运行普通用户正负对照和 GPU 测试。上游成熟后再决定是否替换；
撤回时先由 Portage 卸载私有用户态，再卸载兼容包，然后撤回相应新增配方补丁。
模块／GSP 包与原系统独立保留，不用手工删除登记文件或切换默认 libc。

## 全局 ThinLTO 下的启动代码例外

`repository/0005-compat-startup-lto.patch` 在同一 Gentoo-Zh 基线按 0001—0004
对应目标仓库应用后，修改 0003 新增的兼容包；不改动已经发布的前四份补丁。
它增加源码补丁 `092-startup-no-lto.patch`，在已有 `NOSSP_OBJS` 分类的编译规则
末尾追加 `-fno-lto`，使早期启动、重定位和 TLS 等初始化代码保持独立编译。
其余 libc 与兼容 shim 仍使用全局 ThinLTO，不关闭普通软件的 LTO 或沙箱。

原因是 Clang LTO 可能移除由汇编引用的 `__dls2`，首轮实际构建已复现未定义符号。
修复参考 [musl 邮件讨论](https://www.openwall.com/lists/musl/2025/05/12/4) 中对早期
启动代码的分析，复用原有对象分类；这是本地适配，不宣称已被上游合并。

仓库补丁及源码补丁的应用／撤回检查通过；正常 Portage 沙箱重建安装通过，日志确认
两份加载器对象禁用 LTO、1,343 份普通 musl 对象保留 ThinLTO。安装后普通 UID 1000、
只读根和独立配置的 stock 负对照、私有加载、EGL 像素回读、CUDA 显存往返及 NVML
查询均通过，系统原始 musl 仍匹配 Portage 哈希。这不增加完整 XLibre／新内核启动
验收范围。

后续上游提供等效启动保护时，可先撤回 0005，再用相同正常构建及正负对照回归验证；
通过后删除此补丁，保留 0003／0004 的私有前缀边界及配套版本核验。

## 可选私有 XLibre 模块与入口

按前序补丁应用 `repository/0006-private-xlibre-modules.patch`，为同一包增加
`xlibre` USE、私有 `nvidia_drv.so`／`libglxserver_nvidia.so` 及 `nvidia-musl-xorg`
入口，不增加 overlay。普通软件版本不受额外上限限制；兼容层按 ABI slot 依赖，
内核驱动继续与用户态 `${PV}` 配套。默认关闭此可选 USE，实验配置按包显式启用。

模块来自前述经 Manifest 核验的官方 `.run`，通过原有 unpacker 解包而不执行
nvidia-installer，再按核心库相同方式修改实验私有 ELF。模块只安装到
`/usr/libexec/nvidia-musl/xorg`，不覆盖系统模块、GLX 链接或登录器配置。入口调用
Xorg 查询当前默认模块目录（输出在 stderr），再由私有加载器启动 Xorg；不固定
XLibre 主版本路径。旧包的本地二进制回退保留。

在目标 chroot 中合并 USE、按补丁索引逐份检查后，可安装并先只查询路径：

```bash
emerge --ask x11-drivers/nvidia-userspace-musl
nvidia-musl-xorg -showDefaultModulePath
```

正常 Portage 安装及入口查询通过。普通 UID 1000、只读候选根、无网络、无 GPU／DRM／
真实 VT 的 dummy XLibre 会话中，已安装入口能启动并通过 xdpyinfo，NVIDIA DDX 加载
通过；另用测试专属 GLX 别名加载已安装 GLX 模块通过。该别名仅存在于测试目录，
没有安装全局 `libglx.so`。重新安装后的核心 EGL／CUDA／NVML 正负回归也通过。

**验收限制：**测试没有设置 IgnoreABI，但 XLibre 自身日志明确显示针对 NVIDIA
隐式忽略 ABI 差异。因此这是上游现有兼容路径下的模块加载和 dummy 会话证明，
不是严格 ABI、NVIDIA 硬件屏幕、PRIME／混合 GLX、休眠或完整 Sonic 登录验收。
真实登录器尚未切换，后续需独立的实机显示与回退步骤。

未来上游提供同等私有运行路径或完成原生支持后，先通过同样正负对照及真实显示
验收，再移除 0006；只停用该 USE 不会更改默认系统 Xorg 入口。


## 真机设备节点准备

2026-11-19 真机已识别 RTX4060、加载620.70.06和匹配 GSP，但缺少 `/dev/nvidia*`。
modules-only 路线没有安装常规驱动包附带的 helper，因而“模块在”还不代表 CUDA 可用。
`repository/0007-native-device-helper.patch` 向已有 Gentoo-Zh 增加独立的小型
`x11-misc/nvidia-modprobe`，不用新 overlay 或完整驱动安装器。源码来自 NVIDIA 官方
42009字节归档，复用 Gentoo 官方 Manifest 的 BLAKE2B/SHA512；UVM 权限修复也沿用
Gentoo。与同维护版本的 modules-only 驱动关联，版本协调门槛保持。

独立 helper 以原生 musl/Clang/mold/ThinLTO 编译，正常 Portage 沙箱安装、OpenRC
节点准备及打包QA通过。真实新内核的原生私有CUDA/NVML均识别一块GPU；托管
NVCC/CMake/CTest通过，32项sinf回读最大绝对误差5.96e-8。包使用 Gentoo
的 root:video 4710 策略；OpenRC一次性准备控制、GPU、modeset与UVM节点，权限0660。
它不启动常驻GPU守护进程，不在 stop 时卸载可能正在使用的模块，不修改 EFI 或密钥。

新机 chroot 中应用仓库补丁、登记关键词后，可预演并安装
`x11-misc/nvidia-modprobe::gentoo-zh`；`rc-update add nvidia-device-files boot`
仅登记启动服务，不在安装介质上启动目标驱动。进入真实系统后再执行
`rc-service nvidia-device-files start` 和普通用户 CUDA 测试。


运行后复查发现，当前驱动仍采用旧 initramfs 的 `DeviceFileGID=0`／`DeviceFileMode=438`
默认值，并会在GPU调用后重设节点。新安装的 `/etc/modprobe.d/nvidia-device-files.conf`
已经正确写入 video GID 与十进制432（0660），但这些已加载模块参数只读，不能靠一次
chmod 宣称持久修复。同内核 musl initramfs 已重建、解包核验并发布到原路径，
早期模块配置已包含；五个模块、四份 GSP 固件及 Intel 微码与验收基线一致。原镜像
已私有备份，kernel、菜单及旧根保持；下一次手动启动后再核验 GPU 调用前后权限是否稳定。
新机chroot须先安装helper，再生成最终initramfs；不在安装介质上加载目标驱动。

首次服务参数与组查询问题、手册压缩／预剥离QA均已按日志修正。构建使用与Gentoo
官方驱动相同的空值 `DO_STRIP=`／`MANPAGE_GZIP=`，把剥离和压缩交给Portage。
UVM修复保留全部原语义，以严格非空上下文验证，未降低fuzz或忽略QA。
