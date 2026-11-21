#!/usr/bin/env python3
"""Install native CLI launchers and HarmonyOS fonts after physical musl boot.

Root + --apply required. Does not modify boot files, privileges or user secrets.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    if not args.apply:
        print('Plan: HarmonyOS font keyword/license; normal emerge; system font alias; codium/vscodium/codex launchers')
        return
    if os.getuid() != 0:
        ap.error('--apply requires root')
    root = subprocess.check_output(['findmnt', '-no', 'FSROOT', '/'], text=True).strip()
    if root != '/@musl':
        ap.error('This acceptance installer is limited to the booted @musl root')
    lock = open('/run/lock/musl-postboot-desktop.lock', 'a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    for pid in Path('/proc').glob('[0-9]*'):
        try:
            if (pid / 'comm').read_text().strip() == 'emerge':
                ap.error('Another Portage process is running; inspect before retrying')
        except (OSError, ProcessLookupError):
            pass
    backup = Path('/var/lib/musl-migration/postboot-config-backup')
    backup.mkdir(mode=0o700, parents=True, exist_ok=True)
    source = Path(__file__).resolve().parent

    def save(path):
        target = backup / str(path).lstrip('/')
        if path.exists() and not target.exists():
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            shutil.copy2(path, target)
            target.chmod(0o600)

    def insert(path, line, before):
        text = path.read_text() if path.exists() else ''
        if line in text.splitlines():
            return
        save(path)
        if before and before in text:
            text = text.replace(before, line + '\n\n' + before, 1)
        else:
            text += '\n' + line + '\n'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    insert(Path('/etc/portage/package.accept_keywords/desktop'),
           'media-fonts/harmonyos-sans::gentoo-zh ~amd64', 'media-fonts/nerdfonts ~amd64')
    insert(Path('/etc/portage/package.license/desktop'),
           'media-fonts/harmonyos-sans::gentoo-zh HarmonyOS-Sans', '# Intel early microcode data for this machine.')
    subprocess.run(['emerge', '--pretend', '--verbose', 'media-fonts/harmonyos-sans'], check=True, timeout=180)
    subprocess.run(['emerge', '--verbose', 'media-fonts/harmonyos-sans'], check=True, timeout=1800)
    for name, target in [('cjk-readable.conf', Path('/etc/fonts/conf.d/59-musl-cjk-readable.conf')),
                         ('resume-codex.py', Path('/usr/local/bin/musl-codex-resume')),
                         ('launch-codium.py', Path('/usr/local/bin/codium'))]:
        save(target)
        shutil.copyfile(source / name, target)
        target.chmod(0o644 if name.endswith('.conf') else 0o755)
    alias = Path('/usr/local/bin/vscodium')
    if alias.exists() or alias.is_symlink():
        if not alias.is_symlink() or os.readlink(alias) != 'codium':
            ap.error('Existing vscodium entry needs separate review')
    else:
        alias.symlink_to('codium')
    cli = Path('/usr/local/bin/codex')
    if cli.exists() and 'musl-codex-resume' not in cli.read_text():
        ap.error('Existing codex entry needs separate review')
    save(cli)
    cli.write_text('#!/bin/sh\nexec /usr/local/bin/musl-codex-resume --new "$@"\n')
    cli.chmod(0o755)
    subprocess.run(['fc-cache', '-f'], check=True, timeout=180)
    print(json.dumps(dict(completed=True, physical_root=root, fonts='HarmonyOS Sans + existing IntoneMono Nerd Font Mono',
                          launchers=['codium', 'vscodium', 'codex', 'musl-codex-resume'],
                          boot_changed=False, timestamp=time.time())))


if __name__ == '__main__':
    main()
