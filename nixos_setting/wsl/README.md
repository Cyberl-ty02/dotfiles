# NixOS-WSL 开发环境

这套 flake 只负责 WSL 里的 Linux 用户空间和开发工具。Windows 仍是宿主
系统，WSLg 提供图形兼容，Windows 驱动提供 GPU/CUDA 桥接。默认配置不安装
Linux 桌面、显示管理器、内核、引导器或实体机硬件服务。

语言运行时使用 Nixpkgs 的无版本稳定别名。只有人工执行并审核
`nix flake update` 时，环境才会迁移到新的上游稳定版或 LTS；
`flake.lock` 保证当前 generation 可复现。

## 文件说明

- `install.sh`：把配置安装到 `/etc/nixos`，检查后创建下一启动 generation。
- `flake.nix`、`flake.lock`：上游输入及可复现快照。
- `configuration.nix`：NixOS-WSL、用户、GC、日志和 WSL 集成。
- `development.nix`：CLI、编译器、语言运行时和编辑器工具。
- `cuda.nix`：可选 CUDA 编译/运行时组件。
- `windows_setting/dot_wslconfig`：仓库根目录中的 Windows 侧
  `%UserProfile%\.wslconfig` 模板。

可选 profile：

- `nixos-wsl`：默认开发环境；
- `nixos-wsl-cuda`：增加 CUDA 工具，闭包明显更大。

## Windows 侧准备

先检查并更新 Store 版 WSL：

```powershell
wsl --version
wsl --update
```

把仓库中的 `windows_setting/dot_wslconfig` 复制为：

```text
%UserProfile%\.wslconfig
```

该文件只启用 mirrored networking、DNS tunnel 和 Windows 防火墙/代理
集成，不覆盖 WSL 的内存回收、VHD 或其他实验性默认值。修改后执行：

```powershell
wsl --shutdown
```

`.wslconfig` 对所有 WSL 2 发行版生效。若自定义内核，请确保 kernel 与
kernelModules VHD 的版本完全匹配；不需要自定义内核时保持示例行注释。

## 方式一：全新安装并使用自动脚本

### 1. 导入 NixOS-WSL

下载当前 NixOS-WSL 的 `nixos.wsl` 镜像后，在 PowerShell 中执行：

```powershell
wsl --install --from-file .\nixos.wsl --name NixOS
wsl -d NixOS
```

### 2. 在 WSL 中获取仓库

```bash
cd /tmp
nix --extra-experimental-features 'nix-command flakes' \
  shell github:NixOS/nixpkgs/nixos-unstable#git -c \
  git clone https://github.com/Cyberl-ty02/dotfiles.git
cd dotfiles/nixos_setting/wsl
```

### 3. 运行安装脚本

默认配置：

```bash
sudo ./install.sh nixos-wsl
```

需要 CUDA 开发工具时：

```bash
sudo ./install.sh nixos-wsl-cuda
```

脚本会：

1. 验证参数和 root 权限；
2. 把 flake、锁文件和模块复制到 `/etc/nixos`；
3. 执行 `nixos-rebuild dry-build`；
4. 执行 `nixos-rebuild boot`，只准备下一启动 generation，不立即替换当前
   会话。

使用 `boot` 而不是首次直接 `switch`，是因为官方镜像初始用户通常是
`nixos`，而本配置把默认用户改为 UID 1000 的 `lty`。脚本完成后退出 WSL：

```bash
exit
```

在 PowerShell 中依次执行：

```powershell
wsl --terminate NixOS
wsl -d NixOS --user root -- true
wsl --terminate NixOS
wsl -d NixOS
```

第一次进入 `lty` 的交互式 Zsh 时，系统发现密码仍锁定便会提示运行
`passwd`。输入密码时终端不会回显。也可从 PowerShell 手动设置：

```powershell
wsl -d NixOS --user root -- passwd lty
```

## 方式二：完全手动安装

如果不运行 `install.sh`，可逐项完成同样操作。先在 WSL 中创建目标目录：

