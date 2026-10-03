#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: bootstrap-user.sh [--apply]

Preview or apply the repository's portable Gentoo user configuration.
The default is a dry run. --apply remains interactive for existing files.
EOF
}

apply=false
case "${1:-}" in
  "") ;;
  --apply) apply=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi is not installed; no files were changed" >&2
  exit 1
fi

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

if "$apply"; then
  exec chezmoi --source "$repo_root" --interactive --verbose apply
fi

echo "Dry run only. Re-run with --apply after reviewing this output." >&2
exec chezmoi --source "$repo_root" --dry-run --verbose apply
