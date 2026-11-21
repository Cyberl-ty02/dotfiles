# Dragonwell Standard 21 LTS：原生 musl 二进制配方

按用户选择使用 Standard，不使用 Extended。固定官方
[21.0.13.0.13+9 GA 发布](https://github.com/dragonwell-project/dragonwell21/releases/tag/dragonwell-standard-21.0.13.0.13%2B9_jdk-21.0.13-ga)
的 amd64 Alpine/musl 归档；不将 Linux/glibc 构建登记为宿主 VM。
SHA256：`4f3b1bd11ead44f6247cb3f338c3da7b65294c7646ac256182f78c58fe2d0a2e`。
下载大小 207,996,508 字节；Portage Manifest 另记录 BLAKE2B 和 SHA512。

## 配方补丁与应用顺序

基线见 `../../portage/repository-baseline.tsv`。不新建 overlay：

1. `repository/0001-add-standard-musl-recipe.patch` 在现有 Gentoo-Zh 仓库添加
   `dev-java/dragonwell-bin-21.0.13.0.13_p9` 及 Manifest、Java 环境文件。
2. `repository/0002-register-java21-provider.patch` 在 Gentoo 主仓库的
   `virtual/jdk-21` 中加入 Dragonwell 提供者，让依赖检查认识它。
3. 可选的 `repository/0003-optional-private-glibc-runtime.patch` 在第一份补丁之后，
   应用到 Gentoo-Zh，增加 `glibc-runtime` 开关；供 FlClash 等独立 glibc 进程使用。

`0001` 与 `0002` 的目标仓库不同；不要把二者都应用到同一个仓库。
完整启用私有 glibc 构建时，可对 Gentoo-Zh 用两次 `--patch` 组合 `0001` 与
`0003`，调用现有 `scripts/apply-patch-if-needed.py` 做有序组预检；Gentoo 主仓库
的 `0002` 单独处理。这样可识别后续补丁已修改前一份文件的完整状态，重复执行
自动跳过；不兼容则在临时副本停止，不向真实目标写入半组补丁。
新机 chroot 在对应 profile、仓库提交及依赖已经准备好后执行：

```bash
# 假设当前目录是 dotfiles 仓库根，目标根内操作。
patches="$PWD/gentoo_setting/pc/patchsets/dragonwell-21.0.13/repository"
patch --fuzz=0 -d /var/db/repos/gentoo-zh -p1 < "$patches/0001-add-standard-musl-recipe.patch"
patch --fuzz=0 -d /var/db/repos/gentoo -p1 < "$patches/0002-register-java21-provider.patch"
# 将下面这一行登记到目标根的 package.accept_keywords（本仓库 desktop 已包含）。
# =dev-java/dragonwell-bin-21.0.13.0.13_p9::gentoo-zh ~amd64
emerge --pretend --verbose =dev-java/dragonwell-bin-21.0.13.0.13_p9::gentoo-zh virtual/jdk:21
emerge --verbose =dev-java/dragonwell-bin-21.0.13.0.13_p9::gentoo-zh virtual/jdk:21
eselect java-vm set system dragonwell-bin-21
source /etc/profile
java -version
javac -version
```

## 隔离方式与验证

程序及自带运行库位于版本化 `/opt/dragonwell-bin-*`；由 Gentoo `java-vm-2`
eclass 管理 VM 登记、默认选择和卸载。不修改全局 `LD_LIBRARY_PATH`，不新增
`libc.musl-x86_64.so.1` 全局别名。配方仅将自身 ELF 中的 Alpine musl NEEDED 名
改为 Gentoo 的 `libc.so`；不改加载器实现。检查的 69 个 ELF 中 66 个需该调整，
没有外部 libstdc++ 或 libgcc 依赖。保留上游法律文件和自带字体渲染库；Java
证书改为由 baselayout-java 维护的系统证书库。

正常 Portage 沙箱安装六个包（含 Java 管理工具及 `virtual/jdk:21`）通过，
未安装 GCC 或 glibc。实际安装产物再以隔离普通 UID1000 验证：javac 编译、
中文 UTF-8 文件读写、人民币格式、Asia/Shanghai、CJK 字体和 PNG 输出均通过；
系统信任库读到 118 个 CA。这是当前证书快照，不是永久数量要求；读取通过也
不等于完成远端 TLS 联网验证。原用户 Java 配置及真实系统默认 JDK 未改动。

精确应用／撤回及配方语法检查通过；这次在全新 stage3 演进出的桌面根安装，
不等于在空白 stage3 上独立重跑整个安装链。真实桌面 AWT、JNI 应用、FlClash
与旧 Java 项目仍需分别验收。

## 可选私有 glibc 构建

`glibc-runtime` 从同一官方 Standard 21 发布获取 Linux/glibc 归档，Manifest
记录其 BLAKE2B／SHA512；官方资产 SHA256 为
`e85053e90738dd18bae4cf756b627de145b2b88b517356d0a988c8b07fa9f947`。
它与 musl 构建保持相同 Java／厂商版本，安装在版本化
`/opt/dragonwell-glibc-*`，入口数据链接为 `/opt/dragonwell-glibc-21`。
私有目录使用同一系统证书数据，但不登记第二个 VM，不修改宿主动态加载器。

新增文件仍由**同一个 Dragonwell Portage 包**管理和卸载，不需要另建 glibc
chroot。它也不提供系统 glibc；使用它的进程另需已验收的 glibc 运行时。
FlClash 路线复用系统级 Freedesktop Platform 26.08，准备及安装顺序见
[FlClash 补丁组](../flclash-private-runtime/)。只有私有目录排除原生 musl
SONAME 的提供／依赖索引，避免把外来 ABI 当作系统库；实际依赖另由应用入口检查。

候选根已正常沙箱重装该包，musl 默认 Java 与显式 glibc 加载器调用均报告
Standard 21.0.13；`eselect java-vm list` 仍只有一个 `dragonwell-bin-21`。
原生 GCC／glibc 未安装。此项是安装与 CLI 检查，JNI／GUI 随消费它的应用单独验收。

## 后续维护与移除

固定接受基线不等于永久冻结安全更新。跟进 Standard 21 LTS 更新时，核对官方
归档、发布校验值、musl ABI、证书集成和上述运行测试。上游仓库提供合适的原生
Standard 配方及虚拟包依赖后，切换 provider 并验证，再移除对应补丁。直接同步
仓库可能覆盖本地修改；先检查差异，不设置静默自动重放或忽略失败。
