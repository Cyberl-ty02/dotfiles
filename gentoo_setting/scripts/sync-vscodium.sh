#!/bin/sh
set -eu

usage() {
  echo "Usage: sync-vscodium.sh [--apply]" >&2
}

apply=false
case "${1:-}" in
  "") ;;
  --apply) apply=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac

if ! command -v codium >/dev/null 2>&1; then
  echo "VSCodium is not installed; no extensions were changed" >&2
  exit 1
fi

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
installed=$(mktemp)
trap 'rm -f "$installed"' EXIT HUP INT TERM
codium --list-extensions | LC_ALL=C sort -u >"$installed"

sync_manifest() {
  while IFS= read -r extension; do
    case "$extension" in
      ""|\#*) continue ;;
    esac
    if grep -Fqx "$extension" "$installed"; then
      continue
    fi
    if "$apply"; then
      echo "Installing $extension"
      codium --install-extension "$extension"
    else
      echo "Would install $extension"
    fi
  done <"$1"
}

sync_manifest "$repo_root/vscodium/extensions-common.txt"
sync_manifest "$repo_root/vscodium/extensions-linux.txt"

for extension in zokugun.sync-settings zokugun.cron-tasks; do
  if ! grep -Fqx "$extension" "$installed"; then
    continue
  fi
  if "$apply"; then
    echo "Removing redundant $extension"
    codium --uninstall-extension "$extension"
  else
    echo "Would remove redundant $extension"
  fi
done

if ! "$apply"; then
  echo "Dry run only. Re-run with --apply after reviewing this output." >&2
fi
