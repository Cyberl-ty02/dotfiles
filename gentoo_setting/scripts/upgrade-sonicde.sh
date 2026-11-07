#!/bin/bash
# Explicit root entry point; never reboots, restarts the display manager or depcleans.
set -Eeuo pipefail
export LC_ALL=C.UTF-8
if [[ -n ${SONICDE_PROXY:-} ]]; then
  export http_proxy="$SONICDE_PROXY" https_proxy="$SONICDE_PROXY"
  export HTTP_PROXY="$SONICDE_PROXY" HTTPS_PROXY="$SONICDE_PROXY"
fi

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
mode=${1:-all}
boot_exclude='sys-kernel/* sys-boot/* virtual/dist-kernel virtual/linux-sources'
graphics_exclude='x11-base/xlibre-server x11-base/xorg-server x11-drivers/nvidia-drivers'
common=(--verbose --update --deep --newuse --backtrack=100 --autounmask=n --keep-going=n --color=n)
targets=(@world '>=sonicde-base/sonicde-meta-6.8.0' sonicde-base/sonic-print-management)

check_plan() {
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
problems = []
for line in text.splitlines():
    if re.search(r'skipped|^!!!|^WARNING:|^ \* Error:', line, re.I):
        problems.append(line)
    match = re.match(r'^\[ebuild([^\]]*)\]\s+(\S+)', line)
    if match:
        flags, package = match.groups()
        if 'D' in flags or '9999' in package or package.startswith('sys-apps/systemd-'):
            problems.append(line)
if problems:
    raise SystemExit('Unsafe or incomplete upgrade plan:\n' + '\n'.join(problems))
print('Plan accepted: no downgrades, live packages, systemd installation or skipped updates.')
PY
}

case "$mode" in
  --plan)
    # Read-only dependency check, optionally against a prepared configuration root.
    plan_file=$(mktemp /tmp/sonicde-plan.XXXXXX)
    config_args=()
    if [[ $# -ge 2 ]]; then config_args=(--config-root="$2"); fi
    FEATURES=-news emerge "${config_args[@]}" --pretend "${common[@]}" \
      --exclude="$boot_exclude $graphics_exclude" "${targets[@]}" | tee "$plan_file"
    check_plan "$plan_file"
    printf 'Plan saved to %s\n' "$plan_file"
    exit 0
    ;;
  all|desktop|graphics) ;;
  *) echo 'Usage: upgrade-sonicde.sh [all|desktop|graphics|--plan [CONFIG_ROOT]]' >&2; exit 2 ;;
esac

if (( EUID != 0 )); then
  echo 'Run this script as root in a local terminal; no password is accepted by this script.' >&2
  exit 1
fi
for command in btrfs rsync emerge flock findmnt python3 eselect rc-service; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done
exec 9>/run/lock/sonicde-upgrade.lock
flock -n 9 || { echo 'Another SonicDE upgrade is running.' >&2; exit 1; }
if pgrep -x emerge >/dev/null; then
  echo 'Another emerge process is running; wait for it to finish.' >&2
  exit 1
fi
[[ $(findmnt -n -o FSTYPE /) == btrfs && $(findmnt -n -o FSTYPE /home) == btrfs ]]
[[ $(findmnt -n -o TARGET -T /var/db/pkg) == / ]]
[[ $(findmnt -n -o TARGET -T /var/lib/portage) == / ]]
[[ $(findmnt -n -o TARGET -T /boot) == /boot ]]
btrfs subvolume show / >/dev/null
btrfs subvolume show /home >/dev/null

upgrade_stamp=$(date +%Y%m%d-%H%M%S)-$$
backup="/root/sonicde-before-$upgrade_stamp"
log_dir="/var/log/sonicde-upgrade/$upgrade_stamp"
install -d -m 700 "$backup"
install -d -m 755 /var/log/sonicde-upgrade "$log_dir"
touch "$log_dir/run.log"
chmod 644 "$log_dir/run.log"
ln -sfn "$log_dir" /var/log/sonicde-upgrade/latest
exec > >(tee -a "$log_dir/run.log") 2>&1
trap 'code=$?; printf "FAILED (%s). See %s; backup: %s\n" "$code" "$log_dir" "$backup"; exit "$code"' ERR

