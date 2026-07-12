# Introduce

This repo is mainly for backing up my system and shell configuration files.

## System configuration

The unified index and development-capability comparison are under:

- `system_setting/`

## PC: Gentoo

The physical PC/laptop configuration is kept under:

- `alternative_setting/gentoo/mylaptop/`

That profile contains the Portage configuration, selected world packages,
kernel/Secure Boot notes and routine update instructions.

## WSL: Guix

The WSL development environment uses Guix WSL:

- `guix_setting/wsl/`

The Guix WSL profile inherits Guix's upstream `wsl-os` image definition and adds
local fixes for imported WSL instances, including `/run/current-system` repair,
`guix-daemon` startup, the `lty` user, Chinese locale and a development
manifest.

## alternative_setting

Alternative operating-system configurations and fallback profiles.

## windows_setting

Windows-side configuration files, including `.wslconfig`.

## dot(s)

Other shell and user configuration files.
