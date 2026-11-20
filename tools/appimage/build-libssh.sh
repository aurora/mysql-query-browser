#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds libssh for the AppImage (ADR-0048) in the qbr-appimage-el9 container, against its OpenSSL and zlib.
# AlmaLinux 9 ships libssh 0.10.4, which runs the `ssh` program for ProxyJump; 0.11 and later do it themselves.
# The version matches Fedora's (development, CI) and MSYS2's (Windows) closely. Runs INSIDE the container, started by
# tools/package-appimage.sh. Result: backend/build-el9/libssh/lib64/libssh.so.4 with headers and COPYING; a build of
# the same version is kept.
set -eu

VERSION=0.12.2
# also in Fedora's libssh-0.12.2-1.fc44.src.rpm, whose build checks the signature with libssh's release key
# (88A2 28D8 9B07 C2C7 7D0C 7809 03D5 DF8C FDD3 E8E7)
SHA256=49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f
URL=https://www.libssh.org/files/0.12/libssh-$VERSION.tar.xz

CACHE=/src/tools/cache
OUT=/src/backend/build-el9/libssh
TARBALL=$CACHE/libssh-$VERSION.tar.xz

if [ -f "$OUT/lib64/libssh.so.4" ] && [ "$(cat "$OUT/VERSION" 2>/dev/null)" = "$VERSION" ]; then
  echo "libssh $VERSION already built in $OUT"
  exit 0
fi

mkdir -p "$CACHE"
[ -f "$TARBALL" ] || curl -fsSL -o "$TARBALL" "$URL"
echo "$SHA256  $TARBALL" | sha256sum -c --quiet - || { echo "checksum of $TARBALL does not match" >&2; rm -f "$TARBALL"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tar xJf "$TARBALL" -C "$WORK"
rm -rf "$OUT"
# client only: no server part, no GSSAPI (would bring in krb5), no examples or tests
cmake -S "$WORK/libssh-$VERSION" -B "$WORK/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUT" -DCMAKE_INSTALL_LIBDIR=lib64 \
  -DWITH_SERVER=OFF -DWITH_GSSAPI=OFF -DWITH_EXAMPLES=OFF -DUNIT_TESTING=OFF -DCLIENT_TESTING=OFF \
  -DWITH_ZLIB=ON -DWITH_GCRYPT=OFF -DWITH_MBEDTLS=OFF >/dev/null
cmake --build "$WORK/build" | tail -1
cmake --install "$WORK/build" >/dev/null
cp "$WORK/libssh-$VERSION/COPYING" "$OUT/"
echo "$VERSION" > "$OUT/VERSION"
[ -f "$OUT/lib64/libssh.so.4" ] || { echo "libssh was not built" >&2; exit 1; }
echo "built $OUT/lib64/libssh.so.4 ($VERSION)"
