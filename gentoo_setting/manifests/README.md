# Gentoo role manifests

这些文件是从 PC/WSL world 中提取的可选角色，不是自动安装脚本，也不是
某台机器 world 的副本。一个新系统通常先选择 `core.txt`，然后按用途叠加：

- `development.txt`：通用开发工具链。
- `desktop.txt`：SonicDE、输入法、Flatpak 与桌面基础。
- `nvidia.txt`：NVIDIA/CUDA 用户空间与驱动。
- `pc-host.txt`：当前实体机的内核和 UEFI/rEFInd 引导。
- `wsl.txt`：WSL 的 LLVM 工具链。
- `optional.txt`：个人应用，重建时逐项选择。

先预览单个角色：

```sh
xargs emerge --pretend --verbose --noreplace < gentoo_setting/manifests/core.txt
```

不要一次盲目安装全部清单。Portage 的 USE、关键字、mask 和仓库选择仍分别
由 `pc/portage/` 或 `wsl/portage/` 决定。
