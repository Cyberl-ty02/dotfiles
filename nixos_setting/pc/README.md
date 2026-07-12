# NixOS 实体 PC / 笔记本配置

这套 flake 用于实体机器，包含 Plasma 6、Wayland、NetworkManager、
PipeWire、打印、蓝牙、常用桌面程序和完整开发工具链。默认使用 zram，
不创建磁盘 swap。语言运行时使用 Nixpkgs 的无版本稳定别名，因此可在
人工审核 `flake.lock` 更新时迁移到新的上游稳定版或 LTS，而不是在配置中
锁死某个大版本。

## 先读：哪些文件可以直接使用

- `install.sh`：安装总控脚本；可选择是否调用磁盘脚本。
- `prepare-btrfs.sh`：交互式分区、格式化、创建子卷和挂载工具。
- `configuration.nix`：实体机基础配置。
- `development.nix`：两套环境共享思路的开发工具。
- `desktop.nix`：Plasma、硬件维护和 TRIM。
- `hardware-configuration.nix`：仅为可求值模板，**不能直接安装**。
- `nvidia.nix`、`cuda.nix`：可选 NVIDIA/CUDA 模块。
- `enable-secureboot.sh`、`secureboot.nix`：首次正常启动后使用的
  Secure Boot 工具。

安装前必须备份重要数据，并从 UEFI 模式启动官方 NixOS 安装介质。任何
分区操作都可能因选错磁盘、断电或固件问题造成数据丢失。

## 配置档选择

- `pc`：默认开源图形栈。
- `pc-nvidia`：Nixpkgs NVIDIA 驱动。
- `pc-nvidia-cuda`：NVIDIA 驱动及 CUDA 开发组件。
- 首次正常启动并完成密钥准备后，可使用对应的 `-secureboot` 配置。

混合 Intel/NVIDIA 笔记本应先根据实际硬件填写 `nvidia.nix` 中的 PRIME
总线 ID；通用 NVIDIA 配置只假设单显卡或由固件管理的显卡切换。

## 方式一：使用自动安装脚本

### 1. 获取仓库

在 NixOS 安装介质中执行：

```bash
cd /tmp
nix --extra-experimental-features 'nix-command flakes' \
  shell github:NixOS/nixpkgs/nixos-unstable#git -c \
  git clone https://github.com/Cyberl-ty02/dotfiles.git
cd dotfiles/nixos_setting/pc
```

### 2. 运行总控脚本

按机器选择一个配置：

```bash
sudo ./install.sh pc
# NVIDIA：
sudo ./install.sh pc-nvidia
# NVIDIA + CUDA：
sudo ./install.sh pc-nvidia-cuda
```

脚本的关键操作都有独立确认，并且默认回答均为“否”：

1. 是否进入 `prepare-btrfs.sh`；
2. 是否接受已经挂载到 `/mnt` 的布局并开始安装；
3. 是否在首次启动后准备 Lanzaboote Secure Boot 流程。

如果选择磁盘助手，它会先列出实体磁盘和未分配空间，再要求输入完整确认
短语。它不会缩小已有分区，也不会把非空 Btrfs 文件系统解释成新布局。
新建并格式化后还必须再次输入 `MOUNT NEW` 才会创建子卷和挂载。

确认安装后，`install.sh` 会：

1. 检查 UEFI、`/mnt` 和 `/mnt/boot`；
2. 用 `nixos-generate-config` 生成本机硬件配置；
3. 将生成结果替换当前安装副本中的模板；
4. 执行 `nix flake check --no-build`；
5. 用所选 profile 调用 `nixos-install`；
6. 把可独立使用的配置和脚本复制到 `/mnt/etc/nixos`；
7. 在重启前要求设置 `lty` 的本地密码。

安装结束后检查 `/mnt/etc/nixos`，确认硬件文件、挂载点和用户设置无误，
再执行：

```bash
reboot
```

## `prepare-btrfs.sh` 的两种工作流

### 工作流 1：使用任意未分配空间

脚本允许从目标 GPT 磁盘的任意一段未分配空间开始：

- `NIXOS_BOOT`：FAT32 EFI System Partition，默认 1024 MiB，最低 512 MiB；
- `NIXOS_ROOT`：Btrfs，默认使用剩余空间，也可指定大小；
- `SHARED_DATA`：可选的未格式化分区，应稍后在 Windows 或 GParted 中
  格式化为 NTFS。

分区号在已有 Windows 磁盘上可能不是连续的，因此应以 PARTLABEL 和物理
起始位置为准，不要假定 Linux 一定安装在 `p1`、`p2` 或 `p3`。

### 工作流 2：复用 GParted 创建的分区

先准备同一磁盘上的两个未挂载分区：

- 一个 FAT EFI System Partition；
- 一个不同的 Btrfs Linux 分区。

脚本会验证文件系统、父磁盘和 ESP 标志，并以只读方式展示 FAT 分区内容。
Btrfs 顶层必须为空，或只包含以下真实子卷：

```text
@
@home
@nix
@log
@snapshots
```

任何额外文件、缺失子卷或同名普通目录都会使脚本停止，不会自动覆盖。

## 方式二：完全手动安装

如果不希望脚本修改磁盘，可使用 GParted、`parted` 或其他工具自行完成
分区。下面假设 ESP 为 `/dev/nvme0n1p1`，Btrfs 为
`/dev/nvme0n1p2`；必须替换成实际设备。

### 1. 创建并挂载 Btrfs 布局

