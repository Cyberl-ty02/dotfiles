#!/usr/bin/env bash
set -euo pipefail

CER="/etc/kernel/secureboot/MOK.cer"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [[ ! -r "$CER" ]]; then
  echo "$CER not found. Run /etc/kernel/secureboot/generate_mok.sh first." >&2
  exit 1
fi

mokutil --import "$CER"
echo "Reboot and enroll the key in MOK Manager."
