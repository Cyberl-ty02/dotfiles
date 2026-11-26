#!/usr/bin/env python3
"""Preview, deploy or remove the PC's optional Portage xmake forwarding policy."""
import argparse
import os
from pathlib import Path
import sys

MARKER = "# Managed by configure-portage-xmake.py\n"
POLICY = MARKER + """*/* xmake-bridge
dev-build/make xmake-original
dev-build/xmake xmake-original
sys-apps/portage xmake-original
sys-boot/* xmake-original
sys-kernel/* xmake-original
x11-drivers/nvidia-drivers xmake-original
"""
ENABLED = MARKER + 'MAKE="/usr/local/libexec/portage-xmake/make"\nXMAKE_PORTAGE_BRIDGE="yes"\n'
DISABLED = MARKER + 'MAKE="make"\nXMAKE_PORTAGE_BRIDGE="no"\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=Path("/"))
    ap.add_argument("--apply", action="store_true", help="write after all preflight checks")
    ap.add_argument("--remove", action="store_true", help="remove only managed policy files")
    args = ap.parse_args()
    root = args.root.resolve()
    base = Path(__file__).resolve().parent.parent
    runtime = base / "patchsets/xmake-trybuild/runtime"
    lib = root / "usr/local/libexec/portage-xmake"
    entries = {
        root / "etc/portage/bashrc": ((runtime / "portage.bashrc").read_bytes(), 0o644),
        root / "etc/portage/package.env/40-xmake-bridge": (POLICY.encode(), 0o644),
        root / "etc/portage/env/xmake-bridge": (ENABLED.encode(), 0o644),
        root / "etc/portage/env/xmake-original": (DISABLED.encode(), 0o644),
        lib / "backend.lua": ((runtime / "backend.lua").read_bytes(), 0o644),
        lib / "make": ((runtime / "driver").read_bytes(), 0o755),
        lib / "ninja": ((runtime / "driver").read_bytes(), 0o755),
    }
    for path, (content, _) in entries.items():
        if path.is_symlink():
            ap.error(f"Refuse symlink target: {path}")
        if path.exists() and path.read_bytes() != content:
            # Do not clobber local edits, credentials, or files owned by another policy.
            ap.error(f"Existing file differs; review before changing: {path}")
    for path in entries:
        temp = path.with_name(path.name + ".xmake-new")
        if temp.exists() or temp.is_symlink():
            ap.error(f"Unexpected temporary path: {temp}")
    print(("Remove" if args.remove else "Deploy") + f" {len(entries)} managed files")
    if not args.apply:
        print("Preview only; add --apply to write.")
        return
    if root == Path("/") and os.geteuid() != 0:
        ap.error("Applying to the running system requires root")
    if root == Path("/"):
        for process in Path("/proc").iterdir():
            if not process.name.isdigit():
                continue
            try:
                argv = (process / "cmdline").read_bytes().split(b"\0")
            except (FileNotFoundError, PermissionError, ProcessLookupError):
                continue
            if any(Path(os.fsdecode(arg)).name in {"emerge", "ebuild"}
                   for arg in argv[:2]):
                ap.error("A Portage writer is active; wait before changing executors")
    # Executors and envs must exist before the package.env selector becomes active.
    selector = root / "etc/portage/package.env/40-xmake-bridge"
    ordered = [p for p in entries if p != selector] + [selector]
    if args.remove:
        ordered = [selector] + [p for p in entries if p != selector]
    for path in ordered:
        content, mode = entries[path]
        if args.remove:
            path.unlink(missing_ok=True)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_name(path.name + ".xmake-new")
            if temp.exists() or temp.is_symlink():
                ap.error(f"Unexpected temporary path: {temp}")
            temp.write_bytes(content)
            temp.chmod(mode)
            temp.replace(path)
    print("Applied. GNU Make/Ninja remain installed; no package was built or merged.")


if __name__ == "__main__":
    main()
