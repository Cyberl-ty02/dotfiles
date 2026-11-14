# Firefox 153.7 ESR：官方配方回补与 musl 修复

**状态：正常 Portage UID 250 沙箱构建及安装通过，无 GCC／glibc；Node、中文语言包
已安装。普通用户、隔离网络、空白 profile 的离线中文页面渲染和截图目检通过。**
GPU、输入法、旧 profile 和 Widevine DRM 尚未验收，不切换到 rapid 渠道。

## 基线与来源

目标是现有 Gentoo 主仓库，基线
`3d5af35677728d11439cacc1ca2165f39b1eaa3d`，与
`../../portage/repository-baseline.tsv` 一致；不新建 overlay、不同步整棵仓库。

回补来源是 Gentoo 官方提交
[`338d47a0d22df38dff7154713bb93f0502bd5d8d`](https://github.com/gentoo/gentoo/commit/338d47a0d22df38dff7154713bb93f0502bd5d8d)。
该版本于 2026-11-10 发布，含安全修复，见
[Mozilla ESR 153.7.0 发布说明](https://www.mozilla.org/en-US/firefox/153.7.0/releasenotes/)。

从上述固定提交读取的文件已按 Git blob 算法计算并核对官方对象 SHA：

| 上游文件 | Git blob SHA |
| --- | --- |
| `www-client/firefox/firefox-153.7.0.ebuild` | `a513143694338e1efecefc6a77a81163d8a2fa97` |
| `www-client/firefox/Manifest` | `7999a93773f08a807904aaa03e7c5906eb52337c` |
| `www-client/firefox-l10n/firefox-l10n-153.7.0.ebuild` | `898db092575632fe52726377bc01d8cf214cbc3a` |
| `www-client/firefox-l10n/Manifest` | `16ddf31d772962134de9af68488792c709af712e` |

## 补丁范围

`repository/0001-import-official-esr-153.7.patch` 只修改四个路径：

- 新增原样的 Firefox 153.7.0 和对应 l10n ebuild，保留旧 153.6.0 文件。
- Firefox Manifest 仅加入新版源码和 `firefox-153esr-patches-05.tar.xz` 两项。
- l10n Manifest 仅加入新版 100 个语言包条目，包括 `zh-CN`；与配方全部可选
  语言交叉核对。`en`／`en-US` 按上游逻辑由程序内部提供。

Manifest 的文件名、大小、BLAKE2B 和 SHA512 均逐项来自上述官方固定文件，
没有推算或重新编造校验值，也没有带入 160 等其他版本的条目。

上游配方相对本轮 153.6.0 的实质变化包括补丁集 04→05、`llvm-r1`→`llvm-r2`、
NSS 最低版本 3.125→3.125.1，以及 D-Bus 依赖的书写整理。当前固定仓库有全部
直接继承的 eclass，且候选根已安装 NSS 3.125.1；这些静态检查不能替代 Portage
对新版本完整依赖闭包的预演。此前 153.6.0 无 GCC 的预演不自动算作新版通过。

`repository/0002-use-baseline-llvm-eclass.patch` 在导入后仅把 Firefox 的两处
`llvm-r2` helper 调用恢复为基线的 `llvm-r1`。固定仓库的 `rust.eclass` 仍继承
`llvm-r1`，同时加载两代 helper 会在 depend 阶段触发只读变量及导出函数冲突。
这项适配不改全局 eclass，也不降低编译器版本：实际选择 Clang/LLVM 22。

`repository/0003-musl-rust-build-scripts-dlopen.patch` 限定修改此版本的 musl
构建路径：上游 rust-bin 默认生成静态 musl 构建脚本，无法 `dlopen(libclang)`。
仅设置 target RUSTFLAGS 不覆盖 Cargo `--target` 下的宿主构建脚本，因此由配方
在临时目录建立 rustc wrapper，对宿主和目标编译均追加
`-C target-feature=-crt-static`，不修改全局 Rust 或 libc 配置。
已有 `RUSTC_WRAPPER` 时明确停止，需先核对组合方式；本轮没有启用 ccache。
普通 Portage UID 250 下，默认静态探针复现错误，动态探针成功加载 libclang；
离线 Cargo 显式 `--target=x86_64-unknown-linux-musl` 的真实宿主 build.rs 也通过。
随后完整重建及安装通过；小型对照与安装均不能替代 GPU、输入法和旧 profile 验收。

## 验证与下一步

已在独立临时副本中，以固定基线文件验证：

- `patch --dry-run --fuzz=0 -p1` 和实际应用通过，无 fuzz 或 offset。
- 两个新 ebuild 与官方对象逐字节一致，`bash -n` 通过。
- 旧 153.6.0 配方保持不变；反向应用后全部原文件逐字节恢复，新文件消失。

候选根已按顺序应用两个补丁，未改关键词或全局 USE；完整预演选择 LLVM 22、
中文语言包且不引入 GCC／glibc。Zip、cbindgen、图标虚拟包、simdutf、simdjson 五项
较小前置、Node 26.12.1 和中文语言包已正常安装；Firefox 本体也已安装；对应源码及补丁、中文 XPI 预取校验通过，
未从空缓存构建。
新机在目标根确认基线、
运行中的任务及可用空间后，先检查差异再应用；以下不是自动部署脚本：

```bash
# 在 dotfiles 仓库根，目标系统或其 chroot 内操作。
patchfile="$PWD/gentoo_setting/experiments/musl-llvm-pc/patchsets/firefox-153.7/repository/0001-import-official-esr-153.7.patch"
patch --dry-run --fuzz=0 -d /var/db/repos/gentoo -p1 < "$patchfile"
patch --fuzz=0 -d /var/db/repos/gentoo -p1 < "$patchfile"
compat="${patchfile%/*}/0002-use-baseline-llvm-eclass.patch"
patch --fuzz=0 -d /var/db/repos/gentoo -p1 < "$compat"
muslrust="${patchfile%/*}/0003-musl-rust-build-scripts-dlopen.patch"
patch --dry-run --fuzz=0 -d /var/db/repos/gentoo -p1 < "$muslrust"
patch --fuzz=0 -d /var/db/repos/gentoo -p1 < "$muslrust"
emerge --pretend --verbose --autounmask=n '=www-client/firefox-153.7.0:esr::gentoo'
```

预演须确认无 GCC／glibc 引入，并复核 locale、编译器、Rust 和语言包选择；若有
新阻塞，保留日志并按已知原因处理，不通过放宽沙箱、全局关键词或忽略补丁失败
继续。真正安装后再验证普通用户的私有 GUI、中文输入、音视频／GPU与隔离配置；
不要直接复用真实用户的浏览器 profile。

## 空间约束

当前官方配方的构建盘检查如下；这不是本轮实际峰值测量：

| 配置 | `CHECKREQS_DISK_BUILD` |
| --- | --- |
| 关闭 pgo/debug，非 LTO | `9700M` |
| LTO | `10900M` |
| pgo 或 debug | `18700M` |

至少保留 **20GiB 空闲底线，再额外提供配方要求的 9700M 构建余量**（配方实际值
`9700M`），还要另计源码下载、依赖、安装及二进制包缓存。仅剩 24GiB 不能据此
启动本体编译。不要降低实验空间保护来满足 ebuild 自身检查；LTO／pgo／debug
所需余量更高。空缓存、完整构建及实际峰值仍待验证。

## 移除条件

Gentoo 接受基线更新到已经提供等价 153.7 ESR 或后续安全版本时，先比较本地
修改与上游配方、Manifest，确认翻译和 musl 构建／运行通过，再移除被覆盖的
补丁。第三份补丁在宿主构建脚本已能动态加载 libclang 且完整编译通过后独立移除；
不能仅凭 target RUSTFLAGS 的变化判断已解决。第二份适配补丁在仓库的 Rust／LLVM helper 已统一到新版时单独复核移除。
不要在新版本上静默重放此固定补丁，也不要为保留实验版本永久冻结安全更新。
