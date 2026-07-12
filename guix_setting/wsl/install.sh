#!/bin/sh
set -eu

# An imported image may start without /run/current-system and with an almost
# empty PATH.  Bootstrap from the persistent system profile before using any
# external command.
system_path=/var/guix/profiles/system/profile
export PATH=$system_path/sbin:$system_path/bin:/run/setuid-programs:/bin

case $0 in
  */*) script_dir=${0%/*} ;;
  *) script_dir=. ;;
esac
repo_dir=$(CDPATH= cd -- "$script_dir" && pwd)

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run inside the Guix WSL instance as root." >&2
  exit 1
fi

"$repo_dir/fix-runtime.sh"

install -Dm644 "$repo_dir/system.scm" /etc/config.scm
install -Dm755 "$repo_dir/fix-runtime.sh" /etc/guix-wsl-fix-runtime

daemon_pid=
if ! guix gc --list-roots >/dev/null 2>&1; then
  rm -f /var/guix/daemon-socket/socket
  mkdir -p /var/guix/daemon-socket /var/log
  guix-daemon --build-users-group=guixbuild \
    >>/var/log/guix-daemon.log 2>&1 &
  daemon_pid=$!
  sleep 2
fi

cleanup() {
  if [ -n "$daemon_pid" ]; then
    kill "$daemon_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if command -v guix >/dev/null 2>&1; then
  # Guix 1.4's WSL dummy bootloader crashes during `system reconfigure` even
  # when bootloader installation is disabled.  Build the system, create the
  # same generation links Guix normally uses, and activate it transactionally.
  build_guix=guix
  # The imported image's first generation contains the newest known-working
  # bootstrap Guix.  Later system profiles may contain an older Guix package
  # whose source references patches absent from that profile.
  if [ -x /var/guix/profiles/system-1-link/profile/bin/guix ]; then
    build_guix=/var/guix/profiles/system-1-link/profile/bin/guix
  fi
  new_system=$($build_guix system build /etc/config.scm)
  old_generation=$(readlink /var/guix/profiles/system)
  next_generation=1
  for link in /var/guix/profiles/system-*-link; do
    [ -L "$link" ] || continue
    number=${link##*/system-}
    number=${number%-link}
    case $number in
      *[!0-9]*) continue ;;
    esac
    if [ "$number" -ge "$next_generation" ]; then
      next_generation=$((number + 1))
    fi
  done

  new_link=/var/guix/profiles/system-$next_generation-link
  ln -s "$new_system" "$new_link"
  ln -sfn "system-$next_generation-link" /var/guix/profiles/system

  if ! GUIX_NEW_SYSTEM="$new_system" "$new_system/activate"; then
    ln -sfn "$old_generation" /var/guix/profiles/system
    old_system=$(readlink -f /var/guix/profiles/system)
    GUIX_NEW_SYSTEM="$old_system" "$old_system/activate" || true
    rm -f "$new_link"
    echo "Activation failed; restored $old_generation." >&2
    exit 1
  fi
  ln -sfn /var/guix/profiles/system /run/current-system
else
  echo "guix is still unavailable after runtime repair." >&2
  exit 1
fi

echo
echo "System generation $next_generation applied. Restart from Windows with:"
echo "  wsl --terminate Guix"
echo "  wsl -d Guix"
echo
echo "Then install the user development profile as lty:"
echo "  guix package -m /mnt/c/Users/lty00/source/repos/dotfiles/guix_setting/wsl/manifest.scm"
