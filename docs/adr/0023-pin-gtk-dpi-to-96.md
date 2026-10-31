# ADR-0023 — Pin GTK's dpi setting to 96 on Linux

- Status: Accepted (implemented for GTK2; checked by the author on a scaled KDE desktop)
- Date: 2026-10-31
- Deciders: Harald Lapp (project owner)

## Context

The forms are laid out in pixels for 96 dpi (fonts as pixel heights, controls with fixed sizes), as in the
Windows original. GTK2 sizes everything it draws itself from the desktop's dpi setting (`gtk-xft-dpi`): the
menu, the fonts the LCL maps to the system font, and `Screen.PixelsPerInch`. On a scaled desktop (KDE with
scale 1.45, the application running as an X11 client that the compositor scales) that setting is not 96, so
text drawn by GTK was larger than the rest of the window, and the compositor scaled the whole window on
top of that: the menu came out too large next to the rest, and bars sized for the smaller text looked
unbalanced. Setting `gtk-xft-dpi=98304` (96 x 1024) for the program through a private `gtkrc` made the
window consistent (checked by the project owner).

ADR-0009 defers real HiDPI support (scaling all sizes, vector icons) until after functional parity.

## Decision

- Outside Windows the program sets GTK's `gtk-xft-dpi` to 96 dpi at start, before the application object is
  initialised (`PinGtkDpiTo96` in `app/compat/GtkDpi.pas`, called from `qbr.lpr`). Only GTK2 is affected;
  with another widgetset the call does nothing.
- The program no longer follows the desktop's dpi. On a high-resolution display without compositor scaling
  the window is as small as the Windows program at 100 %; with compositor scaling (KDE: "Legacy applications
  (X11): scaled by the system") it is scaled as a whole.
- Proper HiDPI stays with ADR-0009.

## Consequences

Positive:
- Text and layout match on every desktop, as in the Windows original; no per-user `gtkrc` needed.
- No change to the forms or to the Windows build.

Negative:
- The user cannot make the text larger through the desktop's font dpi; the compositor scale is the only
  knob until ADR-0009 is implemented.
- Real dpi values below or above 96 are ignored for this program, also where a correct HiDPI setup would
  have been right.
- Qt5 is not covered (it has its own scaling, `QT_SCALE_FACTOR`).

## Alternatives considered

- **Follow the desktop's dpi and scale the layouts:** the real fix, but a large change (ADR-0009).
- **Document the private `gtkrc`:** works, but every user would have to find it.
- **Set it per form/font:** the menu and `Screen.PixelsPerInch` are global, so the global setting is the
  smallest one.

## Related

- ADR-0001 — the layout stays as the original's.
- ADR-0009 — HiDPI and vector icons after parity.
- `docs/linux-port.md`.
