#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds the Linux AppImage (ADR-0027). Run on the host (needs podman, distrobox with the "freepascal" container
# from tools/distrobox-setup.sh).
#
#   tools/package-appimage.sh              build everything, write dist/QueryMole-<version>-x86_64.AppImage
#   tools/package-appimage.sh --no-build   reuse app/bin/querymole and backend/build-el9, only stage and pack
#   QBR_WIDGETSET=qt6 tools/package-appimage.sh   the same with the Qt6 widgetset (ADR-0044; default gtk2 until the
#                                          release switches): bundles Qt 6 and libQt6Pas instead of GTK2
#   tools/package-appimage.sh --velopack   additionally pack the same AppDir with `vpk pack` (ADR-0037): an AppImage
#                                          that updates itself, plus the update feed, in dist/Releases-linux
#
# For --velopack, the native library libvelopack_libc.so comes from, in this order: VELOPACK_LIBRARY (a ready file);
# the velopack-pas release VELOPACK_PAS_RELEASE, by default the tag third_party/velopack-pas is pinned to (built
# on manylinux_2_28, glibc 2.28 at most; checked against the release's SHA256SUMS); otherwise it is built in the
# AlmaLinux 9 container (tools/appimage/build-velopack.sh). VPK names the vpk program; otherwise `vpk` from PATH or
# tools/cache/vpk/vpk (dotnet tool install vpk --version <see ADR-0037> --tool-path tools/cache/vpk).
#
# 1. the C backend is built in tools/appimage/Containerfile (AlmaLinux 9, glibc 2.34), so the image runs on
#    every distribution with that glibc or a newer one (RHEL 9, Ubuntu 22.04, Debian 12, Fedora 44, ...);
# 2. the Pascal program is built in the freepascal container against that backend (the program itself needs no
#    glibc newer than 2.34);
#    For Qt6, libQt6Pas is built in the AlmaLinux 9 container first (tools/appimage/build-qt6pas.sh) from the binding
#    sources of the Lazarus in the freepascal container;
# 3. tools/appimage/stage.sh collects the program, the backend, GTK2 or Qt 6 and the other libraries in an AppDir;
# 4. appimagetool (downloaded once to tools/cache/) packs it.
#
# Without distrobox (CI, .github/workflows/release.yml): QBR_FPC_IMAGE=<name> runs step 2 in a plain podman
# container of that name instead, built from tools/appimage/Containerfile.fpc if it does not exist yet.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/cache/appimagetool-x86_64.AppImage"
# the image is rebuilt when its Containerfile changes
IMAGE=qbr-appimage-el9:$(sha256sum "$ROOT/tools/appimage/Containerfile" | cut -c1-12)
WIDGETSET="${QBR_WIDGETSET:-gtk2}"
case "$WIDGETSET" in gtk2|qt6) ;; *) echo "QBR_WIDGETSET must be gtk2 or qt6, not $WIDGETSET" >&2; exit 2 ;; esac
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
OUT="$DIST/QueryMole-$VERSION-x86_64.AppImage"

do_build=1 do_velopack=0
for a in "$@"; do
  case "$a" in
    --no-build) do_build=0 ;;
    --velopack) do_velopack=1 ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

[ -x "$TOOL" ] || { echo "appimagetool is missing: download appimagetool-x86_64.AppImage from" \
  "https://github.com/AppImage/appimagetool/releases (continuous) to $TOOL and make it executable" >&2; exit 1; }

run_el9() {
  podman run --rm --security-opt label=disable -v "$ROOT":/src -v "$DIST":/out -w /src "$IMAGE" "$@"
}

# the Pascal toolchain: the distrobox, or a plain container with the repository at the same path (so that the
# absolute paths below mean the same inside)
FPC_IMAGE="${QBR_FPC_IMAGE:-}"
run_fpc() {
  if [ -n "$FPC_IMAGE" ]; then
    podman run --rm --security-opt label=disable -v "$ROOT":"$ROOT" -w "$ROOT" "$FPC_IMAGE" "$@"
  else
    (cd "$ROOT" && distrobox enter freepascal -- "$@")
  fi
}

mkdir -p "$DIST"
podman image exists "$IMAGE" || podman build -t "$IMAGE" -f "$ROOT/tools/appimage/Containerfile" "$ROOT/tools/appimage"
if [ -n "$FPC_IMAGE" ]; then
  podman image exists "$FPC_IMAGE" || podman build -t "$FPC_IMAGE" -f "$ROOT/tools/appimage/Containerfile.fpc" "$ROOT/tools/appimage"
fi

if [ "$do_build" = 1 ]; then
  echo "== backend (AlmaLinux 9)"
  run_el9 sh -c 'cmake -S backend -B backend/build-el9 -G Ninja >/dev/null && cmake --build backend/build-el9 | tail -3'
  if [ "$WIDGETSET" = qt6 ]; then
    echo "== libQt6Pas (AlmaLinux 9)"
    # with their timestamps, so that make in the kept build directory only rebuilds what changed (a full build takes
    # a quarter of an hour)
    rm -rf "$ROOT/tools/cache/qt6pas-src"
    mkdir -p "$ROOT/tools/cache"
    run_fpc cp -rp /usr/lib64/lazarus/lcl/interfaces/qt6/cbindings "$ROOT/tools/cache/qt6pas-src"
    rm -rf "$ROOT/tools/cache/qt6pas-src/attic" "$ROOT"/tools/cache/qt6pas-src/libQt6Pas.so*
    run_el9 sh tools/appimage/build-qt6pas.sh
  fi
  echo "== application (freepascal container)"
  # linking is only redone when a source changed: force it, the library directory is not part of the check
  touch "$ROOT/app/qbr.lpr"
  run_fpc env QBR_BACKEND_BUILD="$ROOT/backend/build-el9" QBR_WIDGETSET="$WIDGETSET" bash ./build.sh --runtime
