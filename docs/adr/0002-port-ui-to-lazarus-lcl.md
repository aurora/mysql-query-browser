# ADR-0002 — Port the UI to Free Pascal / Lazarus (LCL)

- Status: Accepted
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

ADR-0001 requires the Windows UI to be reproduced as it was. That UI is
Delphi 2006 code: forms are `.dfm` text files with exact pixel geometry, the
logic is Pascal, the controls are VCL plus a few third-party packages (TNT
Unicode Controls, VirtualTreeView, UniCodeEditor, PNGImage). Closure of the
main window is 79 units / ~145k lines, of which an estimated 30–40k are the
project's own code; the rest is third-party code that is replaced.

The choice of UI technology decides whether "exactly as before" is cheap or
expensive.

## Decision

- Port the UI to **Free Pascal with the Lazarus LCL**, keeping the Pascal
  source and porting it unit by unit (`{$mode delphi}`).
- Forms come from the original `.dfm` files, converted to `.lfm`
  (ADR-0008). Geometry is never touched.
- The LCL win32 widgetset uses the same native Win32 controls the VCL wraps,
  so Windows looks and behaves like the original; Linux/macOS use the GTK/Qt
  and Cocoa widgetsets.
- Toolchain: Lazarus 4.8 / FPC 3.2.2 (installed via winget on the development
  machine).

## Consequences

Positive:

- The `.dfm` → `.lfm` conversion is mostly mechanical (same text syntax);
  twelve forms already load with zero LCL load errors.
- Source language stays Pascal; the logic is ported, not re-implemented in a
  different language.
- Most replacement libraries ship with Lazarus (VirtualTreeView, SynEdit) or
  FPC (regexpr, registry).

Negative / costs:

- The own-code part of the port is large (tens of thousands of lines) and has
  to be done unit by unit; nothing is free beyond the form conversion.
- Windows API calls in the sources (e.g. `AuxFuncs`, ~3.4k lines) need
  platform guards before Linux/macOS work.
- Some controls have no LCL equivalent (`TRichEdit`, `TAnimate`, IE web
  control); they need placeholders or replacements.
- The Lazarus Cocoa widgetset is less mature than win32; macOS will need the
  most polishing.

## Alternatives considered

- **Qt (C++).** Rejected: every window would have to be rebuilt by hand and
  would drift from the original geometry; the logic would need translating to
  C++.
- **Electron / Tauri.** Rejected: cannot reproduce native Win32 controls
  pixel for pixel, heavy runtime, and a complete rewrite of the logic.
- **Current Delphi (VCL).** Rejected: Windows-only, commercial licence, and it
  contradicts the cross-platform goal; FMX does not look native.
- **Keep gtkmm and Cocoa UIs.** Rejected in ADR-0001.

## Related

- ADR-0001 (goal), ADR-0007 (library replacements), ADR-0008 (form
  conversion).
