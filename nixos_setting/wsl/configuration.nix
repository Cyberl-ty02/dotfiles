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
