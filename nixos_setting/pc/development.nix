{ pkgs, ... }:

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
    emacs
    nh
    nil
    nix-output-monitor
    nixfmt
    shellcheck
    shfmt
    vscodium

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
    jdk
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

    nix-ld.enable = true;
  };
}
