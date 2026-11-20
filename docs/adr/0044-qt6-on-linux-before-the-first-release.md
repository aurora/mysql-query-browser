<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0044 — Qt6 on Linux before the first release

- Status: Accepted; the release build switched with 0.1.0-alpha.6 (2026-11-20; the desktop checklist is still open)
- Date: 2026-11-19
- Deciders: Harald Lapp (project owner)

## Context

ADR-0024 kept the first Linux release on GTK2 and planned the move to Qt (Qt6 preferred) for the release after it,
together with the first deliberate UI changes. It allowed bringing the move forward if GTK2 stopped being packaged
or if its rendering turned out unacceptable. The situation has changed since:

- **GTK2 is on its way out, also in the LCL.** Lazarus 5.0 (RC1 since mid-October 2026) makes GTK3 the default
  widgetset on Linux; GTK2 stays selectable. Fedora 44 and Ubuntu 26.04 no longer install GTK2 by default; the
  AppImage carries it (ADR-0027). On Wayland the program runs through XWayland, and with the dpi pinned to 96
  (ADR-0023) a scaled desktop gets a blurry, compositor-scaled window.
- **Much of the Linux debugging was GTK2-specific.** Heap corruption from LCL calls in worker threads that the VCL
  tolerated (GDK region assertions, `double free`), the scroll bar loop in VirtualTreeView (`WM_SIZE` delivered
  late), an X round trip with a nested main loop for every clipboard query in the idle handler, tab strips and group
  captions measured differently (`docs/linux-port.md`). Each fix is guarded with `{$IFDEF LCLGTK2}` as ADR-0024
  asked.
- **A Qt6 trial build (2026-11-19) worked without source changes.** Lazarus 4.8 with `lazarus-lcl-qt6` and
  `qt6pas` (Qt 6.11) builds the program; the application tests pass on all six matrix servers; the developer modes
  (screenshots, stop and edit, schema tree stress test, the menu smoke test over 137 entries, dialogs) run under
  Xvfb; UTF-8 and CJK text show correctly. Visible differences to GTK2: group box captions above the frame instead
  of in its line, the options page header cut at its right edge, darker grid lines. The trial also found a crash on
  quit that existed under GTK2 as well (merged menus freed while merged; fixed for all widgetsets).
- The first release is not out yet (0.1.0-alpha.5). Tuning the layouts for GTK2 now and again for Qt6 after the
  release is work done twice, and the first stable release would start on a widgetset that is about to be replaced.

GTK3 was considered as the other way off GTK2 (see Alternatives).

## Decision

- **The Linux widgetset becomes Qt6** (LCL `qt6`, `libQt6Pas`), and the move happens **before the first release**.
  This supersedes ADR-0024 in its timing; its rule for widgetset-specific code stays.
- **ADR-0001 still applies.** The move is not a UI change: the Qt6 build is tuned to the original layouts as the
  GTK2 build was, reviewed by screenshot (ADR-0008). Differences such as the group captions are bugs of the port,
  not new design. Deliberate UI changes still wait for parity.
- **Widgetset-specific code** is guarded with `{$IFDEF LCLQT6}`, as GTK2 code is with `{$IFDEF LCLGTK2}`; fixes for a
  general VCL/LCL difference stay under `{$IFNDEF MSWINDOWS}` or unguarded.
- **Toolchain:** Lazarus 4.8, as on Windows. Lazarus 5.0 is not needed for Qt6; moving to it is a separate decision
  once it is final.
- **Release build switches** from GTK2 to Qt6 when:
  1. the Qt6 build passes `tests/run-matrix.sh` (FPCUnit and application tests) on all servers;
  2. the converted forms and the main window were reviewed by screenshot under Qt6 and the differences fixed or
     listed;
  3. the manual checklist (`docs/linux-manual-test.md`) was done on a real desktop, Wayland and X11, unscaled and
     scaled;
  4. the AppImage bundles Qt6 and runs on the oldest supported distribution of ADR-0027.
