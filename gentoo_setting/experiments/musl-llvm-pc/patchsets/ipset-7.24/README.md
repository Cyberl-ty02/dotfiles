# ipset 7.24

适用于 Gentoo `net-firewall/ipset-7.24-r1`。LLVM LLD 拒绝导出表中没有定义的
符号；该版导出表包含已不存在的函数、静态函数，以及只在 debug 构建中出现的函数。

本地源码补丁移除五项没有可导出定义的名字，将可选的 `ipset_debug_msg` 改为匹配模式，
保留 debug 构建的导出能力。不全局添加 `--undefined-version`，不修改防火墙规则。
该补丁尚未提交上游。

安装到以下路径后重建该包：

```text
/etc/portage/patches/net-firewall/ipset-7.24-r1/0001-prune-unavailable-version-exports.patch
```

独立源码的应用与撤回检查、全新实验根正常 Portage 沙箱编译安装和帮助命令通过。
未在新内核中操作实际 ipset 集合，debug 构建也未单独验证。
上游修复导出表后，核对目标版本及导出符号，再移除此版本限定补丁。
