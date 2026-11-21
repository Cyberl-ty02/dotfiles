#!/usr/bin/env bash
set -euo pipefail
linker=mold
major=
dry_run=false
while (( $# )); do
    case "$1" in
        --linker) linker=${2:?Missing linker}; shift 2 ;;
        --clang-major) major=${2:?Missing Clang major}; shift 2 ;;
        --dry-run) dry_run=true; shift ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[[ "$linker" == mold || "$linker" == lld ]] || { printf 'Choose mold or lld\n' >&2; exit 2; }
if [[ -z "$major" ]]; then major=$(clang -dumpversion); major=${major%%.*}; fi
[[ "$major" =~ ^[0-9]+$ ]] || { printf 'Invalid Clang major\n' >&2; exit 2; }
if ! "$dry_run"; then
    (( EUID == 0 )) || { printf 'Run as root inside the target system/chroot.\n' >&2; exit 2; }
    command -v "ld.$linker" >/dev/null || { printf 'Install the selected linker first.\n' >&2; exit 127; }
fi
python3 - "$major" "$linker" "$dry_run" <<'CONFIG'
from pathlib import Path
import datetime, os, re, shutil, sys, tempfile
major,linker,dry=sys.argv[1:]
cfg=Path('/etc/clang')/major/'gentoo-linker.cfg'
make=Path('/etc/portage/make.conf')
if not cfg.is_file() or not make.is_file():raise SystemExit('Target Clang configuration or Portage make.conf missing.')
old_cfg=cfg.read_text();old_make=make.read_text()
lines=old_cfg.splitlines()
active=[x.strip() for x in lines if x.strip() and not x.lstrip().startswith('#')]
if len(active)!=1 or not active[0].startswith('-fuse-ld='):
 raise SystemExit('Unexpected Clang linker configuration; review it before changing the default.')
new_cfg='\n'.join('-fuse-ld='+linker if x.strip()==active[0] else x for x in lines)+'\n'
begin='# BEGIN managed-default-linker';end='# END managed-default-linker'
block=begin+'\nLD="ld.'+linker+'"\n'+end+'\n'
if re.search(r'^DEFAULT_LINKER="[^"\n]*"$',old_make,re.M):
 if len(re.findall(r'^DEFAULT_LINKER=',old_make,re.M))!=1 or begin in old_make:
  raise SystemExit('Ambiguous linker settings in make.conf.')
 new_make=re.sub(r'^DEFAULT_LINKER="[^"\n]*"$',lambda m:'DEFAULT_LINKER="'+linker+'"',old_make,flags=re.M)
elif begin in old_make:
 if old_make.count(begin)!=1 or old_make.count(end)!=1:raise SystemExit('Malformed linker block in make.conf.')
 new_make=re.sub(re.escape(begin)+r'\n.*?'+re.escape(end)+r'\n?',lambda m:block,old_make,flags=re.S)
else:new_make=old_make.rstrip()+'\n\n'+block
changes=[(cfg,old_cfg,new_cfg),(make,old_make,new_make)]
for path,old,new in changes:print(('Would update ' if dry=='true' else 'Target ')+str(path)+' -> '+linker+(' (unchanged)' if old==new else ''))
if dry=='true':raise SystemExit(0)
changed=[x for x in changes if x[1]!=x[2]]
if changed:
 backup=Path('/var/backups/linker-setup')/datetime.datetime.now().strftime('%Y%m%dT%H%M%S%f')
 backup.mkdir(parents=True,mode=0o700)
 for path,old,new in changed:
  dest=backup/path.relative_to('/');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,dest)
  fd,name=tempfile.mkstemp(prefix='.'+path.name+'.',dir=path.parent)
  try:
   with os.fdopen(fd,'w') as stream:stream.write(new)
   os.chmod(name,path.stat().st_mode & 0o777);os.replace(name,path)
  finally:
   if os.path.exists(name):os.unlink(name)
 print('Previous configuration saved to '+str(backup))
CONFIG