echo "Mode: $mode; logs: $log_dir; backup: $backup"
findmnt -rn -o TARGET,SOURCE,FSTYPE
btrfs subvolume list / > "$log_dir/subvolumes.txt"
# Nested VDB/world subvolumes would be omitted by the root snapshot.
if grep -Eq ' path (@/)?var/(db/pkg|lib/portage)(/|$)' "$log_dir/subvolumes.txt"; then
  echo 'VDB/world are separate subvolumes; arrange a matching backup before upgrading.' >&2
  exit 1
fi
cp -a /etc/portage "$backup/portage"
cp -a /var/lib/portage/world "$backup/world"
if [[ -e /var/lib/portage/world_sets ]]; then cp -a /var/lib/portage/world_sets "$backup/world_sets"; fi
cp -a /boot "$backup/boot"
install -d -m 700 /.snapshots
btrfs subvolume snapshot -r / "/.snapshots/sonicde-root-$upgrade_stamp"
btrfs subvolume snapshot -r /home "/.snapshots/sonicde-home-$upgrade_stamp"
printf '%s\n' "/.snapshots/sonicde-root-$upgrade_stamp" "/.snapshots/sonicde-home-$upgrade_stamp" > "$backup/snapshots"

config_updates() {
  find /etc -type f -name '._cfg????_*' -print > "$log_dir/config-updates.txt"
  if [[ -s "$log_dir/config-updates.txt" ]]; then
    echo 'Configuration updates need review before continuing:'
    cat "$log_dir/config-updates.txt"
    exit 1
  fi
}

run_stage() {
  local stage=$1 exclude=$2
  shift 2
  local extra=("$@")
  emerge --pretend "${common[@]}" --exclude="$exclude" "${extra[@]}" "${targets[@]}" \
    | tee "$log_dir/$stage-plan.log"
  check_plan "$log_dir/$stage-plan.log"
  # Finish downloads before replacing any packages in this stage.
  emerge --fetchonly "${common[@]}" --exclude="$exclude" "${extra[@]}" "${targets[@]}"
  emerge --oneshot "${common[@]}" --exclude="$exclude" "${extra[@]}" "${targets[@]}"
  config_updates
}

config_updates
if [[ "$mode" != graphics ]]; then
  # Copy the reviewed policy without deleting machine-specific files.
  rsync -ai --chown=root:root --exclude=make.profile "$repo_root/gentoo_setting/pc/portage/" /etc/portage/
  if [[ ${SONICDE_OFFICIAL_SOURCES:-0} == 1 ]]; then
    # Supply the complete config: PORTAGE_REPOSITORIES replaces repos.conf loading.
    # Only source addresses change; signature verification and other overlays remain.
    PORTAGE_REPOSITORIES=$(python3 - <<'PY'
import configparser
import io
import portage

config = configparser.RawConfigParser()
config.read_string(portage.settings.repositories.config_string())
config.set('gentoo', 'sync-uri', 'https://github.com/gentoo-mirror/gentoo.git')
config.set('gentoo-zh', 'sync-uri', 'https://github.com/gentoo-zh/overlay.git')
output = io.StringIO()
config.write(output)
print(output.getvalue(), end='')
PY
)
    export PORTAGE_REPOSITORIES
    export GENTOO_MIRRORS=https://distfiles.gentoo.org
    echo 'Using official source addresses for this process only; on-disk defaults stay domestic.'
  fi
  emerge --sync
  eselect news read
  emerge --oneshot --verbose --autounmask=n --keep-going=n sys-apps/portage
  config_updates
  run_stage desktop "$boot_exclude $graphics_exclude"
  emerge --noreplace --autounmask=n --keep-going=n sonicde-base/sonic-print-management
  emerge --deselect kde-plasma/print-manager
  emerge --oneshot --autounmask=n --keep-going=n @preserved-rebuild
fi
if [[ "$mode" != desktop ]]; then
  run_stage graphics "$boot_exclude" --reinstall-atoms=x11-drivers/xf86-input-libinput
  emerge --oneshot --autounmask=n --keep-going=n @x11-module-rebuild
  emerge --oneshot --autounmask=n --keep-going=n @preserved-rebuild
fi
config_updates
emerge --pretend "${common[@]}" --exclude="$boot_exclude" "${targets[@]}" \
  | tee "$log_dir/final-plan.log"
check_plan "$log_dir/final-plan.log"
rc-service soniclogin status
rc-update show > "$log_dir/services.txt"
printf 'Package upgrade completed. Verify login, lock/unlock, audio, input and portals before cleanup or reboot.\n'
printf 'Backup: %s\nLogs: %s\n' "$backup" "$log_dir"
