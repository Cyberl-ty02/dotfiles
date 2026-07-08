#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${TARGET_ROOT:-/mnt}"
# Compression saves space and noatime avoids read-triggered metadata writes.
# Keep discard out of the mount path: NixOS batches TRIM weekly. Avoid
# autodefrag/commit tuning here because they can increase write amplification
# or widen the amount of recent metadata lost after an abrupt power failure.
# 压缩用于节省空间，noatime 避免“读取也写盘”；TRIM 由系统每周批量执行。
MOUNT_OPTIONS="compress=zstd:3,noatime"
EXPECTED_SUBVOLUMES=(
  @
  @home
  @nix
  @log
  @snapshots
)

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

for command in \
  awk btrfs find findmnt grep lsblk mkfs.btrfs mkfs.fat mount \
  parted readlink sort tr udevadm umount; do
  if ! command -v "$command" >/dev/null; then
    echo "Required installer command not found: $command" >&2
    exit 1
  fi
done

if [[ ! -d /sys/firmware/efi ]]; then
  echo "The installer was not booted in UEFI mode." >&2
  exit 1
fi

if findmnt --mountpoint "$TARGET_ROOT" >/dev/null; then
  echo "$TARGET_ROOT is already mounted." >&2
  echo "Unmount it before using the storage preparation helper." >&2
  exit 1
fi
install -d -m 0755 "$TARGET_ROOT"

cleanup_on_error() {
  status=$?
  trap - EXIT
  if ((status != 0)); then
    echo "An error occurred; unmounting the partially prepared target." >&2
    for path in \
      "$TARGET_ROOT/boot" \
      "$TARGET_ROOT/.snapshots" \
      "$TARGET_ROOT/var/log" \
      "$TARGET_ROOT/nix" \
      "$TARGET_ROOT/home" \
      "$TARGET_ROOT"; do
      if findmnt --mountpoint "$path" >/dev/null; then
        umount "$path" || true
      fi
    done
  fi
  exit "$status"
}
trap cleanup_on_error EXIT

show_disk_layout() {
  echo
  echo "Physical partition order:"
  parted "$DISK" unit MiB print free
  echo
  lsblk --sort START \
    -o NAME,START,SIZE,FSTYPE,FSVER,LABEL,PARTLABEL,MOUNTPOINTS "$DISK"
}

validate_partition() {
  local partition="$1"
  local expected_type="$2"
  local actual_type parent

  partition="$(readlink -f -- "$partition")"
  if [[ ! -b "$partition" ]] || [[ "$(lsblk -dnro TYPE "$partition")" != "part" ]]; then
    echo "Not a block partition: $partition" >&2
    return 1
  fi

  parent="$(lsblk -dnro PKNAME "$partition")"
  if [[ "/dev/${parent}" != "$DISK" ]]; then
    echo "$partition does not belong to $DISK." >&2
    return 1
  fi

  if findmnt --source "$partition" >/dev/null; then
    echo "$partition is already mounted." >&2
    return 1
  fi

  actual_type="$(lsblk -dnro FSTYPE "$partition")"
  if [[ "$expected_type" == "vfat" ]]; then
    case "$actual_type" in
    vfat | fat | fat32) ;;
    *)
      echo "$partition is '$actual_type', not FAT." >&2
      return 1
      ;;
    esac
  elif [[ "$actual_type" != "$expected_type" ]]; then
    echo "$partition is '$actual_type', not '$expected_type'." >&2
    return 1
  fi
}

