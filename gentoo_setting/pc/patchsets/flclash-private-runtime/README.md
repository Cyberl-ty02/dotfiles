# FlClash：musl 宿主上的私有 glibc 前端

基线为 Gentoo-Zh `73b502777b071c0cb934f4ad0053eec6c54a2139` 的
`net-proxy/flclash-bin-0.9.3`。修改已有仓库，不新增 overlay；原生 glibc 路线保留。
本组提供 Portage 安装与运行时检查，**不自动配置 OpenRC、setuid 或 TUN 权限**。
真实网络转发、桌面系统代理和新内核启动需另行验收。

## 组成与边界

- `glibc-compat` 开关将前端与插件的解释器／DT_RPATH 指向已验收的系统级
  Freedesktop Platform 26.08。Flatpak 继续管理该运行时；Portage 不复制其库。
- 五个小型托盘库从 Debian trixie 的 Ayatana／dbusmenu 包提取，约 0.5 MiB，
  由 FlClash 包管理在 `/opt/FlClash/compat/tray`。保留 copyright，不执行 Debian
  安装脚本。不是 LocalSend 的私有依赖，也不安装 Debian 包管理器。
- JVM 使用 `dev-java/dragonwell-bin:21[glibc-runtime]` 的私有 glibc Standard 21，
  与宿主默认 musl Standard 21 核对 Java／厂商版本。不注册第二个系统 VM。
- 保留 Flutter AOT `libapp.so` 和 manifest 校验的静态 Core 原始字节。
  动态 ELF 先预检再重定位；上游 AOT 结构变化时停止，不能盲目重放补丁。
- 入口使用程序私有环境；经 PATH 启动的 `xdg-open`、`gio`、`gsettings`、
  `pkexec`、`kwriteconfig`、`dbus-send` 等辅助命令由小型包装恢复调用者环境，防止外来 GIO／GL 模块路径进入
  原生 musl 子程序。这不等于已验收任意绝对路径启动的子程序或真实浏览器流程。
  `which` 也按原生 PATH 查找，避免辅助命令的别名误报尚未安装的可选后端。
- 软件渲染默认仅限此前端，不改宿主 GL。真实 GPU、托盘面板、中文输入和电源行为
  仍需桌面验收。私有 ABI 文件不进入原生 musl SONAME 提供／依赖索引；
  `FlClash --check-runtime` 实际检查它们在指定 glibc 运行时的依赖解析。

## 来源与更新

