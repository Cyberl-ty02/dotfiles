#!/usr/bin/env bash
set -euo pipefail

ESP="/boot"
EFI_DIR="${ESP}/EFI/refind"
SHIM="/usr/share/shim/BOOTX64.EFI"
MOK_MANAGER="/usr/share/shim/mmx64.efi"
REFIND="/usr/lib64/refind/refind/refind_x64.efi"
KEY="/etc/kernel/secureboot/MOK.pem"
SIGNED_REFIND="${EFI_DIR}/grubx64.efi"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if ! mountpoint -q "$ESP"; then
  echo "$ESP is not mounted; refusing to write to the root filesystem." >&2
  exit 1
fi

for file in "$SHIM" "$MOK_MANAGER" "$REFIND" "$KEY"; do
  if [[ ! -r "$file" ]]; then
    echo "$file not found/readable. Install rEFInd and shim, then generate the MOK first." >&2
    exit 1
  fi
done

install -d -m 0755 "$EFI_DIR"
install -m 0644 "$SHIM" "${EFI_DIR}/BOOTX64.EFI"
install -m 0644 "$MOK_MANAGER" "${EFI_DIR}/mmx64.efi"

# Shim looks for a sibling named grubx64.efi. The signed payload written here
# is rEFInd; the compatibility filename does not imply a GRUB dependency.
sbsign --key "$KEY" --cert "$KEY" --output "$SIGNED_REFIND" "$REFIND"

if command -v sbverify >/dev/null; then
  sbverify --list "${EFI_DIR}/BOOTX64.EFI"
  sbverify --list "$SIGNED_REFIND"
fi

echo
echo "Installed shim, MokManager, and signed rEFInd in $EFI_DIR"
echo "Create or verify a UEFI entry for:"
echo '  \EFI\refind\BOOTX64.EFI'
