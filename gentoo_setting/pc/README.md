# Gentoo PC Clang/LLVM 配置

目标：amd64、OpenRC、Clang/LLVM 主工具链、SonicDE/XLibre、NVIDIA 与 Secure Boot。
少数无法可靠使用 Clang/libc++ 构建的软件通过 `portage/env/gcc_generic` 回退到 GCC。

## 应用

```bash
doas cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
doas rsync -a --delete --exclude=make.profile portage/ /etc/portage/
doas emerge --sync
doas xargs emerge -av --noreplace < world_packages.txt
doas emerge -pvuDN @world
doas emerge -avuDN @world
```

本配置以 `stage3-amd64-llvm-openrc` 及其
`default/linux/amd64/23.0/llvm` profile 为基础；Clang、LLVM binutils、
libc++、compiler-rt、llvm-libunwind 和 lld 均沿用 profile 默认值，
`make.conf` 不再重复声明工具链变量。GCC 仅供已记录的包级回退使用。
基础优化、Clang ThinLTO 与 Fortran LTO 分别由 `COMMON_FLAGS`、
`CLANG_LTO_FLAGS` 和 `FORTRAN_LTO_FLAGS` 控制；兼容环境显式使用
`-fno-lto`，无需重写其他语言或工具链设置。

应用前请阅读 `kernel/secureboot/README.md`。私钥不会保存在本仓库中。
