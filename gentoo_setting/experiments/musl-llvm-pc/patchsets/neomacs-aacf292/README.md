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
新根实际源码应用预检也通过。修复后的完整编译正在验证，尚不表示已安装或可运行。
后续还须完成版本、SQLite、中文 batch 输出及 GUI／输入法验收。

## 应用与移除

先确认源码基线，再将源码补丁放入目标根
`/etc/portage/patches/app-editors/neomacs-9999/`；当前配方的 `src_prepare` 调用
`default`，由 Portage 应用用户补丁。已有失败构建须重新准备源码，不能仅继续旧的
compile 阶段而漏掉补丁。新机 chroot 使用相同目录，不需要本地 overlay 副本。

SQLite 特性还需要独立的配方调整；源码补丁不能改变 ebuild 的 `IUSE` 或 Cargo
特性选择。目前这项调整仍在实验验证中，不把本目录单独视作完整安装方案。
上游合入相应修复或更新固定提交后，先核对实现并在全新源码重建验证，再删除已经
被上游覆盖的补丁；不要同时重复应用。
