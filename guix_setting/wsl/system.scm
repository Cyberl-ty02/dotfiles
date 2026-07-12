;; Guix WSL system profile for this workstation.
;;
;; Build an image from a Guix host:
;;
;;   guix system image -t wsl2 system.scm
;;
;; Apply inside an already imported Guix WSL instance:
;;
;;   sudo guix system reconfigure /etc/config.scm
;;
;; The configuration inherits Guix's upstream WSL image definition instead of
;; carrying EFI bootloader or block-device details that WSL does not use.

(use-modules (gnu)
             (gnu system images wsl2)
             (gnu system nss)
             (gnu services)
             (gnu services base)
             (guix gexp))

(use-package-modules certs
                     curl
                     fonts
                     shells
                     version-control)

(define %wsl-conf
  (plain-file
   "wsl.conf"
   "[interop]
appendWindowsPath=false
"))

(define %set-password-script
  (plain-file
   "guix-wsl-set-password"
   "#!/bin/sh
set -eu

if [ \"${SUDO_USER:-}\" != lty ] || [ \"$(id -u)\" -ne 0 ]; then
  echo 'This helper may only be run by lty through sudo.' >&2
  exit 1
fi

echo '请为 lty 设置新的 Linux 密码（输入时不会显示字符）。'
echo 'Set a new Linux password for lty; typed characters will not be shown.'
/run/current-system/profile/bin/passwd lty
install -d -m 0755 /var/lib/guix-wsl
touch /var/lib/guix-wsl/password-set
echo '密码已设置。后续登录将不再显示此引导。'
"))

(define %first-login-script
  (plain-file
   "guix-wsl-first-login.sh"
   "# Run only in lty's interactive login shell until password setup succeeds.
if [ \"${USER:-}\" = lty ] && [ -t 0 ] && \
   [ ! -e /var/lib/guix-wsl/password-set ] && \
   [ -z \"${GUIX_WSL_PASSWORD_PROMPTED:-}\" ]; then
  export GUIX_WSL_PASSWORD_PROMPTED=1
  printf '\\n首次使用 Guix WSL，需要设置 lty 的 Linux 密码。\\n'
  printf '此密码用于 sudo，与 Windows 密码相互独立。\\n\\n'
  sudo /run/current-system/profile/bin/sh /etc/guix-wsl-set-password || \
    printf '\\n本次未完成；下次登录时会再次提示。\\n'
fi
"))

(define %sudoers
  (plain-file
   "sudoers"
   "root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
lty ALL=(root) NOPASSWD: /run/current-system/profile/bin/sh /etc/guix-wsl-set-password
"))

(operating-system
  (inherit wsl-os)
  (host-name "guix-wsl")
  (timezone "Europe/London")
  (locale "zh_CN.utf8")

  ;; Upstream wsl-os leaves this empty because it is normally consumed by
  ;; `guix system image`.  A declared root is nevertheless required by
  ;; `guix system reconfigure`.  WSL already owns and mounts / from its VHD;
  ;; this entry only describes that existing mount and is never formatted.
  (file-systems
   (list (file-system
           (mount-point "/")
           ;; This is the root block device exposed by the current WSL2 VM.
           ;; It is descriptive here; WSL mounts it before Guix starts.
           (device "/dev/sdd")
           (type "ext4")
           (check? #f))))

  ;; The narrowly scoped helper makes initial password setup possible even
  ;; though the imported account starts locked.  It cannot run arbitrary
  ;; commands as root.
  (sudoers-file %sudoers)

  (users
   (cons*
    (user-account
     (name "lty")
     (comment "lty")
     (group "users")
     (home-directory "/home/lty")
     (shell (file-append zsh "/bin/zsh"))
     (supplementary-groups '("wheel" "audio" "video")))
    ;; WSL initially invokes root.  The upstream boot program starts the Guix
    ;; system and Shepherd, then replaces itself with lty's login shell.
    (user-account
     (inherit %root-account)
     (shell (wsl-boot-program "lty")))
    %base-user-accounts))

  (packages
   (append
    (list curl
          git
          zsh
          font-gnu-freefont
          font-google-noto
          font-google-noto-emoji
          font-google-noto-sans-cjk)
    %base-packages))

  (services
   (cons*
    (simple-service
     'lty-login-profile
     activation-service-type
     #~(let ((profile "/home/lty/.profile"))
         ;; The existing dotfiles .zprofile sources ~/.profile.  Create only
         ;; when absent so activation never overwrites user-owned content.
         (unless (file-exists? profile)
           (call-with-output-file profile
             (lambda (port)
               (display
                ". /etc/profile.d/guix-wsl-first-login.sh\n"
                port)))
           (let ((account (getpwnam "lty")))
             (chown profile (passwd:uid account) (passwd:gid account))))))
    (simple-service
     'guix-wsl-files
     etc-service-type
     `(("wsl.conf" ,%wsl-conf)
       ("guix-wsl-set-password" ,%set-password-script)
       ("profile.d/guix-wsl-first-login.sh" ,%first-login-script)))
    (operating-system-user-services wsl-os)))

  (name-service-switch %mdns-host-lookup-nss))
