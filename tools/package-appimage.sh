#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds the Linux AppImage (ADR-0027). Run on the host (needs podman, distrobox with the "freepascal" container
# from tools/distrobox-setup.sh).
#
#   tools/package-appimage.sh              build everything, write dist/QueryMole-<version>-x86_64.AppImage
#   tools/package-appimage.sh --no-build   reuse app/bin/qbr and backend/build-el9, only stage and pack
#
# 1. the C backend is built in tools/appimage/Containerfile (AlmaLinux 9, glibc 2.34), so the image runs on
#    every distribution with that glibc or a newer one (RHEL 9, Ubuntu 22.04, Debian 12, Fedora 44, ...);
# 2. the Pascal program is built in the freepascal container against that backend (the program itself needs no
#    glibc newer than 2.34);
# 3. tools/appimage/stage.sh collects the program, the backend, GTK2 and the other libraries in an AppDir;
# 4. appimagetool (downloaded once to tools/cache/) packs it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/cache/appimagetool-x86_64.AppImage"
IMAGE=qbr-appimage-el9
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
OUT="$DIST/QueryMole-$VERSION-x86_64.AppImage"

do_build=1
for a in "$@"; do
  case "$a" in
    --no-build) do_build=0 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

[ -x "$TOOL" ] || { echo "appimagetool is missing: download appimagetool-x86_64.AppImage from" \
  "https://github.com/AppImage/appimagetool/releases (continuous) to $TOOL and make it executable" >&2; exit 1; }

run_el9() {
  podman run --rm --security-opt label=disable -v "$ROOT":/src -v "$DIST":/out -w /src "$IMAGE" "$@"
}

mkdir -p "$DIST"
podman image exists "$IMAGE" || podman build -t "$IMAGE" -f "$ROOT/tools/appimage/Containerfile" "$ROOT/tools/appimage"

if [ "$do_build" = 1 ]; then
  echo "== backend (AlmaLinux 9)"
  run_el9 sh -c 'cmake -S backend -B backend/build-el9 -G Ninja >/dev/null && cmake --build backend/build-el9 | tail -3'
  echo "== application (freepascal container)"
  # linking is only redone when a source changed: force it, the library directory is not part of the check
  touch "$ROOT/app/qbr.lpr"
  (cd "$ROOT" && distrobox enter freepascal -- env QBR_BACKEND_BUILD="$ROOT/backend/build-el9" bash ./build.sh --runtime)
fi
[ -f "$ROOT/app/bin/qbr" ] && [ -d "$ROOT/backend/build-el9" ] || { echo "app/bin/qbr or backend/build-el9 is missing" >&2; exit 1; }

echo "== staging"
run_el9 sh tools/appimage/stage.sh
APPDIR="$DIST/AppDir"
install -m 755 "$ROOT/tools/appimage/AppRun" "$APPDIR/AppRun"
install -m 644 "$ROOT/tools/appimage/qbr.desktop" "$APPDIR/qbr.desktop"

# icon: the QueryMole icon, 256x256 (ADR-0033, written by tools/make_branding.sh)
install -m 644 "$ROOT/app/images/querymole.png" "$APPDIR/querymole.png"
ln -sf querymole.png "$APPDIR/.DirIcon"

# licence files of what is linked statically into the program (Lazarus/FPC) and of the shipped font
mkdir -p "$APPDIR/licenses/lazarus" "$APPDIR/licenses/fonts"
distrobox enter freepascal -- sh -c "cp /usr/share/licenses/lazarus-lcl/COPYING.* '$APPDIR/licenses/lazarus/'"
cp "$ROOT/docs/third-party/Bitstream-Vera-fonts.txt" "$APPDIR/licenses/fonts/"
mkdir -p "$APPDIR/licenses/fonts/wine-tahoma"
cp "$ROOT/third_party/fonts/wine-tahoma/README.md" "$ROOT/third_party/fonts/wine-tahoma/LICENSE-LGPL-2.1.txt" "$APPDIR/licenses/fonts/wine-tahoma/"
cp "$ROOT/docs/licenses.md" "$APPDIR/licenses/README-licenses.md"

echo "== packing"
rm -f "$OUT"
ARCH=x86_64 "$TOOL" --appimage-extract-and-run --no-appstream "$APPDIR" "$OUT"
echo "AppImage: $OUT ($(du -h "$OUT" | cut -f1))"
