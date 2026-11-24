#!/usr/bin/env python3
"""Check, or explicitly restore, recorded repository patches after sync.

Preflight every repository before changing any. Old commits are evidence, not
hard pins. Incompatible patches stop the batch; no fuzzy application or sync.
"""
import argparse
from pathlib import Path
import subprocess
import sys


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repos-root', type=Path, default=Path('/var/db/repos'))
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--with-xmake', action='store_true',
                    help='also preflight the optional xmake executor patch')
    args = ap.parse_args()
    base = Path(__file__).resolve().parent.parent
    groups = {
        'gentoo': [('dragonwell-21.0.13', '0002'), ('mold-musl-stack', '*'),
                   ('sec-keys-short-gnupghome', '*'),
                   ('firefox-153.7', '*'), ('nvidia-620.70.06', '0001')],
        'gentoo-zh': [('bun-1.4.4', '*'), ('dragonwell-21.0.13', '0001'),
                      ('dragonwell-21.0.13', '0003'), ('neomacs-aacf292', '0001'),
                      ('flclash-private-runtime', '*'), ('cuda-13.4', '*')]
                      + [('nvidia-620.70.06', f'{i:04}') for i in range(2, 8)],
        'sonicde': [('sonic-quick-image-editor', '*')],
    }
    old_assets = base / 'patchsets/neomacs-aacf292/repository/0002-install-pinned-source-assets.patch'
    recipe = args.repos_root / 'gentoo-zh/app-editors/neomacs/neomacs-9999.ebuild'
    text = recipe.read_text()
    # Upstream changed its runtime crate layout and removed obsolete DOCS.
    # Do not overwrite that fix with asset paths for the historical source pin.
    if 'crates/neomacs-display-runtime/assets/window-icon.svg' in text and 'BUGS CONTRIBUTE' not in text:
        print('Neomacs: upstream asset/DOCS fix present; historical 0002 is not replayed.')
    else:
        groups['gentoo-zh'].insert(4, ('neomacs-aacf292', '0002'))
    commands = []
    for repo, entries in groups.items():
        command = [sys.executable, str(base / 'scripts/apply-patch-if-needed.py'),
                   '--root', str(args.repos_root / repo)]
        for group, prefix in entries:
            paths = sorted((base / 'patchsets' / group / 'repository').glob(
                '*.patch' if prefix == '*' else prefix + '*.patch'))
            if not paths:
                ap.error(f'Missing patch: {group}/{prefix}')
            for path in paths:
                if group == 'firefox-153.7' and path.name.startswith('0002'):
                    rust = (args.repos_root / 'gentoo/eclass/rust.eclass').read_text()
                    if 'inherit llvm-r2' in rust:
                        print('Firefox: current rust uses llvm-r2; skip historical llvm-r1 adapter. Previously applied adapters require strict reversal first.')
                        continue
                    if 'inherit llvm-r1' not in rust:
                        ap.error('Unknown rust LLVM inheritance; inspect before applying the historical Firefox adapter')
                command += ['--patch', str(path)]
        commands.append(command)
    # Independent executor patch: preserve the already-applied overlapping series.
    xmake_enabled = (args.repos_root == Path('/var/db/repos') and
                     Path('/etc/portage/package.env/40-xmake-bridge').is_file())
    if args.with_xmake or xmake_enabled:
        commands.append([sys.executable, str(base / 'scripts/apply-patch-if-needed.py'),
                         '--root', str(args.repos_root / 'gentoo'), '--patch',
                         str(base / 'patchsets/xmake-trybuild/repository/0001-optional-ninja-executor.patch')])
    for command in commands:
        subprocess.run(command, check=True)
    if args.apply:
        for command in commands:
            subprocess.run(command + ['--apply'], check=True)


if __name__ == '__main__':
    main()
