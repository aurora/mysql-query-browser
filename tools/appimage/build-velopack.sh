#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Builds Velopack's native library (libvelopack_libc.so) for the AppImage (ADR-0037). Runs inside the
# AlmaLinux 9 image of tools/appimage/Containerfile, so the library needs no newer glibc than the rest of the
# image. The Velopack revision is the one velopack-pas was written against
# (third_party/velopack-pas/third_party/velopack/VERSION); the source is cloned to tools/cache/velopack.
#
#   sh tools/appimage/build-velopack.sh      (from the repository root, in the container)
# Result: tools/cache/velopack/target/release/libvelopack_libc.so
set -eu

SRC=/src
PIN="$SRC/third_party/velopack-pas/third_party/velopack/VERSION"
REPO="$(sed -n 's/^repository=//p' "$PIN")"
COMMIT="$(sed -n 's/^commit=//p' "$PIN")"
DIR="$SRC/tools/cache/velopack"

[ -d "$DIR/.git" ] || git clone -q "$REPO" "$DIR"
git -C "$DIR" fetch -q origin "$COMMIT" 2>/dev/null || true
git -C "$DIR" -c advice.detachedHead=false checkout -q "$COMMIT"

export CARGO_HOME="$SRC/tools/cache/cargo-home"
cd "$DIR"
cargo build --release --locked -p velopack_libc
LIB="$DIR/target/release/libvelopack_libc.so"
echo "built $LIB (velopack $COMMIT)"
echo "newest glibc symbol: $(objdump -T "$LIB" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
