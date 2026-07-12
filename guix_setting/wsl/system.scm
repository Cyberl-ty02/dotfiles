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
                     bash
                     curl
                     fonts
                     guile
                     shells
                     version-control)

(define %wsl-sh
  (program-file
   "guix-wsl-sh"
   #~(begin
       ;; Remote WSL deliberately starts a non-login `sh -c`.  Give it the
       ;; same Guix tools as an interactive shell before handing off to Bash.
       (setenv
        "PATH"
        (string-append
         "/home/lty/.config/guix/current/bin:"
         "/home/lty/.guix-profile/bin:"
         "/run/current-system/profile/sbin:"
         "/run/current-system/profile/bin:"
         "/var/guix/profiles/system/profile/sbin:"
         "/var/guix/profiles/system/profile/bin:"
         "/run/privileged/bin:/usr/bin:/bin"))
       ;; WSL starts [boot].command and the requested user command in
       ;; parallel.  Avoid racing the daemon during Remote WSL startup, while
       ;; never blocking the root-owned boot command itself.  Continue after
       ;; 30 seconds so a daemon failure cannot prevent shell access.
       (unless (zero? (getuid))
         (let wait ((remaining 30))
           (unless (or (zero? remaining)
                       (file-exists? "/var/guix/daemon-socket/socket"))
             (sleep 1)
             (wait (- remaining 1)))))
       (apply execl #$(file-append bash "/bin/bash")
              "sh" (cdr (command-line))))))

(define %wsl-boot
  (program-file
   "guix-wsl-boot"
   #~(let* ((profiles "/var/guix/profiles/")
            (profile (string-append profiles "system"))
            (generation (readlink profile))
            (generation-path
             (if (string-prefix? "/" generation)
                 generation
                 (string-append profiles generation)))
            (system (readlink generation-path))
            (system-path
             (if (string-prefix? "/" system)
                 system
                 (string-append profiles system))))
       ;; WSL waits for [boot].command to return.  Start Shepherd in a child,
       ;; then return only after the daemon socket is ready.  This follows the
       ;; upstream wsl-boot-program lifecycle without opening a login shell.
       (for-each
        (lambda (socket)
          (when (file-exists? socket)
            (delete-file socket)))
        '("/var/run/shepherd/socket"
          "/var/guix/daemon-socket/socket"))
       (if (zero? (primitive-fork))
           (begin
             (setenv "GUIX_NEW_SYSTEM" system-path)
             (execl #$(file-append guile-3.0 "/bin/guile")
                    "guile"
                    "--no-auto-compile"
                    (string-append system-path "/boot")))
           (let ((socket "/var/guix/daemon-socket/socket"))
             (let wait ()
               (unless (file-exists? socket)
                 (sleep 1)
                 (wait))))))))

(define %wsl-conf
  (plain-file
   "wsl.conf"
   "[user]
default=lty

[interop]
appendWindowsPath=false

[boot]
command=/etc/guix-wsl-boot >>/var/log/guix-wsl-boot.log 2>&1
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
    (user-account
     (inherit %root-account)
     (shell (file-append bash "/bin/bash")))
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
       ("guix-wsl-boot" ,%wsl-boot)
       ("guix-wsl-set-password" ,%set-password-script)
       ("profile.d/guix-wsl-first-login.sh" ,%first-login-script)))
    (modify-services
        (operating-system-user-services wsl-os)
      (special-files-service-type
       files =>
       (map (lambda (entry)
              (if (string=? (car entry) "/bin/sh")
                  `( "/bin/sh" ,%wsl-sh)
                  entry))
            files)))))

  (name-service-switch %mdns-host-lookup-nss))
