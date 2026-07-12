#!/bin/sh
set -eu

# Repair an imported guix-wsl runtime before /etc/profile can see a live
# /run/current-system symlink.  This is safe to run repeatedly.

system_profile=/var/guix/profiles/system
system_path=$system_profile/profile

export PATH=$system_path/sbin:$system_path/bin:/run/setuid-programs:/bin

if [ ! -e "$system_profile" ]; then
  echo "Missing $system_profile; the Guix system profile is not installed." >&2
  exit 1
fi

mkdir -p /run
ln -sfn "$system_profile" /run/current-system

export PATH=/run/current-system/profile/sbin:/run/current-system/profile/bin:/run/setuid-programs:/bin

if [ -x /run/current-system/profile/bin/guix ]; then
  guix --version
fi

echo "Guix WSL runtime repaired."
echo "If package operations still cannot reach guix-daemon, run install.sh or restart WSL after reconfiguration."
