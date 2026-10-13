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
doom_remote=https://github.com/doomemacs/core

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
  git clone --depth 1 "$doom_remote" "$doom_emacs"
else
  current_remote=$(git -C "$doom_emacs" remote get-url origin)
  case "$current_remote" in
    https://github.com/doomemacs/core|https://github.com/doomemacs/core.git|git@github.com:doomemacs/core.git)
      ;;
    https://github.com/doomemacs/doomemacs|https://github.com/doomemacs/doomemacs.git|git@github.com:doomemacs/doomemacs.git|https://github.com/hlissner/doom-emacs|https://github.com/hlissner/doom-emacs.git|git@github.com:hlissner/doom-emacs.git)
      git -C "$doom_emacs" remote set-url origin "$doom_remote"
      ;;
    *)
      echo "$doom_emacs uses an unrecognized origin: $current_remote" >&2
      echo "Refusing to replace a possible personal fork." >&2
      exit 1
      ;;
  esac

  if "$upgrade"; then
    "$doom_emacs/bin/doom" upgrade
  fi
fi

"$doom_emacs/bin/doom" sync --env

for file in config.el custom.el init.el packages.el README.md; do
  if ! cmp -s "$doom_source/$file" "$doom_config/$file"; then
    echo "Doom configuration verification failed: $file" >&2
    exit 1
  fi
done

echo "Doom Emacs is synchronized for $target_home"
