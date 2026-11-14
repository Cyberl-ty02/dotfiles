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

## 完整工具链仍待完成的部分

旧成功程序虽使用 musl ELF、Clang 和 libc++，仍结合静态 cudart 与 gcompat 调用
NVIDIA 用户态驱动，并非完全不需要兼容层。官方 ptxas、fatbinary、nvlink、NVCC
是 glibc ELF；动态 cudart 还依赖 glibc 版 C++ 运行库，不能直接作为原生 musl 库安装。
候选根的兼容工具、静态运行库、用户态驱动及匹配新内核的模块仍须分别打包验收。
NVCC、RDC、cuBLAS／cuDNN、PyTorch、数学边界与真实生产负载不在数据包验收范围。

升级时重新核对组件版本、布局、许可证、头文件哈希及 Clang 强制头依赖；上游提供
等价支持后复验并移除补丁。已安装时先由 Portage 卸载精确数据包，再撤回仓库补丁，
不手工删除已登记文件，不清理原系统 CUDA。
