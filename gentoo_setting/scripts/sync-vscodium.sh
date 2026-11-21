#!/bin/sh
# Preview by default; only explicit --apply changes extensions.
set -eu
export LC_ALL=C
apply=false
case "${1:-}" in
  "") ;;
  --apply) apply=true ;;
  -h|--help) echo "Usage: sync-vscodium.sh [--apply]"; exit 0 ;;
  *) echo "Usage: sync-vscodium.sh [--apply]" >&2; exit 2 ;;
esac
command -v codium >/dev/null 2>&1 || { echo "VSCodium is not installed" >&2; exit 1; }
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
manifest() {
  awk '/^[A-Za-z0-9_-]+[.][A-Za-z0-9_.-]+$/ {print tolower($0)}' "$@" | LC_ALL=C sort -u
}
refresh() {
  codium --list-extensions >"$work/cli-list" || return $?
  manifest "$work/cli-list" >"$work/installed"
}
manifest "$repo_root/vscodium/extensions-common.txt" "$repo_root/vscodium/extensions-linux.txt" >"$work/wanted"
manifest "$repo_root/vscodium/extensions-excluded.txt" "$repo_root/vscodium/extensions-windows.txt" >"$work/excluded"
if [ -n "$(comm -12 "$work/wanted" "$work/excluded")" ]; then
  echo "Conflicting desired and excluded extension IDs" >&2; exit 1
fi
refresh
comm -12 "$work/excluded" "$work/installed" >"$work/pending"
if "$apply"; then
  # Removing a pack can also remove its members. Refresh the index and restore
  # the desired flat manifest afterwards; do not assume the old index is valid.
  while [ -s "$work/pending" ]; do
    cp "$work/pending" "$work/previous"
    while IFS= read -r extension; do
      refresh
      grep -Fqx "$extension" "$work/installed" || continue
      echo "Removing replaced extension: $extension"
      if ! codium --uninstall-extension "$extension" >"$work/last-removal" 2>&1; then
        : # A dependent may be removed later in this pass; retry only on progress.
      fi
    done <"$work/previous"
    refresh
    comm -12 "$work/excluded" "$work/installed" >"$work/pending"
    if cmp -s "$work/previous" "$work/pending"; then
      cat "$work/last-removal" >&2
      echo "Excluded extensions still have dependents; review before continuing" >&2
      exit 1
    fi
  done
else
  while IFS= read -r extension; do echo "Would remove replaced extension: $extension"; done <"$work/pending"
fi
refresh
comm -23 "$work/wanted" "$work/installed" >"$work/missing"
while IFS= read -r extension; do
  if "$apply"; then
    echo "Installing: $extension"
    codium --install-extension "$extension" --do-not-include-pack-dependencies
  else
    echo "Would install: $extension"
  fi
done <"$work/missing"
if "$apply"; then
  refresh
  [ -z "$(comm -23 "$work/wanted" "$work/installed")" ] || { echo "Missing desired extensions" >&2; exit 1; }
  [ -z "$(comm -12 "$work/excluded" "$work/installed")" ] || { echo "Excluded dependency reinstalled" >&2; exit 1; }
  echo "Extension manifest verified. Existing editor windows may require a normal restart."
else
  echo "Preview only. Re-run with --apply to synchronize." >&2
fi
