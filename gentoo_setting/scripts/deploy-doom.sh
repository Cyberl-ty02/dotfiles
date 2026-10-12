#!/bin/sh
set -eu

usage() {
  echo "usage: $0 [--root] [--upgrade]" >&2
  exit 2
}

target_root=false
upgrade=false
for argument in "$@"; do
  case "$argument" in
    --root) target_root=true ;;
    --upgrade) upgrade=true ;;
    *) usage ;;
  esac
done

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
doom_source="$repo_root/dot_config/doom"

if "$target_root" && [ "$(id -u)" -ne 0 ]; then
  if "$upgrade"; then
    exec doas "$0" --root --upgrade
  fi
  exec doas "$0" --root
fi

if "$target_root"; then
  target_home=/root
  config_home=/root/.config
else
  target_home=${HOME:?HOME is not set}
  config_home=${XDG_CONFIG_HOME:-"$target_home/.config"}
fi

doom_config="$config_home/doom"
doom_emacs="$config_home/emacs"

install -d -m 0755 "$doom_config"
for file in config.el custom.el init.el packages.el README.md; do
  install -m 0644 "$doom_source/$file" "$doom_config/$file"
done

if [ ! -d "$doom_emacs/.git" ]; then
  if [ -e "$doom_emacs" ]; then
    echo "$doom_emacs exists but is not a Git checkout; refusing to replace it" >&2
    exit 1
  fi
  git clone --depth 1 https://github.com/doomemacs/doomemacs "$doom_emacs"
elif "$upgrade"; then
  "$doom_emacs/bin/doom" upgrade
fi

"$doom_emacs/bin/doom" sync --env

echo "Doom Emacs is synchronized for $target_home"
