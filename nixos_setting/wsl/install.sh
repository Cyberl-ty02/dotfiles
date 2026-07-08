#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/etc/nixos"
PROFILE="${1:-nixos-wsl}"

case "$PROFILE" in
nixos-wsl | nixos-wsl-cuda) ;;
*)
  echo "用法 / Usage: sudo $0 [nixos-wsl|nixos-wsl-cuda]" >&2
  exit 2
  ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "请使用 root 运行 / Run as root: sudo $0 [$PROFILE]" >&2
  exit 1
fi

install -d -m 0755 "$TARGET_DIR"

for file in flake.nix flake.lock configuration.nix development.nix cuda.nix; do
  install -m 0644 "${SOURCE_DIR}/${file}" "${TARGET_DIR}/${file}"
done

echo "已复制 NixOS-WSL flake 到 ${TARGET_DIR}。"
echo "正在验证并创建 ${PROFILE} 的下一启动 generation..."
nixos-rebuild dry-build --flake "${TARGET_DIR}#${PROFILE}"
nixos-rebuild boot --flake "${TARGET_DIR}#${PROFILE}"

echo
echo "下一启动 generation 已准备好。"
echo "请继续阅读 ${SOURCE_DIR}/README.md 中的用户切换步骤。"
