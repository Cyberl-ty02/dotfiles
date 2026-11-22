# rEFInd 外部介质图标

Gentoo 手动菜单由 `../../scripts/configure-refind-dual-root.py` 显式引用 rEFInd
自带的 `EFI/refind/icons/os_gentoo.png`，不依赖内核文件名猜测发行版。

`ventoy.png` 原样来自 [Ventoy 官方 logo_128.png](https://github.com/ventoy/Ventoy/blob/master/ICON/logo_128.png)，
Git blob 为 `a13884a46f46860dd2591f92adc4b18333cddb85`，GPLv3 许可见 `COPYING`。
这些是图标来源证据，不限制 Ventoy 软件升级，也没有改动 USB 分区或载荷。

在已安装 rEFInd 的目标根／chroot 中，以本目录为工作目录：

```sh
install -m0644 ventoy.png /boot/EFI/refind/icons/os_ventoy.png
install -m0644 ventoy.png /boot/EFI/refind/icons/os_vtoyefi.png
install -m0644 COPYING /boot/EFI/refind/icons/COPYING.ventoy
```

rEFInd 自带的扫描与卷标匹配会为 Ventoy／VTOYEFI 使用对应图标；其他发行版使用
已有图标。启动菜单出现后才插入介质，可按 Esc 重新扫描。任意未知卷标、固件
自带启动项不保证能识别品牌；不通过改名载荷或改分区标签强行匹配。
图标文件校验和规则检查不代替下次真实开机的显示验收。
