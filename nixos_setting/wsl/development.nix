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

    # Language runtimes and development tools.
    bun
    cargo
    clippy
    jdk21
    nodejs_24
    pixi
    pnpm
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
