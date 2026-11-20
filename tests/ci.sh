#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# What the test workflow (.github/workflows/test.yml) runs on Linux; runs the same on a developer machine with podman
# (on the host, not inside the distrobox):
#
#   tests/ci.sh [--only mysql:8.4,mariadb:11.4]
#
# 1. builds the image tests/ci/Containerfile (rebuilt when the file changes);
# 2. in it: the backend (backend/build-linux), the program with GTK2 (only to check that it still compiles,
#    ADR-0044 keeps it buildable) and then with Qt6 (app/bin/querymole, the one that is tested), the runtime files
#    and the FPCUnit tests (tests/bin/qbr_tests);
# 3. tests/run-matrix.sh on this machine: it starts the servers with podman here and runs the tests and the
#    program's self-tests in the image (QBR_EXEC), on the host's network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="qbr-ci:$(sha256sum "$ROOT/tests/ci/Containerfile" | cut -c1-12)"

podman image exists "$IMAGE" || podman build -t "$IMAGE" -f "$ROOT/tests/ci/Containerfile" "$ROOT/tests/ci"

# the checkout at the same path inside, so that paths mean the same on both sides; --init: run-matrix.sh starts the
# programs through `timeout`, which fails silently (exit 125) as the container's process 1 (coreutils 9.10)
in_image=(podman run --rm --init --network host --security-opt label=disable -v "$ROOT:$ROOT" -w "$ROOT" "$IMAGE")

echo "== build (backend, GTK2 check, Qt6, tests)"
"${in_image[@]}" bash -c '
  set -euo pipefail
  cmake -S backend -B backend/build-linux -G Ninja >/dev/null
  cmake --build backend/build-linux | tail -1
  QBR_WIDGETSET=gtk2 ./build.sh --runtime 2>&1 | grep -E -i "^built:| error|fatal" || true
  readelf -d app/bin/querymole | grep -q "libgtk-x11-2.0" || { echo "GTK2 build failed" >&2; exit 1; }
  QBR_WIDGETSET=qt6 ./build.sh 2>&1 | grep -E -i "^built:| error|fatal" || true
  readelf -d app/bin/querymole | grep -q "libQt6Pas" || { echo "Qt6 build failed" >&2; exit 1; }
  units=$(ls -d /usr/lib64/fpc/*/units/x86_64-linux/fcl-fpcunit | head -1)
  mkdir -p tests/lib tests/bin
  fpc -Fubindings -Fuapp/compat -Fuapp/src -Flbackend/build-linux -FUtests/lib -FEtests/bin -Fu"$units" \
    tests/qbr_tests.lpr 2>&1 | grep -E -i "error|fatal|lines compiled" || true
  test -x tests/bin/qbr_tests || { echo "the tests did not build" >&2; exit 1; }
'

echo "== server matrix"
# the self-tests write their reports below TMPDIR; inside the checkout both sides see them
export TMPDIR="$ROOT/tests/tmp"
mkdir -p "$TMPDIR"
QBR_EXEC="${in_image[*]}" "$ROOT/tests/run-matrix.sh" "$@"
