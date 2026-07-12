# Gentoo laptop profile

Target: `default/linux/amd64/23.0/desktop/plasma`, GCC, OpenRC, SonicDE/XLibre,
NVIDIA, and Secure Boot.

The Gentoo Plasma profile supplies stable Qt/KDE desktop defaults but does not require
`kde-plasma/plasma-meta` to be installed. SonicDE remains the selected desktop because:

- `world_packages.txt` contains `kde-plasma/sonic-meta`;
- `package.mask/plasma` masks the official Plasma desktop/meta packages from `::gentoo`;
- `repos.conf/sonicde.conf` provides the SonicDE packages;
- `package.use/sonicde` selects OpenRC + elogind and disables systemd-only features.

The GCC flags keep Gentoo's normal `-O2 -pipe` baseline and add `-march=native` for
this machine. Global LTO is intentionally left disabled, so package build systems and
the selected profile retain their upstream optimization defaults without an exception
list.

The package mask keeps Gentoo's source and distribution kernels out of the dependency
plan so `sys-kernel/xanmod-kernel` remains the only selected kernel.

## Apply

From `alternative_setting/gentoo/mylaptop`, back up the active configuration
and replace it directly:

```bash
doas cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
doas rsync -a --delete --exclude=make.profile portage/ /etc/portage/
```

## Migrate From An LLVM Stage

Read pending news first, ensure GCC is installed, and select a working GCC version:

```bash
doas emerge --sync
doas eselect news read
doas emerge -av sys-devel/gcc
gcc-config -l
doas gcc-config <gcc-profile-number>
source /etc/profile
gcc --version
```

Switch to the stable GCC/OpenRC Plasma profile:

```bash
doas eselect profile set default/linux/amd64/23.0/desktop/plasma
eselect profile show
```

Review the plan and rebuild the system so packages previously linked against libc++ or
the Clang runtime are rebuilt against the GCC/libstdc++ toolchain:

```bash
doas emerge -pve --with-bdeps=y @world
doas emerge -ave --with-bdeps=y @world
doas emerge -av --depclean
```

For a Secure Boot installation, review `kernel/secureboot/README.md` before copying or
generating keys. Private keys are intentionally not stored in this repository.

For later routine updates:

```bash
doas emerge --sync
doas emerge -pvuDN @world
doas emerge -avuDN @world
```
