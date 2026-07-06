{ pkgs, ... }:

{
  # Plasma and SDDM run natively on Wayland. XWayland remains available only
  # for applications that have not migrated from X11 yet.
  programs.xwayland.enable = true;

  services = {
    xserver.enable = false;

    displayManager = {
      defaultSession = "plasma";
      sddm = {
        enable = true;
        wayland = {
          enable = true;
          compositor = "kwin";
        };
      };
    };

    desktopManager.plasma6.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    printing.enable = true;

    # 使用 NixOS/util-linux 的默认批量 TRIM 周期。
    fstrim.enable = true;
    fwupd.enable = true;
    hardware.bolt.enable = true;
    smartd.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-rime
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.ark
    kdePackages.filelight
    kdePackages.gwenview
    kdePackages.kate
    kdePackages.kwalletmanager
    kdePackages.partitionmanager
    kdePackages.yakuake
    krita
    libreoffice-qt6-fresh
    vlc
  ];
}
