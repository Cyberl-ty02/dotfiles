{ lib, ... }:

{
  # Lanzaboote replaces systemd-boot only after the machine has completed one
  # successful normal systemd-boot startup and local keys have been created.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
