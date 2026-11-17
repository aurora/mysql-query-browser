#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Installs (or checks) what the macOS build needs; the counterpart of tools/distrobox-setup.sh.
# Run on the Mac; running it again only installs what is missing. See docs/macos-setup.md.
#
#   tools/macos-setup.sh            install the Homebrew packages, check Xcode tools and Lazarus
#   tools/macos-setup.sh --check    only check, install nothing
#
# Contents: cmake/ninja/pkg-config and the backend libraries (glib, libxml2, pcre, MariaDB Connector/C)
# from Homebrew, mingw-w64 for windres (tools/build_resources.py; the .res files are platform neutral),
# Python 3. Lazarus and FPC are not in Homebrew in a usable form (the cask is disabled, the fpc formula
# has no Lazarus): install the three packages of Lazarus 4.8 for macOS aarch64 from
# https://sourceforge.net/projects/lazarus/files/Lazarus%20macOS%20aarch64/ (fpc, fpc-src, lazarus);
# Lazarus goes to /Applications/Lazarus, FPC to /usr/local/bin.
set -euo pipefail

BREW_PACKAGES=(cmake ninja pkgconf python@3 glib libxml2 pcre mariadb-connector-c mingw-w64)
LAZARUS="${LAZARUS_DIR:-/Applications/Lazarus}"

check_only=0
case "${1:-}" in
  --check) check_only=1 ;;
  "") ;;
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
esac

[ "$(uname -s)" = Darwin ] || { echo "this script is for macOS" >&2; exit 1; }
missing=0

echo "== Xcode command line tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "ok: $(xcode-select -p)"
else
  echo "missing: run 'xcode-select --install' and start this script again" >&2
  missing=1
fi

echo "== Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "missing: install Homebrew from https://brew.sh" >&2
  exit 1
fi
BREW="$(brew --prefix)"
todo=()
for p in "${BREW_PACKAGES[@]}"; do
  brew list --formula "$p" >/dev/null 2>&1 || todo+=("$p")
done
if [ ${#todo[@]} -eq 0 ]; then
  echo "ok: ${BREW_PACKAGES[*]}"
elif [ "$check_only" = 1 ]; then
  echo "missing: ${todo[*]} (brew install ${todo[*]})" >&2
  missing=1
else
  brew install "${todo[@]}"
fi

echo "== backend libraries (pkg-config)"
export PKG_CONFIG_PATH="$BREW/opt/libxml2/lib/pkgconfig:$BREW/opt/pcre/lib/pkgconfig:$BREW/opt/mariadb-connector-c/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
for m in glib-2.0 gthread-2.0 libxml-2.0 libpcre libmariadb; do
  if v="$(pkg-config --modversion "$m" 2>/dev/null)"; then
    echo "ok: $m $v"
  else
    echo "missing: $m" >&2
    missing=1
  fi
done

echo "== windres"
if command -v x86_64-w64-mingw32-windres >/dev/null 2>&1; then
  echo "ok: $(command -v x86_64-w64-mingw32-windres)"
else
  echo "missing: x86_64-w64-mingw32-windres (brew install mingw-w64)" >&2
  missing=1
fi

echo "== Free Pascal and Lazarus"
if command -v fpc >/dev/null 2>&1; then
  echo "ok: fpc $(fpc -iV) for $(fpc -iTP)-$(fpc -iTO)"
  [ "$(fpc -iTP)" = aarch64 ] || echo "note: fpc's default target is $(fpc -iTP), not aarch64" >&2
else
  echo "missing: fpc (see the header of this script)" >&2
  missing=1
fi
if [ -x "$LAZARUS/lazbuild" ]; then
  echo "ok: $LAZARUS/lazbuild ($("$LAZARUS/lazbuild" --version 2>/dev/null | tail -1))"
else
  echo "missing: $LAZARUS/lazbuild (see the header of this script; LAZARUS_DIR names another folder)" >&2
  missing=1
fi

echo "== git submodule"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -e "$ROOT/third_party/velopack-pas/src" ]; then
  echo "ok: third_party/velopack-pas"
elif [ "$check_only" = 1 ]; then
  echo "missing: third_party/velopack-pas (git submodule update --init)" >&2
  missing=1
else
  git -C "$ROOT" submodule update --init
fi

if [ "$missing" = 1 ]; then
  echo "not ready, see the messages above" >&2
  exit 1
fi
echo "ready: ./build.sh --backend --runtime"
