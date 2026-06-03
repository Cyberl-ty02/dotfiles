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
  tar -C /etc -czf "/root/portage-backup-laptop-${STAMP}.tar.gz" portage
  echo "Backed up /etc/portage to /root/portage-backup-laptop-${STAMP}.tar.gz"
fi

rsync -a "${SRC_DIR}/laptop/etc/portage/" /etc/portage/
rsync -a "${SRC_DIR}/laptop/etc/kernel/secureboot/" /etc/kernel/secureboot/
chmod +x /etc/kernel/secureboot/*.sh 2>/dev/null || true

echo "Done. Next suggested checks:"
echo "  emerge --info | less"
echo "  eselect profile show"
echo "  emerge -pv sys-kernel/xanmod-kernel kde-plasma/sonic-meta x11-drivers/nvidia-drivers"
echo "If using Secure Boot, generate/enroll keys before emerging signed kernels/modules."
