# ADR-0018 — Update check with velopack-pas and GitHub releases

- Status: Accepted (implemented, not yet built or run: see Consequences)
- Date: 2026-10-17
- Deciders: Harald Lapp (project owner)

## Context

ADR-0014 chose Velopack for installing and updating, and left the update client open until the Pascal
binding exists. The binding is the project owner's library velopack-pas (MIT): a source library that loads
Velopack's native library (`velopack_libc`) at run time, with a thread-based `TVelopackUpdater` for GUI
programs. Releases of this project are published on GitHub, so the natural feed is the GitHub releases
(`vpk upload github`). velopack-pas lacked a way to use that source from the component; it was added there
(`GitHubRepoUrl`).

The mechanism has to work on Linux and macOS as well once those ports exist; Velopack and velopack-pas
support both (Linux: AppImage, macOS: bundle).

## Decision

- **Library:** velopack-pas is a git submodule in `third_party/velopack-pas`, pinned to a commit; the
  project adds `../third_party/velopack-pas/src` to its unit path. Only `src/` is used.
- **Startup:** `StartupVelopack` (unit `UpdateCheck`) is the first statement of `qbr.lpr`. It lets Velopack
  handle install, update and uninstall launches and applies a downloaded update at startup. If
  `velopack_libc.dll` is missing (development builds) it returns and the program runs without update
  support.
- **Feed:** the GitHub releases of `aurora/mysql-query-browser`, pre-releases excluded
  (`UpdateRepositoryUrl` in `UpdateCheck.pas`).
- **UI:** Help > "Check for Updates ..." (a deliberate exception to ADR-0001, like ADR-0017), placed after
  "Report a new bug". The item is added to `Main.lfm` by the converter (`ADD_MENU_ITEMS` in
  `tools/dfm2lfm.py`). Flow: check, "Version X is available. Download and install it now?", a small progress
  window, "Restart now?"; if declined, the update is applied at the next start. No automatic check at startup.
  The item is disabled without the native library or without an internet connection.
- **Package:** `tools/package.sh` copies `velopack_libc.dll` (win-x64) next to `qbr.exe` from
  `VELOPACK_LIBRARY` or, with `VELOPACK_PAS_RELEASE=<tag>`, from a velopack-pas release through its
  `fetch-native.py` (checked against the release's SHA256SUMS).

## Consequences

- **Not verified.** The author could not build the application (no Lazarus/Windows in the session) nor run the
  Windows x64 combination: velopack-pas tests Windows with a 32-bit compiler only (its
  `docs/implementation-plan.md`), and the end-to-end cycle (installed app, `vpk` feed) is open there too. First
  steps on a Windows machine: build, install a 0.1.0 `Setup.exe`, publish 0.1.1 to GitHub, update.
- The submodule points at a branch commit of velopack-pas that adds `GitHubRepoUrl`; re-pin it to a commit on
  that repository's main branch after merging.
- A portable zip is not an installation: the check reports Velopack's error ("not installed") there.
- The release process gains steps: `package.sh --velopack`, then `vpk upload github` (needs a token).
- The licence text of Velopack itself is not yet shipped (`docs/licenses.md`, open).
- No code signing (ADR-0014 unchanged); the downloaded package is verified by Velopack against the release feed.

## Alternatives considered

- **Own HTTP feed:** works with the stock component but needs hosting; GitHub releases are free and already
  used for the project.
- **Copy of velopack-pas into this repository:** simpler to build, but the library is maintained separately
  and shared with other projects.
- **Check at every startup:** a UX change beyond the requested menu item, and a network call at start.

## Related

- ADR-0001, ADR-0014 (packaging), ADR-0017 (menu changes), velopack-pas (https://github.com/aurora/velopack-pas).
