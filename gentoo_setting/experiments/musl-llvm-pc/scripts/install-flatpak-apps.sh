#!/usr/bin/env bash
set -euo pipefail
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dry_run=false
scope=
remote_url=https://mirrors.ustc.edu.cn/flathub
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=true ;;
        --user|--system)
            [[ -z "$scope" || "$scope" == "$arg" ]] || { printf "Choose one installation scope\n" >&2; exit 2; }
            scope=$arg ;;
        --official) remote_url=https://dl.flathub.org/repo ;;
        *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
if [[ -z "$scope" ]]; then
    if (( EUID == 0 )); then scope=--system; else scope=--user; fi
fi
if ! "$dry_run"; then
    if [[ "$scope" == --user ]] && (( EUID == 0 )); then
        printf 'Use --system in a root chroot; --user is for the desktop user.\n' >&2
        exit 2
    fi
    if [[ "$scope" == --system ]] && (( EUID != 0 )); then
        printf 'Run system installation as root inside the target system/chroot.\n' >&2
        exit 2
    fi
    [[ -d /proc/self && -c /dev/null ]] || {
        printf 'Prepare /proc and /dev in the chroot first.\n' >&2; exit 2;
    }
    command -v flatpak >/dev/null || {
        printf 'Install Flatpak first (Gentoo: emerge --ask sys-apps/flatpak).\n' >&2
        exit 127
    }
fi
packages=()
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" =~ ^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+){2,}$ ]] || {
        printf 'Invalid application ID: %s\n' "$line" >&2; exit 2
    }
    packages+=("$line")
done < "$script_dir/flatpak-apps.txt"
(( ${#packages[@]} > 0 )) || { printf 'Empty application list\n' >&2; exit 2; }
run() {
    if "$dry_run"; then
        printf '%q ' "$@"; printf '\n'
    else
        "$@"
    fi
}
run flatpak remote-add "$scope" --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
run flatpak remote-modify "$scope" flathub --url="$remote_url"
extra_languages=''
if ! "$dry_run"; then
    extra_languages=$(flatpak config "$scope" --get extra-languages 2>/dev/null || true)
    if [[ "$extra_languages" == "*unset*" ]]; then extra_languages=''; fi
fi
for language in zh en; do
    case ";$extra_languages;" in
        *";$language;"*) ;;
        *) extra_languages="${extra_languages:+${extra_languages};}$language" ;;
    esac
done
run flatpak config "$scope" --set extra-languages "$extra_languages"
run flatpak install "$scope" --noninteractive flathub "${packages[@]}"