```bash
sudo mkdir -p /etc/nixos
sudo cp flake.nix flake.lock configuration.nix \
  development.nix cuda.nix /etc/nixos/
```

检查默认 profile：

```bash
sudo nixos-rebuild dry-build \
  --flake /etc/nixos#nixos-wsl
```

或检查 CUDA profile：

```bash
sudo nixos-rebuild dry-build \
  --flake /etc/nixos#nixos-wsl-cuda
```

确认构建无误后创建下一启动 generation：

```bash
sudo nixos-rebuild boot \
  --flake /etc/nixos#nixos-wsl
```

需要 CUDA 时替换 profile 名。随后退出 WSL，并执行上一节的
terminate/root 启动序列来切换默认用户。不要在第一次用户迁移前省略
dry-build，也不要直接删除原有 generation。

如果已经正常使用 `lty`，日常修改可直接临时测试并切换：

```bash
sudo nixos-rebuild test --flake /etc/nixos#nixos-wsl
sudo nixos-rebuild switch --flake /etc/nixos#nixos-wsl
```

## 空间与写入优化

配置采用以下策略：

- Nix 每周以自带的 `optimise` 任务去重 store，不增加每次构建的扫描负担；
- 每周清理 30 天前的 generation；
- Nix 可用空间低于 5 GiB 时，只收集未被 GC root 引用的对象，目标恢复到
  15 GiB；
- systemd journal 上限为 256 MiB，最多保留 30 天；
- WSL 根盘和虚拟磁盘回收沿用 NixOS-WSL/WSL 自身生成的默认机制，本配置
  不覆盖 fstrim 周期，也不启用实验性 `.wslconfig` 开关。

可用以下命令检查 Linux 侧占用：

```bash
df -h /
nix path-info -Sh /run/current-system
sudo nix-store --gc --print-dead
sudo journalctl --disk-usage
systemctl list-timers nix-gc.timer nix-optimise.timer
```

`nix-store --gc --print-dead` 只列出候选对象，不会删除。需要立即执行与定时
任务相同的保守清理时使用：

```bash
sudo nix-collect-garbage --delete-older-than 30d
```

Windows 上的 `.vhdx` 文件大小可能不会在删除文件后立刻下降；不要直接
使用资源管理器、编辑器或普通文件工具修改 AppData 内的 VHDX。Linux 文件
应通过 `\\wsl.localhost\NixOS\` 访问。

## Bun

配置保留 Bun、移除未使用的 pnpm，不覆盖 Bun 的缓存、linker 或安装
backend，完全采用当前上游默认机制。为了 WSL 的常规小文件性能，日常项目
仍建议放在 Linux 文件系统中，例如：

```bash
mkdir -p ~/source
cd ~/source
git clone <repository>
```

`/mnt/c` 更适合与 Windows 交换文件，不建议承载依赖数量很多的日常项目。
系统不会自动清理或重写 Bun 缓存。

## 日常更新、验证与回滚

在 `/etc/nixos` 中更新整个上游快照：

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild dry-build --flake .#nixos-wsl
sudo nixos-rebuild test --flake .#nixos-wsl
sudo nixos-rebuild switch --flake .#nixos-wsl
```

CUDA 环境使用 `.#nixos-wsl-cuda`。验证常用工具：

```bash
nixos-version
whoami
git --version
gcc --version
rustc --version
python --version
node --version
bun --version
```

若新 generation 有问题：

```bash
sudo nixos-rebuild switch --rollback
```

如果当前用户无法启动，可从 PowerShell 以 root 进入，再检查 generation：

```powershell
wsl -d NixOS --user root
```

```bash
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## 参考资料

- https://github.com/nix-community/NixOS-WSL
- https://nix-community.github.io/NixOS-WSL/install.html
- https://nix-community.github.io/NixOS-WSL/how-to/change-username.html
- https://learn.microsoft.com/windows/wsl/wsl-config
- https://learn.microsoft.com/windows/wsl/disk-space
- https://nixos.org/manual/nixos/stable/
