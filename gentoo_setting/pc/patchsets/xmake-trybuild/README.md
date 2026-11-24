# xmake：日常项目优先与 Makefile 转接

本机基线为 GURU `dev-build/xmake-3.1.2`。源码归档由现有 Manifest 的大小、
SHA512 校验；Makefile 探测源文件 SHA256 为
`0be2dae53c0b398be6986cfd3c741ee898f6e20c66086154f48549e2d112908b`。
xmake 已在 world 中，无须通过上游
安装脚本或 xmake 自更新覆盖 Portage 管理的文件。

## 系统构建边界

xmake 是使用 `xmake.lua` 的构建系统，不是 Makefile 解释器，不能替换
`/usr/bin/make`、`gmake` 或 Portage 的 `MAKE`／`emake`。`MAKEOPTS` 仍按 GNU Make
语义使用。官方 [try-build 文档](https://xmake.io/guide/extras/trybuild-3rd-sourcecode.html)
说明第三方项目通过原来的构建工具执行；统一入口不等于移除后端。

2026-11-24 本机 `emerge --pretend --depclean dev-build/make dev-build/bmake
 dev-build/ninja dev-build/cmake dev-build/meson` 无卸载项。GNU Make 属于 profile
system，CMake 本体也使用它构建；BSD make 被 lowdown 构建依赖。Ninja、CMake、
Meson 由现有软件和 eclass 的构建链需要，均保留。不能只按运行时反向依赖判断
构建依赖，也不通过 `emerge --unmerge` 强制越过依赖检查。

不批量改写 CMake／Meson／autotools 项目的构建系统；如上游提供正式 xmake 支持，
可逐包验证配置、功能开关、生成代码、测试、安装清单及沙箱后切换。自行重写这些
行为会成为长期维护的另一套构建系统，不能作为通用兼容补丁自动推广。

## 自有项目模板

新项目的 `xmake.lua` 可从以下最小模板开始，另放置 `main.cpp`：

```lua
set_project("example")
set_languages("c++20")
set_toolchains("clang")
add_rules("mode.debug", "mode.release")
target("example")
    set_kind("binary")
    add_files("main.cpp")
    add_cxxflags("-stdlib=libc++", "-flto=thin")
    add_ldflags("-stdlib=libc++", "-flto=thin", "-fuse-ld=mold")
```

```sh
xmake f -c -m release --ccache=n
xmake -v
xmake run
xmake project -k compile_commands
```

本机 Clang 22／libc++／musl 的 C++20 vector/accumulate 编译、ThinLTO＋mold
链接、执行结果和编译数据库生成通过。xmake 不自动等价继承 `/etc/portage/make.conf`，
故模板显式选择工具链和链接选项；不默认启用编译缓存，不为新机器硬编码本机 CPU。
这只是最小 C++ 项目验证，不代表 Qt、CUDA、全部 Portage 包已改用原生 xmake。

## Qt、CMake 与内核的实际边界

本机 Qt 6.11.3 的原生 xmake 控制台项目通过：`add_rules("qt.console")`、
`add_frameworks("QtCore")`，把含 `Q_OBJECT` 的头文件也加入 `add_files`，
xmake 直接调用 moc，编译生成代码并链接 QtCore；元对象类名与 QString 输出正确。
编译链接同样使用 Clang／libc++／ThinLTO／mold。这证明 Qt 应用可以原生使用
xmake，不表示已将 Qt 框架或 SonicDE 自身的构建系统迁移。
[Qt 官方构建说明](https://doc.qt.io/qt-6/qt6-buildsystem.html)仍使用 CMake。

已有 CMake 项目可在自己的源码目录使用：

```sh
xmake f --trybuild=cmake --ccache=n --tryconfigs="-DCMAKE_CXX_COMPILER=clang++"
CMAKE_GENERATOR=Ninja xmake
```

本机最小 C++ 项目的配置、Ninja 构建与直接运行通过；环境变量仅作用于此命令。
不要只在 `--tryconfigs` 中传 `-G Ninja`：该版本 xmake 仍按默认 Makefiles 选择
执行器，造成 CMake 生成 Ninja 文件后却调用 make。转接还可能执行后端自己的
install 阶段，应审阅项目和输出目录，不能将任意第三方项目作为 root 运行。

现用 Linux 源码包含约三千份 Makefile，顶层直接检查 GNU Make >=4.0；
LLVM 编译器支持并不等于替换 Kbuild。已独立将 `scripts/basic/fixdep.c` 用原生
xmake 编译并用依赖文件样本运行通过（需要 `scripts/include` 的 xalloc.h），
没有替换内核源码树中的工具。这只覆盖一个宿主辅助工具，不是内核镜像或模块验收。
完整内核、NVIDIA 模块、签名和 initramfs 沿用已验收的联合构建链，
不为全 xmake 目标重写 Kconfig、递归构建、链接脚本和架构生成规则。

## Makefile 探测补丁

原 `find_file("[mM]akefile", ...)` 在该版本的本机运行时没有匹配到已有文件，
继而询问生成 xmake.lua 或报 project not found。补丁按 GNU Make 的文件名优先级
显式探测 `GNUmakefile`、`makefile`、`Makefile`，不改变 Makefile 内容或 make 参数。

GURU 的原配方已有 `default`，无需修改配方或新增 overlay；只部署源码补丁到版本目录：

```sh
# 在本目录的上两级 PC 配置根执行；以下部署与安装命令需要 root。
install -Dm0644 patchsets/xmake-trybuild/source/0001-detect-makefile-names-explicitly.patch \
  /etc/portage/patches/dev-build/xmake-3.1.2/0001-detect-makefile-names-explicitly.patch
emerge --ask --usepkg=n --oneshot dev-build/xmake
```

官方归档源码的补丁严格应用／撤回检查通过。隔离运行时已验证三种文件名的构建及清理，日志显示实际调用 `make -j...`。
系统包已在正常 Portage 沙箱中重装，相同三种文件名构建／清理回归全部通过。对于现有 Makefile 项目，可运行
`xmake f --trybuild=make`，之后 `xmake`／`xmake clean`；GNU Make 后端必须保留。

新版本不自动匹配旧版本源码补丁目录，不锁定升级；源码不同而无法严格匹配则停止复核，不强行应用。
上游文件名探测已修复且回归通过后，删除本组及部署的旧版本补丁。

## 整机效率与空间

本机已启用 `buildpkg`／`binpkg-multi-instance`，默认增加 `--usepkg`，并显式保留
`--binpkg-respect-use=y --binpkg-changed-deps=y`。只复用本机 PKGDIR，不添加外部 binhost。
定向 xmake 重装预演实际选择本机二进制包；这项检查不等于全 world 重建已执行。

修改源码补丁、编译器、CPU 参数、LTO 或链接选项后，不能假定旧二进制包自动识别这些
变化，必须对目标包使用 `emerge --oneshot --usepkg=n ...` 重新构建；新补丁的安装示例
也显式禁用 binpkg 复用。二进制包不作为跨机器／ABI 通用缓存，谨慎清理仍需复用的包。

保留 `MAKEOPTS="-j13 -l13"`、Portage `--jobs=2 --load-average=13` 和 ThinLTO
链接内部 jobs=2。32 个逻辑 CPU、约32GiB内存不适合无差别拉满全部包并行度；
逐包调整前先观察峰值内存。成功安装后 Portage 构建临时目录为空。
没有启用 ccache／sccache，保持原有“不默认编译缓存”的选择。

原生最小 C++ 与 Qt 项目二次构建均不重写二进制，单次调用约0.15–0.17秒；
这是本机热增量样本，不是与 Make/Ninja 的受控性能比较，不能外推大型包加速比例。
`emerge -e` 本来会要求重装整个依赖闭包，不作为日常维护命令；一般维护先预演
`emerge --pretend --update --deep --newuse @world`，再按需执行。只有工具链／ABI
迁移等明确需要时才安排完整源码重建，并显式关闭二进制包复用。
