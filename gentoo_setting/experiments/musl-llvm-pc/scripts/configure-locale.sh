#!/usr/bin/env bash
set -euo pipefail

language=zh_CN.UTF-8
timezone=Asia/Shanghai
dry_run=false
while (( $# )); do
    case "$1" in
        --lang|--timezone)
            (( $# >= 2 )) || { printf 'Missing argument for %s\n' "$1" >&2; exit 2; }
            if [[ "$1" == --lang ]]; then language=$2; else timezone=$2; fi
            shift 2 ;;
        --dry-run) dry_run=true; shift ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done
case "$language" in
    zh-CN|zh_CN|zh_CN.UTF8|zh_CN.UTF-8) language=zh_CN.UTF-8 ;;
    en-US|en_US|en_US.UTF8|en_US.UTF-8) language=en_US.UTF-8 ;;
    C.UTF8|C.UTF-8) language=C.UTF-8 ;;
    *) printf 'Supported locales: zh_CN.UTF-8, en_US.UTF-8, C.UTF-8\n' >&2; exit 2 ;;
esac
[[ "$timezone" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] || {
    printf 'Invalid timezone\n' >&2; exit 2;
}
[[ -f "/usr/share/zoneinfo/$timezone" ]] || {
    printf 'Timezone data missing: %s\n' "$timezone" >&2; exit 2;
}
command -v portageq >/dev/null || { printf 'Run inside the Gentoo target/chroot\n' >&2; exit 2; }
libc=$(portageq envvar ELIBC)
[[ "$libc" == musl || "$libc" == glibc ]] || {
    printf 'Unsupported libc profile: %s\n' "$libc" >&2; exit 2;
}
printf 'libc=%s LANG=%s timezone=%s\n' "$libc" "$language" "$timezone"
if "$dry_run"; then
    printf 'Would update /etc/env.d/02locale, /etc/timezone and /etc/localtime; run env-update.\n'
    if [[ "$libc" == glibc && "$language" != C.UTF-8 ]]; then
        printf 'Would enable %s UTF-8 in /etc/locale.gen and run locale-gen.\n' "$language"
    fi
    exit 0
fi
(( EUID == 0 )) || { printf 'Run as root inside the target system/chroot\n' >&2; exit 2; }
command -v env-update >/dev/null || { printf 'env-update is missing\n' >&2; exit 2; }
if [[ "$libc" == glibc && "$language" != C.UTF-8 ]]; then
    command -v locale-gen >/dev/null || { printf 'locale-gen is missing\n' >&2; exit 2; }
fi

mkdir -p /var/backups/locale-setup
chmod 700 /var/backups/locale-setup
backup_dir=$(mktemp -d /var/backups/locale-setup/before-XXXXXXXX)
chmod 700 "$backup_dir"
for file in /etc/env.d/02locale /etc/timezone /etc/localtime /etc/locale.gen; do
    if [[ -e "$file" || -L "$file" ]]; then
        cp -a -- "$file" "$backup_dir/$(basename "$file")"
    fi
done
printf 'Previous configuration: %s\n' "$backup_dir"
if [[ "$libc" == glibc && "$language" != C.UTF-8 ]]; then
    touch /etc/locale.gen
    entry="$language UTF-8"
    grep -Fqx -- "$entry" /etc/locale.gen || printf '\n%s\n' "$entry" >> /etc/locale.gen
    locale-gen
fi

mkdir -p /etc/env.d
locale_tmp=$(mktemp /etc/env.d/.02locale.XXXXXXXX)
timezone_tmp=''
trap 'rm -f -- "$locale_tmp"; if [[ -n "$timezone_tmp" ]]; then rm -f -- "$timezone_tmp"; fi' EXIT
printf '# Login language; keep LC_ALL scoped to individual commands.\nLANG="%s"\n' "$language" > "$locale_tmp"
chmod 644 "$locale_tmp"
mv -f -- "$locale_tmp" /etc/env.d/02locale
timezone_tmp=$(mktemp /etc/.timezone.XXXXXXXX)
printf '%s\n' "$timezone" > "$timezone_tmp"
chmod 644 "$timezone_tmp"
mv -f -- "$timezone_tmp" /etc/timezone
ln -sfn -- "/usr/share/zoneinfo/$timezone" /etc/localtime
env-update
printf 'Configured. For this shell: unset LC_ALL; source /etc/profile\n'
if [[ "$libc" == musl ]]; then
    printf 'musl locale data differs from glibc; validate application/ICU formatting separately.\n'
fi
