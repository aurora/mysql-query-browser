# ADR-0038 — The program file is named `querymole`

- Status: Accepted
- Date: 2026-11-16
- Deciders: Harald Lapp (project owner)
- Decides the point ADR-0030 deferred ("the executable name (`qbr`/`qbr.exe`)")

## Context

ADR-0030 renamed the product to QueryMole but left the program file as `qbr` / `qbr.exe` (from "Query Browser
Revival"). The name means nothing to users, and it is visible: the Windows Task Manager, firewall prompts and the
installation folder show `qbr.exe`; on Linux it is the window class and the name in process lists; the crash report is
`qbr.error.txt`. Users who start the program with its command-line options (`-h`, `-u`, `-P`, `-datadir`, ...) type it.

ADR-0037 makes the name hard to change: `vpk pack --mainExe` writes it into every update package, and Setup.exe points
the Windows shortcuts at it. No Velopack release has been published yet, so a rename now costs only our own scripts.

## Decision

- The program file is **`querymole`** on Linux and **`querymole.exe`** on Windows: the product name in lower case, no new
  abbreviation. The Lazarus target (`app/qbr.lpi`), `build.sh`, `tools/package.sh`, `tools/package-appimage.sh`
  (`--mainExe querymole`), the AppImage (`usr/bin/querymole`, `querymole.desktop` with `StartupWMClass=querymole`,
  `AppRun`) and the version resource (`InternalName`, `OriginalFilename`) use it.
- Files named after the program follow it by themselves: `querymole.error.txt`, `querymole.trace.txt`.
- **What stays `qbr`:** names that only developers see. These are the project files `app/qbr.lpi` / `qbr.lpr`, the
  resource files `qbr.rc` / `qbr.res`, the environment variables `QBR_*`, the test program `qbr_tests` and the test
  containers `qbr-*`.
- Settings stay where they are (`%APPDATA%\QueryMole\`, ADR-0030); they do not depend on the file name.

## Consequences

- What users see now matches the product name, before the first self-updating release fixes it.
- The portable Windows zip and the plain AppImage of the old alphas contain `qbr`/`qbr.exe`; users of those start
  `querymole` after downloading a new version. Nothing else carries over between the two, since settings are found by
  product name.
- Developer commands in `AGENTS.md` and scripts that call `app/bin/qbr` change; old notes in `docs/` that describe
  past work keep the old name.
- Inside the repository the two names coexist (`qbr.lpi` builds `querymole`); the split is listed above.

## Alternatives considered

- **Keep `qbr`:** no work, but the meaningless name would be fixed for good by the Velopack packages.
- **`qmole`:** shorter to type, but a second, new abbreviation of the product name; with tab completion the length of
  `querymole` does not matter.
- **Rename everything, including `qbr.lpi`, `QBR_*` and the tests:** much more churn (scripts, CI, documentation,
  developer habits) for names no user sees.

## Related

- ADR-0030 (product name QueryMole), ADR-0037 (Velopack packages, `--mainExe`), ADR-0027 (AppImage).
