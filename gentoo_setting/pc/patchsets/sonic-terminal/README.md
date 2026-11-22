# Sonic Terminal：窗口管理与标签栏间隙

适用基线：`sonicde-base/sonic-terminal-26.08.3`，对应官方发布源码归档。
上游修复：[75ba4c38](https://github.com/Sonic-DE/sonic-terminal/commit/75ba4c38f00ce9d3ba7d13f5951132f6599947da)。

QML 主窗口最小化时，旧实现将同一状态同步给隐藏的 QWidget 兼容窗口，触发
Hide 事件再隐藏 QML 窗口。因此进程仍在，窗口却被窗口管理器撤管、任务栏无法恢复。
回补上游完整修复及其 `QmlWindowTest` 回归用例，不新增 overlay 或切换 live 版本。

`source/0001-keep-minimized-window-managed.patch` 应用到解包源码根。
发布归档的大小、BLAKE2B、SHA512 已与现有仓库 Manifest 一致核验；补丁应用与
撤回严格检查通过，旧版本的实机隔离窗口已复现。正常 Portage 沙箱重建安装通过；新窗口的正常最小化／
恢复、最大化后最小化／恢复均通过，窗口保持受管理、进程存活，最大化状态保留。
实际回归使用 X11 请求与窗口属性检查；
随补丁保留上游测试源，不表示已执行整套上游测试。

在本机配置后，以 root 执行的部署入口为：

```sh
install -Dm0644 patchsets/sonic-terminal/source/0001-keep-minimized-window-managed.patch \
  /etc/portage/patches/sonicde-base/sonic-terminal-26.08.3/0001-keep-minimized-window-managed.patch
emerge --ask --oneshot sonicde-base/sonic-terminal
```

只对已验证的 26.08.3 部署到版本补丁目录；这是自动失效边界，不锁定包升级。
新版本默认不应用此补丁，先检查是否包含等价修复，再验证最小化、任务栏恢复及
最大化状态保持。上游发布已包含修复并通过实机回归后，可删除旧版本补丁目录。
已有终端继续运行旧代码，不强制关闭；回归使用独立新窗口，不影响已有 shell 任务。

## 标签栏下方漏出壁纸

同一 26.08.3 基线的透明 QML 窗口中，兼容控件的样式会在标签行、页眉／容器边界
及单标签窗格的首个设备像素处留下未绘制区域。实际 X11 ARGB 读取确认整行 alpha=0，
因此会直接透出壁纸；将截图转换为 RGB 时它显示为黑线，不能据此判定没有间隙。

`source/0002-paint-tab-row-style-gap.patch` 是本地修复：在窗口坐标空间补齐可见窗格
上方／下方的 chrome 和顶部设备像素边缘，处理顶部、底部及自动隐藏标签栏，
不给整个终端铺不透明底色。
顺序为 0001→0002，正常沙箱重建同一个包；不新增 overlay，不改终端全局透明度。
严格应用／撤回、正常 Portage 沙箱重建安装已通过。真实 X11 ARGB 八组回归
（显示／自动隐藏标签栏 × 顶部／底部 × 普通／65% 透明终端）通过，终端内部
alpha 保持255／166。另按真实系统 desktop 启动项打开交互式 Zsh，再新建标签，
并验证右键新窗口的等效命令；这些路径也不再出现透明横行。不能仅凭休眠命令或
隔离 profile 正常就声称任务栏入口通过。最小化、恢复与最大化状态另行回归通过，
不把这些实机检查等同于执行整套上游测试。

把 0002 同样安装到上面的版本补丁目录后再重建。上游出现等价绘制修复或布局变更时，
先严格预检，已有修复则跳过，不兼容则停止；新包版本不会自动套用旧版本目录。
