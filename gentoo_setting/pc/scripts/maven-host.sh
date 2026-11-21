#!/bin/sh
# The Flatpak editor and its host terminal share this version-independent path.
# Keep native Maven on the host's selected Dragonwell 21, outside SDK library paths.
if [ -f /.flatpak-info ] && [ -x /app/bin/host-spawn ]; then
    exec /app/bin/host-spawn -no-pty /usr/bin/mvn "$@"
fi
exec /usr/bin/mvn "$@"
