#!/usr/bin/env python3
"""Run the locally installed Codex in a native terminal, without Flatpak hooks.

Discover the current extension installation instead of pinning its release path.
Default: show the session picker. --new starts a new session in the configuration
repository; read AGENTS.md and the private migration checkpoint to continue.
"""
import argparse
import json
import os
from pathlib import Path
import pwd
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--new', action='store_true', help='Start a new session instead of resuming')
    parser.add_argument('--check', action='store_true', help='Only report the selected installed binary')
    args, extra = parser.parse_known_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    extension_dir = home / '.vscode-oss/extensions'
    index = extension_dir / 'extensions.json'
    candidates = []
    if index.is_file():
        for entry in json.loads(index.read_text()):
            if entry.get('identifier', {}).get('id', '').lower() != 'openai.chatgpt': continue
            relative = entry.get('relativeLocation')
            if relative and Path(relative).name == relative:
                candidates.append(extension_dir / relative)
    if not candidates:
        candidates = sorted(extension_dir.glob('openai.chatgpt-*-linux-x64'),
                            key=lambda p: p.stat().st_mtime_ns, reverse=True)
    binary = next((p / 'bin/linux-x86_64/codex' for p in candidates
                   if os.access(p / 'bin/linux-x86_64/codex', os.X_OK)), None)
    if binary is None:
        parser.error('No installed Linux Codex extension binary; preserve data and install a compatible release')
    repository = home / 'source/repos/dotfiles'
    if args.check:
        print(json.dumps(dict(binary=str(binary),repository=str(repository),flatpak_bridge=False)))
        return
    env = dict(os.environ, HOME=str(home), CODEX_HOME=str(home / '.codex'))
    for folder in ['tmp', 'ipc', 'shell_snapshots', 'thread-writer-locks']:
        (home / '.codex' / folder).mkdir(parents=True, exist_ok=True, mode=0o700)
    if repository.is_dir() and not args.new: os.chdir(repository)
    # Extension builds can omit the standalone daemon package. Use their supported
    # in-process mode, without changing sandbox/approval policy or installing glibc.
    help_result = subprocess.run([str(binary), '--help'], capture_output=True,
                                 text=True, timeout=15, env=env)
    mode = ['--no-daemon'] if '--no-daemon' in help_result.stdout else []
    command = [str(binary)] + mode + ([] if args.new else ['resume', '--all', '--include-non-interactive']) + extra
    try: os.execve(binary, command, env)
    except OSError as error:
        parser.exit(2, f'Unable to run installed Codex ({error.strerror}); do not add a global glibc loader alias.\n')


if __name__ == '__main__':
    main()
