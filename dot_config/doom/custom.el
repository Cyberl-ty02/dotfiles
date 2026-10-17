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

;; Let every text-terminal frame inherit its terminal emulator's background,
;; including Doom's dashboard and Fundamental-mode buffers. A TTY-specific
;; override spec is recalculated for existing and future frames; graphical
;; frames do not match it and retain the complete Doom theme.
(defun dotfiles/terminal-transparent-background (&optional _frame)
  (dolist (face '(default fringe hl-line line-number line-number-current-line))
    (when (facep face)
      (face-spec-set
       face
       '((((type tty)) . (:background "unspecified-bg")))
       'face-override-spec))))

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
