#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

mkdir -p /etc/portage
if [[ -e /etc/portage ]]; then
  tar -C /etc -czf "/root/portage-backup-wsl-${STAMP}.tar.gz" portage
  echo "Backed up /etc/portage to /root/portage-backup-wsl-${STAMP}.tar.gz"
fi

rsync -a "${SRC_DIR}/wsl/etc/portage/" /etc/portage/
cp -v "${SRC_DIR}/wsl/etc/wsl.conf" /etc/wsl.conf

echo "Done. Next suggested checks:"
echo "  eselect profile show"
echo "  ${SRC_DIR}/wsl/scripts/check_multilib.sh"
echo "Then from PowerShell after edits: wsl --shutdown"
