;;; init.el --- Minimal migrated Neomacs settings -*- lexical-binding: t; -*-
;; 旧 Doom 配置单独保留；不自动加载其编译文件或 GNU Emacs 插件。
(prefer-coding-system 'utf-8-unix)
(setq initial-scratch-message nil)
(when (display-graphic-p)
  (set-face-attribute 'default nil :family "IntoneMono Nerd Font Mono" :height 120)
  (when (fboundp 'set-fontset-font)
    (set-fontset-font t 'han (font-spec :family "HarmonyOS Sans SC"))))
