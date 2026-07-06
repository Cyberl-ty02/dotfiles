#!/usr/bin/env bash
set -euo pipefail

BASE_PROFILE="${1:-pc}"

case "$BASE_PROFILE" in
pc | pc-nvidia | pc-nvidia-cuda)
  SECURE_PROFILE="${BASE_PROFILE}-secureboot"
  ;;
*)
  echo "Usage: sudo $0 [pc|pc-nvidia|pc-nvidia-cuda]" >&2
  exit 2
  ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 [$BASE_PROFILE]" >&2
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo "This system was not booted in UEFI mode." >&2
  exit 1
fi

if ! bootctl is-installed; then
  echo "First boot normally with systemd-boot before enabling Lanzaboote." >&2
  exit 1
fi

bootctl status
echo
echo "This prepares Lanzaboote and creates private keys in /var/lib/sbctl."
echo "It does not enroll keys or change firmware Setup Mode automatically."
read -r -p "Type 'PREPARE SECURE BOOT' to continue: " ANSWER
if [[ "$ANSWER" != "PREPARE SECURE BOOT" ]]; then
  echo "Confirmation did not match; no changes made."
  exit 1
fi

if [[ ! -d /var/lib/sbctl/keys ]]; then
  sbctl create-keys
else
  echo "Existing sbctl keys found; they will be reused."
fi

nixos-rebuild switch --flake "/etc/nixos#${SECURE_PROFILE}"
sbctl verify

echo
echo "Lanzaboote is prepared, but Secure Boot is not enrolled yet."
echo "Next:"
echo "  1. Reboot into firmware settings and enter Secure Boot Setup Mode."
echo "  2. Boot NixOS again with Secure Boot enforcement still disabled."
echo "  3. Run: sudo sbctl enroll-keys --microsoft"
echo "  4. Reboot and verify with: bootctl status"
