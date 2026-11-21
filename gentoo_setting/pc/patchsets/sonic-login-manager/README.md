# Sonic Login Manager：直接包含 POSIX 类型定义

`SelfProvisioner.h` 声明使用 `uid_t`、`gid_t` 和 `mode_t` 的接口，却未直接包含
定义这些 POSIX 类型的头文件。musl/Clang 编译 `DaemonApp.cpp` 时因此失败。

`source/0001-include-posix-id-types.patch` 只给该头文件补上 `<sys/types.h>`，
不改变用户创建、权限设置、PAM 或登录逻辑。原验收基线为
[6.8.0.3 源码](https://github.com/Sonic-DE/sonic-login-manager/blob/6.8.0.3/src/daemon/SelfProvisioner.h)，
当时已通过应用／撤回检查和正常 musl/Clang 编译安装。

2026-11-21 升级到 6.8.2 时同一错误再次出现：旧补丁仅安装在精确版本目录，
没有应用到新版。新版归档 Manifest 的 BLAKE2B／SHA512／大小校验及源码精确
应用预检通过，因此将同一补丁移到包目录，不新增 overlay 或修改配方：

```text
/etc/portage/patches/sonicde-base/sonic-login-manager/0001-include-posix-id-types.patch
```

同时撤下旧精确版本目录里的副本，避免旧版本重建时重复应用。6.8.2 已通过正常
Portage 沙箱编译安装，VDB 文件清单非空；不代表已重新登录验收。以后升级先复核新源码；上游已直接包含
所需定义时移除该用户补丁，不兼容时停止，不强制覆盖或模糊应用。
