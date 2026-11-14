# Dragonwell Standard 21 LTS：原生 musl 二进制配方

按用户选择使用 Standard，不使用 Extended。固定官方
[21.0.13.0.13+9 GA 发布](https://github.com/dragonwell-project/dragonwell21/releases/tag/dragonwell-standard-21.0.13.0.13%2B9_jdk-21.0.13-ga)
的 amd64 Alpine/musl 归档；不把 Linux/glibc 归档混入宿主。
SHA256：`4f3b1bd11ead44f6247cb3f338c3da7b65294c7646ac256182f78c58fe2d0a2e`。
下载大小 207,996,508 字节；Portage Manifest 另记录 BLAKE2B 和 SHA512。

## 两个配方补丁

基线见 `../../portage/repository-baseline.tsv`。不新建 overlay：

1. `repository/0001-add-standard-musl-recipe.patch` 在现有 Gentoo-Zh 仓库添加
   `dev-java/dragonwell-bin-21.0.13.0.13_p9` 及 Manifest、Java 环境文件。
2. `repository/0002-register-java21-provider.patch` 在 Gentoo 主仓库的
   `virtual/jdk-21` 中加入 Dragonwell 提供者，让依赖检查认识它。

这两份补丁的目标仓库不同；不要把二者都应用到同一个仓库。
新机 chroot 在对应 profile、仓库提交及依赖已经准备好后执行：

```bash
# 假设当前目录是 dotfiles 仓库根，目标根内操作。
patches="$PWD/gentoo_setting/experiments/musl-llvm-pc/patchsets/dragonwell-21.0.13/repository"
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

## 后续维护与移除

固定接受基线不等于永久冻结安全更新。跟进 Standard 21 LTS 更新时，核对官方
归档、发布校验值、musl ABI、证书集成和上述运行测试。上游仓库提供合适的原生
Standard 配方及虚拟包依赖后，切换 provider 并验证，再移除对应补丁。直接同步
仓库可能覆盖本地修改；先检查差异，不设置静默自动重放或忽略失败。
