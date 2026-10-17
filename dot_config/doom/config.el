;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; This is Doom's default theme. In particular, keep the dashboard themed;
;; terminal transparency is applied only to editing buffers in custom.el.
(setq doom-theme 'doom-one)

;; Use the installed Nerd Font in GUI frames so Doom's private-use glyphs
;; (modeline icons, diagnostics, and file icons) do not render as boxes.
(setq doom-font (font-spec :family "IntoneMono NFM" :size 14))

;; Keep user identity and machine-local paths out of the shared configuration.
(setq org-directory "~/org/")

;; All reusable personal behavior is isolated from the upstream-style base.
(load! "custom")
