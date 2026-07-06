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

      # Under disk pressure, collect only unreachable store paths. System
      # generations remain GC roots until the age-based job below removes them.
      min-free = 5 * 1024 * 1024 * 1024;
      max-free = 15 * 1024 * 1024 * 1024;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      randomizedDelaySec = "45min";
      options = "--delete-older-than 30d";
    };

    # Let Nix deduplicate identical store files in one scheduled pass instead
    # of adding optimise work to every build/install operation.
    # 使用 Nix 自带的定时去重，避免每次构建都额外扫描和硬链接。
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # Bound persistent logs to one rollback window. This keeps diagnostics useful
  # without allowing the separate @log subvolume to grow indefinitely.
  # 日志保留一个回滚窗口，并限制总空间，避免 @log 子卷无限增长。
  services.journald.extraConfig = ''
    SystemMaxUse=512M
    MaxRetentionSec=30day
  '';

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
