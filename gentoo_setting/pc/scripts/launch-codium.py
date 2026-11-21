#!/usr/bin/env python3
"""Native CLI entry for Flatpak VSCodium; forward the calling shell's proxy only."""
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit


def main():
    command = ['flatpak', 'run']
    for key in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy',
                'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY'):
        if key in os.environ:
            command.append('--env=' + key + '=' + os.environ[key])
    command += ['com.vscodium.codium']
    proxy = os.environ.get('https_proxy') or os.environ.get('http_proxy')
    if proxy and not any(a.startswith('--proxy-server') for a in sys.argv[1:]):
        value = urlsplit(proxy)
        if value.scheme not in ('http', 'https', 'socks5') or not value.hostname or value.username:
            sys.exit('Unsupported Chromium proxy URL; use an HTTP proxy without embedded credentials.')
        command.append('--proxy-server=' + proxy)
        bypass = os.environ.get('no_proxy') or os.environ.get('NO_PROXY')
        if bypass:
            command.append('--proxy-bypass-list=' + bypass.replace(',', ';'))
    if '--migration-check' in sys.argv[1:]:
        print('Flatpak VSCodium entry ready; proxy configured: ' + str(bool(proxy)))
        return
    os.execvp(command[0], command + sys.argv[1:])


if __name__ == '__main__':
    main()
