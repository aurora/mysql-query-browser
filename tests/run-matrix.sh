#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Linux counterpart of run-matrix.ps1: runs the FPCUnit tests against several server versions
# using throw-away Podman/Docker containers.
#
#   tests/run-matrix.sh [--only mysql:8.4,mariadb:11.4] [--keep] [--app-only]
#
# --app-only skips the FPCUnit tests and only runs the application self-tests; QBR_APP names the program to run
# (default app/bin/querymole), e.g. dist/AppDir/AppRun to check the AppImage's libraries against every server.
# QBR_EXEC is a command prefix that runs the test program and the application somewhere else, e.g. in a container
# that sees the servers' ports and this checkout at the same path (tests/ci.sh); the servers still run here.
#
# Prerequisites: backend built (backend/build-linux), tests built (tests/bin/qbr_tests):
#   fpc -Fubindings -Fuapp/compat -Fuapp/src -Flbackend/build-linux -FUtests/lib -FEtests/bin \
#     -Fu/usr/lib64/fpc/<version>/units/x86_64-linux/fcl-fpcunit tests/qbr_tests.lpr
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXE="$ROOT/tests/bin/qbr_tests"
APP="${QBR_APP:-$ROOT/app/bin/querymole}"

only="" keep=0 app_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="$2"; shift ;;
    --keep) keep=1 ;;
    --app-only) app_only=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

[ "$app_only" = 1 ] || [ -x "$EXE" ] || { echo "Build the tests first: $EXE not found" >&2; exit 1; }

