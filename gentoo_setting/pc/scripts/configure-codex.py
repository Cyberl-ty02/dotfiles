#!/usr/bin/env python3
"""Opt-in deployment for Gentoo musl PC with VSCodium Flatpak and optional Magpie.

Run as the desktop user. This installer targets the Linux Flatpak profile;
the Windows and WSL setup do not invoke it.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if os.getuid() == 0:
        parser.error('Run as the desktop user, not root')
    home = Path.home()
    source = Path(__file__).resolve().parent
    local_bin = home / '.local/bin'
    settings_path = home / '.var/app/com.vscodium.codium/config/VSCodium/User/settings.json'
    if not settings_path.is_file():
        parser.error('Expected existing Flatpak VSCodium settings; configure the editor first')
    try:
        settings = json.loads(settings_path.read_text())
    except ValueError:
        parser.error('Review JSONC or invalid editor settings before merging')
    if not isinstance(settings, dict):
        parser.error('Expected an editor settings object')
    runtime = local_bin / 'codex-runtime'
    configured = settings.get('chatgpt.cliExecutable')
    if configured and configured != str(runtime):
        parser.error('Review the existing custom Codex executable before replacing it')
    settings['chatgpt.cliExecutable'] = str(runtime)
    files = {
        runtime: ((source / 'codex-runtime.py').read_text(), 0o755),
        local_bin / 'codium': ((source / 'launch-codium.py').read_text(), 0o755),
        local_bin / 'vscodium': ('#!/bin/sh\nexec "$(dirname -- "$0")/codium" "$@"\n', 0o755),
        settings_path: (json.dumps(settings, ensure_ascii=False, indent=2) + '\n', 0o600),
    }
    changes = {}
    for target, (content, mode) in files.items():
        if target.is_symlink():
            parser.error(f'Review existing symlink before replacing: {target}')
        if not target.is_file() or target.read_text() != content or target.stat().st_mode & 0o777 != mode:
            changes[target] = (content, mode)
    print(json.dumps(dict(
        apply=args.apply, codex_home=str(home / '.codex'), runtime=str(runtime),
        files=[str(target) for target in changes], old_profiles_preserved=True,
        chatgpt_gateway='When selected, local Magpie receives the existing ChatGPT authorization',
        reload='Exit all VSCodium windows once, then launch codium; no process is stopped here'),
        ensure_ascii=False, indent=2))
    if not args.apply or not changes:
        return
    backup_root = home / '.local/state/codex-runtime-backup'
    backup_root.mkdir(parents=True, mode=0o700, exist_ok=True)
    backup_root.chmod(0o700)
    backup = Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%dT%H%M%S-'), dir=backup_root))
    for target, (content, mode) in changes.items():
        if target.exists():
            saved = backup / target.relative_to(home)
            saved.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
            shutil.copy2(target, saved)
            saved.chmod(0o600)
        target.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(prefix=f'.{target.name}-', dir=target.parent)
        try:
            with os.fdopen(descriptor, 'w') as output:
                output.write(content)
                os.fchmod(output.fileno(), mode)
            os.replace(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    print(f'Backup: {backup}')


if __name__ == '__main__':
    main()
