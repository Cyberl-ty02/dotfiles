#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ROOT="${TARGET_ROOT:-/mnt}"
PROFILE="${1:-pc}"
TARGET_CONFIG="${TARGET_ROOT}/etc/nixos"
GENERATED_CONFIG="${TARGET_CONFIG}/hardware-configuration.nix"
SECURE_BOOT_REQUESTED=false
STORAGE_HELPER_USED=false

case "$PROFILE" in
pc | pc-nvidia | pc-nvidia-cuda) ;;
*)
  echo "Usage: sudo $0 [pc|pc-nvidia|pc-nvidia-cuda]" >&2
  exit 2
  ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 [$PROFILE]" >&2
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo "The installer was not booted in UEFI mode." >&2
  exit 1
fi

read -r -p \
  "Open the interactive FAT/Btrfs storage preparation helper? [y/N] " \
  USE_BTRFS
if [[ "$USE_BTRFS" =~ ^[Yy]$ ]]; then
  STORAGE_HELPER_USED=true
  bash "${SOURCE_DIR}/prepare-btrfs.sh"
fi

if ! findmnt --mountpoint "$TARGET_ROOT" >/dev/null; then
  if [[ "$STORAGE_HELPER_USED" == true ]]; then
    echo "No target filesystem is mounted. Stopping before installation."
    echo "Review the partition table and rerun this script when ready."
    exit 0
  fi
  echo "$TARGET_ROOT is not a mounted target root." >&2
  exit 1
fi

if ! findmnt --mountpoint "${TARGET_ROOT}/boot" >/dev/null; then
  echo "${TARGET_ROOT}/boot is not a mounted EFI System Partition." >&2
  exit 1
fi

echo
echo "Proposed installation mounts:"
findmnt -R "$TARGET_ROOT"
read -r -p "Continue from mounted filesystems to NixOS installation? [y/N] " \
  CONTINUE_INSTALL
if [[ ! "$CONTINUE_INSTALL" =~ ^[Yy]$ ]]; then
  echo "Stopping before NixOS installation; mounted filesystems are unchanged."
  exit 0
fi

read -r -p \
  "Prepare optional Lanzaboote Secure Boot steps after first boot? [y/N] " \
  USE_SECURE_BOOT
if [[ "$USE_SECURE_BOOT" =~ ^[Yy]$ ]]; then
  SECURE_BOOT_REQUESTED=true
fi

echo "Generating hardware configuration for the mounted target..."
nixos-generate-config --root "$TARGET_ROOT"

# The repository contains an intentionally unusable placeholder. Replace it in
# this installation checkout with facts detected from the target machine.
install -m 0644 "$GENERATED_CONFIG" "${SOURCE_DIR}/hardware-configuration.nix"

echo "Checking profile ${PROFILE}..."
nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build "path:${SOURCE_DIR}"

echo "Installing NixOS profile ${PROFILE}..."
nixos-install \
  --root "$TARGET_ROOT" \
  --flake "path:${SOURCE_DIR}#${PROFILE}" \
  --no-root-passwd

install -d -m 0755 "$TARGET_CONFIG"
for file in \
  flake.nix flake.lock configuration.nix development.nix desktop.nix \
  nvidia.nix cuda.nix secureboot.nix hardware-configuration.nix; do
  install -m 0644 "${SOURCE_DIR}/${file}" "${TARGET_CONFIG}/${file}"
done
for script in install.sh prepare-btrfs.sh enable-secureboot.sh; do
  install -m 0755 "${SOURCE_DIR}/${script}" "${TARGET_CONFIG}/${script}"
done

echo
echo "Set the login password for lty before rebooting:"
nixos-enter --root "$TARGET_ROOT" -c "passwd lty"

echo
echo "Installation complete. Review ${TARGET_CONFIG}, then reboot."

if [[ "$SECURE_BOOT_REQUESTED" == true ]]; then
  echo
  echo "After one successful normal systemd-boot startup, run:"
  echo "  sudo /etc/nixos/enable-secureboot.sh ${PROFILE}"
fi