Debian 官方公钥指纹见 [FTP 团队记录](https://ftp-master.debian.org/keys.html)。
本次核对了三份 InRelease 签名、Release 中的 Packages.xz SHA256 和逐包 SHA256；
国内 USTC 与官方源 InRelease 一致。补丁 Manifest 固定接受资产的 BLAKE2B／SHA512，
重建时不依赖镜像当时恰好提供的新版本。

| Debian 包 | 本次接受版本 |
| --- | --- |
| libayatana-appindicator3-1 | 0.5.94-1 |
| libayatana-ido3-0.4-0 | 0.10.4-1 |
| libayatana-indicator3-7 | 0.9.4-1+b1 |
| libdbusmenu-glib4 | 18.10.20180917~bzr492+repack1-4 |
| libdbusmenu-gtk3-4 | 18.10.20180917~bzr492+repack1-4 |

这些是验收基线，不是 package.* 的永久版本锁。更新库包时从有效签名索引重新选择
维护版本、刷新 Manifest 并重新验收；镜像若清理旧资产，不跳过校验或改用未知文件。
更新 Flatpak 运行时前先退出 FlClash，更新后复查入口与图形流程；更换运行时分支
须协调修改配方、入口和一键脚本，不能只放宽一个版本检查。

升级通过 `portage/sets/musl-private-apps` 的 USE 依赖约束：若同步后的新配方
不再提供 `glibc-compat`／`glibc-runtime`，解析器不能静默选用该未适配配方。
这不固定应用发布版本；上游改用等价原生方案后，验收并修改此集合约束即可。

## 新机／chroot 安装顺序

先按主实验 README 准备官方 musl/LLVM profile、仓库及桌面依赖。在目标根或已挂好
`/proc`、`/dev` 的 chroot 内操作；源码仓库需可读，DNS、CA、时间和代理需有效。

1. 依照 [Dragonwell 补丁组](../dragonwell-21.0.13/) 应用 `0001` 与 `0002`，
   再将其 `0003-optional-private-glibc-runtime.patch` 应用到 Gentoo-Zh。
2. 依次使用本目录 `repository/0001-musl-private-runtime.patch`、
   `repository/0002-native-proxy-command-environment.patch` 修改 Gentoo-Zh。
   用现有 `scripts/apply-patch-if-needed.py` 先检查，再加 `--apply`；
   已有相同修复会跳过，不兼容时停止。未通过检查不能强制应用。
   两份补丁有重叠，重复安装时以两个 `--patch` 参数按顺序检查完整组；工具先在
   临时副本预检，已完整应用则跳过，第二份不兼容也不会向真实目标写入第一份。
3. 准备系统级 Flatpak 运行时，并登记 package.use／关键词。可复用实验目录的
   一键安装脚本，默认国内镜像，需要时加 `--official`：

```bash
# 当前目录为 gentoo_setting/pc。
python3 scripts/apply-patch-if-needed.py --root /var/db/repos/gentoo-zh \
    --patch patchsets/flclash-private-runtime/repository/0001-musl-private-runtime.patch \
    --patch patchsets/flclash-private-runtime/repository/0002-native-proxy-command-environment.patch --apply
# --flclash-runtime 必须与 --system 配合；脚本同时安装清单中的七个主应用。
bash scripts/install-flatpak-apps.sh --system --flclash-runtime
# package.use/desktop，按包原子顺序登记：
# dev-java/dragonwell-bin:21 glibc-runtime
# net-proxy/flclash-bin glibc-compat
# package.accept_keywords/desktop：
# dev-java/dragonwell-bin:21::gentoo-zh ~amd64
# net-proxy/flclash-bin::gentoo-zh ~amd64
# 将 portage/sets/musl-private-apps 放入 /etc/portage/sets/musl-private-apps。
emerge --pretend --verbose @musl-private-apps
emerge --verbose @musl-private-apps
FlClash --check-runtime
# 正常登录桌面后，以普通用户启动；软件条款由该用户自行决定。
FlClash
```

不需要手动建立第二个发行版 chroot。需要额外执行的是系统级 Flatpak 运行时准备；
JVM 和托盘库由 Portage 管理，软件卸载后不会成为无人跟踪的全局兼容库。
不在 chroot 内启动真实桌面或服务，不预先迁入真实订阅、账号及旧配置。

## 本次验收

已在候选根正常 Portage 沙箱安装，19 个动态 ELF 的依赖检查通过，安装 AOT 与
验签来源 deb 中的原始文件摘要一致。普通 UID 1000、只读候选根和独立 HOME／
Xvfb／网络中，中文仪表盘、五个私有托盘库、显式 JNI 及原生 GIO 辅助命令环境
恢复通过。界面流程本身未触发 JVM 加载，不扩大为所有 Java 功能验收。

实际安装的 GUI 另已通过中文文件选择器导入自制 YAML、启动 Core、回环 HTTP 200、
私有 KIO 代理写入，以及停止后 ProxyType=0／端口关闭的完整往返。应用全局混合
端口会覆盖 YAML 的同名端口，测试经实际 GUI 调整为一致，未改真实用户配置。
独立用户／网络命名空间内还通过直接客户端的 TUN TCP 转发、收发计数及
不可达路由负对照，恢复路由后再次成功；宿主路由哈希不变。它们仍是隔离验收，
不等于真机自动路由、外网连接或所有桌面应用均已使用代理。

上游在没有 `/run/systemd/system` 时直接走 Core 授权，无需另造 OpenRC 服务。
其 Polkit 路线将 Core 设为 root／请求者组、4750；已仅在自有用户命名空间的
一次性副本验证引用含空格与引号路径及权限检查，实际候选 Core 仍为 0755。
候选 `sonic-polkit-agent` 保留 KDE 兼容启动名称，与 SonicDE 的 DesktopNames=KDE
匹配。真实登录后的授权窗口与 TUN 权限仍须单独验收，不在宿主可访问的实验文件上
预先开启 root setuid。源码依据为上游 v0.9.3 的
[system.dart](https://github.com/chen08209/FlClash/blob/v0.9.3/lib/common/system.dart)、
[linux_elevation.dart](https://github.com/chen08209/FlClash/blob/v0.9.3/lib/common/linux_elevation.dart) 和
[linux_proxy.dart](https://github.com/chen08209/FlClash/blob/v0.9.3/plugins/proxy/lib/src/linux_proxy.dart)。

一键脚本在无系统 DBus 的 chroot 中幂等执行通过；集合已登记，package.* 排序
检查通过，当前允许关键词范围内的 world 预演为零项。未接受 LLVM 23 的关键词
扩展建议。尚未从新根启动，真机 TUN 自动路由、OpenRC 授权、实际桌面代理及旧订阅仍待验收。

## 移除条件

上游／Gentoo-Zh 提供等价 musl 配方或可维护的原生界面后，先验证替代方案，再移除
本组配方差异、应用专用辅助命令和不再使用的 `glibc-runtime` 开关。Flatpak
运行时可能仍被 WPS 等应用使用，不能随 FlClash 一并盲删；不用本组时原生默认
Java 仍保留。补丁中的 ELF 工具与公开 `scripts/relocate-flclash-elf.py` 相同，修改
工具后必须同步副本并重新检查应用／撤回、摘要保护及正常沙箱安装。
