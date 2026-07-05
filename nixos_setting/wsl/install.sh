#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/etc/nixos"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

install -d -m 0755 "$TARGET_DIR"

for file in flake.nix flake.lock configuration.nix development.nix cuda.nix; do
  install -m 0644 "${SOURCE_DIR}/${file}" "${TARGET_DIR}/${file}"
done

echo "Installed the NixOS-WSL flake in ${TARGET_DIR}."
echo "Validating the next boot generation..."
nixos-rebuild dry-build --flake "${TARGET_DIR}#nixos-wsl"
nixos-rebuild boot --flake "${TARGET_DIR}#nixos-wsl"

echo
echo "The next boot generation is ready."
echo "Continue with the username migration steps in ${SOURCE_DIR}/README.md."
