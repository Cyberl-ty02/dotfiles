#!/usr/bin/env python3
"""Collect local first-boot identity evidence; --offline never asserts a real boot."""
from __future__ import annotations

import argparse
import datetime
import json
import os
import pwd
from pathlib import Path
import shutil
import subprocess
import tempfile


def command(*args: str) -> dict:
    if not shutil.which(args[0]):
        return {"available": False, "exit": None, "output": ""}
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=30)
        return {"available": True, "exit": result.returncode,
                "output": (result.stdout + result.stderr).strip()}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"available": True, "exit": None, "error": type(error).__name__}


def text(path: str) -> str | None:
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="For chroot/install checks; never claim a real boot")
    parser.add_argument("--expected-root", default="@musl")
    parser.add_argument("--expected-home", default="@home-musl")
    parser.add_argument("--expected-user-home", type=Path, help="Expected HOME; defaults to the expected account home")
    parser.add_argument("--expected-uid", type=int, default=1000)
    parser.add_argument("--kernel-tag", default="musl")
    parser.add_argument("--check-runtimes", action="store_true", help="Also read Java, editor, linker and system Flatpak versions")
    parser.add_argument("--output", type=Path, help="Save a private JSON report; otherwise print to stdout")
    args = parser.parse_args()
    root = command("findmnt", "-n", "-o", "FSROOT", "-T", "/")
    home = command("findmnt", "-n", "-o", "FSROOT", "-T", "/home")
    libc = command("portageq", "envvar", "ELIBC")
    release = os.uname().release
    user_home = os.environ.get("HOME", "")
    expected_user_home = args.expected_user_home or Path(pwd.getpwuid(args.expected_uid).pw_dir)
    checks = {
        "target_kernel": bool(args.kernel_tag) and args.kernel_tag in release.split("-"),
        "root_subvolume": root.get("exit") == 0 and root["output"] == "/" + args.expected_root.lstrip("/"),
        "home_subvolume": home.get("exit") == 0 and home["output"] == "/" + args.expected_home.lstrip("/"),
        "native_musl_profile": libc.get("exit") == 0 and libc["output"] == "musl",
        "expected_user": os.getuid() == args.expected_uid,
        "expected_user_home": Path(user_home).is_dir() and Path(user_home) == expected_user_home,
    }
    report = {
        "schema_version": 2,
        "collected_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "mode": "offline" if args.offline else "running-system",
        "first_boot_identity_matches": not args.offline and all(checks.values()),
        "checks": checks,
        "kernel": release,
        "root": root, "home": home, "elibc": libc,
        "uid": os.getuid(), "user_home": user_home, "expected_user_home": str(expected_user_home),
        "locale": {key: os.environ.get(key) for key in ("LANG", "LC_ALL")},
        "session": {key: os.environ.get(key) for key in ("XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE")},
        "display_present": bool(os.environ.get("DISPLAY")),
        "session_bus_present": bool(os.environ.get("DBUS_SESSION_BUS_ADDRESS")),
        "openrc_runlevel": text("/run/openrc/softlevel"),
        "kernel_modules_present": {name: Path("/sys/module", name).is_dir() for name in
                                   ("i915", "nvidia", "nvidia_drm", "nvidia_modeset", "nvidia_uvm")},
        "acceptance_limits": ["Identity evidence only: GUI, GPU, sound, input, network and rollback need separate tests.",
                              "Old application profiles, conversations and databases are not accepted by this report."],
    }
    if args.check_runtimes:
        report["runtimes"] = {
            "java": command("java", "-version"),
            "editor": command("eselect", "editor", "show"),
            "linker": command("mold", "--version"),
            "system_flatpak_apps": command("flatpak", "list", "--system", "--app", "--columns=application"),
        }
    payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        destination = args.output.expanduser().absolute()
        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix=".firstboot-", dir=destination.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                os.fchmod(stream.fileno(), 0o600)
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, destination)
        finally:
            Path(temporary).unlink(missing_ok=True)
        print(f"Private report saved: {destination}")
    else:
        print(payload, end="")
    return 0 if args.offline or report["first_boot_identity_matches"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
