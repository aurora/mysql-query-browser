#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds libQt6Pas, the C binding between the LCL's Qt6 widgetset and Qt (ADR-0044), against the Qt 6 of the
# qbr-appimage-el9 container. Runs INSIDE that container, started by tools/package-appimage.sh, which has copied the
# binding sources of the Lazarus used for the program to tools/cache/qt6pas-src first: the binding and the Pascal
# units of the widgetset must be the same version. Result: backend/build-el9/qt6pas/libQt6Pas.so.6
set -eu

SRC=/src/tools/cache/qt6pas-src
OUT=/src/backend/build-el9/qt6pas

[ -f "$SRC/Qt6Pas.pro" ] || { echo "binding sources missing: $SRC" >&2; exit 1; }
mkdir -p "$OUT"
cd "$OUT"
qmake6 "$SRC/Qt6Pas.pro" 2>&1 | grep -v '^Project MESSAGE' || true
make -j"$(nproc)" -s 2>&1 | grep -E -i 'error|warning: unused' | head -20 || true
[ -f libQt6Pas.so.6 ] || { echo "libQt6Pas was not built" >&2; exit 1; }
echo "built $OUT/libQt6Pas.so.6 against Qt $(qmake6 -query QT_VERSION)"
