# ADR-0009 — HiDPI scaling and vector icons come after functional parity

- Status: Proposed (deferred until functional parity)
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

The original is a 96-dpi bitmap UI. On current displays at 150–200 % scaling
it is either blurred by the OS or tiny. About 240 icons, banners and
backgrounds are PNG resources (150 in `mysqlqb.rc`, 93 in `mysqlcommon.rc`);
the toolbar icons are hand-pixelled 16×16 rasters from 2005. There are no
vector originals, and automatic vectorising of such pixel art looks poor.
Replacing the icons with SVG art would therefore mean *redrawing* them, which
is a visible UX change (ADR-0001).

DFM geometry is absolute; the LCL scales forms through `PixelsPerInch`.

## Decision

Proposed, to be revisited after functional parity:

1. **Now:** all images are loaded through one place (`PNGTools`, by resource
   name), so format and size can change without touching the rest of the
   code. The original PNGs are used unchanged.
2. **Next:** make the application DPI aware (manifest / LCL scaling) and scale
   icons by whole factors (2×, nearest neighbour) so the look stays identical
   to the original and only the blur disappears.
3. **Optional later:** an additional icon set rendered from SVG at **build
   time** into PNGs at 100/125/150/200 %, selectable as "modern icons". No SVG
   library at run time. The classic icons stay the default.

## Consequences

Positive:

- No visual change in the first milestone; HiDPI becomes a contained
  follow-up.
- Pre-rendering avoids a run-time dependency (e.g. BGRABitmap/BGRASVG) and
  keeps start-up cost unchanged.

Negative / costs:

- Until step 2, the UI looks as small or as blurry as the original on HiDPI
  screens.
- Step 3 needs new artwork: real design work, not an engineering task.
- Fonts (MS Sans Serif / Tahoma at fixed heights) and the pixel-exact layouts
  scale differently from vector UIs; some dialogs may need review at large
  factors.

## Alternatives considered

- **Replace everything with SVG now.** Rejected: redraws the icons, breaking
  the "no UX change" rule, and is a large design effort.
- **Render SVG at run time.** Rejected: adds a library and per-start cost for
  no advantage over pre-rendering.
- **Ignore HiDPI.** Rejected as a long-term position: it is the biggest
  everyday annoyance of the original.

## Related

- ADR-0001, ADR-0005 (another deferred UI decision), ADR-0008.
