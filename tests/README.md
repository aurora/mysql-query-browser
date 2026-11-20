# Tests

FPCUnit tests that exercise the backend DLLs through the Pascal bindings.

Needs a MySQL server. Defaults match the throw-away container from the docs;
override with `QBR_TEST_HOST`, `QBR_TEST_PORT`, `QBR_TEST_USER`, `QBR_TEST_PASSWORD`.

```
podman run -d --name qbr-mysql8 -p 33306:3306 -e MYSQL_ROOT_PASSWORD=<pwd> mysql:8.4
```

Build and run (Windows, MSYS2 mingw64 + Lazarus/FPC 3.2.2):

```
cmake -S backend -B backend/build -G Ninja && cmake --build backend/build
fpc -Fubindings -Fuapp/compat -Fuapp/src -FUtests/lib -FEtests/bin -Fu<fpc>/units/x86_64-win64/fcl-fpcunit tests/qbr_tests.lpr
# backend/build and mingw64/bin must be on PATH so the DLLs are found
tests/bin/qbr_tests.exe --all --format=plain
```

Linux (inside the `freepascal` distrobox from `tools/distrobox-setup.sh`):

```
cmake -S backend -B backend/build-linux -G Ninja && cmake --build backend/build-linux
fpc -Fubindings -Fuapp/compat -Fuapp/src -Flbackend/build-linux -FUtests/lib -FEtests/bin -Fu/usr/lib64/fpc/3.2.3/units/x86_64-linux/fcl-fpcunit tests/qbr_tests.lpr
LD_LIBRARY_PATH=backend/build-linux tests/bin/qbr_tests --all --format=plain
```

All supported servers in throw-away containers: `pwsh tests/run-matrix.ps1` (Windows),
`tests/run-matrix.sh` (Linux).

Everything the test workflow (`.github/workflows/test.yml`, ADR-0046) checks on Linux, in one command on a host with
podman (not inside the distrobox): `tests/ci.sh [--only mysql:8.4]`. It builds the backend, the program (GTK2 as a
compile check, Qt6 for the tests) and the tests in the image `tests/ci/Containerfile`, then runs the server matrix.

The SSH tunnel tests (`test_ssh_tunnel.pas`, ADR-0048) need an OpenSSH server that reaches the database server, and
its keys: `QBR_TEST_SSH_PORT` and `QBR_TEST_SSH_DIR` (with `id_ed25519`, `id_ed25519_pass` (passphrase `qbr-pass`)
and their `.pub` files; user `qbr`, password `qbr-test`). `tests/run-matrix.sh` builds `tests/ci/sshd`, makes the keys
and starts it on the host network (port 24022); without these variables the tests are reported as ignored, and the
matrix table says how many were. On Windows the SSH tests need `mingw-w64-x86_64-libssh` from MSYS2 and are not run
by `run-matrix.ps1` yet.

The export tests (`test_export.pas`, ADR-0049) also time a large export (200,000 rows; `QBR_EXPORT_ROWS` sets
another count) and print the times per format. They also cover the CSV/TSV settings and the TSV format (ADR-0050),
including a round trip of a TSV file through `LOAD DATA LOCAL INFILE` (the test enables `local_infile` for the time
of the load and restores it).
