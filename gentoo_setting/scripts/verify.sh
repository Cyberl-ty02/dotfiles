#!/bin/sh
set -eu

usage() {
  echo "Usage: verify.sh [pc|wsl]" >&2
}

role=${1:-pc}
case "$role" in
  pc|wsl) ;;
  *) usage; exit 2 ;;
esac

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
settings="$repo_root/gentoo_setting"

check_sorted() {
  LC_ALL=C sort -c "$1"
}

echo "Checking shell syntax"
sh -n "$settings/scripts/bootstrap-user.sh"
sh -n "$settings/scripts/sync-vscodium.sh"
sh -n "$settings/scripts/verify.sh"
bash -n "$repo_root/dot_bashrc"
zsh -n "$repo_root/dot_zshrc"

echo "Checking sorted package lists"
check_sorted "$settings/pc/world_packages.txt"
check_sorted "$settings/wsl/world_packages.txt"
for manifest in "$settings"/manifests/*.txt; do
  check_sorted "$manifest"
done
for manifest in "$repo_root"/vscodium/extensions-*.txt; do
  check_sorted "$manifest"
done

echo "Checking JSON configuration"
python3 -m json.tool \
  "$repo_root/dot_config/private_VSCodium/User/settings.json" >/dev/null
python3 -m json.tool \
  "$repo_root/windows_setting/AppData/Roaming/VSCodium/User/settings.json" \
  >/dev/null

echo "Checking package atoms with Portage"
python3 - "$settings" <<'PY'
from pathlib import Path
import sys

from portage.dep import Atom

root = Path(sys.argv[1])
paths = [root / "pc/world_packages.txt", root / "wsl/world_packages.txt"]
paths.extend(sorted((root / "manifests").glob("*.txt")))
for path in paths:
    for line_number, raw_line in enumerate(path.read_text().splitlines(), 1):
        atom = raw_line.strip()
        if atom and not atom.startswith("#"):
            try:
                Atom(atom)
            except Exception as error:
                raise SystemExit(f"{path}:{line_number}: {error}") from error
PY

echo "Checking doas syntax"
doas -C "$repo_root/doas_dot_conf"

echo "Previewing chezmoi changes (no files are written)"
# A managed target may have changed since chezmoi last wrote it.  In a
# non-interactive dry run, allow the preview to choose the source version so
# chezmoi does not stop at its overwrite prompt with EOF.
chezmoi --source "$repo_root" --dry-run --no-tty apply --force >/dev/null

if [ "$role" = pc ] && [ -r /var/lib/portage/world ]; then
  echo "Comparing the live PC world file"
  if ! cmp -s /var/lib/portage/world "$settings/pc/world_packages.txt"; then
    echo "warning: live world differs from pc/world_packages.txt" >&2
  fi
fi

echo "Verification completed for role: $role"
