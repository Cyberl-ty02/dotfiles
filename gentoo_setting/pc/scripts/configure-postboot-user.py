#!/usr/bin/env python3
"""Repair postboot user font and encrypted VSCodium storage preferences.

Run as the real desktop user. --apply is required; never edits live credential
values or restarts the editor. Config backups stay in one private state directory.
"""
import argparse
import json
import os
import re
from pathlib import Path
import shutil


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    if os.getuid() == 0:
        ap.error('Run as the desktop user, not root')
    home = Path.home()
    config = home / '.var/app/com.vscodium.codium/config'
    changes = {}
    # Keep encryption. Secret Service is accessible through the existing portal
    # permission and is supplied by the current unlocked KWallet 6 service.
    # product.dataFolderName is .vscode-oss in the installed VSCodium. Runtime
    # arguments live here, not beside the XDG User/settings.json. Preserve JSONC.
    p = home / '.vscode-oss/argv.json'
    text = p.read_text() if p.exists() else '{}\n'

    def uncomment(value):
        pattern = r'("(?:\\.|[^"\\])*")|(/\*.*?\*/|//[^\n]*)'
        return re.sub(pattern, lambda m: m.group(1) or '', value, flags=re.S)

    clean = uncomment(text)
    try:
        current = json.loads(re.sub(r',\s*([}\]])', r'\1', clean))
    except json.JSONDecodeError:
        ap.error('Invalid existing runtime argv JSONC; inspect before editing')
    if 'password-store' in current:
        text, count = re.subn(r'(?m)^(\s*"password-store"\s*:\s*)"[^"]*"',
                              r'\1"gnome-libsecret"', text)
        if count != 1:
            ap.error('Runtime argv layout needs a manual merge')
    else:
        end = text.rfind('}')
        prefix = text[:end].rstrip()
        comma = '' if clean[:clean.rfind('}')].rstrip().endswith(('{', ',')) else ','
        text = prefix + comma + '\n  "password-store": "gnome-libsecret"\n' + text[end:]
    changes[p] = text
    p = config / 'VSCodium/User/settings.json'
    settings = json.loads(p.read_text()) if p.exists() else {}
    settings['editor.fontFamily'] = "'IntoneMono Nerd Font Mono', 'HarmonyOS Sans SC', 'Noto Sans CJK SC', monospace"
    settings['terminal.integrated.fontFamily'] = settings['editor.fontFamily']
    # The Flatpak runtime cannot execute the native musl shell directly.
    # Its bundled host-spawn preserves a proper host PTY and login environment.
    profiles = settings.get('terminal.integrated.profiles.linux') or {}
    if not isinstance(profiles, dict):
        ap.error('Inspect existing Linux terminal profiles before merging')
    profiles['zsh'] = dict(path='/app/bin/host-spawn',
                           args=['/usr/bin/zsh', '-l'],
                           icon='terminal', overrideName=True)
    settings['terminal.integrated.profiles.linux'] = profiles
    settings['terminal.integrated.defaultProfile.linux'] = 'zsh'
    changes[p] = json.dumps(settings, ensure_ascii=False, indent=2) + '\n'
    changes[config / 'fontconfig/conf.d/60-cjk-readable.conf'] = Path(__file__).with_name('cjk-readable.conf').read_text()
    # Discard no user settings, histories, cookies or keyring entries.
    backup = home / '.local/state/musl-migration/postboot-config-backup'
    for target, content in changes.items():
        print(str(target.relative_to(home)))
        if not args.apply:
            continue
        if target.is_file() and target.read_text() == content:
            continue
        old = backup / target.relative_to(home)
        if target.exists() and not old.exists():
            old.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
            shutil.copy2(target, old)
            old.chmod(0o600)
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_name(target.name + '.migration-new')
        tmp.write_text(content)
        tmp.chmod(0o600)
        os.replace(tmp, target)


if __name__ == '__main__':
    main()
