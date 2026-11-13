# Sonic Login Manager 6.8.0.3

`SelfProvisioner.h` 声明使用 `uid_t`、`gid_t` 和 `mode_t` 的接口，却未直接包含
定义这些 POSIX 类型的头文件。musl/Clang 编译 `DaemonApp.cpp` 时因此失败。

`source/0001-include-posix-id-types.patch` 只给该头文件补上 `<sys/types.h>`，
不改变用户创建、权限设置、PAM 或登录逻辑。目标为
[6.8.0.3 源码](https://github.com/Sonic-DE/sonic-login-manager/blob/6.8.0.3/src/daemon/SelfProvisioner.h)。

应用、反向撤回检查及 musl/Clang 实际源码编译安装已通过。按版本限定安装为：

```text
/etc/portage/patches/sonicde-base/sonic-login-manager-6.8.0.3/0001-include-posix-id-types.patch
```

仅使用标准 Portage 用户源码补丁，不需要本地 ebuild 或额外 overlay。
上游头文件直接包含所需定义后，先核对目标版本和源码，再删除这一个用户补丁。
不将同一补丁自动应用于所有后续版本。
