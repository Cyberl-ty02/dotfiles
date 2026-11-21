#!/usr/bin/env python3
"""Preview a home import; --apply clones compatible files to a NEW directory.

Run against a read-only snapshot. Active Codex/editor stores need a separate
quiescent final copy. Reports are private and contain paths, never file contents.
Flatpak extension payloads may use their private glibc runtime; Java 25 providers
are deferred. System configuration and service databases are outside this tool.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import stat
import struct

SKIP = {('.cache',), ('.rustup',), ('.cargo', 'registry'), ('.cargo', 'git'),
        ('.npm', '_cacache'), ('.pixi', 'envs'), ('.local', 'share', 'Trash'),
        ('.local', 'share', 'flatpak'), ('.local', 'share', 'baloo'),
        ('.codex',), ('.config', 'VSCodium'), ('.dbus',), ('.nv',),
        ('.cargo', 'bin')}



def elf_kind(path):
    with path.open('rb') as stream:
        header = stream.read(64)
        if header[:4] != b'\x7fELF':
            return None
        if len(header) < 64 or header[4] not in (1, 2) or header[5] not in (1, 2):
            return 'unknown ELF'
        if header[8:11] in (b'AI\x01', b'AI\x02'):
            return 'AppImage runtime'
        endian = '<' if header[5] == 1 else '>'
        bits = header[4]
        kind = struct.unpack_from(endian + 'H', header, 16)[0]
        if kind not in (2, 3):
            return 'compiled ELF object'
        offset = struct.unpack_from(endian + ('Q' if bits == 2 else 'I'), header, 32 if bits == 2 else 28)[0]
        size, count = struct.unpack_from(endian + 'HH', header, 54 if bits == 2 else 42)
        if not size or count > 2048:
            return 'unknown ELF'
        interpreter, needed = '', False
        for n in range(count):
            stream.seek(offset + size * n)
            raw = stream.read(size)
            values = struct.unpack_from(endian + ('IIQQQQQQ' if bits == 2 else 'IIIIIIII'), raw)
            typ, pos, length = values[0], values[2 if bits == 2 else 1], values[5 if bits == 2 else 4]
            if typ == 3:
                stream.seek(pos)
                interpreter = stream.read(min(length, 4096)).rstrip(b'\0').decode(errors='replace')
            elif typ == 2:
                stream.seek(pos)
                data = stream.read(min(length, 65536)); width = 16 if bits == 2 else 8
                for i in range(0, len(data) - width + 1, width):
                    tag = struct.unpack_from(endian + ('Q' if bits == 2 else 'I'), data, i)[0]
                    if tag == 0: break
                    needed |= tag == 1
        if 'ld-musl-' in interpreter: return 'musl'
        if not interpreter and not needed: return 'static'
        return 'foreign dynamic ELF'


def reason(path, rel):
    parts = rel.parts
    if any(parts[:len(prefix)] == prefix for prefix in SKIP): return 'cache, managed runtime or separately finalized store'
    if parts[:2] == ('.vscode-oss', 'extensions'):
        if len(parts) >= 3 and (parts[2].startswith('redhat.java-') or parts[2].startswith('vscjava.')):
            return 'deferred JVM provider; Dragonwell Standard 21 required'
        return None  # These payloads are for Flatpak, not the musl host.
    if path.name in {'node_modules', '__pycache__'} or path.name.startswith('Singleton'): return 'generated data'
    if path.is_dir() and (path / 'pyvenv.cfg').is_file(): return 'rebuild Python environment on musl'
    if path.name == 'target' and (path.parent / 'Cargo.toml').is_file(): return 'Rust build output'
    if path.suffix in {'.pyc', '.pyo', '.eln', '.elc', '.zwc', '.o', '.a', '.lo', '.la'}: return 'compiled cache or library'
    if path.is_file() and not path.is_symlink():
        kind = elf_kind(path)
        if kind and kind not in {'static', 'musl'}: return kind
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--uid', type=int, help='Defaults to source directory owner')
    parser.add_argument('--gid', type=int, help='Defaults to source directory group')
    parser.add_argument('--minimum-free-gib', type=int, default=20)
    args = parser.parse_args()
    src = args.source.resolve(); dst = args.destination.absolute()
    args.uid = src.stat().st_uid if args.uid is None else args.uid
    args.gid = src.stat().st_gid if args.gid is None else args.gid
    if dst.exists() or dst.is_symlink() or dst.is_relative_to(src):
        parser.error('Destination must be new and outside source')
    report = dict(applied=args.apply, files=0, directories=0, bytes=0, deferred=[], symlinks=0)
    def visit(source, target, relative):
        why = reason(source, relative) if relative.parts else None
        if why:
            report['deferred'].append(dict(path=str(relative), reason=why)); return
        mode = source.lstat().st_mode
        if source.is_symlink():
            if args.apply: target.symlink_to(os.readlink(source)); os.lchown(target, args.uid, args.gid)
            report['symlinks'] += 1; return
        if source.is_dir():
            report['directories'] += 1
            if args.apply: target.mkdir(mode=0o700)
            for p in sorted(source.iterdir()): visit(p, target / p.name, relative / p.name)
        elif stat.S_ISREG(mode):
            report['files'] += 1; report['bytes'] += source.stat().st_size
            if args.apply:
                if shutil.disk_usage(dst.parent).free < args.minimum_free_gib * 1024**3:
                    raise RuntimeError('Free-space floor reached; preserve partial destination for review')
                with source.open('rb') as sf, target.open('xb') as df:
                    fcntl.ioctl(df.fileno(), 0x40049409, sf.fileno())
        else:
            report['deferred'].append(dict(path=str(relative), reason='runtime IPC or special file')); return
        if args.apply:
            shutil.copystat(source, target, follow_symlinks=False)
            os.chown(target, args.uid, args.gid)
            os.chmod(target, stat.S_IMODE(mode) & ~0o6000)
    visit(src, dst, Path())
    fd = os.open(args.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream: json.dump(report, stream, ensure_ascii=False, indent=2); stream.write('\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'deferred'} | {'deferred': len(report['deferred'])}))


if __name__ == '__main__':
    main()
