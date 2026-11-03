# ADR-0026 — First public beta: no updater, own version, About dialog with the revival's credits

- Status: Accepted (principle); packaging for Linux and macOS is not done yet
- Date: 2026-11-03
- Deciders: Harald Lapp (project owner)

## Context

ADR-0014 and ADR-0018 prepared installers and updates with Velopack. For a first public beta the project owner
prefers to ship plain downloads for Windows and Linux (macOS later, it needs a Mac) and to leave the update
mechanism for later; users replace the program by hand. The program is still called "MySQL Query Browser"; the
rename (ADR-0025) comes later.

Two things in the program are wrong for a public beta:

- **Versions.** The program shows the original's version (`product_version` 1.2.4 beta, from `Consts.ini`) while the
  project has its own (`VERSION`).
- **About dialog.** It credits only the original authors and says nothing about the revival, its maintainer, its
  licence terms (the original text says "GPL", the project is GPL-2.0-or-later, ADR-0011) or the use of an AI
  assistant in the development.

## Decision

- **Version.** The `VERSION` file is the version of the revival, as a semantic version with a pre-release part
  (`0.1.0-beta.1`). `tools/gen_version.py` writes `app/src/RevivalInfo.inc` from it (run by `build.sh`; the file is
  generated and committed like the other generated sources). The splash screen, the About dialog and the connect
  dialog's title show it ("0.1.0 beta.1"); the About dialog adds "based on 1.2.4 beta", the version of the original.
  The version resource of `qbr.exe` takes its numbers from the part before the hyphen.
- **About dialog** (a deliberate exception to ADR-0001, like ADR-0017): the original's copyright line and credits
  stay unchanged; the credits get one more entry, "Revival (Free Pascal / Lazarus): Harald Lapp, with the help of
  Claude Code (Anthropic), an AI coding assistant"; the licence note names the licence as GPL version 2 or later,
  states that there is no warranty and gives the source and bug report address. No copyright line is invented for the
  revival (AGENTS.md). The credits text may use more lines than the original's; the label is made taller, and outside
  Windows the three text labels use one pixel smaller font, because the substitute for Tahoma is wider.
- **Updates.** The beta has no update mechanism. The menu item "Check for Updates ..." is hidden
  (`UpdateMenuVisible` in `UpdateCheck.pas`); the code, the Velopack startup call and `tools/package.sh --velopack`
  stay, so the mechanism can be switched on in a later release without rework.
- **Releases.** Windows: the portable zip of `tools/package.sh`. Linux: an AppImage, built in an older container so
  that it runs on older distributions (to be written). macOS: after the Linux package, when a Mac or a CI runner is
  available. All are published as GitHub pre-releases with a tag; the source of exactly that tag is what the About
  dialog points to.

## Consequences

Positive:
- The beta is honest about what it is: version, licence, maintainer, source, use of an AI assistant.
- No Velopack dependency for the first download; the update work is not wasted.

Negative:
- Users update by downloading again, and the old version stays installed next to the new one if they unpack
  elsewhere.
- The Windows build changes visibly (version text, hidden menu item, credits), which ADR-0001 otherwise forbids;
  listed here as the exception.
- Until the rename, the name "MySQL Query Browser" is used for a public release (see ADR-0025; the trademark
  question is left to the owner).

## Alternatives considered

- **Keep the original's version number:** confuses the revival with the 2006 program.
- **Ship Velopack in the beta:** more to test before anyone has the program; no installer is needed to try it.
- **Put the AI note only in the README:** the About dialog is where users look for who made the program.

## Related

- ADR-0001 — no UX changes before parity; exceptions are recorded in their own ADRs.
- ADR-0014, ADR-0018 — Velopack packaging and update check (kept, switched off in the beta).
- ADR-0025 — package id and feed when the application is renamed.
