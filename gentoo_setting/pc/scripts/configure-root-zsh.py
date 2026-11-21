#!/usr/bin/env python3
"""Copy an installed user's Zsh setup to root; dry-run unless --apply.

Uses root-owned snapshots, not links into a writable user home. Works in a
prepared chroot too: install zsh, util-linux and shadow, and provide the user's
existing Zim modules first. Does not download plugins or copy user history.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import pwd
import signal
import shutil
import subprocess
import tempfile
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--user', default='lty')
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    user = pwd.getpwnam(args.user)
    root = pwd.getpwnam('root')
    if user.pw_uid == 0 or root.pw_dir != '/root':
        ap.error('Expected a non-root source user and root HOME /root')
    home = Path(user.pw_dir)
    files = ['.zshrc', '.zimrc', '.p10k.zsh']
    zim = home / '.zim'
    cache = home / '.cache/gitstatus/gitstatusd-linux-x86_64'
    for f in files + ['.zim/zimfw.zsh', '.zim/init.zsh']:
        if not (home / f).is_file() or (home / f).is_symlink():
            ap.error(f'Missing regular source file: {home / f}')
    if not zim.is_dir() or zim.is_symlink():
        ap.error('Expected installed Zim modules, not a directory symlink')
    for base, dirs, names in os.walk(zim):
        dirs[:] = [d for d in dirs if d != '.git']
        for name in dirs + names:
            p = Path(base) / name
            if p.is_symlink() and (os.path.isabs(os.readlink(p)) or
                                   not p.resolve().is_relative_to(zim.resolve())):
                ap.error(f'Module symlink must stay relative and internal: {p}')
    for command in ['zsh', 'usermod', 'unshare', 'env']:
        if not shutil.which(command):
            ap.error(f'Required command missing: {command}')
    shell = str(Path(shutil.which('zsh')).resolve())
    if shell not in Path('/etc/shells').read_text().splitlines():
        ap.error('zsh must already be registered in /etc/shells')
    plan = dict(source_user=args.user, source_home=str(home), target_home='/root',
                shell=shell, files=files, modules='root-owned copy without .git/.old/.zwc',
                copy_gitstatus_cache=cache.is_file())
    if not args.apply:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return
    if os.getuid() != 0:
        ap.error('--apply requires root')
    for parent in [Path('/root/.cache'), Path('/root/.cache/gitstatus')]:
        if parent.is_symlink():
            ap.error(f'Root cache directory symlink needs review: {parent}')
    backup = Path('/var/lib/musl-migration/root-zsh') / time.strftime('%Y%m%dT%H%M%S')
    backup.mkdir(parents=True, mode=0o700, exist_ok=False)
    backup.parent.chmod(0o700)
    (backup / 'original-shell.txt').write_text(root.pw_shell + '\n')
    stage = Path(tempfile.mkdtemp(prefix='.root-zsh-stage-', dir='/root'))
    target = Path('/root')
    changed = []
    cache_target = target / '.cache/gitstatus/gitstatusd-linux-x86_64'
    cache_saved = False
    cache_changed = False
    env = dict(HOME='/root', USER='root', LOGNAME='root', SHELL=shell,
               PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
               TERM='xterm-256color', LANG='zh_CN.UTF-8', ZIM_HOME='/root/.zim')
    def run(argv):
        command = ['unshare', '--net', '--', 'env', '-i',
                   *[f'{k}={v}' for k, v in env.items()], *argv]
        # A regular log file avoids pipe EOF waits caused by background shell jobs.
        with tempfile.TemporaryFile(mode='w+t') as log:
            proc = subprocess.Popen(command, cwd='/root', stdout=log,
                                    stderr=subprocess.STDOUT, start_new_session=True)
            try:
                proc.wait(timeout=90)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGTERM)
                proc.wait(timeout=10)
                raise
            log.seek(0)
            output = log.read()
        if proc.returncode:
            raise subprocess.CalledProcessError(proc.returncode, command,
                                                output=output, stderr='')
        return subprocess.CompletedProcess(command, proc.returncode, output, '')
    try:
        for name in files:
            shutil.copy2(home / name, stage / name)
        shutil.copytree(zim, stage / '.zim', symlinks=True,
                        ignore=shutil.ignore_patterns('.git', '*.old', '*.zwc'))
        for base, dirs, names in os.walk(stage):
            for name in dirs + names:
                p = Path(base) / name
                os.chown(p, 0, 0, follow_symlinks=False)
                if not p.is_symlink():
                    p.chmod(p.stat().st_mode & 0o777 & ~0o022)
        # Move previous root-only files intact into a private rollback directory.
        for name in files + ['.zim']:
            dest = target / name
            if dest.exists() or dest.is_symlink():
                dest.rename(backup / name)
            changed.append(name)
            (stage / name).rename(dest)
        if cache.is_file() and not cache.is_symlink():
            cache_target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            if cache_target.exists() or cache_target.is_symlink():
                cache_target.rename(backup / 'gitstatusd.previous')
                cache_saved = True
            shutil.copyfile(cache, cache_target)
            cache_changed = True
            cache_target.chmod(0o700)
            os.chown(cache_target, 0, 0)
        build = run([shell, '-fc', 'zstyle ":zim" disable-version-check yes; source /root/.zim/zimfw.zsh build'])
        for name in files:
            run([shell, '-n', str(target / name)])
        # Offline login probe: catches cross-user HOME/history and missing modules.
        probe = run([shell, '-lic',
                     '[[ $EUID == 0 && $HOME == /root && $ZIM_HOME == /root/.zim '
                     '&& $HISTFILE == /root/.zhistory && $EDITOR == neomacs ]] '
                     '&& (( $+functions[proxy] && $+functions[nproxy] '
                     '&& $+functions[p10k] )) || exit 21; '
                     '[[ $PATH != *"/home/"* ]] || exit 22; '
                     'SAVEHIST=0; print -r -- ROOT_ZSH_OK'])
        if 'ROOT_ZSH_OK' not in probe.stdout:
            raise RuntimeError('Missing login probe completion marker')
        subprocess.run(['usermod', '--shell', shell, 'root'], check=True)
        actual = pwd.getpwnam('root')
        if actual.pw_shell != shell or actual.pw_dir != '/root':
            raise RuntimeError('Root account shell verification failed')
        hashes = {name: hashlib.sha256((target / name).read_bytes()).hexdigest()
                  for name in files}
        assert all(hashes[name] == hashlib.sha256((home / name).read_bytes()).hexdigest()
                   for name in files), 'Source changed during copy; retry after review'
        result = dict(completed=True, **plan, backup=str(backup),
                      source_config_hashes=hashes, offline_login_probe=True)
        (backup / 'build.log').write_text(build.stdout + build.stderr)
        (backup / 'probe.log').write_text(probe.stdout + probe.stderr)
        (backup / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except BaseException as error:
        print(str(getattr(error, 'stdout', '') or ''), flush=True)
        (backup / 'failure.log').write_text(str(error) + '\n' +
                                            str(getattr(error, 'stdout', '') or '') +
                                            str(getattr(error, 'stderr', '') or ''))
        subprocess.run(['usermod', '--shell', root.pw_shell, 'root'], check=True)
        for name in reversed(changed):
            dest = target / name
            if dest.is_dir() and not dest.is_symlink():
                shutil.rmtree(dest)
            elif dest.exists() or dest.is_symlink():
                dest.unlink()
            saved = backup / name
            if saved.exists() or saved.is_symlink():
                saved.rename(dest)
        if cache_changed:
            cache_target.unlink(missing_ok=True)
        if cache_saved:
            (backup / 'gitstatusd.previous').rename(cache_target)
        raise
    finally:
        shutil.rmtree(stage)


if __name__ == '__main__':
    main()
