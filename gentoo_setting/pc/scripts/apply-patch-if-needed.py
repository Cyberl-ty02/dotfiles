#!/usr/bin/env python3
"""检查补丁适用性：已应用则跳过，不兼容则停止；默认只检查。"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def series(root, patches, apply):
    """在临时副本上预检有重叠的有序补丁，再一次性应用最终差异。"""
    paths = set()
    for patch in patches:
        result = subprocess.run(['git', '-C', str(root), 'apply', '--numstat', '-z', str(patch)],
                                capture_output=True)
        if result.returncode:
            raise ValueError(result.stderr.decode(errors='replace'))
        for item in result.stdout.split(b'\0'):
            if not item:
                continue
            fields = item.split(b'\t', 2)
            if len(fields) != 3 or not fields[2]:
                raise ValueError('补丁组暂不处理重命名；请单独复核该补丁')
            relative = Path(fields[2].decode())
            if relative.is_absolute() or {'..', '.git'} & set(relative.parts):
                raise ValueError('拒绝仓库外或 Git 内部路径')
            for parent in [relative, *relative.parents]:
                if (root / parent).is_symlink():
                    raise ValueError('补丁组涉及符号链接，须单独复核')
            paths.add(relative)
    if not paths:
        raise ValueError('补丁组没有可检查的文件')

    def command(tree, patch, reverse=False, check=False):
        args = ['git', '-C', str(tree), 'apply', '--whitespace=nowarn']
        if reverse:
            args.append('--reverse')
        if check:
            args.append('--check')
        return subprocess.run(args + [str(patch)], capture_output=True, text=True)

    with tempfile.TemporaryDirectory(prefix='musl-patch-series-') as temporary:
        temporary = Path(temporary)
        before, after, reverse = [temporary / name for name in ('before', 'after', 'reverse')]
        for tree in [before, after, reverse]:
            tree.mkdir()
            for relative in paths:
                source = root / relative
                if source.exists():
                    if not source.is_file():
                        raise ValueError(f'目标不是普通文件：{relative}')
                    dest = tree / relative
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, dest)
        # 后续补丁会修改前一份补丁的内容，不能逐份逆向检查最终树。
        if all(command(reverse, patch, reverse=True).returncode == 0
               for patch in reversed(patches)):
            print('ALREADY_APPLIED：完整补丁组已包含，自动跳过。')
            return 0
        for patch in patches:
            if command(after, patch, reverse=True, check=True).returncode == 0:
                continue
            result = command(after, patch)
            if result.returncode:
                raise ValueError(f'{patch.name}: {result.stderr}')
        diff = subprocess.run(['git', 'diff', '--no-index', '--binary', '--no-prefix', '--no-renames',
                               'before', 'after'], cwd=temporary, capture_output=True)
        if diff.returncode not in (0, 1):
            raise ValueError(diff.stderr.decode(errors='replace'))
        if not diff.stdout:
            print('ALREADY_APPLIED：补丁组未产生新差异。')
            return 0
        combined = temporary / 'combined.patch'
        combined.write_bytes(diff.stdout)
        result = command(root, combined, check=True)
        if result.returncode:
            raise ValueError(result.stderr)
        if apply:
            result = command(root, combined)
            if result.returncode:
                raise ValueError(result.stderr)
            print('APPLIED：补丁组完整预检通过，已应用最终差异。')
        else:
            print('APPLICABLE：补丁组完整预检通过；加 --apply 才写入目标。')
        return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True, help='目标源码或仓库目录')
    parser.add_argument('--patch', type=Path, required=True, action='append',
                        help='维护中的补丁；重复此参数时按顺序预检完整补丁组')
    parser.add_argument('--apply', action='store_true', help='检查通过后实际应用；默认只检查')
    args = parser.parse_args()
    root = args.root.resolve(strict=True)
    patches = [patch.resolve(strict=True) for patch in args.patch]
    if not root.is_dir() or not all(patch.is_file() for patch in patches):
        parser.error('目标必须是目录，补丁必须是普通文件')
    if len(patches) > 1:
        try:
            return series(root, patches, args.apply)
        except (ValueError, OSError) as error:
            print(f'INCOMPATIBLE：补丁组不能安全应用，目标未作部分修改：{error}', file=sys.stderr)
            return 2
    patch = patches[0]
    command = ['git', '-C', str(root), 'apply', '--whitespace=nowarn']
    reverse = subprocess.run(command + ['--reverse', '--check', str(patch)],
                             capture_output=True, text=True)
    if reverse.returncode == 0:
        print('ALREADY_APPLIED：目标已包含相同补丁，自动跳过。')
        return 0
    forward = subprocess.run(command + ['--check', str(patch)],
                             capture_output=True, text=True)
    if forward.returncode:
        print('INCOMPATIBLE：无法证明已修复，也不能安全应用；保持目标不变，请复核上游。', file=sys.stderr)
        print(forward.stderr, file=sys.stderr, end='')
        return 2
    if args.apply:
        # git apply 默认不使用 GNU patch 的模糊上下文，也不部分应用失败的补丁。
        applied = subprocess.run(command + [str(patch)], capture_output=True, text=True)
        if applied.returncode:
            print(applied.stderr, file=sys.stderr, end='')
            return applied.returncode
        print('APPLIED：补丁已应用。')
    else:
        print('APPLICABLE：可应用；加 --apply 才会写入目标。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
