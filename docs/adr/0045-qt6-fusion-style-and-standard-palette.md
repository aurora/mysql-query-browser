<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0045 — Qt6 build draws with the Fusion style and its standard palette

- Status: Accepted
- Date: 2026-11-19
- Deciders: Harald Lapp (project owner)

## Context

ADR-0044 moves Linux to the Qt6 widgetset and keeps ADR-0001: the forms are tuned to the original's pixel layouts.
How a control looks under Qt is decided by the Qt style and the palette, and those normally come from the desktop
(platform theme plugins such as KDE's Breeze, `QT_STYLE_OVERRIDE`, qt6ct). That gives the program a different look,
different control metrics and possibly a dark palette on every desktop, and the layouts can only be tuned for one.

The AppImage (ADR-0027) bundles its own Qt, which cannot load the desktop's style plugins (they are built against
the host's Qt); without them Qt falls back to Fusion. So the released program would draw with Fusion on most
desktops anyway, and with something else on the few where a compatible plugin happens to load.

The two candidates that Qt itself ships were compared by screenshot under Xvfb (connect dialog, options pages,
main window; 2026-11-19, `docs/linux-port.md`):

- **Fusion:** clean and consistent; group box captions sit above the frame instead of in its line; otherwise the
  layouts fit with small corrections.
- **Windows** (the classic Windows 9x/2000 style of Qt): the captions sit in the frame line as in the original, but
  without a matching palette the controls look crude (edit fields without their 3D border, mismatched greys); a
  palette of our own would be needed.

The GTK2 build has no fixed look either: it takes the desktop's GTK2 theme.

## Decision

- Under the Qt6 widgetset the program sets the **Fusion** style and Fusion's **standard (light) palette** right
  after `Application.Initialize` (`UseFusionStyle` in `app/compat/QtStyle.pas`), regardless of the desktop,
  `QT_STYLE_OVERRIDE` and the platform theme. Qt's own scaling (`QT_SCALE_FACTOR`, the desktop's scale) is not
  affected.
- The Qt6 layouts are tuned and reviewed against Fusion only. Differences to the original that come from the style
  itself, such as the caption position of group boxes, are accepted as the platform's rendering, like the GTK2
  theme's; differences that hide or cut off content are port bugs.
- There is no option to choose another style or a dark palette; that would be a UI change after parity
  (ADR-0001, ADR-0009).

## Consequences

Positive:
- One look on every Linux desktop and in every way of starting the program (AppImage, development build); the
  layouts have to fit one set of metrics.
- The screenshots of the developer modes are representative of what users see.
- The program's own colours (result grid, editor, gradients, the original's light pictures) never meet a dark
  palette.

Negative:
- The program does not follow the desktop's theme or dark mode; on a dark desktop it is a light window.
- Group box captions above the frame differ from the original.
- Fusion is Qt's look, not the original Windows XP look of 2006; neither GTK2 nor Qt reproduces that.

## Alternatives considered

- **Follow the desktop (no style set):** looks native where it works, but the look and the metrics differ per
  desktop, a bundled Qt usually ends up with Fusion anyway, and a dark palette clashes with the program's own
  colours.
- **Qt's Windows style:** captions in the frame line like the original, but crude without a hand-made palette, and
  a hand-made palette is a design of our own.
- **A style sheet that imitates the original:** most control fidelity, but a large amount of styling to write and
  maintain, and it fights the LCL's own use of style sheets (tab sizes).

## Related

- ADR-0044 — Qt6 on Linux; this ADR fixes its look.
- ADR-0001 — no UX changes; the style is the platform rendering, not a redesign.
- ADR-0008 — screenshot review, done against Fusion.
- ADR-0009 — HiDPI and theming after parity.
- ADR-0027 — the AppImage bundles Qt, which is why the desktop's style plugins are not available.
