#!/usr/bin/env python3
"""Render a temporary musl menu for a shared /boot; write only with --apply."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

BEGIN = '# BEGIN gentoo-musl dual-root'
END = '# END gentoo-musl dual-root'
HEADER = '# Managed musl dual-root menu; regenerate after kernel installation.\n'


def atomic_write(path, contents):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.refind-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', newline='') as stream:
            os.fchmod(stream.fileno(), 0o644)
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--boot-root', type=Path, default=Path('/boot'))
    parser.add_argument('--cmdline-file', type=Path, default=Path('/etc/kernel/cmdline'))
    parser.add_argument('--kernel-tag', default='musl')
    parser.add_argument('--require-kernel', help='Fail if this newly installed release has no complete pair')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    try:
        boot = args.boot_root
        main_file = boot / 'EFI/refind/refind.conf'
        menu_file = boot / 'EFI/Gentoo/musl.conf'
        if main_file.is_symlink() or menu_file.is_symlink():
            raise ValueError('Refuse symlink configuration targets')
        original = main_file.read_bytes().decode('utf-8')
        if original.count(BEGIN) != original.count(END) or original.count(BEGIN) > 1:
            raise ValueError('Managed block markers need review')
        base = original
        if BEGIN in base:
            start, end = base.index(BEGIN), base.index(END)
            if start >= end:
                raise ValueError('Managed block order needs review')
            end += len(END)
            if base[end:].startswith('\r\n'): end += 2
            elif base[end:].startswith('\n'): end += 1
            base = base[:start] + base[end:]
        options = args.cmdline_file.read_text().strip()
        if any(c in options for c in ['\n', '\r', '"', '\\']) or not re.search(r'(?:^| )root=\S+', options) or not re.search(r'(?:^| )rootflags=(?:[^ ,]+,)*(?:subvol=[^ ,]+|subvolid=[1-9][0-9]*)(?:,[^ ]+)*(?: |$)', options) or 'initrd=' in options:
            raise ValueError('Expected one root/Btrfs subvol or subvolid command line without initrd or quoted escapes')
        pairs, excluded = [], []
        for kernel in sorted(boot.glob('vmlinuz-*'), key=lambda p: (p.stat().st_mtime_ns, p.name), reverse=True):
            release = kernel.name.removeprefix('vmlinuz-').removesuffix('.efi')
            if args.kernel_tag not in release.split('-') or not re.fullmatch(r'[A-Za-z0-9._+-]+', release) or release.endswith(('.old', '.bak', '.png')):
                continue
            if kernel.is_symlink() or not kernel.is_file():
                continue
            excluded.append(kernel.name)
            initrd = boot / ('initramfs-' + release + '.img')
            if initrd.is_file() and not initrd.is_symlink():
                with kernel.open('rb') as stream:
                    if stream.read(2) != b'MZ': raise ValueError('Kernel has no EFI stub: ' + kernel.name)
                pairs.append((release, kernel.name, initrd.name))
        if not pairs or args.require_kernel and args.require_kernel not in [p[0] for p in pairs]:
            raise ValueError('No complete required kernel/initramfs pair; leave current configuration intact')
        menu = HEADER
        for release, kernel, initrd in pairs:
            menu += f'\nmenuentry "Gentoo musl ({release})" {{\n    loader /{kernel}\n    initrd /{initrd}\n    options "{options}"\n    ostype Linux\n    submenuentry "Debug" {{\n        add_options "rd.debug rd.shell"\n    }}\n}}\n'
        newline = '\r\n' if '\r\n' in original else '\n'
        separator = '' if base.endswith(newline * 2) else newline if base.endswith(newline) else newline * 2
        block = newline.join([BEGIN, 'dont_scan_files + ' + ','.join(sorted(excluded)), 'include /EFI/Gentoo/musl.conf', END, ''])
        updated = base + separator + block
        if menu_file.exists() and not menu_file.read_text().startswith(HEADER):
            raise ValueError('Existing menu is not owned by this helper')
        if args.apply:
            backup = main_file.with_name('refind.conf.pre-root-layout')
            if not backup.exists(): shutil.copyfile(main_file, backup)
            if not menu_file.exists() or menu_file.read_text() != menu: atomic_write(menu_file, menu)
            if original != updated: atomic_write(main_file, updated)
        print(json.dumps(dict(applied=args.apply, kernels=[p[0] for p in pairs], excluded_auto_loaders=sorted(excluded), main_config=str(main_file), independent_menu=str(menu_file))))
        return 0
    except (OSError, ValueError) as error:
        parser.exit(2, f'error: {error}\n')


if __name__ == '__main__':
    raise SystemExit(main())
