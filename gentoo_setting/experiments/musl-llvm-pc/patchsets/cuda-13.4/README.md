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

当前没有经过验收的 CUDA musl ebuild，不能假定复制进 Portage 用户补丁目录即可
正确应用。升级 CUDA 时重新核对头文件和最小 kernel；官方入口变化或支持本目标后
重新评估是否移除，不将这份补丁自动套到其他主版本。
