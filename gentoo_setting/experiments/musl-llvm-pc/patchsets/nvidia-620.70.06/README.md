# NVIDIA 620.70.06：开源模块与 GSP 数据包

**状态：正常 Portage 沙箱编译安装、五个模块的密码学验签及四个 GSP 固件哈希
检查通过；尚未加载新模块、切换启动或完成 NVIDIA 用户态集成。** 不新增 overlay。

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

这只完成模块和匹配 GSP 的包管理。完整 NVIDIA 用户态、CUDA 宿主运行链、PRIME、
显示输出、休眠和真实负载仍未验收。现有 linux-firmware 20261019 不含 620 GSP；
本包也不能代替 Wi-Fi、蓝牙、集显等其他设备固件。布局确定后仍须重建并检查目标
initramfs，再进行真实启动与回退验证。

## 升级与撤回

升级时先比较上游是否已有 modules-only 或等价拆分，以及固件的官方来源、布局、
许可与哈希；重新验证目标内核接口和签名。上游提供等价实现后移除本地分支，不将
此固定补丁静默套到新版本。卸载由 Portage 管理并保留旧系统回退；不能手删已登记
模块或固件，也不能把仍在使用的模块包切回完整 glibc 驱动而跳过依赖复核。
