# Guix WSL 配置

本目录提供 Guix WSL 开发环境。物理 PC 继续使用 Gentoo；统一入口见 [`../../system_setting/README.md`](../../system_setting/README.md)。

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
wsl -d Guix -u root --cd /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl --exec /var/guix/profiles/system/profile/bin/bash install.sh
wsl --terminate Guix
wsl -d Guix
```

重新进入后，WSL 会自动以 `lty` 登录，并提示输入两次新的 Linux 密码。输入密码时终端不会显示字符，这是正常行为。该密码只用于 Guix/Linux（例如 `sudo`），与 Windows 密码无关。成功后会写入 `/var/lib/guix-wsl/password-set`，后续启动不再提示；若取消或失败，下次登录会再次引导。

仅需临时恢复 `guix` 命令时可运行：

```powershell
wsl -d Guix -u root --cd /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl --exec /var/guix/profiles/system/profile/bin/bash fix-runtime.sh
```

## 安装开发工具

以 `lty` 登录后执行：

```bash
guix pull
guix package -m /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl/manifest.scm
```

该 manifest 已与 Gentoo PC 的开发包交叉核对。完整对照与“只属于物理机”的工具边界见 [`../../system_setting/development-parity.md`](../../system_setting/development-parity.md)。

## VS Code Remote WSL

配置把 WSL 默认用户设为 `lty`，并为 Remote WSL 使用的非登录 `sh -c` 注入 Guix profile PATH。WSL 启动时会在后台启动 Shepherd 与 `guix-daemon`；普通用户 shell 最多等待 daemon 30 秒，以避免首次连接竞态，但 daemon 故障不会永久阻止 shell。

如果 Remote WSL 曾缓存失败状态，先在 Windows 运行：

```powershell
wsl --terminate Guix
```

然后重新执行“连接到 WSL”。可用与扩展相同的探测方式验证：

```powershell
wsl -d Guix -e sh -c "id; uname -m; command -v tar; command -v curl"
```

预期用户为 `lty`，工具路径位于 `/run/current-system/profile/bin`。启动日志保存在 `/var/log/guix-wsl-boot.log`。

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
