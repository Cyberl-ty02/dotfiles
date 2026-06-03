#!/usr/bin/env bash
set -euo pipefail

KEY="/etc/kernel/secureboot/MOK.pem"
EFI="/boot/efi/EFI/gentoo/grubx64.efi"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [[ ! -r "$KEY" ]]; then
  echo "$KEY not found/readable. Generate it first." >&2
  exit 1
fi

if [[ ! -f "$EFI" ]]; then
  echo "$EFI not found. Edit this script if your GRUB EFI path differs." >&2
  exit 1
fi

cp -av "$EFI" "${EFI}.unsigned.$(date +%Y%m%d-%H%M%S)"
sbsign --cert "$KEY" --key "$KEY" --output "${EFI}.signed" "$EFI"
mv -v "${EFI}.signed" "$EFI"
sbverify --list "$EFI" || true
