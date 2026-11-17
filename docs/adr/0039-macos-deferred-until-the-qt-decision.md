# ADR-0039 — macOS is deferred until the widgetset decision of the Qt move

- Status: Accepted
- Date: 2026-11-17
- Deciders: Harald Lapp (project owner)

## Context

ADR-0001 names Windows, Linux and macOS as targets, from one code base. The first macOS build was tried on
2026-11-17 (Apple Silicon, macOS 26.4, FPC 3.2.4rc1, Lazarus 4.8, Cocoa widgetset; `docs/macos-setup.md`). It needed
only small changes: a clang error in the backend, explicit linking of the backend libraries (FPC ignores the library
of `external` declarations on Darwin), `-ld_classic` for Apple's linker, a `TThreadID` field. The program builds,
starts and shows its dialogs.

Every dialog looked at (connect, options) is cut off: controls do not fit into the frames that the forms take over
from the Windows original pixel by pixel. The cause was not analysed. The likely one is the Cocoa metrics (fonts,
control heights), the same kind of difference that the GTK2 port had to adjust for (ADR-0023, ADR-0024). ADR-0002
already expected macOS to need the most polishing.

ADR-0024 plans a move from GTK2 to a Qt widgetset after the first release, together with the first deliberate UI
changes, when layouts no longer have to copy the original pixel by pixel. Tuning the forms for Cocoa now may be work
that the layout changes of that step make obsolete, or that has to be repeated if macOS uses Qt as well. A macOS
release also needs work that Windows and Linux do not: an `.app` bundle that carries the Homebrew libraries,
signing and notarisation (an Apple Developer account) or instructions to remove the quarantine flag, and a Mac to
test on.

## Decision

- The first releases are for **Windows and Linux only**. macOS gets no release, no package and no layout work
  until the Qt move of ADR-0024 starts.
- The ADR of that move also decides the widgetset for macOS (Cocoa or Qt), preferably after comparing a dialog
  under both on a Mac.
- What the first build needed stays in the code (`{$IFDEF DARWIN}` parts, `build.sh`, `tools/macos-setup.sh`,
  `docs/macos-setup.md`). Keeping it building is welcome but not required; nobody has to check changes on a Mac.

## Consequences

Positive:
- No effort goes into Cocoa layouts that may be replaced; Windows and Linux get the time.
- The macOS state is written down (`docs/macos-setup.md`), so the work can resume where it stopped.

Negative:
- Mac users have no build, apart from building it themselves with the checklist and accepting the cut-off dialogs.
- The macOS build may break unnoticed until then; `-ld_classic`, which it currently needs, is deprecated by Apple.

## Alternatives considered

- **Polish Cocoa now:** a macOS release earlier, but layout work that may have to be done again with Qt, and the
  packaging and signing work on top.
- **Build on the Qt widgetset for macOS now:** Qt's macOS style has similar metrics, so the forms would likely need
  the same adjustments; it adds the Qt frameworks and `libQt6Pas` to the bundle; not tried.

## Related

- ADR-0001 — the targets; this ADR orders them.
- ADR-0002 — the LCL; Cocoa expected to need the most polishing.
- ADR-0024 — the Qt move; its follow-up ADR decides the macOS widgetset.
- ADR-0037 — updates per platform; its macOS part waits for this.
