#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds the application (and, on request, the backend) on Windows (MSYS2), Linux (distrobox) or macOS.
#
#   ./build.sh              build app/bin/querymole.exe (Windows) or app/bin/querymole (Linux, macOS)
#   ./build.sh --backend    also (re)build the C backend libraries first
#   ./build.sh --runtime    also refresh app/bin (XML, doc, fonts, locale) and the compiled resources
#   ./build.sh --run [args] start the application afterwards (arguments are passed on)
#
# Windows needs Lazarus in C:\lazarus and MSYS2 mingw64 in C:\msys64; Linux needs the
# "freepascal" container from tools/distrobox-setup.sh (see AGENTS.md); macOS needs Homebrew and Lazarus
# (tools/macos-setup.sh, docs/macos-setup.md). The widgetset can be chosen with QBR_WIDGETSET (Linux:
# gtk2|qt5|qt6, default the project's, gtk2; macOS: default cocoa); QBR_BACKEND_BUILD names another
# backend build directory (tools/package-appimage.sh links against the one built in the older container).
# macOS only: LAZARUS_DIR (default /Applications/Lazarus), HOMEBREW_PREFIX (default /opt/homebrew),
# QBR_FPC_OPTS (extra compiler options, appended to the ones below).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

windows=0 macos=0
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) windows=1 ;;
  Darwin) macos=1 ;;
esac
PYTHON=python

if [ "$windows" = 1 ]; then
  LAZARUS="${LAZARUS_DIR:-/c/lazarus}"
  MINGW="${MINGW_BIN:-/c/msys64/mingw64/bin}"
  BACKEND_BUILD="$ROOT/backend/build"
  EXE=querymole.exe
  export PATH="$MINGW:$BACKEND_BUILD:$LAZARUS:$PATH"
  LAZBUILD=("$LAZARUS/lazbuild.exe" --lazarusdir="$(cygpath -m "$LAZARUS")")
elif [ "$macos" = 1 ]; then
  BREW="${HOMEBREW_PREFIX:-/opt/homebrew}"
  LAZARUS="${LAZARUS_DIR:-/Applications/Lazarus}"
  BACKEND_BUILD="${QBR_BACKEND_BUILD:-$ROOT/backend/build-macos}"
  EXE=querymole
  PYTHON=python3                      # macOS has no unversioned python
  export PATH="$BREW/bin:$LAZARUS:$PATH"
  # keg-only formulae (libxml2, sometimes the others) are not on pkg-config's default path
  for f in libxml2 pcre mariadb-connector-c; do
    if [ -d "$BREW/opt/$f/lib/pkgconfig" ]; then
      PKG_CONFIG_PATH="$BREW/opt/$f/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    fi
  done
  export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
  export DYLD_LIBRARY_PATH="$BACKEND_BUILD${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
  # like Linux, the linker resolves the backend libraries at link time; CMake names them @rpath/lib*.dylib,
  # so the program also gets the build directory as rpath and starts without DYLD_LIBRARY_PATH;
  # $BREW/lib for glib (bindings/myx_types.pas links it for g_free). qbr.lpr calls xmlInitParser: FPC ignores
  # its library name on macOS, and -lxml2 would find the SDK's libxml2 before Homebrew's keg-only one that the
  # backend uses, so that dylib is passed by path. -ld_classic: Apple's current linker rejects the Objective-C
  # method lists FPC 3.2.4 writes ("malformed method list atom" in the Cocoa LCL units)
  LAZBUILD=(lazbuild "--ws=${QBR_WIDGETSET:-cocoa}"
            "--opt=-Fl$BACKEND_BUILD -Fl$BREW/lib -k$BREW/opt/libxml2/lib/libxml2.dylib -k-ld_classic -k-rpath -k$BACKEND_BUILD${QBR_FPC_OPTS:+ $QBR_FPC_OPTS}")
  if [ -d "$LAZARUS" ]; then LAZBUILD+=("--lazarusdir=$LAZARUS"); fi
else
  # own build directory: backend/build may hold a Windows build of the same checkout
  BACKEND_BUILD="${QBR_BACKEND_BUILD:-$ROOT/backend/build-linux}"
  EXE=querymole
  export LD_LIBRARY_PATH="$BACKEND_BUILD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  # the Linux linker resolves the backend libraries at link time
  LAZBUILD=(lazbuild "--opt=-Fl$BACKEND_BUILD")
  if [ -n "${QBR_WIDGETSET:-}" ]; then LAZBUILD+=("--ws=$QBR_WIDGETSET"); fi
fi

do_backend=0 do_runtime=0 do_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --backend) do_backend=1 ;;
    --runtime) do_runtime=1 ;;
    --run) do_run=1; shift; break ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

if [ "$windows" = 1 ] && tasklist //FI "IMAGENAME eq querymole.exe" 2>/dev/null | grep -qi "querymole.exe"; then
  echo "querymole.exe is running and locks app/bin/querymole.exe; close it first." >&2
  exit 1
fi

if [ "$do_backend" = 1 ]; then
  echo "== backend"
  cmake -S "$ROOT/backend" -B "$BACKEND_BUILD" -G Ninja
  cmake --build "$BACKEND_BUILD"
fi

if [ "$do_runtime" = 1 ]; then
  echo "== resources and runtime files"
  "$PYTHON" "$ROOT/tools/build_resources.py"
  "$PYTHON" "$ROOT/tools/prepare_runtime.py"
fi

echo "== version"
"$PYTHON" "$ROOT/tools/gen_version.py"

echo "== application"
cd "$ROOT/app"
"${LAZBUILD[@]}" qbr.lpi

echo "built: $ROOT/app/bin/$EXE"

if [ "$do_run" = 1 ]; then
  echo "== run"
  cd "$ROOT/app/bin"
  exec "./$EXE" "$@"
fi
