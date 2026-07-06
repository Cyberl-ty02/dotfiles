{ config, ... }:

{
  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
    open = false;

    # Follow the current production driver carried by Nixpkgs.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
}
