#!/usr/bin/env python3
"""Gentoo musl PC only: route the VSCodium Flatpak Codex backend via optional Magpie.

This entry uses the installed Linux x86-64 extension and Linux memfd. It is
intended for chatgpt.cliExecutable, separate from the regular Codex CLI.
"""
import fcntl
from http.client import HTTPConnection, HTTPException
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib
from urllib.parse import urlencode


MAGPIE_ENDPOINTS = {
    'http://127.0.0.1:3425/v1',
    'http://127.0.0.1:3425/backend-api/codex',
}


def installed_binary(home):
    extensions = home / '.vscode-oss/extensions'
    candidates = []
    try:
        entries = json.loads((extensions / 'extensions.json').read_text())
        for entry in entries:
            if entry.get('identifier', {}).get('id', '').lower() != 'openai.chatgpt':
                continue
            relative = entry.get('relativeLocation')
            if isinstance(relative, str) and Path(relative).name == relative:
                candidates.append(extensions / relative)
    except (OSError, ValueError, AttributeError, TypeError):
        pass
    candidates.extend(sorted(extensions.glob('openai.chatgpt-*-linux-x64'),
                             key=lambda path: path.stat().st_mtime_ns, reverse=True))
    for extension in candidates:
        binary = extension / 'bin/linux-x86_64/codex'
        if os.access(binary, os.X_OK) and binary.is_file():
            return binary
    raise RuntimeError('No installed Linux Codex extension binary; install a compatible release')


def gateway_ready(model):
    connection = HTTPConnection('127.0.0.1', 3425, timeout=0.5)
    try:
        connection.request('GET', '/v1/models')
        response = connection.getresponse()
        if response.status != 200:
            return False
        payload = json.loads(response.read(2 * 1024 * 1024))
        models = payload.get('data') if isinstance(payload, dict) else None
        return isinstance(models, list) and any(
            isinstance(entry, dict) and entry.get('id') == model for entry in models)
    except (OSError, HTTPException, ValueError, TypeError):
        return False
    finally:
        connection.close()


def magpie_route(home):
    staging = home / '.var/app/local.yetone.Magpie/data/codex-staging'
    try:
        config = tomllib.loads((staging / 'config.toml').read_text())
    except (OSError, ValueError):
        return {}
    model = config.get('model')
    provider = config.get('model_provider', 'openai')
    providers = config.get('model_providers', {})
    gateway = providers.get('magpie', {}) if isinstance(providers, dict) else {}
    if not isinstance(gateway, dict):
        return {}
    if provider == 'magpie':
        endpoint = gateway.get('base_url')
    elif provider == 'openai':
        endpoint = config.get('openai_base_url')
    else:
        return {}
    if (not isinstance(model, str) or not model.strip()
            or not isinstance(endpoint, str) or endpoint.rstrip('/') not in MAGPIE_ENDPOINTS):
        return {}
    route = dict(model=model, model_provider=provider)
    if provider == 'openai':
        route['openai_base_url'] = endpoint
    else:
        if gateway.get('wire_api', 'responses') != 'responses':
            return {}
        route['model_providers'] = dict(magpie=dict(
            name='Magpie', base_url=endpoint, wire_api='responses',
            requires_openai_auth=gateway.get('requires_openai_auth', False)))
        for key in ('env_key', 'experimental_bearer_token', 'http_headers', 'env_http_headers'):
            if key in gateway:
                route['model_providers']['magpie'][key] = gateway[key]
    for key, expected in (
            ('model_reasoning_effort', str), ('model_verbosity', str),
            ('model_context_window', int), ('model_auto_compact_token_limit', int)):
        if key in config:
            if type(config[key]) is not expected:
                return {}
            route[key] = config[key]
    if 'model_catalog_json' in config:
        if not isinstance(config['model_catalog_json'], str):
            return {}
        catalog = Path(config['model_catalog_json'])
        if not catalog.is_absolute():
            catalog = staging / catalog
        if not catalog.is_file() or not catalog.resolve().is_relative_to(staging.resolve()):
            return {}
        route['model_catalog_json'] = str(catalog)
    if not gateway_ready(model):
        print('Magpie model unavailable; using the regular Codex configuration.', file=sys.stderr)
        return {}
    return route


