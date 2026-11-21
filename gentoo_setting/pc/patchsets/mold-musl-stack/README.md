# mold：musl 下 LLVMgold 工作线程栈

修复仅针对 musl 构建的 mold 产物，不新增 overlay、env 文件、软件版本上限或全局
ulimit 设置；全局 mold／ThinLTO 默认不变。

## 基线、应用与移除

`repository/0001-musl-default-thread-stack.patch` 针对 Gentoo 基线
`3d5af35677728d11439cacc1ca2165f39b1eaa3d` 中的 mold 2.42.1 配方。
在 `src_configure` 中仅当 `elibc_musl` 启用时追加
`-Wl,-z,stack-size=8388608`。先按补丁索引检查并应用；仓库同步后重新检查。
版本是验收基线，不是禁止后续 mold 升级的上限。

上游自行为 LLVMgold 工作线程提供足够栈，或产物已有等效默认栈时，可不再应用；
若实现不同，需复核而不是强打补丁。撤回后用同样 curl ThinLTO 链接及库初始化检查
通过，才删除本补丁。配方上下文已变化而正反检查均失败时停止，重新评估新版本。

## 原因及证据

首轮 world 对齐在第 29 项 curl 8.23.0 的 ThinLTO 链接中发生 SIGSEGV，之前
28 项已合并。普通 UID 250 重放同一组目标文件，原 mold 崩溃、同版本 LLD 成功；
回溯位于 LLVMgold 的 LLVM 优化线程，包含深层 PHITransAddr 递归。
只修改独立 mold 副本的 PT_GNU_STACK 默认值为 8MiB 后，同一链接成功。
原系统链接器与 libc 没有被该诊断副本修改。

musl 默认线程栈较小，可由 ELF 的 PT_GNU_STACK 或显式 pthread 属性调整，参见
[musl 官方线程差异说明](https://wiki.musl-libc.org/functional-differences-from-glibc.html#thread-stack-size)。
本地对照支持线程栈不足的诊断，不把它误记为 curl 源码错误或系统 musl 的符号损坏。

## 正常安装与首次引导

旧 mold 尚不具备此设置时，用 LLD **仅引导这一次 mold 重建**，避免新产物尚未生成前
又让旧 mold 承载重型 LLVMgold 优化。目标 chroot 中应用补丁后可执行：

```bash
mold_bootstrap_ldflags="$(portageq envvar LDFLAGS | sed 's/-fuse-ld=mold/-fuse-ld=lld/g')"
LD=ld.lld LDFLAGS="${mold_bootstrap_ldflags}" \
  emerge --ask --oneshot sys-devel/mold
unset mold_bootstrap_ldflags
readelf -lW "$(command -v mold)"
```

检查 GNU_STACK 的 MemSiz 至少为 `0x800000`，且 Flags 不含 E。没有取消可执行文件
保护，也不把工作线程栈变成可执行内存。全新 stage3 则沿用实验 README 的
LLD／无 LTO 引导顺序，先安装修复后的 mold 和匹配 LLVMgold，再启用最终默认。

配方应用／撤回检查与正常 Portage 沙箱重建通过，产物实际为 8MiB、RW 非可执行栈。
已安装 mold 对原 curl 目标文件重新链接成功，普通用户加载新 libcurl、版本查询和
全局初始化／清理通过。curl 正常安装及其余 130 项 world 接续已全部完成，最终
world 复查为零项，更新后的 C／C++／Cargo ThinLTO 检查通过。桌面、真实显示与
新内核启动仍独立验收，不能由链接验证代替。