```bash
sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt
for subvol in @ @home @nix @log @snapshots; do
  sudo btrfs subvolume create "/mnt/$subvol"
done
sudo umount /mnt

sudo mount -o subvol=@,compress=zstd:3,noatime \
  /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/{boot,home,nix,var/log,.snapshots}
sudo mount -o subvol=@home,compress=zstd:3,noatime \
  /dev/nvme0n1p2 /mnt/home
sudo mount -o subvol=@nix,compress=zstd:3,noatime \
  /dev/nvme0n1p2 /mnt/nix
sudo mount -o subvol=@log,compress=zstd:3,noatime \
  /dev/nvme0n1p2 /mnt/var/log
sudo mount -o subvol=@snapshots,compress=zstd:3,noatime \
  /dev/nvme0n1p2 /mnt/.snapshots
sudo mount /dev/nvme0n1p1 /mnt/boot
findmnt -R /mnt
```

这里不使用持续 `discard`、`autodefrag`、`nodatacow` 或超长 `commit=`：
每周批量 TRIM 的写路径更简单；`nodatacow` 会失去压缩和数据校验；
自动碎片整理与过长提交周期分别可能增加写放大和断电后的时间戳/元数据
损失窗口。

### 2. 生成硬件配置

```bash
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
  ./hardware-configuration.nix
```

务必人工检查文件系统 UUID/标签、CPU 微码、存储驱动和显卡信息。仓库原有
模板中的 `NIXOS_ROOT_REPLACE_ME` 和 `NIXOS_ESP_REPLACE_ME` 不能出现在
真正安装中。

### 3. 检查并安装

```bash
nix --extra-experimental-features 'nix-command flakes' \
  flake check --no-build path:.
sudo nixos-install --root /mnt --flake path:.#pc --no-root-passwd
```

NVIDIA 机器将最后的 `#pc` 换为 `#pc-nvidia` 或
`#pc-nvidia-cuda`。随后复制配置并设置密码：

```bash
sudo mkdir -p /mnt/etc/nixos
sudo cp flake.nix flake.lock configuration.nix development.nix \
  desktop.nix nvidia.nix cuda.nix secureboot.nix \
  hardware-configuration.nix /mnt/etc/nixos/
sudo cp install.sh prepare-btrfs.sh enable-secureboot.sh /mnt/etc/nixos/
sudo nixos-enter --root /mnt -c 'passwd lty'
```

确认无误后重启。

## 空间、写入与存储维护

当前配置采用以下保守策略：

- Btrfs 使用 `compress=zstd:3,noatime`，减少占用和读操作触发的写入；
- PC 使用 NixOS/util-linux 默认的批量 TRIM 计划；
- Nix 每周以自带的 `optimise` 任务去重 store，不增加每次构建的扫描负担；
- 每周清理 30 天前的 Nix generation；
- Nix 可用空间低于 5 GiB 时只清理未引用对象，目标恢复到 15 GiB；
- systemd journal 最多使用 512 MiB，并保留不超过 30 天；
- zram 代替磁盘 swap，减少 SSD 写入。

可以检查定时任务：

```bash
systemctl list-timers nix-gc.timer nix-optimise.timer fstrim.timer
sudo journalctl --disk-usage
```

不要把自动 Btrfs balance 当作日常清理；它会重写大量块。只有在
`btrfs filesystem usage /` 显示明显的块组分配问题时，才应备份后人工使用
带有限制条件的 balance。

`/nix` 是独立子卷。Btrfs 根快照不会被 Nix GC 删除，但根快照也不包含
对应的 Nix store。应把可启动快照保留期限制在 30 天 generation 窗口内；
需要长期保留的快照必须另外为其 store closure 建立 GC root。

## Bun

配置保留 Bun、移除未使用的 pnpm，不覆盖 Bun 的缓存、linker 或安装
backend。包管理行为完全采用当前上游默认值，项目如有特殊需求应在项目内
自行配置。

## Secure Boot

首次安装不要直接选择 `-secureboot` profile。先用普通 systemd-boot
成功启动一次，然后运行：

```bash
sudo /etc/nixos/enable-secureboot.sh pc
# 或 pc-nvidia / pc-nvidia-cuda
```

脚本会检查 UEFI/systemd-boot，要求输入 `PREPARE SECURE BOOT`，在
`/var/lib/sbctl` 创建本机密钥，并切换到对应 Lanzaboote profile。它不会
修改固件状态或自动注册密钥。根据主板文档进入 Setup Mode 后执行：

```bash
sudo sbctl enroll-keys --microsoft
```

保留安装介质和 Windows BitLocker 恢复密钥。固件信任状态变化可能触发
BitLocker 恢复，也可能因主板实现差异导致暂时无法启动。

## 更新、验证和回滚

先构建和临时测试，再切换：

```bash
cd /etc/nixos
nix flake check
sudo nixos-rebuild build --flake .#pc
sudo nixos-rebuild test --flake .#pc
sudo nixos-rebuild switch --flake .#pc
```

更新整个上游快照：

```bash
nix flake update
sudo nixos-rebuild build --flake .#pc
sudo nixos-rebuild test --flake .#pc
sudo nixos-rebuild switch --flake .#pc
```

如果新 generation 有问题，可从 systemd-boot 选择旧 generation，或在
仍可登录时执行：

```bash
sudo nixos-rebuild switch --rollback
```

## 参考资料

- https://nixos.org/manual/nixos/stable/
- https://wiki.nixos.org/wiki/NixOS_system_configuration
- https://wiki.nixos.org/wiki/Dual_Booting_NixOS_and_Windows
- https://wiki.nixos.org/wiki/Systemd/boot
- https://nix-community.github.io/lanzaboote/
- https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html