inspect_esp() {
  local esp_partition="$1"
  local inspection_dir="/run/nixos-esp-inspection"

  install -d -m 0700 "$inspection_dir"
  mount -o ro "$esp_partition" "$inspection_dir"

  echo
  echo "Existing FAT contents (nothing is deleted):"
  if ! find "$inspection_dir" -mindepth 1 -maxdepth 3 -printf '%P\n' | head -n 40; then
    true
  fi
  if [[ -z "$(find "$inspection_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "  [empty filesystem]"
  fi

  umount "$inspection_dir"
}

prepare_subvolumes() {
  local root_partition="$1"
  local actual_entries expected_entries

  mount -o subvolid=5 "$root_partition" "$TARGET_ROOT"
  actual_entries="$(
    find "$TARGET_ROOT" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
  )"
  expected_entries="$(
    printf '%s\n' "${EXPECTED_SUBVOLUMES[@]}" | sort
  )"

  if [[ -z "$actual_entries" ]]; then
    echo "The Btrfs filesystem is empty; creating the standard subvolumes."
    for subvolume in "${EXPECTED_SUBVOLUMES[@]}"; do
      btrfs subvolume create "${TARGET_ROOT}/${subvolume}"
    done
  elif [[ "$actual_entries" == "$expected_entries" ]]; then
    for subvolume in "${EXPECTED_SUBVOLUMES[@]}"; do
      if ! btrfs subvolume show "${TARGET_ROOT}/${subvolume}" >/dev/null; then
        echo "${subvolume} exists but is not a Btrfs subvolume; refusing." >&2
        return 1
      fi
    done
    echo "The existing standard Btrfs subvolume layout will be reused."
  else
    echo "The Btrfs top level is not pristine and does not exactly match:" >&2
    printf '  %s\n' "${EXPECTED_SUBVOLUMES[@]}" >&2
    echo "Actual top-level entries:" >&2
    printf '%s\n' "$actual_entries" | sed 's/^/  /' >&2
    echo "Refusing to overwrite or reinterpret existing data." >&2
    return 1
  fi

  umount "$TARGET_ROOT"
}

mount_layout() {
  local esp_partition="$1"
  local root_partition="$2"

  mount -o "subvol=@,${MOUNT_OPTIONS}" "$root_partition" "$TARGET_ROOT"
  install -d -m 0755 \
    "$TARGET_ROOT/boot" \
    "$TARGET_ROOT/home" \
    "$TARGET_ROOT/nix" \
    "$TARGET_ROOT/var/log" \
    "$TARGET_ROOT/.snapshots"
  mount -o "subvol=@home,${MOUNT_OPTIONS}" "$root_partition" "$TARGET_ROOT/home"
  mount -o "subvol=@nix,${MOUNT_OPTIONS}" "$root_partition" "$TARGET_ROOT/nix"
  mount -o "subvol=@log,${MOUNT_OPTIONS}" "$root_partition" "$TARGET_ROOT/var/log"
  mount -o "subvol=@snapshots,${MOUNT_OPTIONS}" \
    "$root_partition" "$TARGET_ROOT/.snapshots"
  mount "$esp_partition" "$TARGET_ROOT/boot"

  echo
  echo "Storage is mounted, but NixOS has not been installed:"
  findmnt -R "$TARGET_ROOT"
}

