{ pkgs, ... }:

{
  imports = [
    ./development.nix
    ./desktop.nix
  ];

  networking = {
    hostName = "nixos-pc";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
    };
    efi.canTouchEfiVariables = true;
  };

  users.users.lty = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "audio"
      "input"
      "networkmanager"
      "video"
      "wheel"
    ];
    shell = pkgs.zsh;
  };

  security = {
    rtkit.enable = true;
    sudo.wheelNeedsPassword = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.sessionVariables = {
    EDITOR = "emacs";
    VISUAL = "emacs";

    # Electron and Firefox otherwise still choose XWayland in some releases.
    # Qt and GTK auto-detect Wayland and retain their own X11 fallback.
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  programs.zsh.enable = true;

  environment.systemPackages = [ pkgs.sbctl ];

  # Compatibility baseline only; package versions come from the flake input.
  system.stateVersion = "26.05";
}
