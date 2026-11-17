<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0041 — The version include is generated at build time, not committed

- Status: Accepted
- Date: 2026-11-17
- Deciders: Harald Lapp (project owner)

## Context

ADR-0026 made `VERSION` the version of the revival: `tools/gen_version.py` writes `app/src/RevivalInfo.inc` from it
(the constants the splash screen, the About dialog and the update check use), run by `build.sh`, and the file was
committed like the other generated sources. That gave two copies of the version in git. A build with plain
`lazbuild` or from the Lazarus IDE did not run the generator, so after a change of `VERSION` the program could show
the old version; every version change needed two files in the commit, and test cycles had to restore both
(`docs/update-test.md`).

## Decision

- `app/src/RevivalInfo.inc` is **not in git** (`.gitignore`); `VERSION` is the only place the version is written.
- `app/qbr.lpi` runs `tools/gen_version.py` as its **"Execute before"** step, so every build of the project
  (`build.sh`, `lazbuild`, the IDE) writes the file first. The interpreter is the build macro `QBR_PYTHON`, set by the
  project's conditionals: `python3` for macOS (no unversioned `python` there, as in `build.sh`), `python` otherwise.
- `build.sh` keeps its own call of the generator (harmless, and it shows in the build output).

This amends the "Version" part of ADR-0026 (generated and committed → generated at build time).

## Consequences

- Building needs Python 3 on `PATH` under that name, also in the IDE; it was already needed for the resources.
- After a fresh clone the file appears with the first build; a unit compiled without the project (e.g. a test program
  that pulls in `CommonFuncs`) would need the generator run first. No test does today.
- The generator writes the file only when its content changes, so it does not force recompiles.

## Alternatives

- **Keep it committed** and rely on `build.sh` (the release paths all use it). Leaves the IDE/lazbuild drift and the
  double commit.
- **Read `VERSION` at run time.** The file would have to be shipped, could be missing or edited, and the update check
  would trust a text file next to the program; a constant is bound to the build.

## Related

ADR-0026, ADR-0040.
