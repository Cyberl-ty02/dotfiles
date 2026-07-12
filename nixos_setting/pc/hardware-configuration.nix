# TEMPLATE ONLY: replace this file with output generated on the target PC:
#   sudo nixos-generate-config --show-hardware-config
#
# Filesystems, storage drivers, CPU microcode and detected hardware deliberately
# do not belong in a generic repository template.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Deliberately impossible labels make the template evaluable without
  # pretending to know the target disk layout. Replace this whole file.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT_REPLACE_ME";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd:3"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/NIXOS_ROOT_REPLACE_ME";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd:3"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/NIXOS_ROOT_REPLACE_ME";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd:3"
      "noatime"
    ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/NIXOS_ROOT_REPLACE_ME";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "compress=zstd:3"
      "noatime"
    ];
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-label/NIXOS_ROOT_REPLACE_ME";
    fsType = "btrfs";
    options = [
      "subvol=@snapshots"
      "compress=zstd:3"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS_ESP_REPLACE_ME";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];
}
