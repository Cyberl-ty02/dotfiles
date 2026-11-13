# Bun 1.4.4：amd64 musl

以 Gentoo-Zh `73b502777b071c0cb934f4ad0053eec6c54a2139` 为基线。第一组补丁新增
一个私有 musl C++ 运行库包，第二组修改已有 Bun 配方及 Manifest；不维护整份 overlay。

官方 `bun-linux-x64-musl-baseline.zip` 还需要 `libstdc++`。这里从已固定摘要并验签的
Alpine v3.24 `libstdc++-15.2.0-r5.apk` 提取该库，约 2.7 MiB，安装在
`/opt/musl-cxx-runtime/lib`。这是 GCC 的运行库，不安装 GCC 编译器或 glibc。
签名验证工具和公钥包也固定了版本与 Manifest 摘要。

配方用小型 patchelf 工具，将副本的 libc 依赖名改为 Gentoo musl 的 `libc.so`，
C++ 运行库的 libgcc 依赖名则取已安装 LLVM ABI 库的实际 SONAME。Bun 位于
`/opt/bun-musl`，标准 wrapper 只为该进程添加私有库路径；不改全局库配置，
也不再额外创建 libc 别名。`bunx` 随包提供，默认不伪装为 `node`。

## 验证范围

独立官方 musl/LLVM stage3 中，正常 Portage UID 250 与沙箱安装通过；
LLVM libgcc 22.1.8 从源码构建，两个本地配方安装、JavaScript、中文和人民币格式化
通过，最终没有未解析 SONAME 警告。没有 GCC 编译器、glibc 或额外 glibc chroot。
此前版本的库名警告已修复，不以屏蔽 QA 代替修复。

该验证使用最小测试仓库及已校验的下载缓存。公开补丁已在独立上游副本通过应用／
撤回检查；主桌面实验根的 Gentoo-Zh 集成安装仍排队，完整博客依赖安装和构建尚未验证。
不把这一结果扩展到 arm64、其他版本或全部 Node.js 工具链。

## 使用与维护

先核对目标仓库基线，备份本地差异。以 root 在目标系统或已准备好的 chroot 中，
按顺序用 `patch --fuzz=0 -p1 -d /var/db/repos/gentoo-zh -i /补丁绝对路径` 应用
`repository/0001-add-private-musl-cxx-runtime.patch`、
`repository/0002-bun-amd64-musl-private-runtime.patch`。

为 `sys-libs/musl-cxx-runtime`、`dev-lang/bun-bin` 接受 `~amd64`，并为前者接受
`gcc-runtime-library-exception-3.1` 许可后，先预演再安装：

```bash
emerge -pv sys-libs/musl-cxx-runtime dev-lang/bun-bin
emerge -av sys-libs/musl-cxx-runtime dev-lang/bun-bin
bun --version
bun -e 'console.log(new Intl.NumberFormat("zh-CN", {style:"currency", currency:"CNY"}).format(12.5))'
```

需要正常 DNS、CA、时间与网络；GitHub、Alpine 源可能需要本地代理。正常安装流程
不需要实验使用的 bwrap 包装器，也不需要启动桌面。

上游同步可能覆盖本地差异，不安装自动重放钩子。更新 Bun、Alpine APK、公钥、
签名工具或 LLVM ABI 库后，重新核验摘要、签名、SONAME 与独立 stage3 安装；
旧 APK 修订可能从镜像清理，不能动态改 URL 后跳过校验。上游提供完整 amd64 musl
方案后，先验证替代配方与依赖，再逐项移除此补丁组及不再需要的私有运行库。
