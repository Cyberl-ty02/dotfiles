#!/usr/bin/env python3
"""Preview or deploy Portage settings from this checkout in a new target root."""

import argparse
from configparser import ConfigParser, Error as ConfigError
from io import StringIO
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import NamedTemporaryFile, TemporaryDirectory, mkdtemp


SETTINGS = Path(__file__).resolve().parents[1]
PORTAGE = Path("/etc/portage")
PROFILES = {
    "musl": ("pc", "musl", "x86_64-pc-linux-musl", "default/linux/amd64/23.0/musl/llvm"),
    "wsl": ("wsl", "glibc", "x86_64-pc-linux-gnu", "default/linux/amd64/23.0/desktop"),
}

# Bind the recorded user patches to their Portage selectors. These paths do not
# pin packages. Keep package-wide selectors only where the patch group uses one.
SOURCE_PATCHES = {
    "clamtk-6.18": "app-antivirus/clamtk-6.18-r2",
    "neomacs-aacf292": "app-editors/neomacs-9999",
    "lowdown-3.1.1": "app-text/lowdown-3.1.1",
    "xmake-trybuild": "dev-build/xmake-3.1.2",
    "kwayland-sonic-ecm": "kde-plasma/kwayland",
    "ipset-7.24": "net-firewall/ipset-7.24-r1",
    "nftables-1.1.7": "net-firewall/nftables-1.1.7",
    "sonic-login-manager": "sonicde-base/sonic-login-manager",
    "sonic-quick-image-editor": "sonicde-base/sonic-quick-image-editor-0.7.0.1",
    "sonic-terminal": "sonicde-base/sonic-terminal-26.08.3",
}


def verify_target(route):
    _, libc, chost, profile = PROFILES[route]
    root = subprocess.check_output(
        ["portageq", "envvar", "ROOT", "PORTAGE_CONFIGROOT", "EPREFIX"], text=True
    ).splitlines()
    if root != ["/", "/", ""]:
        raise ValueError("Enter the target directly; unset ROOT, PORTAGE_CONFIGROOT and EPREFIX overrides.")
    if subprocess.check_output(["portageq", "envvar", "ELIBC", "CHOST"], text=True).split() != [libc, chost]:
        raise ValueError(f"Expected {libc} / {chost}; enter the matching target root.")
    tree = Path(subprocess.check_output(
        ["portageq", "get_repo_path", "/", "gentoo"], text=True
    ).strip())
    if not tree.is_absolute() or not (tree / "profiles" / profile).is_dir():
        raise ValueError("Initialize Gentoo's main repository before deploying.")
    if (PORTAGE / "make.profile").resolve() != (tree / "profiles" / profile).resolve():
        raise ValueError(f"Select {profile} in the target first.")


def overlay_plan(source):
    template = ConfigParser(interpolation=None)
    template.read(sorted((source / "repos.conf").glob("*.conf")))
    overlays = ConfigParser(interpolation=None)
    for name in template.sections():
        if name not in {"DEFAULT", "gentoo"}:
            overlays[name] = template[name]
            overlays[name].pop("main-repo", None)
    current = ConfigParser(interpolation=None, strict=False)
    config = PORTAGE / "repos.conf"
    files = [config] if config.is_file() else sorted(config.glob("*.conf"))
    current.read(files)
    for name in overlays.sections():
        if not current.has_section(name):
            continue
        if any(current[name].get(key) != value for key, value in overlays[name].items()):
            raise ValueError(f"Overlay {name} has different settings. Review its existing section first.")
        overlays.remove_section(name)
    if not overlays.sections():
        return {}
    output = StringIO()
    overlays.write(output)
    fragment = output.getvalue().encode()
    dest = config / "dotfiles-overlays.conf"
    if config.is_file():
        return {config: config.read_bytes().rstrip() + b"\n\n" + fragment}
    if dest.is_file():
        return {dest: dest.read_bytes().rstrip() + b"\n\n" + fragment}
    return {dest: fragment}


def config_plan(source, route):
    plan = {}
    for path in sorted(source.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(source)
        if relative.parts[0].startswith("package.") or relative.parts[0] in {
            "make.conf", "binrepos.conf", "env", "profile", "sets"
        }:
            plan[PORTAGE / relative] = path.read_bytes()
    if route == "musl":
        for group, selector in SOURCE_PATCHES.items():
            patches = sorted((SETTINGS / "pc/patchsets" / group / "source").glob("*.patch"))
            if not patches:
                raise ValueError(f"Missing source patches: {group}")
            for patch in patches:
                plan[PORTAGE / "patches" / selector / patch.name] = patch.read_bytes()
    return plan


def verify_toolchain(route):
    commands = ["clang", "ld.lld", "ld.mold"]
    if route == "musl":
        commands.append("curl")
    for command in commands:
        if not shutil.which(command):
            raise ValueError(f"Install {command} with the original stage settings first.")
    if subprocess.run(["portageq", "has_version", "/", "llvm-core/llvmgold"]).returncode:
        raise ValueError("Install LLVMgold for the selected LLVM slot first.")
    flags = ["-flto=thin", "-fuse-ld=mold"]
    if route == "musl":
        flags.append("-Wl,--plugin-opt=jobs=2")
    with TemporaryDirectory(prefix="portage-link-test-") as work:
        subprocess.run(
            ["clang", *flags, "-x", "c", "-", "-o", str(Path(work) / "test")],
            input="int main(void) { return 0; }\n", text=True, check=True
        )


def review(plan, stage):
    changes = {}
    for path, content in plan.items():
        for parent in path.parents:
            if parent == PORTAGE.parent:
                break
            if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
                raise ValueError(f"Merge manually: {parent} must be a real directory.")
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError(f"Merge manually: {path} must be a regular file.")
        if path.exists():
            if path.read_bytes() == content:
                continue
            if stage != "repos" and path not in {PORTAGE / "make.conf", PORTAGE / "binrepos.conf/gentoo.conf"}:
                raise ValueError(f"Merge manually: existing file differs: {path}")
        changes[path] = content
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("route", choices=PROFILES)
    parser.add_argument("stage", choices=("repos", "config"))
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    try:
        verify_target(args.route)
        source = SETTINGS / PROFILES[args.route][0] / "portage"
        if args.stage == "repos":
            changes = review(overlay_plan(source), args.stage)
        else:
            changes = review(config_plan(source, args.route), args.stage)
        for path in changes:
            print(f"{'Replace' if path.exists() else 'Create'} {path}")
        if not changes:
            print("All selected files already match.")
        elif args.apply:
            if os.geteuid() != 0:
                raise ValueError("Run --apply as root inside the target.")
            if args.stage == "config":
                verify_toolchain(args.route)
            backup = Path(mkdtemp(prefix="portage-before-", dir="/root"))
            shutil.copytree(PORTAGE, backup / "portage", symlinks=True)
            print(f"Backup: {backup / 'portage'}", flush=True)
            for path in sorted(changes, key=lambda p: p == PORTAGE / "make.conf"):
                content = changes[path]
                path.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
                with NamedTemporaryFile(dir=path.parent, delete=False) as stream:
                    temporary = Path(stream.name)
                try:
                    temporary.write_bytes(content)
                    temporary.chmod(0o644)
                    temporary.replace(path)
                finally:
                    temporary.unlink(missing_ok=True)
        else:
            print("Preview only. Apply after reviewing the target and the source files.")
    except (OSError, ValueError, ConfigError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
