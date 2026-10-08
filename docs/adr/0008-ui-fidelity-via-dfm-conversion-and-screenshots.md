# ADR-0008 — UI fidelity: convert the DFMs, review by screenshots

- Status: Accepted; reference screenshots outstanding
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

"Exactly as before" (ADR-0001) needs a way to produce and check forms
reproducibly. There are about 30 application `.dfm` files in the sources; 12 matter for
the Query Browser. They are text files with exact geometry, fonts and properties,
and the LFM syntax of Lazarus is practically identical. What cannot be
compared against is the running original: no installation is at hand and the
Delphi 2006 toolchain is gone, so there are no reference screenshots.

Not everything is in the DFMs: the main window's `.dfm` is a skeleton. Toolbars,
tab headers, the query/result area and many images are created in code
(`Toolbar.pas`, `TabHeader`, `SqlCmdPanel.pas`, `ScriptPanel.pas`) and drawn
from PNG resources.

## Decision

- Convert with `tools/dfm2lfm.py`: a real parser (not text substitution) that
  maps classes (`TTnt*` → LCL, `TUniCodeEdit` → `TSynEdit`, ...), drops
  properties the LCL does not have, converts strings from Windows-1252 `#nnn`
  escapes to UTF-8, and **never alters geometry or events**.
- Frames stay frames in the application's `.lfm` files (`app/forms/`). For
  review only, `--flatten-frames` expands them into panels with
  collision-free names.
- Review with `tools/lfmview`, a Lazarus program that loads any `.lfm` without
  form code, logs every property or class the LCL does not understand, and
  saves screenshots including each tab page. `tools/convert_forms.py` runs the
  whole set; `docs/reconstructed/` holds the images (12 forms, 0 issues).
- Fidelity of the code-built parts is achieved by porting the original code
  (ADR-0002), not by redrawing them.

## Consequences

Positive:

- Reproducible and diffable: the conversion is a script, not manual work in an
  IDE, and re-runs after converter changes show regressions.
- Unknown properties are reported, not silently dropped; the problem list
  drove the property tables.
- The images show authentic assets (e.g. the About dialog's dolphin).

Negative / costs:

- No pixel comparison against the original is possible; review is by eye
  against the DFM geometry. **Reference screenshots from someone who still
  runs the original would raise confidence considerably** (open item).
- `TUniCodeEdit`, `TAnimate` and menu owner-draw (`OnAdvancedDrawItem`) lose
  their configuration in the conversion and must be rebuilt in code.
- The window-capture tool is Windows specific (PrintWindow) and the viewer is
  a console-subsystem app because a GUI-subsystem build hangs on `WriteLn`.
- Delphi `TImageList` data has a format Lazarus cannot read; toolbar icon
  lists must be rebuilt from the PNG files.

## Alternatives considered

- **The Lazarus IDE's Delphi converter.** Rejected as the main path: GUI-only,
  not scriptable or repeatable, and it works on the `.pas` as well, which is
  ported separately.
- **Rebuild the forms in the Lazarus designer.** Rejected: manual, error prone
  and not repeatable.
- **Pixel diff against screenshots of the original.** Desirable, blocked on
  obtaining the screenshots.

## Related

- ADR-0001, ADR-0002, ADR-0007, ADR-0009.