def memory_catalog(home, binary, route, env):
    provider = route.get('model_providers', {}).get('magpie', {})
    headers = dict(provider.get('http_headers', {}))
    for name, variable in provider.get('env_http_headers', {}).items():
        if variable in env:
            headers[name] = env[variable]
    token = provider.get('experimental_bearer_token') or env.get(provider.get('env_key', ''))
    if route['model_provider'] == 'openai' or (not token and provider.get('requires_openai_auth')):
        auth = json.loads((home / '.codex/auth.json').read_text())
        tokens = auth.get('tokens') or {}
        token = tokens.get('access_token')
        account = tokens.get('account_id')
        if account:
            headers['ChatGPT-Account-Id'] = account
    if token:
        headers['Authorization'] = 'Bearer ' + token
    version = subprocess.run([str(binary), '--version'], capture_output=True, text=True,
                             check=True, timeout=5, env=env).stdout.split()[-1]
    connection = HTTPConnection('127.0.0.1', 3425, timeout=5)
    try:
        connection.request('GET', '/backend-api/codex/models?' + urlencode(
            dict(client_version=version)), headers=headers)
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError('Magpie model catalog unavailable')
        content = response.read(8 * 1024 * 1024 + 1)
    finally:
        connection.close()
    if len(content) > 8 * 1024 * 1024:
        raise ValueError('Magpie model catalog too large')
    catalog = json.loads(content)
    models = catalog.get('models') if isinstance(catalog, dict) else None
    if not isinstance(models, list) or not any(
            isinstance(model, dict) and model.get('slug') == route['model'] for model in models):
        raise ValueError('Selected Magpie model missing from catalog')
    descriptor = os.memfd_create('codex-magpie-models', os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
    try:
        with os.fdopen(os.dup(descriptor), 'wb') as output:
            output.write(content)
        os.lseek(descriptor, 0, os.SEEK_SET)
        fcntl.fcntl(descriptor, fcntl.F_ADD_SEALS,
                    fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL)
        os.set_inheritable(descriptor, True)
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def toml_value(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, int):
        return str(value)
    if isinstance(value, dict):
        return '{' + ', '.join(
            f'{json.dumps(key)} = {toml_value(item)}' for key, item in value.items()) + '}'
    raise ValueError('Unsupported Magpie routing value')


def routing_arguments(route, env):
    route = dict(route)
    if 'model_providers' in route:
        provider = dict(route['model_providers']['magpie'])
        token = provider.pop('experimental_bearer_token', None)
        if token is not None:
            if not isinstance(token, str):
                raise ValueError('Invalid Magpie gateway token')
            env['CODEX_RUNTIME_MAGPIE_TOKEN'] = token
            provider['env_key'] = 'CODEX_RUNTIME_MAGPIE_TOKEN'
            provider['requires_openai_auth'] = False
        headers = provider.pop('http_headers', {})
        env_headers = provider.get('env_http_headers', {})
        if not isinstance(headers, dict) or not isinstance(env_headers, dict):
            raise ValueError('Invalid Magpie gateway headers')
        env_headers = dict(env_headers)
        for index, (name, value) in enumerate(headers.items()):
            if not isinstance(value, str):
                raise ValueError('Invalid Magpie gateway header')
            variable = f'CODEX_RUNTIME_MAGPIE_HEADER_{index}'
            env[variable] = value
            env_headers[name] = variable
        if env_headers:
            provider['env_http_headers'] = env_headers
        del route['model_providers']
        route['model_providers.magpie'] = provider
    arguments = []
    for key, value in route.items():
        arguments.extend(['-c', f'{key}={toml_value(value)}'])
    return arguments


def explicit_routing(arguments):
    for index, argument in enumerate(arguments):
        if argument in ('-m', '--model', '-p', '--profile', '--oss', '--local-provider'):
            return True
        if argument.startswith(('--model=', '--profile=', '--local-provider=')):
            return True
        value = None
        if argument in ('-c', '--config') and index + 1 < len(arguments):
            value = arguments[index + 1]
        elif argument.startswith('--config='):
            value = argument[len('--config='):]
        elif argument.startswith('-c') and len(argument) > 2:
            value = argument[2:]
        if value and value.split('=', 1)[0].strip().startswith(
                ('model', 'openai_base_url', 'chatgpt_base_url')):
            return True
    return False


def main():
    home = Path.home()
    arguments = sys.argv[1:]
    check = arguments == ['--check']
    env = dict(os.environ, CODEX_HOME=str(home / '.codex'))
    bypass = []
    for value in (env.get('no_proxy', ''), env.get('NO_PROXY', ''), 'localhost,127.0.0.1,::1'):
        for entry in value.split(','):
            entry = entry.strip()
            if entry and entry not in bypass:
                bypass.append(entry)
    env['no_proxy'] = env['NO_PROXY'] = ','.join(bypass)
    route = {}
    descriptor = None
    administrative = ('login', 'logout', 'completion', 'update', 'mcp', 'plugin')
    try:
        binary = installed_binary(home)
        if (not explicit_routing(arguments)
                and not any(argument in ('-h', '--help', '-V', '--version') for argument in arguments)
                and (not arguments or arguments[0] not in administrative)):
            route = magpie_route(home)
        if route and 'model_catalog_json' not in route:
            try:
                descriptor = memory_catalog(home, binary, route, env)
                route['model_catalog_json'] = f'/proc/self/fd/{descriptor}'
            except (OSError, ValueError, HTTPException, subprocess.SubprocessError,
                    IndexError, TypeError, AttributeError):
                print('Magpie model catalog unavailable; using the regular Codex configuration.',
                      file=sys.stderr)
                route = {}
        overrides = routing_arguments(route, env)
        if check:
            print(json.dumps(dict(binary=str(binary), codex_home=env['CODEX_HOME'],
                                  routing='magpie' if route else 'regular',
                                  model=route.get('model'),
                                  memory_catalog=descriptor is not None), ensure_ascii=False))
            return
        os.execve(binary, [str(binary), *overrides, *arguments], env)
    except (OSError, ValueError, RuntimeError) as error:
        sys.exit(f'Unable to start Codex: {error}')
    finally:
        if descriptor is not None:
            os.close(descriptor)


if __name__ == '__main__':
    main()
