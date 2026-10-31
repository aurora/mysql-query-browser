#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Linux counterpart of run-matrix.ps1: runs the FPCUnit tests against several server versions
# using throw-away Podman/Docker containers.
#
#   tests/run-matrix.sh [--only mysql:8.4,mariadb:11.4] [--keep]
#
# Prerequisites: backend built (backend/build-linux), tests built (tests/bin/qbr_tests):
#   fpc -Fubindings -Fuapp/compat -Fuapp/src -Flbackend/build-linux -FUtests/lib -FEtests/bin \
#     -Fu/usr/lib64/fpc/<version>/units/x86_64-linux/fcl-fpcunit tests/qbr_tests.lpr
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXE="$ROOT/tests/bin/qbr_tests"
APP="$ROOT/app/bin/qbr"
[ -x "$EXE" ] || { echo "Build the tests first: $EXE not found" >&2; exit 1; }

only="" keep=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="$2"; shift ;;
    --keep) keep=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

engine=$(command -v podman || command -v docker) || { echo "neither podman nor docker found" >&2; exit 1; }
password="${QBR_TEST_PASSWORD:-qbr-test}"
export QBR_TEST_PASSWORD="$password"
export LD_LIBRARY_PATH="$ROOT/backend/build-linux${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# image, env var for the root password, admin client used for readiness checks
matrix=(
  "mysql:5.7      MYSQL_ROOT_PASSWORD   mysqladmin"
  "mysql:8.0      MYSQL_ROOT_PASSWORD   mysqladmin"
  "mysql:8.4      MYSQL_ROOT_PASSWORD   mysqladmin"
  "mysql:9        MYSQL_ROOT_PASSWORD   mysqladmin"
  "mariadb:10.11  MARIADB_ROOT_PASSWORD mariadb-admin"
  "mariadb:11.4   MARIADB_ROOT_PASSWORD mariadb-admin"
)

results=() failed=0 port=34000
for entry in "${matrix[@]}"; do
  read -r image pwdvar admin <<< "$entry"
  port=$((port + 1))
  if [ -n "$only" ] && [[ ",$only," != *",$image,"* ]]; then continue; fi
  name="qbr-matrix-${image//[^a-zA-Z0-9]/-}"
  echo "=== $image on port $port"
  "$engine" rm -f "$name" >/dev/null 2>&1
  "$engine" run -d --name "$name" -p "$port:3306" -e "$pwdvar=$password" "docker.io/library/$image" >/dev/null

  ready=0
  for _ in $(seq 60); do
    if "$engine" exec "$name" "$admin" ping -uroot "-p$password" 2>&1 | grep -q alive; then ready=1; break; fi
    sleep 3
  done
  if [ "$ready" = 0 ]; then
    results+=("$image|server did not start|-|")
    failed=1
    [ "$keep" = 1 ] || "$engine" rm -f "$name" >/dev/null
    continue
  fi
  # the entrypoint restarts the server once after initialisation; wait until it is stable
  sleep 3

  log=$(QBR_TEST_PORT="$port" timeout 300 "$EXE" --all --format=plain 2>&1)
  run=$(grep -oP 'Number of run tests:\s+\K\d+' <<< "$log")
  err=$(grep -oP 'Number of errors:\s+\K\d+' <<< "$log")
  fail=$(grep -oP 'Number of failures:\s+\K\d+' <<< "$log")
  if [ -n "$run" ] && [ "$err" = 0 ] && [ "$fail" = 0 ]; then
    status="PASS ($run tests)" details=""
  else
    status="FAIL ($run tests)" failed=1
    details=$(grep -E 'Failed:|Exception|Assertion|Message' <<< "$log" | head -5 | tr '\n' ' ')
  fi

  # the application itself: connect through the ported code, once via the command line path and
  # once by driving the connect dialog (needs app/bin/qbr and `python tools/prepare_runtime.py`)
  app_result="n/a"
  # a virtual X server keeps the windows off the desktop (and works without one)
  xvfb=(); if command -v xvfb-run >/dev/null; then xvfb=(xvfb-run -a); fi
  if [ -x "$APP" ]; then
    data_dir="${TMPDIR:-/tmp}/qbr-matrix-data"
    mkdir -p "$data_dir"
    app_result="PASS"
    for mode in selftest-connect selftest-dialog; do
      report="$data_dir/$mode.txt"
      rm -f "$report"
      timeout 60 "${xvfb[@]}" "$APP" -datadir "$data_dir" -u root -p "$password" -h 127.0.0.1 -P "$port" "--$mode" "$report" \
        >/dev/null 2>&1
      grep -qE '^(dialog )?connected' "$report" 2>/dev/null || app_result="FAIL"
    done
    [ "$app_result" = PASS ] || failed=1
  fi
  results+=("$image|$status|$app_result|$details")

  [ "$keep" = 1 ] || "$engine" rm -f "$name" >/dev/null
done

echo
printf '%-15s %-22s %-6s %s\n' Server Result App Details
for r in "${results[@]}"; do
  IFS='|' read -r s res app det <<< "$r"
  printf '%-15s %-22s %-6s %s\n' "$s" "$res" "$app" "$det"
done
exit "$failed"
