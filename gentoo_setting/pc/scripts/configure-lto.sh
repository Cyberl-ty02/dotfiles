#!/usr/bin/env bash
set -euo pipefail
mode=thin
major=
dry_run=false
while (( $# )); do
    case "$1" in
        --mode) mode=${2:?Missing mode}; shift 2 ;;
        --clang-major) major=${2:?Missing Clang major}; shift 2 ;;
        --dry-run) dry_run=true; shift ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[[ "$mode" == thin || "$mode" == off ]] || { printf 'Choose thin or off\n' >&2; exit 2; }
if [[ -z "$major" ]]; then major=$(clang -dumpversion); major=${major%%.*}; fi
[[ "$major" =~ ^[0-9]+$ ]] || { printf 'Invalid Clang major\n' >&2; exit 2; }
if ! "$dry_run"; then
    (( EUID == 0 )) || { printf 'Run as root inside the target system/chroot.\n' >&2; exit 2; }
fi
python3 - "$major" "$mode" "$dry_run" <<'CONFIG'
from pathlib import Path
import datetime, os, re, shutil, subprocess, sys, tempfile
major,mode,dry=sys.argv[1:]
make=Path('/etc/portage/make.conf');envfile=Path('/etc/env.d/99toolchain-lto')
if not make.is_file():raise SystemExit('Target Portage make.conf missing.')
if make.is_symlink() or envfile.is_symlink():raise SystemExit('Refusing symlinked configuration files.')
old=make.read_text();begin='# BEGIN managed-thin-lto';end='# END managed-thin-lto'
if begin in old and (old.count(begin)!=1 or old.count(end)!=1):raise SystemExit('Malformed LTO block in make.conf.')
block=begin+'\nCFLAGS="${CFLAGS} -flto=thin"\nCXXFLAGS="${CXXFLAGS} -flto=thin"\nLDFLAGS="${LDFLAGS} -flto=thin -Wl,--plugin-opt=jobs=2"\nCARGO_PROFILE_RELEASE_LTO="thin"\n'+end+'\n'
named=re.search(r'^CLANG_LTO_FLAGS="[^"\n]*"$',old,re.M)
if named:
 if begin in old:raise SystemExit('Ambiguous LTO settings in make.conf.')
 new=old
 for key,value in [('CLANG_LTO_FLAGS','-flto=thin' if mode=='thin' else ''),('CLANG_LTO_LINK_FLAGS','-Wl,--plugin-opt=jobs=2' if mode=='thin' else ''),('CARGO_PROFILE_RELEASE_LTO','thin' if mode=='thin' else 'false')]:
  if len(re.findall('^'+key+'=',old,re.M))!=1:raise SystemExit('Missing or repeated '+key)
  new=re.sub('^'+key+r'="[^"\n]*"$',lambda m:key+'="'+value+'"',new,flags=re.M)
elif begin in old:new=re.sub(re.escape(begin)+r'\n.*?'+re.escape(end)+r'\n?',lambda m:block if mode=='thin' else '',old,flags=re.S)
elif mode=='thin':new=old.rstrip()+'\n\n'+block
else:new=old
marker='# Managed by configure-lto.sh'
old_env=envfile.read_text() if envfile.exists() else None
if old_env is not None and not old_env.startswith(marker):raise SystemExit('Existing LTO environment file is not managed by this script.')
new_env=marker+'\nCARGO_PROFILE_RELEASE_LTO="thin"\n' if mode=='thin' else None
print(('Would set ' if dry=='true' else 'Requested ')+mode+' LTO for native C/C++ and Cargo release builds.')
if dry=='true':raise SystemExit(0)
if mode=='thin':
 cc=Path('/usr/lib/llvm')/major/'bin/clang'
 if not cc.is_file():raise SystemExit('Requested Clang compiler missing.')
 # Prove the active linker can consume bitcode before touching defaults.
 with tempfile.TemporaryDirectory(prefix='lto-preflight-',dir='/var/tmp') as d:
  src=Path(d)/'probe.c';exe=Path(d)/'probe';src.write_text('int main(void){return 0;}\n')
  subprocess.run([str(cc),'-O2','-flto=thin','-Wl,--plugin-opt=jobs=2',str(src),'-o',str(exe)],check=True)
  subprocess.run([str(exe)],check=True)
changes=[(make,old,new),(envfile,old_env,new_env)]
changed=[x for x in changes if x[1]!=x[2]]
if changed:
 backup=Path('/var/backups/lto-setup')/datetime.datetime.now().strftime('%Y%m%dT%H%M%S%f');backup.mkdir(parents=True,mode=0o700)
 for path,old_data,new_data in changed:
  if old_data is not None:
   dest=backup/path.relative_to('/');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,dest)
  if new_data is None:path.unlink(missing_ok=True);continue
  path.parent.mkdir(parents=True,exist_ok=True)
  fd,name=tempfile.mkstemp(prefix='.'+path.name+'.',dir=path.parent)
  try:
   with os.fdopen(fd,'w') as stream:stream.write(new_data)
   os.chmod(name,path.stat().st_mode & 0o777 if path.exists() else 0o644);os.replace(name,path)
  finally:
   if os.path.exists(name):os.unlink(name)
 subprocess.run(['env-update'],check=True)
 print('Previous configuration saved to '+str(backup))
else:print('Configuration unchanged.')
CONFIG
