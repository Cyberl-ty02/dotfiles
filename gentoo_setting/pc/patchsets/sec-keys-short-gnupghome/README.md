# 公钥包：缩短临时 GnuPG keyring 路径

目标为现有 Gentoo 仓库的 `eclass/sec-keys.eclass`；维护基线见
`../../portage/repository-baseline.tsv`，不另建 overlay，也不固定公钥包版本。

2026-11-20 更新在 Zsh 公钥包的 `gpg --import` 因 agent IPC 失败停止。
本批长工作区使 agent 基础 socket 路径约102字节，`.browser` 后缀会超出
Linux Unix-domain socket 路径容量。包级 PORTAGE_TMPDIR 尝试没有改变实际构建路径，
该临时 env 已撤回。补丁仅把 compile／维护导出函数的临时 GNUPGHOME 从
`${WORKDIR}/gnupg` 移至 `${PORTAGE_BUILDDIR}/g`，本批全部公钥包的最长 browser socket 为103字节。
此前 `${T}/g` 对 Zsh/groff 已通过，但 Zendodd 包名更长，仍超限，最终补丁继续
缩短为包私有构建根下的目录。
公钥原始输入、导入／导出选项、清单校验和 Portage 沙箱不变；不处理用户私有 keyring。

应用顺序：统一恢复脚本的 Gentoo 组中，mold 之后、Firefox 之前；无文件交叠。
先严格预检；一致的上游修复自动跳过，不兼容停止。若上游已提供短路径或独立 socket
目录，复验实际公钥包后撤回此补丁；工作区更长时仍须采用短挂载点，不能无限依赖缩名。

验证：严格补丁应用／逆向幂等预检通过；Zsh、groff、Zendodd 三个公钥包
均已在正常 Portage 批次真实安装通过。后续普通软件更新与保留库预演也已完成；
这个补丁本身的证据仅覆盖公钥包。当前整机边界见 PC 根 README。
