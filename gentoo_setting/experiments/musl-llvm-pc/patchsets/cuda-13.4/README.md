# CUDA 13.4 宿主数学调用

`source/0001-musl-host-math.patch` 保留本轮原始补丁，针对解包 SDK 根目录中的
`include/crt/math_functions.hpp`，将八处 glibc 私有数学入口替换为 Clang builtin。
本轮原生 musl/Clang/libc++ 的最小 CUDA kernel 已在 RTX 4060 上通过。
这不代表完整 CUDA SDK、所有数学边界或 PyTorch 已验收。

这是零上下文补丁，只用于已核对版本与内容的本轮 CRT 头文件：

```bash
# sdk 指向解包后的测试 SDK 根；先检查，不在运行中的系统 SDK 上直接尝试
group=/root/dotfiles/gentoo_setting/experiments/musl-llvm-pc/patchsets/cuda-13.4
patch --dry-run --fuzz=0 -p1 -d "$sdk" < "$group/source/0001-musl-host-math.patch"
```

下述最小数据包已通过正常 Portage 安装与安装后 PTX 验收，不能假定复制进用户补丁目录即可
提供完整 CUDA SDK。升级 CUDA 时重新核对头文件和最小 kernel；官方入口变化或支持本目标后
重新评估是否移除，不将这份补丁自动套到其他主版本。

## Clang device-only 数据包

`repository/0001-clang-device-data.patch` 向已有 Gentoo-Zh 仓库新增版本固定的
`dev-util/cuda-clang-device-headers-13.4.1`，适用基线见
[`repository-baseline.tsv`](../../portage/repository-baseline.tsv)，不新建 overlay。
**状态：精确应用／撤回、配方语法、选择性解包和独立 PTX 编译通过；正常 Portage
预演、安装和安装后普通用户变量 sinf PTX 验证通过。**

包只安装 CCCL、CRT、cudart 的头文件、libdevice，以及 Clang 22 必须包含的三份
cuRAND 兼容头。五个 NVIDIA 官方归档共约 135MiB，按已有官方 redistrib SHA256
核对后生成 Manifest；不安装其中的 NVCC、ptxas、动态／静态 cudart 或 cuRAND
共享库。各组件许可证分别保留。数学补丁先验证固定 CRT 原头文件哈希再应用。

独立普通 UID 1000、只读 musl 根、隔离网络且无 GPU 的测试中，变量输入 `sinf` kernel
成功生成 sm_89 PTX，编译命令确实链接 libdevice，PTX 含范围规约和 FMA 多项式。
Clang 22 对 CUDA 13.4 新于其部分支持版本 12.9 的警告保留；小型编译不能代表
完整 CUDA 13.4 支持。初版缺 cuRAND 头的失败已保留，补齐三文件闭包后通过。

安装后可在普通用户临时目录复验：

```bash
clang++ -std=c++17 --cuda-path=/opt/cuda-clang-device-headers-13.4.1 \
  --cuda-gpu-arch=sm_89 --cuda-device-only -S math.cu -o math.ptx
```

`math.cu` 应包含实际数学操作，不能仅用空 kernel 验收。新机应用补丁前先核对
Gentoo-Zh 基线和已有同名包；只为精确版本配置 `~amd64`、接受适用 NVIDIA-CUDA
许可，再检查合并计划没有 GCC／glibc。该包不能满足宿主链接、cubin 或 GPU 运行需求。

## Portage 管理的 Flatpak 核心 SDK

`repository/0002-flatpak-sdk-core-launcher.patch` 向同一 Gentoo-Zh 基线新增
`dev-util/cuda-sdk-flatpak-13.4.1`，与前述 device-only 数据包独立；两份仓库补丁按编号应用，先 `git apply --check`，已存在同名包则停下复核。
它由正常 Portage 沙箱安装六份 NVIDIA 官方、经 SHA256／Manifest 校验的压缩归档和
`cuda-sdk` 启动器，不把 glibc ELF 登记为原生 musl 共享库，也不运行 NVIDIA 安装器。
NVCC／核心 cudart 使用原厂文件，无需前述 musl 数学补丁；原生 device-only 路线仍保留该补丁。

