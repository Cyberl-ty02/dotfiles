#!/usr/bin/env python3
"""预检 FlClash 私有 ELF 重定位；仅 --apply 写入已解包的工作副本。"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def headers(path):
    with path.open('rb') as stream:
        header = stream.read(64)
        if header[:4] != b'\x7fELF':
            return None
        if len(header) != 64 or header[4:6] != b'\x02\x01':
            raise ValueError(f'未经验证的 ELF 格式：{path.name}')
        if struct.unpack_from('<H', header, 18)[0] != 62:
            raise ValueError(f'仅验证 amd64：{path.name}')
        offset = struct.unpack_from('<Q', header, 32)[0]
        width, count = struct.unpack_from('<HH', header, 54)
        if count == 65535 or (count and width != 56):
            raise ValueError(f'需要人工核对程序头：{path.name}')
        kinds = set()
        for index in range(count):
            stream.seek(offset + index * width)
            entry = stream.read(width)
            if len(entry) != width:
                raise ValueError(f'程序头被截断：{path.name}')
            kinds.add(struct.unpack_from('<I', entry)[0])
        return kinds


def patchelf(*args):
    return subprocess.check_output(['patchelf', *map(str, args)], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--loader', required=True)
    parser.add_argument('--rpath', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve(strict=True)
    if not root.is_dir() or not (root / 'FlClash').is_file():
        parser.error('--root 必须是含 FlClash 的解包工作目录')
    if not args.loader.startswith('/') or ':' in args.loader:
        parser.error('--loader 必须是目标系统内的绝对路径')
    paths = args.rpath.split(':')
    if any(not p.startswith(('/', '$ORIGIN')) or '\n' in p for p in paths):
        parser.error('--rpath 各项必须为绝对路径或 $ORIGIN 相对路径')

    core = root / 'FlClashCore'
    aot = root / 'lib/libapp.so'
    for path in [core, aot, root / 'manifest.json']:
        if path.is_symlink() or not path.is_file():
            parser.error(f'必须是普通文件：{path.name}')
    manifest = json.loads((root / 'manifest.json').read_text())
    immutable = {core: digest(core), aot: digest(aot)}
    if immutable[core] != manifest['coreSha256']:
        raise ValueError('Core 与上游 manifest 摘要不符，停止')

    # 先预检整个副本。AOT ELF 不是普通 DSO；Core 签名依赖原始字节。
    plan = []
    for path in sorted(root.rglob('*')):
        if path.is_symlink() or not path.is_file():
            continue
        kinds = headers(path)
        if kinds is None:
            continue
        needed = patchelf('--print-needed', path).splitlines() if 2 in kinds else []
        if path in immutable and (needed or 3 in kinds):
            raise ValueError(f'受保护文件的 ELF 结构已改变，需人工复核：{path.name}')
        # 没有动态依赖和解释器的 ELF 保持原样，包括 Flutter AOT。
        rewrite = path not in immutable and bool(needed or 3 in kinds)
        plan.append((path, rewrite, 3 in kinds, digest(path)))

    report = []
    for path, rewrite, interpreter, before in plan:
        if args.apply and rewrite:
            # 主程序需要可传递给间接依赖的 DT_RPATH，不能只生成 DT_RUNPATH。
            dynamic = subprocess.check_output(['readelf', '-d', str(path)], text=True)
            if patchelf('--print-rpath', path) != args.rpath or '(RPATH)' not in dynamic:
                patchelf('--force-rpath', '--set-rpath', args.rpath, path)
            if interpreter and patchelf('--print-interpreter', path) != args.loader:
                patchelf('--set-interpreter', args.loader, path)
        report.append(dict(path=str(path.relative_to(root)), rewrite=rewrite,
                           before=before, after=digest(path)))
    if any(digest(path) != original for path, original in immutable.items()):
        raise ValueError('受保护文件发生变化，丢弃工作副本并停止')
    print(json.dumps(dict(applied=args.apply, files=report), indent=2))


if __name__ == '__main__':
    main()
