# Guix WSL 配置

本目录把原来的 NixOS-WSL 目标迁移到 Guix WSL。物理 PC 继续使用 Gentoo；统一入口见 [`../../system_setting/README.md`](../../system_setting/README.md)。

配置参考 [Arian-D/guix-wsl](https://github.com/Arian-D/guix-wsl)，并继承 Guix 官方 `wsl-os`。冷启动由上游 `wsl-boot-program` 启动 Shepherd 和 `guix-daemon`，随后降权进入 `lty`，同时补齐首次密码设置。

## 文件说明

- `system.scm`：系统配置，默认用户为 `lty`，使用简体中文 locale、London 时区和 CJK 字体。
- `manifest.scm`：用户开发工具 profile。
- `channels.scm`：官方 Guix channel。
- `fix-runtime.sh`：重复执行安全，用于修复冷启动后缺失的 `/run/current-system`。
- `install.sh`：修复环境并应用完整系统配置。

## 修复并迁移现有环境

在 Windows PowerShell 中运行：

```powershell
wsl -d Guix --cd /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl --exec /bin/sh install.sh
wsl --terminate Guix
wsl -d Guix
```

重新进入后，WSL 会自动以 `lty` 登录，并提示输入两次新的 Linux 密码。输入密码时终端不会显示字符，这是正常行为。该密码只用于 Guix/Linux（例如 `sudo`），与 Windows 密码无关。成功后会写入 `/var/lib/guix-wsl/password-set`，后续启动不再提示；若取消或失败，下次登录会再次引导。

仅需临时恢复 `guix` 命令时可运行：

```powershell
wsl -d Guix --cd /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl --exec /bin/sh fix-runtime.sh
```

## 安装开发工具

以 `lty` 登录后执行：

```bash
guix pull
guix package -m /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl/manifest.scm
```

该 manifest 已与先前 Nix WSL 的开发能力及 Gentoo PC 的开发包交叉核对。完整对照与“只属于物理机”的工具边界见 [`../../system_setting/development-parity.md`](../../system_setting/development-parity.md)。

Guix 官方仓库不一定包含 Bun、Dragonwell JDK、CUDA 工具链及部分较新的语言工具。本配置不默认加入第三方 channel，以免混淆系统迁移和信任边界；需要时可再显式添加可信 channel 或使用上游安装方式。

## 手动修复与回滚

如果自动脚本失败，可在 root shell 中依次执行：

```bash
/bin/sh fix-runtime.sh
install -Dm644 system.scm /etc/config.scm
guix-daemon --build-users-group=guixbuild
# 在另一个 root shell 中：
new_system=$(guix system build /etc/config.scm)
# Guix 1.4 的 WSL dummy bootloader 不支持直接 reconfigure；建议优先使用
# install.sh，由它安全创建 generation、激活并在失败时恢复旧 generation。
```

Guix 系统和用户 profile 均保留 generation：

```bash
guix system list-generations
sudo guix system roll-back

guix package --list-generations
guix package --roll-back
```