mount_existing_layout() {
  local esp_input root_input answer esp_parttype esp_number

  show_disk_layout
  echo
  read -r -p "Existing clean FAT EFI partition: " esp_input
  ESP_PART="$(readlink -f -- "$esp_input")"
  validate_partition "$ESP_PART" vfat
  esp_parttype="$(lsblk -dnro PARTTYPE "$ESP_PART" | tr '[:upper:]' '[:lower:]')"
  if [[ "$esp_parttype" != "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]]; then
    echo "$ESP_PART is FAT but is not marked as an EFI System Partition."
    read -r -p "Type 'SET ESP ${ESP_PART}' to set its GPT ESP flag: " answer
    if [[ "$answer" != "SET ESP ${ESP_PART}" ]]; then
      echo "ESP flag confirmation did not match; no change made."
      return 0
    fi
    esp_number="$(lsblk -dnro PARTN "$ESP_PART")"
    parted -s "$DISK" set "$esp_number" esp on
    udevadm settle
  fi

  read -r -p "Existing clean Btrfs Linux partition: " root_input
  ROOT_PART="$(readlink -f -- "$root_input")"
  validate_partition "$ROOT_PART" btrfs

  if [[ "$ESP_PART" == "$ROOT_PART" ]]; then
    echo "The EFI and Linux partitions must be different." >&2
    return 1
  fi

  inspect_esp "$ESP_PART"
  echo
  echo "The FAT partition will be reused without formatting."
  echo "The Btrfs partition must be empty or contain exactly the standard"
  echo "subvolumes; no existing files will be deleted."
  read -r -p "Type 'MOUNT EXISTING' to inspect and mount them: " answer
  if [[ "$answer" != "MOUNT EXISTING" ]]; then
    echo "Confirmation did not match; no filesystems were changed."
    return 0
  fi

  prepare_subvolumes "$ROOT_PART"
  mount_layout "$ESP_PART" "$ROOT_PART"
}

create_layout() {
  local answer data_choice esp_size free_index linux_size
  local free_start free_end free_size
  local part_start part_end esp_end linux_end remaining
  local create_data=false
  local -a free_extents

  if lsblk -nrpo MOUNTPOINTS "$DISK" |
    awk 'NF { found = 1 } END { exit !found }'; then
    echo "A partition on $DISK is mounted; refusing to edit its table." >&2
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$DISK" >&2
    return 1
  fi

  if lsblk -nrpo PARTLABEL "$DISK" |
    grep -Fqx -e NIXOS_BOOT -e NIXOS_ROOT -e SHARED_DATA; then
    echo "$DISK already has one of this script's partition labels." >&2
    return 1
  fi

  show_disk_layout
  mapfile -t free_extents < <(
    parted -m "$DISK" unit MiB print free |
      awk -F: '
        /:free;$/ {
          gsub(/MiB/, "", $2)
          gsub(/MiB/, "", $3)
          gsub(/MiB/, "", $4)
          print ($2 + 0) ":" ($3 + 0) ":" ($4 + 0)
        }
      ' |
      sort -t: -k1,1n
  )

  if ((${#free_extents[@]} == 0)); then
    echo "No unallocated extents were found." >&2
    return 1
  fi

  echo
  echo "Unallocated extents:"
  for index in "${!free_extents[@]}"; do
    IFS=: read -r free_start free_end free_size <<<"${free_extents[$index]}"
    printf '  %d) start=%s MiB end=%s MiB size=%s MiB\n' \
      "$((index + 1))" "$free_start" "$free_end" "$free_size"
  done

  read -r -p "Select a free extent number: " free_index
  if [[ ! "$free_index" =~ ^[0-9]+$ ]] ||
    ((free_index < 1 || free_index > ${#free_extents[@]})); then
    echo "Invalid free extent selection." >&2
    return 1
  fi

  IFS=: read -r free_start free_end free_size \
    <<<"${free_extents[$((free_index - 1))]}"
  part_start="$(
    awk -v start="$free_start" \
      'BEGIN { value = int(start); if (value < start) value++; if (value < 1) value = 1; print value }'
  )"
  part_end="$(awk -v end="$free_end" 'BEGIN { print int(end) }')"

  read -r -p "EFI partition size in MiB [1024]: " esp_size
  esp_size="${esp_size:-1024}"
  if [[ ! "$esp_size" =~ ^[0-9]+$ ]] || ((esp_size < 512)); then
    echo "The EFI partition must be an integer of at least 512 MiB." >&2
    return 1
  fi
  esp_end=$((part_start + esp_size))

  remaining=$((part_end - esp_end))
  if ((remaining < 1024)); then
    echo "The selected extent is too small for the ESP and a Linux root." >&2
    return 1
  fi

  read -r -p "Btrfs Linux size in MiB [rest=${remaining}]: " linux_size
  if [[ -z "$linux_size" || "$linux_size" == "rest" ]]; then
    linux_size="$remaining"
  elif [[ ! "$linux_size" =~ ^[0-9]+$ ]] ||
    ((linux_size < 1024 || linux_size > remaining)); then
    echo "Linux size must be between 1024 and ${remaining} MiB." >&2
    return 1
  fi
  linux_end=$((esp_end + linux_size))
  remaining=$((part_end - linux_end))

  if ((remaining >= 16)); then
    read -r -p \
      "Create a third unformatted SHARED_DATA partition from the remaining ${remaining} MiB? [y/N] " \
      data_choice
    if [[ "$data_choice" =~ ^[Yy]$ ]]; then
      create_data=true
    fi
  fi

  echo
  echo "Proposed physical order inside the selected free extent:"
  echo "  1. NIXOS_BOOT  ${part_start}-${esp_end} MiB, FAT32 ESP"
  echo "  2. NIXOS_ROOT  ${esp_end}-${linux_end} MiB, Btrfs Linux"
  if [[ "$create_data" == true ]]; then
    echo "  3. SHARED_DATA ${linux_end}-${part_end} MiB, unformatted"
    echo "     Format it as NTFS later from Windows or GParted."
  elif ((remaining > 0)); then
    echo "  remaining     ${linux_end}-${part_end} MiB, left unallocated"
  fi
  echo
  echo "GPT partition numbers may differ on an existing disk; labels and physical"
  echo "start offsets above are authoritative. Existing partitions are untouched."
  CONFIRMATION="PARTITION ${DISK} ${part_start}-${part_end}"
  read -r -p "Type '${CONFIRMATION}' to write this plan: " answer
  if [[ "$answer" != "$CONFIRMATION" ]]; then
    echo "Confirmation did not match; no changes made."
    return 0
  fi

  parted -s "$DISK" unit MiB \
    mkpart NIXOS_BOOT fat32 "$part_start" "$esp_end"
  parted -s "$DISK" unit MiB \
    mkpart NIXOS_ROOT btrfs "$esp_end" "$linux_end"
  if [[ "$create_data" == true ]]; then
    parted -s "$DISK" unit MiB \
      mkpart SHARED_DATA ntfs "$linux_end" "$part_end"
  fi
  udevadm settle

  ESP_PART="$(
    lsblk -nrpo NAME,PARTLABEL "$DISK" |
      awk '$2 == "NIXOS_BOOT" { print $1; exit }'
  )"
  ROOT_PART="$(
    lsblk -nrpo NAME,PARTLABEL "$DISK" |
      awk '$2 == "NIXOS_ROOT" { print $1; exit }'
  )"
  if [[ -z "$ESP_PART" || -z "$ROOT_PART" ]]; then
    echo "Could not identify the newly created partitions." >&2
    return 1
  fi

  ESP_NUMBER="$(lsblk -dnro PARTN "$ESP_PART")"
  parted -s "$DISK" set "$ESP_NUMBER" esp on
  udevadm settle
  mkfs.fat -F 32 -n NIXOS_BOOT "$ESP_PART"
  mkfs.btrfs -f -L NIXOS_ROOT "$ROOT_PART"

  show_disk_layout
  echo
  echo "Partitions are now created and formatted, but NixOS is not installed."
  read -r -p "Type 'MOUNT NEW' to create subvolumes and mount them: " answer
  if [[ "$answer" != "MOUNT NEW" ]]; then
    echo "Leaving the new partitions unmounted for review."
    echo "Run this helper again and choose the existing-partition workflow."
    return 0
  fi

  prepare_subvolumes "$ROOT_PART"
  mount_layout "$ESP_PART" "$ROOT_PART"
}

echo "Available physical disks:"
lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF == "disk"'
echo
read -r -p "Target disk (for example /dev/nvme0n1): " DISK_INPUT
DISK="$(readlink -f -- "$DISK_INPUT")"

if [[ ! -b "$DISK" ]] || [[ "$(lsblk -dnro TYPE "$DISK")" != "disk" ]]; then
  echo "Not a physical block disk: $DISK" >&2
  exit 1
fi

PARTITION_TABLE="$(lsblk -dnro PTTYPE "$DISK")"
if [[ -z "$PARTITION_TABLE" ]]; then
  if [[ -n "$(lsblk -nrpo NAME "$DISK" | tail -n +2)" ]]; then
    echo "$DISK has partitions but no recognized partition table; refusing." >&2
    exit 1
  fi
  read -r -p "Type 'CREATE GPT ${DISK}' to initialize this blank disk: " ANSWER
  if [[ "$ANSWER" != "CREATE GPT ${DISK}" ]]; then
    echo "Confirmation did not match; no changes made."
    exit 1
  fi
  parted -s "$DISK" mklabel gpt
  udevadm settle
elif [[ "$PARTITION_TABLE" != "gpt" ]]; then
  echo "$DISK uses '$PARTITION_TABLE', not GPT; refusing." >&2
  exit 1
fi

echo
echo "Choose storage workflow:"
echo "  1) Select any free extent and create FAT/Btrfs partitions"
echo "  2) Detect and mount existing clean FAT + Btrfs partitions"
echo "  q) Quit without changes"
read -r -p "Selection: " WORKFLOW

case "$WORKFLOW" in
1) create_layout ;;
2) mount_existing_layout ;;
q | Q)
  echo "No changes made."
  ;;
*)
  echo "Invalid selection." >&2
  exit 1
  ;;
esac

trap - EXIT
