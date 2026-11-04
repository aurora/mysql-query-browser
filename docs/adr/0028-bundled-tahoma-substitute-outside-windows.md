# ADR-0028 — Ship Wine's Tahoma stand-in and use it for the forms outside Windows

- Status: Accepted
- Date: 2026-11-04
- Deciders: Harald Lapp (project owner)

## Context

The forms of the original are laid out for Tahoma (the `.lfm` files name "MS Sans Serif", which the original program
replaces by Tahoma on Windows when ClearType is on and Tahoma exists, `InitForm` in `AuxFuncs`). Outside Windows
neither condition held, so the toolkit chose a substitute: Noto Sans on Fedora, DejaVu Sans on Ubuntu. DejaVu Sans is
wider than Tahoma, and labels and texts were cut off (connect dialog, About dialog). Tahoma itself is Microsoft's
and cannot be shipped.

## Decision

- Ship the "Tahoma" of the Wine project (`tahoma.ttf`, `tahomabd.ttf`; Larry Snyder 2004, derived from Bitstream
  Vera Sans, LGPL-2.1-or-later) unmodified in `third_party/fonts/wine-tahoma/`, with provenance and checksums. It is a
  stand-in with similar metrics and carries the family name "Tahoma", as in Wine, so that the program's font requests
  find it.
- `tools/prepare_runtime.py` copies the files into `fonts/` on every platform except Windows (which has Tahoma).
- At start, before the first form exists, `AddBundledTahoma` (`app/compat/AppFonts.pas`) adds them to the
  application's font set (fontconfig's `FcConfigAppFontAddFile`, the counterpart of the private fonts of
  `CheckFonts`). Outside Windows `InitGlobalVars` then treats Tahoma as available and the "ClearType" branch of
  `InitForm`/`InitFrame` applies, as on Windows 10: the forms get Tahoma. The state is kept in `BundledTahomaLoaded`
  because the toolkit's font list does not show fonts added after it started.
- The Windows package does not carry the fonts. The licence notices go into `licenses/fonts/` of the packages
  (`NOTICE`, `docs/licenses.md`).

## Consequences

- The forms look the same on all Linux systems, and closer to the original than with whatever the system picks.
  A visible change for Linux users, in line with ADR-0001 (the goal is the original's appearance).
- The font is a stand-in: its metrics are similar to Tahoma's, not identical. Text in scripts the font lacks falls
  back to other fonts through the system.
- A system that has a real Tahoma installed may use either one for the family name; not handled.
- The AppImage is about 280 KB larger.
