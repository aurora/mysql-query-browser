#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds a release package of the Windows application.
#
#   tools/package.sh                 stage dist/app and write dist/qbr-<version>-win64.zip (portable)
#   tools/package.sh --velopack      additionally run `vpk pack` on dist/app (installer + update feed in dist/Releases)
#   tools/package.sh --no-build      reuse the existing app/bin/qbr.exe instead of building first
#
# The version comes from the VERSION file. The staged folder holds:
#   qbr.exe (debug info stripped; the unstripped build stays in app/bin), the backend DLLs and the
#   MSYS2 DLLs they need (found with ldd), XML/, doc/, fonts/, locale/, LICENSE, NOTICE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MINGW="${MINGW_BIN:-/c/msys64/mingw64/bin}"
export PATH="$MINGW:/c/msys64/usr/bin:$ROOT/backend/build:$PATH"

do_build=1 do_velopack=0
for a in "$@"; do
  case "$a" in
    --velopack) do_velopack=1 ;;
    --no-build) do_build=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
APP="$DIST/app"

if [ "$do_build" = 1 ]; then
  "$ROOT/build.sh" --backend --runtime
fi
[ -f "$ROOT/app/bin/qbr.exe" ] || { echo "app/bin/qbr.exe is missing" >&2; exit 1; }

echo "== staging $APP (version $VERSION)"
rm -rf "$APP"
mkdir -p "$APP"
cp "$ROOT/app/bin/qbr.exe" "$APP/qbr.exe"
strip --strip-debug "$APP/qbr.exe"

# backend DLLs and everything they and the program need from MSYS2
cp "$ROOT"/backend/build/*.dll "$APP/"
# ldd resolves some names to C:\Windows\System32 first (other software puts copies there), so go by
# the names: whatever MSYS2 provides under that name is shipped.
names=$( (ldd "$APP/qbr.exe"; for d in "$APP"/libmysql*.dll; do ldd "$d"; done) | awk '{print $1}' | sort -u )
extra="libssl-3-x64.dll libcrypto-3-x64.dll"      # loaded by libmariadb/libcurl through plugins and TLS
for n in $names $extra; do
  if [ -f "$MINGW/$n" ] && [ ! -f "$APP/$n" ]; then
    cp "$MINGW/$n" "$APP/"
  fi
done
# the copied libraries may need more of MSYS2's (e.g. libssl needs libcrypto): repeat until stable
for pass in 1 2 3; do
  for f in "$APP"/*.dll; do
    for n in $(ldd "$f" | awk '{print $1}'); do
      if [ -f "$MINGW/$n" ] && [ ! -f "$APP/$n" ]; then cp "$MINGW/$n" "$APP/"; fi
    done
  done
done

for d in XML doc fonts locale; do
  cp -r "$ROOT/app/bin/$d" "$APP/$d"
done
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$APP/"

# Licence information for what is shipped: per DLL the MSYS2 package, version and SPDX licence expression,
# plus the licence files those packages carry. docs/licenses.md has the review behind this.
mkdir -p "$APP/licenses/msys2" "$APP/licenses/lazarus"
{
  echo "Runtime libraries shipped next to qbr.exe, taken from MSYS2 mingw-w64 packages (the backend DLLs"
  echo "libmysql*.dll are built from this repository). Licence expressions are the packages' own; the"
  echo "licence texts that the packages carry are in licenses/msys2/. See docs/licenses.md for the review."
  echo
  for f in "$APP"/*.dll; do
    n=$(basename "$f")
    case "$n" in libmysql*) echo "$n | this project (GPL-2.0-or-later / LGPL-2.1-or-later parts, see NOTICE)"; continue ;; esac
    pkg=$(pacman -Qoq "/mingw64/bin/$n" 2>/dev/null || true)
    if [ -z "$pkg" ]; then echo "$n | unknown package"; continue; fi
    info=$(pacman -Qi "$pkg")
    ver=$(echo "$info" | awk -F': ' '/^Version/ {print $2}')
    lic=$(echo "$info" | awk -F': ' '/^Licenses/ {print $2}')
    echo "$n | $pkg $ver | $lic"
    { pacman -Ql "$pkg" | awk '{print $2}' | grep "^/mingw64/share/licenses/.*[^/]$" || true; } | while read -r lf; do
      d="$APP/licenses/msys2/${pkg#mingw-w64-x86_64-}"
      mkdir -p "$d"
      cp "/c/msys64$lf" "$d/" 2>/dev/null || true
    done
  done
} > "$APP/THIRD-PARTY-DLLS.txt"

# Lazarus/FPC (statically linked): modified LGPL with linking exception for LCL, RTL and LazUtils; the
# SynEdit, VirtualTrees and IpHtml units carry their own terms (docs/licenses.md).
for f in COPYING.modifiedLGPL.txt COPYING.LGPL.txt COPYING.GPL.txt; do
  cp "/c/lazarus/$f" "$APP/licenses/lazarus/" 2>/dev/null || true
done
mkdir -p "$APP/licenses/fonts"
cp "$ROOT/docs/third-party/Bitstream-Vera-fonts.txt" "$APP/licenses/fonts/"
cp "$ROOT/docs/licenses.md" "$APP/licenses/README-licenses.md"

echo "note: doc/ contains an extract of the MySQL 5.0 manual, which is not GPL licensed; see docs/licenses.md section 4 before a public release" >&2

# the exe must start without the development PATH: run it with a minimal one
if ! (cd "$APP" && PATH="/c/Windows/System32:/c/Windows" ./qbr.exe --selftest-resources "$DIST/selftest.txt" ); then
  echo "warning: the staged qbr.exe did not start cleanly with a minimal PATH (missing DLL?)" >&2
fi

ZIP="$DIST/qbr-$VERSION-win64.zip"
rm -f "$ZIP"
(cd "$APP" && powershell.exe -NoProfile -Command "Compress-Archive -Path * -DestinationPath '$(cygpath -w "$ZIP")'")
echo "portable package: $ZIP ($(du -h "$ZIP" | cut -f1))"

if [ "$do_velopack" = 1 ]; then
  command -v vpk >/dev/null || { echo "vpk (Velopack CLI) not found: dotnet tool install -g vpk" >&2; exit 1; }
  echo "== velopack"
  vpk pack --packId QueryBrowserRevival --packVersion "$VERSION" --packDir "$(cygpath -w "$APP")" \
    --mainExe qbr.exe --packTitle "Query Browser" --outputDir "$(cygpath -w "$DIST/Releases")" \
    --icon "$(cygpath -w "$ROOT/legacy/mysql-query-browser/images/icons/MySQLQueryBrowser.ico")"
fi
