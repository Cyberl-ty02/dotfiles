# KWayland：SonicDE ECM 的构建期兼容模块

发现基线：KWayland 6.7.6、SonicDE ECM 6.31.0、Qt 6.11.3。
Yakuake 26.08.3 要求 KWayland；SonicDE ECM 不安装 Wayland 查找模块，CMake
继而使用 Qt 捆绑的旧 FindWaylandScanner，无法识别 PRIVATE_CODE，且找不到
WaylandProtocols。兼容元包本身的空 CONTENTS 属正常情况，不能当成安装损坏。

补丁只向 KWayland 源码树加入 KDE ECM v6.30.0 的两个查找模块，保留 SPDX
版权和 BSD-3-Clause 标识（KWayland 源码已有对应许可）。Scanner 的相对 helper
引用改为 include(ECMFindModuleHelpers)，其余模块内容不改。不会替换全局 ECM、
切换桌面会话或放宽沙箱。系统再次提供这两个模块时，CMake 自动跳过本地回退。

上游来源：

- https://github.com/KDE/extra-cmake-modules/blob/v6.30.0/find-modules/FindWaylandScanner.cmake
- https://github.com/KDE/extra-cmake-modules/blob/v6.30.0/find-modules/FindWaylandProtocols.cmake

原文件 SHA256 分别为 ab5ac96381442423268b44571e14a23cabd05e37669c4fc459bdfa715efcb978、
c7290b4e15cda199d3c828151b34129b29eb012e93cfa96bcc0788a60885904d。

应用：先在 Manifest 校验通过的源码树运行 git apply --check，再将补丁安装到
/etc/portage/patches/kde-plasma/kwayland/，通过正常 emerge 重建。软件包目录不限定
版本；升级时严格检查，若上游源码不兼容则停止。已在已启动系统与 chroot 中使用
相同目录即可，不新增 overlay。系统模块恢复并通过重建，或 KWayland 改用其他
上游接口后，删除本补丁。Manifest SHA512、补丁精确预检和普通用户完整 CMake 配置／生成已通过；
实际 Portage 编译安装仍待本批次结果，不把配置检查视作安装。

本轮 KWayland 6.7.6 已通过正常 Portage 沙箱编译安装；实际 Yakuake 窗口与输入
仍须另行验收，不能由库安装成功推断全部桌面功能通过。
