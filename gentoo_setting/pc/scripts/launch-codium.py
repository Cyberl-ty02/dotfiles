#!/usr/bin/env python3
"""Gentoo musl PC launcher for VSCodium Flatpak and the shared Codex home.

Carries the shell proxy into the Flatpak and exposes the local IDE backend
and optional Magpie staging profile to it.
"""
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit


def main():
    home = Path.home()
    command = ['flatpak', 'run', f'--filesystem={home / ".codex"}',
               f'--env=CODEX_HOME={home / ".codex"}',
               f'--filesystem={home / ".local/bin"}:ro',
               f'--filesystem={home / ".vscode-oss/extensions"}:ro']
    staging = home / '.var/app/local.yetone.Magpie/data/codex-staging'
    if staging.is_dir():
        command.append(f'--filesystem={staging}:ro')
    bypass = []
    for value in (os.environ.get('no_proxy', ''), os.environ.get('NO_PROXY', ''),
                  'localhost,127.0.0.1,::1'):
        for entry in value.split(','):
            entry = entry.strip()
            if entry and entry not in bypass:
                bypass.append(entry)
    for key in ('no_proxy', 'NO_PROXY'):
        os.environ[key] = ','.join(bypass)
    for key in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy',
                'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY'):
        if key in os.environ:
            command.append('--env=' + key + '=' + os.environ[key])
    app_args = []
    proxy = (os.environ.get('https_proxy') or os.environ.get('HTTPS_PROXY')
             or os.environ.get('http_proxy') or os.environ.get('HTTP_PROXY'))
    if proxy:
        value = urlsplit(proxy)
        if value.scheme not in ('http', 'https', 'socks5') or not value.hostname or value.username:
            sys.exit('Unsupported Chromium proxy URL; use an HTTP proxy without embedded credentials.')
        if value.scheme in ('http', 'https'):
            # Chromium's proxy flag does not configure native Node fetch in LSPs.
            command.append('--env=NODE_USE_ENV_PROXY=1')
            for upper in ('HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY'):
                if upper.lower() in os.environ and upper not in os.environ:
                    command.append('--env=' + upper + '=' + os.environ[upper.lower()])
        if not any(a.startswith('--proxy-server') for a in sys.argv[1:]):
            app_args.append('--proxy-server=' + proxy)
        bypass = os.environ.get('no_proxy') or os.environ.get('NO_PROXY')
        if bypass:
            app_args.append('--proxy-bypass-list=' + bypass.replace(',', ';'))
    if '--migration-check' in sys.argv[1:]:
        print('Flatpak VSCodium entry ready; proxy configured: ' + str(bool(proxy)))
        return
    command += ['com.vscodium.codium'] + app_args
    os.execvp(command[0], command + sys.argv[1:])


if __name__ == '__main__':
    main()
