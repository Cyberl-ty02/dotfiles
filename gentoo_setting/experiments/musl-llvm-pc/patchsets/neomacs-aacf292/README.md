# Neomacs：固定提交的 musl 兼容修复

源码基线：`aacf29294ab30aed5736e1eabcb3b83122593fce`。适用于本轮
Gentoo-Zh 的 `app-editors/neomacs-9999`，不随 live 仓库自动追踪其他提交。

`source/0001-musl-fault-diagnostics-and-libc-types.patch` 处理首轮七个编译错误：

- musl 没有 `backtrace` / `backtrace_symbols_fd`；保留原有致命信号处理和重新抛出
  信号流程，在 musl 下输出无法提供原生回溯的提示。这个分支不提供故障栈帧，
  也不在信号处理器中引入可能分配内存的 Rust 回溯实现。其他 libc 分支保持原实现。
- `TAB3` 按 `libc::tcflag_t` 转换后取反，保持终端标志的位运算含义。
- 两项网络接口 ioctl 的请求号按当前目标函数签名转换。

## 验证状态

对失败构建保留的三个固定提交源码文件，`patch --fuzz=0` 应用及撤回后逐字节一致；
新根实际源码应用预检和正常沙箱下的 Rust release 编译也通过。构建产物的
`--version`、最小中文 batch 输出通过，Unicode 数据生成通过。后续 Lisp 字节编译
报 `stacker` 的 `mprotect/mmap: ENOMEM`；普通 UID250 对 `eieio.el` 的单文件复现
同样失败。当时可用内存约 23GiB，地址空间和数据段限制为 unlimited；根因仍待
验证，不能据此归因于 Portage 沙箱或断言 musl 独有。

尚未通过完整引导／安装、SQLite 和 GUI／输入法验收；默认编辑器未改变。保留
已构建二进制和复现日志，避免为未知原因反复重编译或关闭沙箱。

## 应用与移除

先确认源码基线，再将源码补丁放入目标根
`/etc/portage/patches/app-editors/neomacs-9999/`；当前配方的 `src_prepare` 调用
`default`，由 Portage 应用用户补丁。已有失败构建须重新准备源码，不能仅继续旧的
compile 阶段而漏掉补丁。新机 chroot 使用相同目录，不需要本地 overlay 副本。

SQLite 特性的配方调整保存在 `repository/0001-preserve-upstream-sqlite.patch`；
源码补丁不能改变 ebuild 的 `IUSE` 或 Cargo 特性选择。它以本轮
`portage/repository-baseline.tsv` 中的 Gentoo-Zh 提交为基线，在目标仓库中以
`patch --fuzz=0 -p1` 应用；配方层已用于这次 Rust 构建，但 SQLite 运行检查仍待验证。
这个补丁组尚未通过完整安装验收，当前仅供继续实验，不作为默认编辑器安装方案。
上游合入相应修复或更新固定提交后，先核对实现并在全新源码重建验证，再删除已经
被上游覆盖的补丁；不要同时重复应用。
