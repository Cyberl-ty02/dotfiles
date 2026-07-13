#!/usr/bin/env bash
set -euo pipefail

ESP="/boot"
EFI_DIR="${ESP}/EFI/Gentoo"
SHIM="/usr/share/shim/BOOTX64.EFI"
MOK_MANAGER="/usr/share/shim/mmx64.efi"
GRUB="/usr/lib/grub/grub-x86_64.efi.signed"
GRUB_CFG="${EFI_DIR}/grub.cfg"
ENV_TEMPLATE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/99grub"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if ! mountpoint -q "$ESP"; then
  echo "$ESP is not mounted; refusing to write to the root filesystem." >&2
  exit 1
fi

for file in "$SHIM" "$MOK_MANAGER" "$GRUB" "$ENV_TEMPLATE"; do
  if [[ ! -r "$file" ]]; then
    echo "$file not found/readable. Install or rebuild GRUB and shim first." >&2
    exit 1
  fi
done

install -d -m 0755 "$EFI_DIR"
install -m 0644 "$SHIM" "${EFI_DIR}/shimx64.efi"
install -m 0644 "$MOK_MANAGER" "${EFI_DIR}/mmx64.efi"
install -m 0644 "$GRUB" "${EFI_DIR}/grubx64.efi"
install -m 0644 "$ENV_TEMPLATE" /etc/env.d/99grub

grub-mkconfig -o "$GRUB_CFG"

if command -v sbverify >/dev/null; then
  sbverify --list "${EFI_DIR}/shimx64.efi"
  sbverify --list "${EFI_DIR}/grubx64.efi"
fi

echo
echo "Installed shim, MokManager, signed GRUB, and grub.cfg in $EFI_DIR"
echo "Run env-update, then create or verify a UEFI entry for:"
echo '  \EFI\Gentoo\shimx64.efi'
