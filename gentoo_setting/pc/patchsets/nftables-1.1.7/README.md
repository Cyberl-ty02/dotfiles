# nftables 1.1.7

Gentoo `net-firewall/nftables-1.1.7` 启用 `xtables` 后，`src/xt.c` 先经 Linux
UAPI 引入 `ethhdr`，随后经 `xtables.h` 引入 musl 的同名定义，导致编译失败。
本地补丁让 libc 的 Ethernet 头文件先被包含，保持 xtables 功能；不修改系统头文件
或全局设置 UAPI 宏。

按版本安装为：

```text
/etc/portage/patches/net-firewall/nftables-1.1.7/0001-libc-ethernet-header-first.patch
```

已通过独立源码应用检查、全新 musl 根正常 Portage 沙箱编译安装，日志确认补丁
实际应用。尚未用新根操作真实防火墙规则。上游或发行版修复包含顺序后，核对版本并
移除此补丁；本地修复尚未提交上游。
