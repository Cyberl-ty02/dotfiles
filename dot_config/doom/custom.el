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

;; Preserve Doom's normal dashboard/theme, but let terminal editing buffers use
;; the terminal emulator's own background. Face remapping is buffer-local, so
;; this does not mutate Doom themes or graphical frames.
(defun dotfiles/terminal-editor-background ()
  (unless (display-graphic-p)
    (dolist (face '(default fringe line-number line-number-current-line))
      (when (facep face)
        (face-remap-add-relative face :background "unspecified-bg")))))

(dolist (hook '(conf-mode-hook prog-mode-hook text-mode-hook))
  (add-hook hook #'dotfiles/terminal-editor-background))
