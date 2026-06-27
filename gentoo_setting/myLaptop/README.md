# Gentoo laptop profile

Target: amd64, OpenRC, LLVM-oriented userland, SonicDE/XLibre, NVIDIA, and Secure Boot.
Package-specific GCC environments are retained for software that is not reliable with the
main LLVM toolchain.

## Apply

From `gentoo_setting/myLaptop`, back up the active configuration and replace it directly:

```bash
doas cp -a /etc/portage "/root/portage-backup-$(date +%Y%m%d-%H%M%S)"
doas rsync -a --delete --exclude=make.profile portage/ /etc/portage/
```

For a Secure Boot installation, review `kernel/secureboot/README.md` before copying or
generating keys. Private keys are intentionally not stored in this repository.

Then review the dependency plan before rebuilding:

```bash
doas emerge --sync
doas emerge -pvuDN @world
doas emerge -avuDN @world
```
