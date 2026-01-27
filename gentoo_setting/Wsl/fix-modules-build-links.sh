#!/usr/bin/envS /bin/bash

# Put follwing lines and the head
# into /usr/local/sbin/fix-modules-build-links.sh

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

log() { echo "[fix-build] $*"; }
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY: $*"
  else
    eval "$@"
  fi
}

# 如果已有 /usr/src/linux-<kver>，我们就把 build 目录挪过去；
# 如果没有，就创建 /usr/src/linux-<kver> 并挪过去。
# 最后把 /lib/modules/<kver>/build 改为指向 /usr/src/linux-<kver> 的 symlink。

shopt -s nullglob
for moddir in /lib/modules/*; do
  [[ -d "$moddir" ]] || continue
  kver="$(basename "$moddir")"
  build="$moddir/build"

  [[ -e "$build" ]] || continue

  # 只修“build 是目录且不是 symlink”的异常情况
  if [[ -d "$build" && ! -L "$build" ]]; then
    target="/usr/src/linux-$kver"

    log "FOUND non-symlink build dir: $build"

    if [[ -e "$target" && ! -d "$target" ]]; then
      log "SKIP: target exists but not a directory: $target"
      continue
    fi

    if [[ -d "$target" ]]; then
      # 目标已存在：把 build 目录内容挪进去（避免覆盖）
      stamp="$(date +%Y%m%d-%H%M%S)"
      backup="${target}.from-build.${stamp}"
      log "target already exists, move build to: $backup"
      run "mv -T \"$build\" \"$backup\""
      log "link $build -> $target"
      run "ln -s \"$target\" \"$build\""
    else
      # 目标不存在：直接把 build 目录挪过去，然后建 symlink
      log "move $build -> $target"
      run "mv \"$build\" \"$target\""
      log "link $build -> $target"
      run "ln -s \"$target\" \"$build\""
    fi

    # 可选：输出验证
    if [[ $DRY_RUN -eq 0 ]]; then
      if [[ -L "$build" ]]; then
        log "OK: $(ls -l "$build")"
      else
        log "WARN: build is still not a symlink: $build"
      fi
    fi
  fi
done

log "done."
