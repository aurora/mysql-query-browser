#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Creates (or updates) the Linux development container "freepascal" with distrobox.
# Run on the host; running it again only installs what is missing.
#
#   tools/distrobox-setup.sh [name]     default name: freepascal
#   distrobox enter freepascal
#
# Contents: FPC + Lazarus 4.8 (LCL gtk2 and qt5, lazbuild, IDE), gcc/cmake/ninja and the
# backend libraries (glib2, libxml2, pcre, MariaDB Connector/C), Python 3 as `python`,
# mingw64 windres for tools/build_resources.py, the Win64 RTL units (cross-compiling checks that
# the Windows build is unchanged), Xvfb (`xvfb-run` for the GUI self-tests without a desktop),
# gdb, the mariadb client, and `podman` forwarded to the host for the test servers.
set -euo pipefail

NAME="${1:-freepascal}"
IMAGE="registry.fedoraproject.org/fedora-toolbox:44"

PACKAGES=(
  fpc fpc-src lazarus lazarus-lcl-gtk2 lazarus-lcl-qt5
  gcc gcc-c++ cmake ninja-build pkgconf-pkg-config
  glib2-devel libxml2-devel pcre-devel mariadb-connector-c-devel
  python3 python-unversioned-command
  mingw64-binutils mingw64-cpp fpc-units-x86_64-win64
  xorg-x11-server-Xvfb xorg-x11-xauth
  git gdb mariadb
)

if ! distrobox list --no-color | awk -F'|' '{gsub(/ /, "", $2); print $2}' | grep -qx "$NAME"; then
  distrobox create --yes --name "$NAME" --image "$IMAGE"
fi

distrobox enter "$NAME" -- sudo dnf -y install "${PACKAGES[@]}"
distrobox enter "$NAME" -- sh -c \
  '[ -e /usr/local/bin/podman ] || sudo ln -s /usr/bin/distrobox-host-exec /usr/local/bin/podman'

echo "ready: distrobox enter $NAME"
