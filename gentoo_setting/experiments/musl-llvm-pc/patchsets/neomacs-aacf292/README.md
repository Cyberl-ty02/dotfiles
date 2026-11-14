# Neomacs：固定提交的 musl 兼容修复

源码基线：`aacf29294ab30aed5736e1eabcb3b83122593fce`；Gentoo-Zh 配方基线见
`../../portage/repository-baseline.tsv`。不随 live 仓库自动追踪其他提交。

## 补丁内容

- `source/0001-musl-fault-diagnostics-and-libc-types.patch`：修复七处编译错误。
  musl 不提供 glibc 的 `backtrace` / `backtrace_symbols_fd`，因此仅输出提示，保留
  原有默认信号处理及重新抛出流程；不在信号处理器中加入分配内存的回溯。
  同时修正 `TAB3` 的 `tcflag_t` 转换及两项 ioctl 请求号类型。
- `source/0002-reset-stack-probe-across-segments.patch`：在进入、离开栈段时重置
  `last_remaining`，包括展开恢复路径。避免把较大栈段返回调用者时的剩余空间差
  当作消耗量，导致后续申请的栈段不断增大。生产补丁没有诊断用的大小上限。
- `repository/0001-preserve-upstream-sqlite.patch`：保留 SQLite Cargo 特性，使用
  Gentoo 系统 SQLite，配方显式提供对应 USE 和依赖。
- `repository/0002-install-pinned-source-assets.patch`：安装固定源码实际提供的
  hicolor 图标、README 和 COPYING，修复配方引用不存在的图标与文档造成的安装失败。

## 验证状态

实际 musl 下以 UID250、真实 stacker 运行原版与修复版小型对照：原版申请从
32MiB 增长到约 160MiB、670MiB，由测试夹具在分配前的 256MiB 上限终止；
修复版完成 64 次调用及一次故意触发的展开恢复，保持 32MiB。

保留已准备源码和编译缓存进行增量重建，正常 Portage 沙箱和 UID250 下，Rust
release、Unicode 数据、127 个预载及 1,516 个 Lisp 文件的完整引导、安装通过。
`keepwork` 仅供本次重用缓存，未写入持久配置；临时编译钩子已撤除。
这不是空缓存、全新解包重建的证明，后续新机仍需复验。

安装版本 0.0.20，目标 `x86_64-unknown-linux-musl`，未安装 GCC 或 glibc。
普通用户 SQLite 内存库中文增删查、私有 X11 GUI 中文绘制通过；实际 Fcitx5/Rime
输入 `nihao<space>` 并保存得到“你好”。实验根已通过 `eselect editor set neomacs`
选为默认编辑器；真实系统编辑器未更改。尚未验收真实 GPU、旧 Doom 配置及插件。

## 应用与移除

确认上述基线后，先在 Gentoo-Zh 仓库根按编号应用 `repository/` 两个补丁，使用
`patch --fuzz=0 -p1`；再将 `source/` 两个补丁放入目标根
`/etc/portage/patches/app-editors/neomacs-9999/`。配方 `src_prepare` 调用 `default`，
由 Portage 应用源码补丁。chroot 与已启动系统使用相同位置，无需复制本地 overlay。
失败构建需要重新准备源码，不能只继续旧 compile 而漏补丁。

源码与配方补丁均已核对精确应用／撤回。上游更新后逐项确认是否已覆盖，再在
全新源码重建与运行验收后移除对应补丁；不要重复应用或随意漂移 live 提交。
