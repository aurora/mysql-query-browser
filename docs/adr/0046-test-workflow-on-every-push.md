<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0046 — Every push is built and tested by GitHub Actions

- Status: Accepted (first run on GitHub outstanding)
- Date: 2026-11-20
- Deciders: Harald Lapp (project owner)

## Context

Releases are built by GitHub Actions since ADR-0040, but only for tags. Everything else was checked by hand: the
server matrix (`tests/run-matrix.sh`) and the builds ran on the development machine when someone remembered to run
them. AGENTS.md makes the matrix the bar for "done" ("version differences are where the bugs were"), and the Qt6
move (ADR-0044) added a second Linux widgetset that must keep compiling for a release cycle.

The tests need real servers. The matrix starts six of them (MySQL 5.7, 8.0, 8.4, 9, MariaDB 10.11, 11.4) as
throw-away containers; the Pascal toolchain (Lazarus 4.8, FPC 3.2.3, LCL Qt6 and GTK2) comes from Fedora 44, which
the Ubuntu runners do not have in those versions. GitHub's Windows runners cannot run Linux containers.

## Decision

- `.github/workflows/test.yml` runs on every push and pull request (not for changes to documentation only) and on
  demand.
- **Linux:** the job runs `tests/ci.sh`, which developers can run the same way on their machine (host, podman):
  - it builds the image `tests/ci/Containerfile` (Fedora 44, the toolchain of the distrobox without the IDE extras)
    and in it the backend, the program with GTK2 (a compile check), the program with Qt6 (the one under test) and
    the FPCUnit tests;
  - it then runs `tests/run-matrix.sh` on the host, which starts the servers with podman as before and runs the
    FPCUnit tests and the program's self-tests in the image (`QBR_EXEC`, host network). Without `QBR_EXEC` the script
    behaves as before.
- **Windows:** a build check with the release job's toolchain (`./build.sh --backend --runtime`); no tests, since
  the servers cannot run there.
- The release workflow stays as it is; a failing test run does not block a tag, the owner decides.

## Consequences

Positive:
- Every push is checked against all six servers and both Linux widgetsets, and against the Windows build; a broken
  build or a server-specific regression shows up at the push, not at the next release.
- `tests/ci.sh` gives a contributor without the distrobox one command for the whole check.

Negative:
- A Linux run takes the image build plus the matrix (about a quarter of an hour); runs of the same branch cancel each
  other.
- Windows is built, not tested; the Windows-specific code paths (TLS, the socket options of ADR-0043) still need a
  manual check.
- The app self-tests run the connect paths only; the GUI review (screenshots) stays manual (ADR-0008).

## Alternatives considered

- **GitHub service containers for the servers:** one job per server, but the toolchain would have to run on the
  runner itself or in a container job, and the matrix script would be duplicated in YAML instead of being the same
  command developers run.
- **The Pascal toolchain from Ubuntu's packages:** older Lazarus/FPC than the project uses; builds would differ.
- **Servers on Windows (MySQL/MariaDB installers):** possible, but slow and only for some of the versions; deferred.

## Related

- ADR-0040 — release workflow; this one tests what it will build.
- ADR-0044 — Qt6 on Linux, GTK2 kept buildable for one cycle.
- ADR-0004 — the server support matrix.
