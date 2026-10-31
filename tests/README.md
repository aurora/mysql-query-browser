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
