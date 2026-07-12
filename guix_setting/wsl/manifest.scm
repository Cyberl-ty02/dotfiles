;; Development profile for Guix WSL.
;;
;; Install for the default user:
;;
;;   guix package -m manifest.scm
;;
;; This intentionally keeps fast-moving development tools in a user profile.
;; The system profile stays small and recoverable if one package disappears or
;; moves between Guix channels.

(specifications->manifest
 '("bash"
   "bat"
   "binutils"
   "btop"
   "chezmoi"
   "clang"
   "cmake"
   "curl"
   "direnv"
   "emacs"
   "eza"
   "fastfetch"
   "fd"
   "file"
   "findutils"
   "fzf"
   "gcc-toolchain"
   "gdb"
   "git"
   "gnupg"
   "grep"
   "jq"
   "less"
   "lld"
   "lldb"
   "llvm"
   "make"
   "mold"
   "ninja"
   ;; Guix's unversioned aliases advance with the reviewed channel.  This
   ;; preserves upstream security updates without pinning an obsolete major.
   "node-lts"
   "openjdk"
   "openssh"
   "pkg-config"
   "python"
   "ripgrep"
   "rsync"
   "rust"
   "rust-analyzer"
   "rust-cargo"
   "sed"
   "shellcheck"
   "shfmt"
   "tar"
   "typst"
   "unzip"
   "uv"
   "wget"
   "which"
   "xz"
   "xmake"
   "zip"
   "zsh"))