engine=$(command -v podman || command -v docker) || { echo "neither podman nor docker found" >&2; exit 1; }
password="${QBR_TEST_PASSWORD:-qbr-test}"
export QBR_TEST_PASSWORD="$password"
# (not for a self-contained program such as the AppImage: LD_LIBRARY_PATH would win over its own run paths)
[ -n "${QBR_APP:-}" ] || export LD_LIBRARY_PATH="$ROOT/backend/build-linux${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# the programs run through this prefix (empty: here); the environment they need is passed explicitly
read -r -a run_prefix <<< "${QBR_EXEC:-}"
ssh_env=()
run() { "${run_prefix[@]}" env QBR_TEST_PASSWORD="$password" "${ssh_env[@]}" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" "$@"; }

# OpenSSH server for the SSH tunnel tests (tests/ci/sshd, ADR-0048), on the host network so that it reaches the test
# servers at 127.0.0.1; the keys are made per run. Without it the tunnel tests are skipped.
if [ "$app_only" = 0 ]; then
  ssh_image="qbr-sshd:$(sha256sum "$ROOT/tests/ci/sshd/Containerfile" | cut -c1-12)"
  ssh_dir="${TMPDIR:-/tmp}/qbr-ssh-keys"
  if "$engine" image inspect "$ssh_image" >/dev/null 2>&1 \
     || "$engine" build -q -t "$ssh_image" "$ROOT/tests/ci/sshd" >/dev/null 2>&1; then
    rm -rf "$ssh_dir"
    mkdir -p "$ssh_dir"
    # readable for the test program whoever owns the files (throw-away keys)
    "$engine" run --rm --security-opt label=disable -v "$ssh_dir:/out" "$ssh_image" sh -c \
      'ssh-keygen -q -t ed25519 -N "" -C qbr -f /out/id_ed25519 && ssh-keygen -q -t ed25519 -N qbr-pass -C qbr \
       -f /out/id_ed25519_pass && cat /out/*.pub > /out/authorized_keys && chmod 644 /out/*'
    "$engine" rm -f qbr-sshd >/dev/null 2>&1
    "$engine" run -d --name qbr-sshd --network host --security-opt label=disable -v "$ssh_dir:/keys:ro" \
      "$ssh_image" >/dev/null
    for _ in $(seq 20); do
      grep -q 'Server listening' <<< "$("$engine" logs qbr-sshd 2>&1)" && break
      sleep 1
    done
    ssh_env=(QBR_TEST_SSH_PORT=24022 "QBR_TEST_SSH_DIR=$ssh_dir")
  else
    echo "warning: the SSH test server image did not build; the SSH tunnel tests are skipped" >&2
  fi
fi

# image, env var for the root password, admin client used for readiness checks
matrix=(
  "mysql:5.7      MYSQL_ROOT_PASSWORD   mysqladmin"
  "mysql:8.0      MYSQL_ROOT_PASSWORD   mysqladmin"
  "mysql:8.4      MYSQL_ROOT_PASSWORD   mysqladmin"
  "mysql:9        MYSQL_ROOT_PASSWORD   mysqladmin"
  "mariadb:10.11  MARIADB_ROOT_PASSWORD mariadb-admin"
  "mariadb:11.4   MARIADB_ROOT_PASSWORD mariadb-admin"
)

# below Linux's ephemeral range (32768-60999): the tests' own client connections take local ports from that range, and
# one of them on the next server's port made `run -p` fail ("Address already in use", mysql:9 on the GitHub runner)
results=() failed=0 port=24000
for entry in "${matrix[@]}"; do
  read -r image pwdvar admin <<< "$entry"
  port=$((port + 1))
  if [ -n "$only" ] && [[ ",$only," != *",$image,"* ]]; then continue; fi
  name="qbr-matrix-${image//[^a-zA-Z0-9]/-}"
  echo "=== $image on port $port"
  "$engine" rm -f "$name" >/dev/null 2>&1
  started=$("$engine" run -d --name "$name" -p "$port:3306" -e "$pwdvar=$password" "docker.io/library/$image" 2>&1 >/dev/null)

  # up to six minutes (the servers usually need seconds; a slow runner should not fail the run)
  ready=0 waited_since=$SECONDS
  for _ in $(seq 120); do
    # ready when the server's log says it listens on 3306 (the entrypoint's temporary server during initialisation
    # has no network, port 0; MySQL's X plugin line names 33060). The admin client inside the container is only the
    # fallback: on the GitHub runner it never answered for the MySQL images although the servers were running.
    # Both outputs are read whole first: `cmd | grep -q` fails under pipefail when grep stops reading early (SIGPIPE).
    # MySQL 5.7 and MariaDB put "Version: ... port: 3306" on the line after "ready for connections", hence one line.
    server_log=$("$engine" logs "$name" 2>&1 | tr '\n' ' ')
    if grep -qE "ready for connections\.?[[:space:]]+Version: '[^']*'[[:space:]]+socket: '[^']*'[[:space:]]+port: 3306[^0-9]" \
         <<< "$server_log" \
       || grep -q alive <<< "$("$engine" exec "$name" "$admin" ping -uroot "-p$password" 2>&1)"; then ready=1; break; fi
    sleep 3
  done
  echo "waited $((SECONDS - waited_since)) s for the server (ready=$ready)"
  if [ "$ready" = 0 ]; then
    # the server's last words and the container state say why (permissions, kernel features, image pull)
    why=$("$engine" ps -a --filter "name=^$name\$" --format '{{.Status}}' 2>&1 | head -1)
    [ -z "$started" ] || why="$why; run: $(tr '\n|' ' /' <<< "$started" | cut -c1-300)"
    why="$why; $("$engine" logs --tail 6 "$name" 2>&1 | tr '\n|' ' /' | cut -c1-700)"
    results+=("$image|server did not start|-|$why")
    failed=1
    [ "$keep" = 1 ] || "$engine" rm -f "$name" >/dev/null
    continue
  fi
  # the entrypoint restarts the server once after initialisation; wait until it is stable
  sleep 3

  if [ "$app_only" = 1 ]; then
    status="skipped" details=""
  else
    log=$(run QBR_TEST_PORT="$port" timeout 300 "$EXE" --all --format=plain 2>&1)
    run=$(grep -oP 'Number of run tests:\s+\K\d+' <<< "$log")
    err=$(grep -oP 'Number of errors:\s+\K\d+' <<< "$log")
    fail=$(grep -oP 'Number of failures:\s+\K\d+' <<< "$log")
    ign=$(grep -c 'Ignored test:' <<< "$log")
    if [ -n "$run" ] && [ "$err" = 0 ] && [ "$fail" = 0 ]; then
      status="PASS ($run tests)" details=""
      [ "${ign:-0}" = 0 ] || status="PASS ($run tests, $ign ignored)"
    else
      status="FAIL ($run tests)" failed=1
      details=$(grep -E 'Failed:|Exception|Assertion|Message' <<< "$log" | head -5 | tr '\n' ' ')
      # no counts at all: the test program did not run; show how it started
      [ -n "$run" ] || details="no test summary: $(head -3 <<< "$log" | tr '\n' ' ')"
    fi
  fi

  # the application itself: connect through the ported code, once via the command line path and
  # once by driving the connect dialog (needs app/bin/querymole and `python tools/prepare_runtime.py`)
  app_result="n/a"
  # a virtual X server keeps the windows off the desktop (and works without one)
  xvfb=(); if run sh -c 'command -v xvfb-run' >/dev/null 2>&1; then xvfb=(xvfb-run -a); fi
  if [ -x "$APP" ]; then
    data_dir="${TMPDIR:-/tmp}/qbr-matrix-data"
    mkdir -p "$data_dir"
    app_result="PASS"
    for mode in selftest-connect selftest-dialog; do
      report="$data_dir/$mode.txt"
      rm -f "$report"
      run timeout 60 "${xvfb[@]}" "$APP" -datadir "$data_dir" -u root -p "$password" -h 127.0.0.1 -P "$port" "--$mode" "$report" \
        >/dev/null 2>&1
      if ! grep -qE '^(dialog )?connected' "$report" 2>/dev/null; then
        app_result="FAIL"
        # what the program reported, or the first line of its error file
        why=$(head -1 "$report" 2>/dev/null || true)
        err="$(dirname "$APP")/$(basename "$APP").error.txt"
        [ -n "$why" ] || why=$(head -1 "$err" 2>/dev/null || echo "no report")
        details="$details $mode: $why;"
      fi
    done
    [ "$app_result" = PASS ] || failed=1
  fi
  results+=("$image|$status|$app_result|$details")

  [ "$keep" = 1 ] || "$engine" rm -f "$name" >/dev/null
done

[ "$keep" = 1 ] || "$engine" rm -f qbr-sshd >/dev/null 2>&1

echo
printf '%-15s %-22s %-6s %s\n' Server Result App Details
for r in "${results[@]}"; do
  IFS='|' read -r s res app det <<< "$r"
  printf '%-15s %-22s %-6s %s\n' "$s" "$res" "$app" "$det"
done

# in GitHub Actions: the table on the run's summary page, and every failed server as an error annotation (both can be
# read without signing in, unlike the log)
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "| Server | Result | App | Details |"
    echo "|---|---|---|---|"
    for r in "${results[@]}"; do
      IFS='|' read -r s res app det <<< "$r"
      echo "| $s | $res | $app | $det |"
    done
  } >> "$GITHUB_STEP_SUMMARY"
fi
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  for r in "${results[@]}"; do
    IFS='|' read -r s res app det <<< "$r"
    case "$res $app" in *FAIL*|*"did not start"*) echo "::error title=$s::$res, app $app. $det" ;; esac
  done
fi
exit "$failed"