新机准备好 chroot 的挂载、网络、Flatpak 及仓库补丁后，在目标根内执行：

```bash
# 在本实验目录中；主应用清单仍为原有五项
bash scripts/install-flatpak-apps.sh --system --cuda-sdk
emerge --ask =dev-util/cuda-sdk-flatpak-13.4.1::gentoo-zh
```

脚本可在无桌面 D-Bus 的 root chroot 中重复执行，本轮复用已校验缓存的实测通过，
不代表空缓存下载全流程已验证。默认使用国内 Flatpak 缓存并保留签名验证；
`--cuda-sdk` 精确部署 SDK 26.08 和与本候选目标匹配的 NVIDIA 620-70-06 扩展，
不按安装介质当前驱动猜测。其他机器或更新驱动时必须同步调整扩展版本。
启动器要求系统级 SDK，因此此选项不支持 `--user`。

首次正常用户运行时，启动器在 `$XDG_CACHE_HOME/cuda-sdk-flatpak/13.4.1`
（默认 `~/.cache` 下）校验并选择性解包，至少预留 1GiB；更新／卸载 Portage 包
不会自动删除用户缓存。无需另建 glibc chroot，也不向 musl 主系统安装 GCC。
复用现有 Freedesktop SDK 内的 GCC 16.2，因此 CUDA 的宿主编译阶段并非全 LLVM。

```bash
# 登录后，以普通用户在项目目录执行；math.cu 是自己的测试源文件
cuda-sdk nvcc --version
cuda-sdk nvcc -std=c++17 -arch=sm_89 --cudart=shared math.cu -o math
cuda-sdk ./math
# CMake 项目的配置、构建、测试也全部使用 cuda-sdk cmake / cuda-sdk ctest
```

产物是 glibc ELF，编译／链接／运行都在同一 SDK 内进行；不要混入原生 musl C++
目标文件。启动器只开放当前项目和工具缓存，默认无网络，需要时对单次调用设置
`CUDA_SDK_NETWORK=1`。保留 LANG、LC_ALL 及分类 locale／时区；已实测
zh_CN.UTF-8、人民币格式化和中文。首次使用不会替用户登录、导入项目或设置 IDE。

**实测：已安装入口在普通 UID 1000 下用 NVCC 13.4 编译、CMake 构建和 CTest
通过，RTX 4060 上 32 个 sinf 结果回读的最大绝对误差为 3.73e-8 以内。**
GPU 使用当前宿主已加载的 620.70.06 模块；新 musl 内核尚未启动，不能据此验收
新模块加载、显示或功耗。移除未登记的临时工具副本后，托管 CMake／GPU 测试仍通过。

升级时先核对六份归档、许可证、布局、SDK 编译器支持范围和驱动版本，再重新运行
普通用户编译及 GPU 回读；上游已有等价包时先卸载本精确包，再撤回此新增配方补丁。
用户缓存确认不用后另行清理，不手删 Portage 已登记文件。

## 完整工具链仍待完成的部分

旧成功程序虽使用 musl ELF、Clang 和 libc++，仍结合静态 cudart 与 gcompat 调用
NVIDIA 用户态驱动，并非完全不需要兼容层。官方 ptxas、fatbinary、nvlink、NVCC
是 glibc ELF；动态 cudart 还依赖 glibc 版 C++ 运行库，不能直接作为原生 musl 库安装。
新内核的模块与 GSP 已单独打包验签，但原生 NVIDIA 用户态仍须打包验收。
上述托管入口只解决核心 NVCC／cudart；RDC、cuBLAS／cuDNN、PyTorch、数学边界
与真实生产负载不在本轮验收范围。

升级时重新核对组件版本、布局、许可证、头文件哈希及 Clang 强制头依赖；上游提供
等价支持后复验并移除补丁。已安装时先由 Portage 卸载精确数据包，再撤回仓库补丁，
不手工删除已登记文件，不清理原系统 CUDA。
