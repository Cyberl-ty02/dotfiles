# Gentoo PC Clang/LLVM 配置

目标：amd64、OpenRC、Clang/LLVM 主工具链、SonicDE/XLibre、NVIDIA 与 Secure Boot。
少数无法可靠使用 Clang/libc++ 构建的软件通过 `portage/env/gcc_generic` 回退到 GCC。

## 应用

```bash
doas cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
doas rsync -a --delete --exclude=make.profile portage/ /etc/portage/
doas emerge --sync
doas emerge -pvuDN @world
doas emerge -avuDN @world
```

建议使用稳定的 `default/linux/amd64/23.0/desktop/plasma` OpenRC profile；
`make.conf` 按 Gentoo 官方方式将 `CC/CXX` 等变量切换到 Clang/LLVM。
不要把现有 glibc 系统直接切换到 ABI 不同的纯 LLVM profile。

应用前请阅读 `kernel/secureboot/README.md`。私钥不会保存在本仓库中。
