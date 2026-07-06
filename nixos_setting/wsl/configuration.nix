{ pkgs, ... }:

{
  imports = [
    ./development.nix
  ];

  networking.hostName = "nixos-wsl";

  wsl = {
    enable = true;
    defaultUser = "lty";

    # Keep Linux development tools ahead of similarly named Windows programs.
    interop.includePath = false;

    # Reuse the Windows-side graphics/CUDA driver exposed through WSL.
    useWindowsDriver = true;
  };

  users.users.lty = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = false;

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

  # Keep enough diagnostics for the rollback window while limiting VHD growth.
  # 保留足够的排错日志，同时限制 WSL 虚拟磁盘增长。
  services.journald.extraConfig = ''
    SystemMaxUse=256M
    MaxRetentionSec=30day
  '';

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.sessionVariables = {
    EDITOR = "emacs";
    VISUAL = "emacs";

    # WSLg exposes both Wayland and X11 sockets. Prefer native Wayland for
    # Electron and Firefox while leaving DISPLAY available as a fallback.
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  programs.zsh = {
    enable = true;

    # Prompt once on the first interactive login without storing a password
    # in this repository. The condition becomes false after passwd succeeds.
    interactiveShellInit = ''
      if [[ "$USER" == "lty" ]]; then
        password_status="$(passwd -S lty 2>/dev/null || true)"
        if [[ "$password_status" == "lty L "* ]]; then
          echo "Set the login password for lty:"
          sudo passwd lty
        fi
        unset password_status
      fi
    '';
  };

  # Keep this at the version used by the existing NixOS-WSL installation.
  system.stateVersion = "26.05";
}
