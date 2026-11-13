# lowdown 3.1.1

Gentoo `app-text/lowdown-3.1.1` 的 configure 定义了 BSD `__unused` 宏，
与 musl `struct stat` 的同名成员冲突。本组直接回补
[上游修复 cc78c692](https://github.com/kristapsdz/lowdown/commit/cc78c6923a35f169b96260f3c156177d8c4b7526)，
对应 [issue 186](https://github.com/kristapsdz/lowdown/issues/186)。不修改系统头文件。

将源码补丁安装到以下目录，再重建该包：

```text
/etc/portage/patches/app-text/lowdown-3.1.1/0001-oconfigure-musl-cdefs.patch
```

独立源码副本的应用与反向撤回检查通过；全新实验根已确认用户补丁实际应用，
并在正常 Portage 沙箱下编译安装通过。
升级到已包含该提交的版本后，核对 configure，移除这一版本限定补丁。
