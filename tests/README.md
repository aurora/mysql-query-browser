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
fpc -Fubindings -FUtests/lib -FEtests/bin -Fu<fpc>/units/x86_64-win64/fcl-fpcunit tests/qbr_tests.lpr
# backend/build and mingw64/bin must be on PATH so the DLLs are found
tests/bin/qbr_tests.exe --all --format=plain
```
