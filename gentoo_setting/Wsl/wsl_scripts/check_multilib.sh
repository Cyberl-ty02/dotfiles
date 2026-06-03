#!/usr/bin/env bash
set -euo pipefail

echo "== Current profile =="
eselect profile show || true

echo
if eselect profile show 2>/dev/null | grep -qi 'no-multilib'; then
  echo "WARN: current profile looks like no-multilib. ABI_X86=\"64 32\" will not work correctly."
  echo "Choose a multilib amd64 profile, e.g. default/linux/amd64/23.0[/llvm], then rebuild."
else
  echo "OK: profile does not look like no-multilib."
fi

echo
if command -v gcc >/dev/null 2>&1; then
  echo "== GCC multilib smoke test =="
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  echo 'int main(){return 0;}' > "$tmpdir/test.c"
  if gcc -m32 "$tmpdir/test.c" -o "$tmpdir/test32" >/dev/null 2>&1; then
    file "$tmpdir/test32"
    echo "OK: gcc -m32 works."
  else
    echo "WARN: gcc -m32 failed. Multilib userland may be incomplete."
  fi
fi
