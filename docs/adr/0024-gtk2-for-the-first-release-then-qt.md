# ADR-0024 — GTK2 for the first release, a move to Qt afterwards

- Status: Accepted (principle); the switch itself and its trigger are open
- Date: 2026-11-02
- Deciders: Harald Lapp (project owner)

## Context

The Linux port uses the LCL's GTK2 widgetset (ADR-0002). It was the most mature one when the port began, and
the layout work since then (the group box client area, the hidden tab strips, the pinned dpi of ADR-0023, the
clipping of text) is tuned to its metrics, so that the windows look like the Windows original (ADR-0001).

GTK2 is no longer developed; on a Wayland desktop it runs as an X11 client that the compositor scales. A first
try with the Qt5 widgetset (`docs/linux-port.md`, "Qt5 widgetset") built without errors, showed the main window
with the same layout, and scaled as a whole with `QT_SCALE_FACTOR`; its dialogs, the server matrix and the
interactive behaviour were not examined. Qt 5 itself is, to the author's knowledge, no longer supported by its
vendor; the LCL also has a Qt6 widgetset, not tried here.

ADR-0001 forbids UX changes until functional parity. After the first release the program may move away from the
original, which is the point where a different widgetset, and layouts that do not copy the original pixel by
pixel, become acceptable.

## Decision

- The first release of the revival on Linux stays on **GTK2**, as close to the original as the port gets.
- The move to a Qt widgetset (Qt6 preferred over Qt5, to be checked) is planned for the release after it, together
  with the first deliberate UI changes. It gets its own ADR when it starts. It is brought forward if GTK2 is no
  longer packaged by the distributions the project targets, or if the compositor-scaled rendering turns out to be
  unacceptable in use.
- Code that only GTK2 needs is guarded with `{$IFDEF LCLGTK2}`, not with `{$IFNDEF MSWINDOWS}`, so that it is
  visible what has to be redone for another widgetset and does not run there by accident. Code that fixes a
  difference between the VCL and the LCL in general stays under `{$IFNDEF MSWINDOWS}`. Done so far:
  `HidePageControlTabs` and the hidden covering panel in the connect dialog; `PinGtkDpiTo96` was already
  conditional inside its unit.

## Consequences

Positive:
- The first release keeps the look that was reviewed; the switch is decided with the UI changes it belongs to.
- The GTK2 specific adjustments are marked and can be dropped or replaced in one pass.

Negative:
- The first release depends on a widgetset that is on its way out, and on a dpi workaround (ADR-0023).
- Wayland users get an X11 client until the switch.
- Two widgetsets will have to be kept building for a while if Qt is tried before the switch; the Qt build is not
  part of the test matrix.

## Alternatives considered

- **Qt first:** no GTK2 dependency, real scaling; but nothing was tuned for it, the dialogs show differences (group
  captions) and the widgetset is the less mature one for the LCL; it would delay the first release.
- **Both widgetsets in the first release:** doubles the testing and the adjustments for little gain.

## Related

- ADR-0001 — no UX changes until parity; the switch happens after it.
- ADR-0002 — LCL as the UI layer.
- ADR-0009 — HiDPI and vector icons; Qt scaling is one way to get there.
- ADR-0023 — the dpi pin that GTK2 needs.
