#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds the application (and, on request, the backend) on the Windows development machine.
#
#   ./build.sh              build app/bin/qbr.exe
#   ./build.sh --backend    also (re)build the C backend DLLs first
#   ./build.sh --runtime    also refresh app/bin (XML, doc, fonts, locale) and the compiled resources
#   ./build.sh --run [args] start the application afterwards (arguments are passed on)
#
# Needs: Lazarus in C:\lazarus, MSYS2 mingw64 in C:\msys64 (see AGENTS.md).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAZARUS="${LAZARUS_DIR:-/c/lazarus}"
MINGW="${MINGW_BIN:-/c/msys64/mingw64/bin}"
export PATH="$MINGW:$ROOT/backend/build:$LAZARUS:$PATH"

do_backend=0 do_runtime=0 do_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --backend) do_backend=1 ;;
    --runtime) do_runtime=1 ;;
    --run) do_run=1; shift; break ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

if tasklist //FI "IMAGENAME eq qbr.exe" 2>/dev/null | grep -qi "qbr.exe"; then
  echo "qbr.exe is running and locks app/bin/qbr.exe; close it first." >&2
  exit 1
fi

if [ "$do_backend" = 1 ]; then
  echo "== backend"
  cmake -S "$ROOT/backend" -B "$ROOT/backend/build" -G Ninja
  cmake --build "$ROOT/backend/build"
fi

if [ "$do_runtime" = 1 ]; then
  echo "== resources and runtime files"
  python "$ROOT/tools/build_resources.py"
  python "$ROOT/tools/prepare_runtime.py"
fi

echo "== application"
cd "$ROOT/app"
"$LAZARUS/lazbuild.exe" --lazarusdir="$(cygpath -m "$LAZARUS")" qbr.lpi

echo "built: $ROOT/app/bin/qbr.exe"

if [ "$do_run" = 1 ]; then
  echo "== run"
  cd "$ROOT/app/bin"
  exec ./qbr.exe "$@"
fi
