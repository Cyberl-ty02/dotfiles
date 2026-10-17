;;; custom.el -*- lexical-binding: t; -*-

;; Small, reusable editing preferences carried over from the previous editor.
;; Doom continues to own package pins, module defaults, clipboard integration,
;; undo history, and key bindings so upstream upgrades remain uncomplicated.
(setq display-line-numbers-type 'relative
      confirm-kill-emacs nil
      delete-by-moving-to-trash t
      evil-split-window-below t
      evil-vsplit-window-right t)

(setq-default indent-tabs-mode nil
              tab-width 2)

(global-hl-line-mode 1)

;; Let every terminal frame inherit its terminal emulator's background,
;; including Doom's dashboard and Fundamental-mode buffers. Face attributes
;; are frame-local, so graphical frames keep the complete Doom theme.
(defun dotfiles/terminal-transparent-background (&optional frame)
  (dolist (frame (if frame (list frame) (frame-list)))
    (unless (display-graphic-p frame)
      (dolist (face '(default fringe line-number line-number-current-line))
        (when (facep face)
          (set-face-attribute face frame :background "unspecified-bg"))))))

(add-hook 'doom-load-theme-hook #'dotfiles/terminal-transparent-background)
(add-hook 'window-setup-hook #'dotfiles/terminal-transparent-background)
(add-hook 'after-make-frame-functions #'dotfiles/terminal-transparent-background)

;; Windows editor launchers use emacsclient when a GUI instance is already
;; running. Keep the server local to Windows; Linux sessions retain their
;; existing service and daemon policy.
(when (featurep :system 'windows)
  (require 'server)
  (unless (server-running-p)
    (server-start)))
