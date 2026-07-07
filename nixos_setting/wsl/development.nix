{ pkgs, ... }:

let
  # Prefer Alibaba Dragonwell Standard LTS when nixpkgs exposes an upstream-
  # maintained rolling alias. Keep the expression unversioned so a reviewed
  # flake update can move to the next Dragonwell LTS without changing this
  # package list. Current nixpkgs may not yet ship Dragonwell; in that case
  # keep the platform JDK so the system remains evaluable.
  dragonwellStandardLts =
    pkgs.dragonwell or pkgs."alibaba-dragonwell" or pkgs.dragonwell21 or pkgs.jdk;
in

{
  environment.systemPackages = with pkgs; [
    # Shell and everyday CLI tools.
    bat
    btop
    chezmoi
    curl
    eza
    fastfetch
    fd
    file
    fzf
    gnupg
    jq
    less
    openssh
    ripgrep
    rsync
    unzip
    wget
    yazi
    zip

    # Editors and Nix tooling.
    emacs-nox
    nh
    nil
    nix-output-monitor
    nixfmt
    shellcheck
    shfmt

    # Native build and debugging toolchains.
    binutils
    cmake
    gcc
    gdb
    gnumake
    mold
    ninja
    pkg-config
    xmake
    llvmPackages.clang
    llvmPackages.lld
    llvmPackages.lldb
    llvmPackages.llvm

    # Follow Nixpkgs' supported upstream defaults. For ecosystems with an LTS
    # channel, these aliases can advance to a newer LTS during a reviewed
    # flake update instead of pinning one major release here.
    bun
    cargo
    clippy
    dragonwellStandardLts
    nodejs
    pixi
    postgresql
    python3
    rust-analyzer
    rustc
    rustfmt
    typst
    uv
  ];

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    git.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = false;
    };

    # Allows editor extensions and language package managers to run
    # dynamically linked Linux binaries that were not packaged by Nix.
    nix-ld.enable = true;
  };
}
