#!/usr/bin/env python3
"""Import an exported profile into a private VSCodium User directory.

Use on a staged/offline profile. Extension installation is separate; report
JDK25 providers rather than enabling them. Never import authentication storage
from exported globalState. --apply is required to write destination files.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', type=Path, required=True)
    parser.add_argument('--user-dir', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--uid', type=int, help='Defaults to exported profile owner')
    parser.add_argument('--gid', type=int, help='Defaults to exported profile group')
    args = parser.parse_args()
    args.uid = args.profile.stat().st_uid if args.uid is None else args.uid
    args.gid = args.profile.stat().st_gid if args.gid is None else args.gid
    raw = args.profile.read_bytes(); profile = json.loads(raw)
    settings = json.loads(json.loads(profile['settings'])['settings'])
    bindings = json.loads(profile.get('keybindings', '{}')).get('keybindings', '[]')
    tasks = json.loads(profile.get('tasks', '{}')).get('tasks', '{}')
    json.loads(bindings); json.loads(tasks)
    extensions = json.loads(profile['extensions'])
    requested = [e['identifier']['id'].lower() for e in extensions]
    deferred = [i for i in requested if i == 'redhat.java' or i.startswith('vscjava.')]
    # Source configuration may name GNU Emacs/GCC; use the accepted musl tools.
    for language, command in settings.get('code-runner.executorMap', {}).items():
        if isinstance(command, str):
            command = re.sub(r'(?<![\w-])g\+\+(?![\w+])', 'clang++', command)
            command = re.sub(r'(?<![\w-])gcc(?![\w-])', 'clang', command)
            settings['code-runner.executorMap'][language] = command
    java = settings.get('[java]', {})
    if java.get('editor.defaultFormatter') == 'redhat.java':
        java.pop('editor.defaultFormatter')
    storage = json.loads(profile.get('globalState', '{}')).get('storage', {})
    # Exported UI preferences are useful; credentials and machine runtime paths
    # must remain in the separately preserved original profile.
    safe_storage = {k: v for k, v in storage.items() if not any(
        word in k.lower() for word in ('secret', 'token', 'auth', 'credential', 'userdataprofiles'))}
    result = dict(applied=args.apply, source_sha256=hashlib.sha256(raw).hexdigest(),
                  settings=len(settings), requested_extensions=requested,
                  deferred_jvm25_extensions=deferred, global_ui_entries=len(safe_storage))
    if args.apply:
        missing = []; current = args.user_dir
        while not current.exists(): missing.append(current); current = current.parent
        args.user_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        for directory in missing: os.chown(directory, args.uid, args.gid)
        for name, contents in [('settings.json', json.dumps(settings, ensure_ascii=False, indent=2)+'\n'),
                               ('keybindings.json', bindings), ('tasks.json', tasks)]:
            path = args.user_dir / name
            if path.is_symlink(): raise ValueError('Refuse symlink profile output')
            if path.exists():
                backup = path.with_name(path.name + '.pre-code-profile')
                if not backup.exists(): backup.write_bytes(path.read_bytes()); backup.chmod(0o600); os.chown(backup, args.uid, args.gid)
            path.write_text(contents); path.chmod(0o600); os.chown(path, args.uid, args.gid)
        directory = args.user_dir / 'globalStorage'; directory.mkdir(exist_ok=True, mode=0o700); os.chown(directory, args.uid, args.gid)
        db = directory / 'state.vscdb'
        if db.is_symlink(): raise ValueError('Refuse symlink globalStorage database')
        with sqlite3.connect(db) as connection:
            connection.execute('CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)')
            connection.executemany('INSERT OR REPLACE INTO ItemTable(key,value) VALUES (?,?)',
                                   [(k, str(v) if isinstance(v, str) else json.dumps(v)) for k, v in safe_storage.items()])
            assert connection.execute('PRAGMA quick_check').fetchall() == [('ok',)]
        db.chmod(0o600); os.chown(db, args.uid, args.gid)
    fd = os.open(args.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream: json.dump(result, stream, ensure_ascii=False, indent=2); stream.write('\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('requested_extensions',)}))


if __name__ == '__main__':
    main()
