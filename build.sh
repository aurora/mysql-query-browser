#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds the application (and, on request, the backend) on Windows (MSYS2) or Linux (distrobox).
#
#   ./build.sh              build app/bin/qbr.exe (Windows) or app/bin/qbr (Linux)
#   ./build.sh --backend    also (re)build the C backend libraries first
#   ./build.sh --runtime    also refresh app/bin (XML, doc, fonts, locale) and the compiled resources
#   ./build.sh --run [args] start the application afterwards (arguments are passed on)
#
# Windows needs Lazarus in C:\lazarus and MSYS2 mingw64 in C:\msys64; Linux needs the
# "freepascal" container from tools/distrobox-setup.sh (see AGENTS.md). On Linux the widgetset
# can be chosen with QBR_WIDGETSET=gtk2|qt5 (default: the project's, gtk2).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) windows=1 ;;
  *) windows=0 ;;
esac

if [ "$windows" = 1 ]; then
  LAZARUS="${LAZARUS_DIR:-/c/lazarus}"
  MINGW="${MINGW_BIN:-/c/msys64/mingw64/bin}"
  BACKEND_BUILD="$ROOT/backend/build"
  EXE=qbr.exe
  export PATH="$MINGW:$BACKEND_BUILD:$LAZARUS:$PATH"
  LAZBUILD=("$LAZARUS/lazbuild.exe" --lazarusdir="$(cygpath -m "$LAZARUS")")
else
  # own build directory: backend/build may hold a Windows build of the same checkout
  BACKEND_BUILD="$ROOT/backend/build-linux"
  EXE=qbr
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
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

if [ "$windows" = 1 ] && tasklist //FI "IMAGENAME eq qbr.exe" 2>/dev/null | grep -qi "qbr.exe"; then
  echo "qbr.exe is running and locks app/bin/qbr.exe; close it first." >&2
  exit 1
fi

if [ "$do_backend" = 1 ]; then
  echo "== backend"
  cmake -S "$ROOT/backend" -B "$BACKEND_BUILD" -G Ninja
  cmake --build "$BACKEND_BUILD"
fi

if [ "$do_runtime" = 1 ]; then
  echo "== resources and runtime files"
  python "$ROOT/tools/build_resources.py"
  python "$ROOT/tools/prepare_runtime.py"
fi

echo "== application"
cd "$ROOT/app"
"${LAZBUILD[@]}" qbr.lpi

echo "built: $ROOT/app/bin/$EXE"

if [ "$do_run" = 1 ]; then
  echo "== run"
  cd "$ROOT/app/bin"
  exec "./$EXE" "$@"
fi