fi
[ -f "$ROOT/app/bin/querymole" ] && [ -d "$ROOT/backend/build-el9" ] || { echo "app/bin/querymole or backend/build-el9 is missing" >&2; exit 1; }

echo "== staging"
run_el9 env QBR_WIDGETSET="$WIDGETSET" sh tools/appimage/stage.sh
APPDIR="$DIST/AppDir"
install -m 755 "$ROOT/tools/appimage/AppRun" "$APPDIR/AppRun"
install -m 644 "$ROOT/tools/appimage/querymole.desktop" "$APPDIR/querymole.desktop"

# icon: the QueryMole icon, 256x256 (ADR-0033, written by tools/make_branding.sh)
install -m 644 "$ROOT/app/images/querymole.png" "$APPDIR/querymole.png"
ln -sf querymole.png "$APPDIR/.DirIcon"

# licence files of what is linked statically into the program (Lazarus/FPC) and of the shipped font
mkdir -p "$APPDIR/licenses/lazarus" "$APPDIR/licenses/fonts"
run_fpc sh -c "cp /usr/share/licenses/lazarus-lcl/COPYING.* '$APPDIR/licenses/lazarus/'"
cp "$ROOT/docs/third-party/Bitstream-Vera-fonts.txt" "$APPDIR/licenses/fonts/"
mkdir -p "$APPDIR/licenses/fonts/wine-tahoma"
cp "$ROOT/third_party/fonts/wine-tahoma/README.md" "$ROOT/third_party/fonts/wine-tahoma/LICENSE-LGPL-2.1.txt" "$APPDIR/licenses/fonts/wine-tahoma/"
cp "$ROOT/docs/licenses.md" "$APPDIR/licenses/README-licenses.md"

echo "== packing"
rm -f "$OUT"
ARCH=x86_64 "$TOOL" --appimage-extract-and-run --no-appstream "$APPDIR" "$OUT"
echo "AppImage: $OUT ($(du -h "$OUT" | cut -f1))"

if [ "$do_velopack" = 1 ]; then
  VPK="${VPK:-$(command -v vpk || echo "$ROOT/tools/cache/vpk/vpk")}"
  [ -x "$VPK" ] || { echo "vpk (Velopack CLI) not found, see the header of this script" >&2; exit 1; }
  echo "== velopack"
  # vpk takes a ready AppDir as it is when the folder name ends in .AppDir; it adds usr/bin/UpdateNix and
  # usr/bin/sq.version and packs the AppImage itself
  VAPPDIR="$DIST/QueryMole.AppDir"
  rm -rf "$VAPPDIR"
  cp -a "$APPDIR" "$VAPPDIR"
  # Velopack's native library next to the program: velopack-pas loads it from there (ADR-0018)
  native="${VELOPACK_LIBRARY:-}" native_license=""
  release="${VELOPACK_PAS_RELEASE:-$(git -C "$ROOT/third_party/velopack-pas" describe --tags --exact-match 2>/dev/null || true)}"
  if [ -z "$native" ] && [ -n "$release" ]; then
    echo "== velopack native library (velopack-pas release $release)"
    rm -rf "$DIST/velopack-native"
    python3 "$ROOT/third_party/velopack-pas/tools/fetch-native.py" --version "$release" --os linux --arch x64 \
      --with-license --dest "$DIST/velopack-native"
    native="$DIST/velopack-native/libvelopack_libc.so"
    native_license="$DIST/velopack-native/LICENSE-velopack.txt"
  elif [ -z "$native" ]; then
    echo "== velopack native library (AlmaLinux 9; third_party/velopack-pas is not on a release tag)"
    run_el9 sh tools/appimage/build-velopack.sh | tail -2
    native="$ROOT/tools/cache/velopack/target/release/libvelopack_libc.so"
    native_license="$ROOT/tools/cache/velopack/LICENSE"
  fi
  [ -f "$native" ] || { echo "libvelopack_libc.so not found: $native" >&2; exit 1; }
  install -m 755 "$native" "$VAPPDIR/usr/bin/libvelopack_libc.so"
  strip --strip-debug "$VAPPDIR/usr/bin/libvelopack_libc.so"
  mkdir -p "$VAPPDIR/licenses/velopack"
  cp "$ROOT/third_party/velopack-pas/LICENSE" "$VAPPDIR/licenses/velopack/LICENSE-velopack-pas.txt"
  if [ -n "$native_license" ] && [ -f "$native_license" ]; then
    cp "$native_license" "$VAPPDIR/licenses/velopack/LICENSE-velopack.txt"
  else
    echo "warning: Velopack's licence text not found, licenses/velopack/LICENSE-velopack.txt is missing" >&2
  fi
  echo "usr/bin/libvelopack_libc.so | Velopack (native update library, MIT), used through velopack-pas (MIT)" \
    >> "$VAPPDIR/THIRD-PARTY-LIBS.txt"
  DOTNET_ROLL_FORWARD=Major "$VPK" pack --packId QueryMole --packVersion "$VERSION" --packTitle QueryMole \
    --packAuthors "QueryMole contributors" --packDir "$VAPPDIR" --mainExe querymole --channel linux \
    --outputDir "$DIST/Releases-linux"
  rm -rf "$VAPPDIR" "$DIST/velopack-native"
  echo "Velopack release: $DIST/Releases-linux"
fi