- **AppImage:** it bundles Qt6 (QtCore, QtGui, QtWidgets, the platform plugins) and `libQt6Pas` instead of GTK2, built
  in the AppImage's build container (ADR-0027). Whether the Qt6 of AlmaLinux 9 is new enough for `libQt6Pas`, or
  Qt6 and the binding have to be built there, is to be checked. Which Qt platform plugin runs by default (native
  Wayland or `xcb`) is decided with the checklist above.
- **Scaling:** under Qt6 the dpi pin of ADR-0023 does not apply; Qt scales the whole window. Whether the fixed
  layouts survive fractional scaling is part of the checklist.
- **GTK2 stays buildable, without a release,** for one release cycle after the switch as a fallback. Then its
  `{$IFDEF LCLGTK2}` code, the dpi pin (ADR-0023) and the GTK2 parts of the AppImage scripts are removed.
- **macOS stays open** (ADR-0039): this ADR decides Linux only. Cocoa or Qt6 on macOS is decided after comparing a
  dialog under both on a Mac.

## Consequences

Positive:
- The first release starts on the widgetset the program will keep; the layout work is done once.
- Native Wayland and real scaling become possible; the blurry compositor scaling and the dpi pin go away.
- A class of GTK2-specific problems (thread sensitivity of GDK, late size messages, clipboard round trips) no
  longer applies; the developer screenshot modes work under Qt6 (they did not under Qt5).
- Qt6 is maintained upstream and in the distributions; the LCL has had a Qt6 widgetset since Lazarus 3.0.

Negative:
- The first release moves later: the GTK2 tuning has to be redone for Qt6 (group boxes, page headers, grid lines,
  whatever the screenshot review finds).
- The AppImage gets larger, and its build gets harder: `libQt6Pas` is not packaged everywhere and may have to be
  built in the AlmaLinux 9 container together with a matching Qt6.
- Qt6 has its own problems that are not known yet; the GTK2 port had months of use, the Qt6 build one day of
  testing. The GTK2 build has to be kept compiling for a while, so two widgetsets are tested.
- `{$IFDEF LCLGTK2}` fixes may hide general problems that show up again under Qt6 in another form.
- Users who installed a GTK2 alpha get a visibly different (Qt-styled) program through the update.

## Alternatives considered

- **Keep ADR-0024 as it is (GTK2 first, Qt after the release):** the first release sooner, but layout tuning done
  twice and a stable release on a widgetset that is being dropped.
- **GTK3:** the default of Lazarus 5.0, so it will get attention upstream, but it only became usable for the IDE
  this year and is not in Lazarus 4.8 in a mature state; it would bring back the GTK family of problems the port
  already fought (threads, size messages, metrics), and the program is a heavy user of owner-drawn controls and
  VirtualTreeView. Not tried.
- **Qt5:** built and ran in the first try (2026-11-01), but Qt5 is end of life upstream and the screenshot modes
  painted black.
- **Release GTK2 and Qt6 side by side:** doubles testing and packaging for no gain to users.

## Related

- ADR-0024 — GTK2 first, then Qt; superseded in part (timing) by this ADR, its guard rule kept.
- ADR-0001 — no UX changes until parity; the move does not change that.
- ADR-0002 — the LCL as UI layer.
- ADR-0008 — fidelity by screenshot review; applies to the Qt6 build.
- ADR-0009 — HiDPI after parity; Qt's uniform scaling is not a layout change.
- ADR-0023 — the GTK2 dpi pin; removed after the GTK2 fallback ends.
- ADR-0027 — the AppImage; its bundled toolkit becomes Qt6.
- ADR-0037 — updates per platform; the AppImage update path is unchanged.
- ADR-0039 — macOS deferred; its widgetset is still decided separately.
- `docs/linux-port.md` — the Qt6 trial build (2026-11-19) and the Qt5 try (2026-11-01).
