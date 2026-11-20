<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# Linux port: Windows API in the ported units

Inventory for ROADMAP step 5 (platform guards), sorted by the kind of work it needs, and the state
of that work. Regenerate the raw list inside the `freepascal` distrobox:

```
python tools/winapi_usage.py            # per unit: Windows units in `uses`, Windows-only identifiers
python tools/winapi_usage.py --where    # ... and the routines they are used in
python tools/winapi_usage.py --all      # ... and the identifiers the LCL/RTL covers as well
```

The script compares the identifiers of each unit with the declarations of FPC's Windows units
(`Windows`, `ShellAPI`, `ShlObj`, `ActiveX`, `CommCtrl`, `WinInet`, `WinSock`, the Windows part of
`SysUtils`) and the unit's own `external '*.dll'` imports, minus what the LCL, LazUtils,
VirtualTreeView, SynEdit and the portable RTL declare. Outside Windows the LCL ships its own
`Messages` unit (`lcl/nonwin32`) with the common `WM_*` constants and `TWM*` records, so those
count as portable. A trial build with the Windows units swapped for `LCLIntf`/`LCLType` confirmed the
list for `AuxFuncs` (the first unit the compiler reaches).

Conditional compilation is evaluated as for Linux, so guarded code no longer counts. Known false
positives: `password` (`with` fields in `ConnectToInstance`, `OptionsEditor`) and `IID` (a parameter
name in `CommonTypes`). The script does not see Windows *behaviour* behind portable names; see "Not
visible to the script" below.

## State (2026-10-30)

Sections 1 to 3 and the path separators of section 5 are done: `qbr` compiles and links on Linux
(GTK2), the script reports no Windows-only identifiers any more, and `tests/run-matrix.sh` passes on
all six servers including the application's `--selftest-connect` and `--selftest-dialog`. The main
window opens against a live server (schema tree, toolbar, SQL highlighting, help from the server).

How it is done:

- `uses Windows` became `{$IFDEF MSWINDOWS}Windows{$ELSE}LCLIntf, LCLType, WinAliases, Types{$ENDIF}`;
  the other Windows units are guarded the same way (`ActiveX` becomes VirtualTreeView's
  `laz.FakeActiveX`). `Messages` stays: the LCL has its own outside Windows.
- `app/compat/WinAliases.pas` (non-Windows only) holds Windows names that the LCL has under another
  name with the same meaning (`WM_TIMER`, `TWMTimer`, `CF_UNICODETEXT`, `GetTextExtentPoint32W`,
  `DrawTextW`, `MessageBoxW`, ...). Windows-only behaviour is never emulated there; it is guarded with
  `{$IFDEF MSWINDOWS}` where it is used, with a `// Port:` comment.
- **The Windows build is unchanged:** a Win64 cross-build of the changed tree has the same `.text`,
  `.data`, `.rdata`, `.idata` and `.rsrc` as one of the previous commit (stripped executables); the only
  difference in the object files is the removed, never called `AuxFuncs.GetTimeBias`. Path literals
  are written as `('fonts' + PathDelim)` for that reason: FPC folds the parenthesised constant, not
  `X + 'fonts' + PathDelim`. Check it the same way after changes to shared code (section "Checking the
  Windows build").

Interim behaviour until the decisions in section 4:

- Data directory: `~/.mysqlgui/`, the folder of the original Linux version (ADR-0019, decision 4.1).
  Since ADR-0030: `$XDG_CONFIG_HOME/querymole/`, with a one-time copy from `~/.mysqlgui/`.
- Long statements are cancelled on the server with `KILL QUERY` over a second connection, guarded so
  that no other statement can be hit (ADR-0020, decision 4.2), on Linux and Windows. The connect and
  ping threads of the connect dialog are still not killed outside Windows; freeing them waits.
- No global hot keys outside Windows (ADR-0022, decision 4.3).

**64-bit pointer arithmetic (fixed).** Query results stayed empty on Linux: the ported code walked
the C arrays with `Integer(Pointer) + n`, which keeps only the low 32 bits of an address (sign
extended, `movslq` in the Win64 code). On Linux the C heap lies above 4 GB, so it failed at once; on
Win64 it worked only while the heap stayed below 4 GB. Now `PtrUInt(Pointer) + n` in
`MySQLResultSetControls`, `MySQLResultSet`, `EditorTable`, `QueryBrowser`, `EditorTableVTEdit`,
`OptionsEditor`; the hash tries in `LexicalTools`/`StringContainers` keep their `PChar` keys as
`PtrUInt` instead of `Cardinal`; `LexicalTools` seeks by a `PByte` difference; `EM_SETRECTNP` gets
`LPARAM(@R)`. This deliberately changes the Windows build in exactly these units. FPC's warnings 4056
and 4082 (`-vw`) find such places; the one left (`LexicalTools`, an ID stored in `Objects[]`) is
harmless. Results, non-ASCII text, NULL and schema expansion checked by screenshot under GTK2.

**Main window checked under GTK2 (2026-10-30)**, by screenshot with the developer modes (`--sql`,
`--cmd edit,setcell,apply`, `--script`, `--cmd explain`, `--dialog ...`, `--help-page`, `--upper-tab`,
`--expand`, `--dblclick-table`, `--modal-shot`) against MySQL 8.4 with a small test schema:

| Area | Result |
|---|---|
| Result grid, navigation bar (Edit/Apply/Discard/First/Last/Search), status text | works |
| Edit mode; apply with server error (error list), apply that succeeds (row changed in the database) | works |
| EXPLAIN panel, export to CSV/HTML/XML (UTF-8 content correct), modal error dialog | works |
| Script tab: breakpoint stop, script with error (error list), progress bar | works after fix 1 |
| Tab headers (faded icons of inactive tabs) | works after fix 2 |
| Options dialog: page "Browser" (from `QueryBrowserOptionPages`) | works after fix 3; General, Connections, Editors were fine |
| Text search, RegEx importer, schema selection, inline help, history, table double click | works |
| Compare without a second result set | shows the original's message |

Fixes:

1. `THandle` is a 32-bit `Longint` on Linux (64-bit on Win64), so `GetWideStringTextWidth(DC: THandle)`
   cut the device context pointer and the measuring failed; the script panel's progress bar got
   `Left=32769` and raised `ELayoutException`. Now `HDC` (also `LastFont: HGDIOBJ` in the inline editors).
   Same type on Windows.
2. `TPNGObject.DrawPartialTrans` read the pixels through `TLazIntfImage.LoadFromBitmap`, which
   misreads the GTK2 device bitmap (smeared icons); outside Windows it reads them from the PNG.
   `TPNGObject.Draw` now follows the original library: images with alpha are drawn at native size at
   `Rect.Left/Top` (callers pass `Rect(X, Y, Width, Height)`), others stretched. **This changes the
   Windows build** (the only difference in the Win64 objects: `PNGImage`); before, those icons were
   stretched into the odd rectangles there too.
3. A tab sheet that moves into another notebook loses `TabVisible` in the LCL, so GTK2 never added it
   (Win32 shows it as a child window anyway), and the page that takes over index 0 is not switched to.
   `OptionsEditor.BuildOptionSideBar` sets `TabVisible` again and selects another page first (non-Windows).

Not checked yet: real
keyboard/mouse interaction, drag and drop, bookmarks, the field viewer, the Qt5 widgetset
(checklist: `docs/linux-manual-test.md`).

**Scaled desktops (2026-10-31).** On a KDE desktop with scale 1.45 the menu was much larger than the rest of
the window: GTK sized its own text from the desktop's dpi while the forms are fixed pixel layouts. The dpi
setting is now pinned to 96 (ADR-0023); KDE's "Legacy applications: scaled by the system" scales the window
as a whole. The result bar's status text was cut off at its lower edge because the LCL clips `DrawText` to the
given rectangle while the Windows code clips to the text height (`DrawWideStringText`, fixed, Win64 build
unchanged). The tab strips of the page controls that the VCL hides behind a panel (connect dialog "Advanced Connection Options",
options dialog) showed through under GTK2; they are switched off and the control is moved down by the height of
the strip (`HidePageControlTabs` in `AuxFuncs`, done when the control is visible, because GTK2 knows the strip's
height only then). In the connect dialog the original's strip is only 1 pixel high, so the control moves down by
that plus the 3D border, and the covering panel is hidden (it would cut into the taller GTK2 group caption).
Checked by screenshot; the Win64 build is unchanged.

**Qt5 widgetset (2026-11-01, first try).** `lazbuild --ws=qt5` builds the whole program without errors (own unit
and output directory, so the GTK2 build is untouched; needs `libQt5Pas`) and it starts, connects and shows the main
window under Xvfb with the same layout as GTK2 (menu, toolbar, result tabs, schema tree, syntax tree, result bar
with its text complete). Qt picks the Wayland plugin inside the distrobox because `WAYLAND_DISPLAY` is inherited:
run with `QT_QPA_PLATFORM=xcb` and `unset WAYLAND_DISPLAY`, otherwise the windows appear on the real desktop. With
`QT_SCALE_FACTOR=1.5` the whole window scales uniformly. Not done: the developer screenshot modes (they paint
black under Qt5), the GTK2-specific adjustments (`AdjustGroupBoxes` measures GTK2; the connect dialog shows the group
caption above its frame), dialogs other than connect, interaction, the server matrix.

**Qt6 widgetset (2026-11-19, trial build for the move in ADR-0024).** Lazarus 4.8 with `lazarus-lcl-qt6` and
`qt6pas` (Qt 6.11) builds the whole program without errors or source changes. Built apart from the GTK2 build with
`lazbuild -B --ws=qt6 --opt=-Fl<repo>/backend/build-linux --opt=-FU<lib dir> --opt=-o<bin dir>/querymole app/qbr.lpi`
and `python tools/prepare_runtime.py <bin dir>`; run with `QT_QPA_PLATFORM=xcb` and `WAYLAND_DISPLAY` unset as above.
Checked under Xvfb against MySQL 8.4 (300,000 rows, UTF-8 and CJK text, NULL): the developer screenshot modes work
under Qt6 (black under Qt5); the main window with results, schema expansion and double click on a table,
`--stop-and-edit` (stop after 700 ms, edit, run again), `--stress-schemata 30`, the About, options (all pages),
connections and text search dialogs, and `--menu-smoke run` (137 entries, only the expected "Only two resultsets can
be compared" message). `tests/run-matrix.sh --app-only` with `QBR_APP` set to the Qt6 build passes on all six servers.
Visible differences to GTK2: group box captions sit above the frame instead of in its line (the GTK2 adjustments
do not apply), the options page header is cut at its right edge, grid lines in the result are darker. Not checked:
interaction on a real desktop (Wayland, scaling), drag and drop, the AppImage with Qt6 libraries.

Found on the way, both widgetsets: quitting crashed (exit code 217, after the main program, so without an error
report). The query browser form's menu is merged into the main menu (`MainMenu.Merge`) and was never unmerged; when
either form was freed, the LCL updated the other menu's handles during destruction (GTK2: use after free in
`TMenu.Destroy` on File > Exit; Qt6: access violation in `TQtWSMenu.CreateHandle` also at the end of every developer
mode). The VCL tolerated it. Both forms now unmerge in `OnDestroy`, which the LCL runs before handles and components
are freed; File > Exit ends with exit code 0 under GTK2 and Qt6, and the Win64 build compiles.

**Qt6, first layout pass (2026-11-19).** Build with `QBR_WIDGETSET=qt6 ./build.sh`; the units now go to
`app/lib/<cpu>-<os>-<widgetset>`, so switching between GTK2 and Qt6 no longer mixes their units (the binary in
`app/bin` is whichever was built last). Run under Xvfb with `QT_QPA_PLATFORM=xcb` and `WAYLAND_DISPLAY` unset.
- Style: Fusion with its standard palette, set in `UseFusionStyle` (`app/compat/QtStyle.pas`, ADR-0045), also when
  `QT_STYLE_OVERRIDE` is set. Compared by screenshot with GTK2 and Qt's Windows style (connect dialog, all options
  pages, main window, about, text search, regex importer, schema selection).
- Grid lines of the result were black: VirtualTreeView draws grid and tree lines with a monochrome pattern brush whose
  colours come from the canvas, and the Qt6 widgetset draws the pattern as a black and white image. `VTCompat` draws
  those lines itself under Qt6 (solid and dotted, same colours and pixel pattern as the brush).
- The options dialog's Connections page had no "Connection Parameters"/"Advanced Parameters" tabs: for `TabHeight`
  the Qt6 widgetset sets the style sheet `QTabBar::tab { height: 16px; width: 0px; }` on the page control, and style
  sheets apply to child widgets, so every page control on its pages had tabs of width 0.
  `ScopeTabSizeStyleSheets` (`QtStyle`, called from `InitForm`) limits the rule to the control's own tab bar and
  leaves out the size 0. The outer tabs stay hidden behind `HeaderPnl` as in the original.
- Accepted as Fusion's rendering: group box captions above the frame. Left as small differences: pages of the options
  dialog start a few pixels higher than under GTK2, the page header is 2 pixels wider than the page frame, the
  "FK naming" combo box shows its text scrolled.
- `tests/run-matrix.sh` passes with GTK2 (all tests) and with the Qt6 build (`--app-only`, `QBR_APP`); under Qt6 the
  menu smoke test, stop and edit and the schema tree stress test pass; the Win64 build compiles (same code size).

**Qt6 AppImage and the Tahoma stand-in under Qt (2026-11-19).** `QBR_WIDGETSET=qt6 tools/package-appimage.sh` builds
the AppImage with the Qt6 widgetset (default still GTK2 until the release switches, ADR-0044):
- Qt 6.10.3 comes from EPEL 9. EPEL has no `qt6pas`, so `tools/appimage/build-qt6pas.sh` builds libQt6Pas in the
  AlmaLinux 9 container from the binding sources of the Lazarus in the freepascal container (6.2.10 for Lazarus 4.8;
  copied to `tools/cache/qt6pas-src` with their timestamps, so the build in `backend/build-el9/qt6pas` stays
  incremental: the first build takes about a quarter of an hour, later runs seconds). The binding is LGPL with the LCL's
  linking exception (`docs/licenses.md`).
- `stage.sh` bundles Qt Core/Gui/Widgets/PrintSupport/DBus, the xcb and Wayland platform plugins (with Wayland's shell,
  decoration and graphics parts), compose and IBus input; no style or platform theme plugins (Fusion is built in), no
  image format plugins. Qt finds its plugins through `usr/bin/qt.conf`, not `QT_PLUGIN_PATH`, which would leak into
  programs the application starts. `libOpenGL.so.0` is bundled: Qt 6 needs it to load, the program does not draw with
  OpenGL, and Ubuntu desktops often lack it (`libopengl0`). It checks that `app/bin/querymole` was built with the
  widgetset it packs. Size: 38 MB (GTK2: 17 MB), mostly ICU.
- The Containerfile of the AlmaLinux image gained Qt; the image tag is now a hash of the Containerfile, so a changed
  file builds a new image. `Containerfile.fpc` (CI) installs `lazarus-lcl-qt6`.
- Checked: newest symbols needed GLIBC_2.34 and GLIBCXX_3.4.29 (GCC 11); the app self-tests of the AppDir pass on all
  six servers (GTK2 and Qt6 images); the Qt6 AppImage starts and draws with Fusion and the Tahoma stand-in on Ubuntu
  22.04, Debian 12 and AlmaLinux 9 containers (Xvfb, with only libgl1/libegl1/fontconfig/harfbuzz installed, no Qt and
  no libxkbcommon) and on Fedora 44; no Qt library comes from the host (read from `/proc/<pid>/maps`). The host
  provides the C library, X11 core, GL/EGL (libglvnd), fontconfig/freetype/harfbuzz and libstdc++.
- Found on the way: under Qt6 the bundled Tahoma stand-in (ADR-0028) was never used, the forms were drawn with Noto Sans
  (Fedora) or DejaVu Sans (Ubuntu), because Qt keeps its own font database and does not see fonts added to fontconfig.
  `AddBundledTahomaToQt` (`AppFonts`) adds the files to Qt's database after `Application.Initialize`. The connect
  dialog and the options pages fit with it (the first layout pass above was done with Noto Sans).
- Seen, not changed: the bundled libxkbcommon (1.0, AlmaLinux 9) prints "unrecognized keysym dead_hamza" for the
  newer Compose file of Fedora 44 on stderr; those compose sequences are ignored, the others work.
- Not tried: the image on a Wayland session (Qt picks the Wayland platform there unless `QT_QPA_PLATFORM` says
  otherwise; whether the LCL's Qt6 widgetset behaves there, or AppRun should prefer xcb, is for the desktop check),
  scaling, the file dialog, and the Velopack variant (`--velopack`) with Qt6.

**Qt6 AppImage on a real Wayland desktop (2026-11-20).** The project owner started the Qt6 AppImage on KDE Plasma
(Wayland, native Qt Wayland platform, no `QT_QPA_PLATFORM`): it works, no problems seen so far. Two kinds of messages
appear on the console, both from the LCL's Qt6 widgetset, not from the program:
- `QObject::disconnect: No such slot QComboBox::_q_returnPressed()`, once per editable combo box: `qtwidgets.pas`
  (Lazarus 4.8, line 11391) disconnects a private slot of `QComboBox` that Qt 6 no longer has. Nothing happens; only
  fixable in Lazarus. Harmless.
- `This plugin supports grabbing the mouse only for popup windows`, on mouse presses: the LCL's mouse capture
  (`SetCapture`, under Qt `QWidget::grabMouse`) is refused by Qt's Wayland plugin for normal windows. While a button is
  held, Wayland delivers the mouse events to the window anyway, so it usually goes unnoticed. To check on the desktop
  (the places where dragging leaves the control or the window):
  - splitters (schema tree / editor, query / result), dragged fast and beyond the window edge;
  - column widths in the result grid;
  - drag and drop of a table from the schema tree into the query editor;
  - selecting text in the editor with the mouse held beyond its edge (it should scroll);
  - dragging a scroll bar thumb and leaving the window.
  If one of these misbehaves under Wayland and works with `QT_QPA_PLATFORM=xcb` (XWayland), AppRun should default to
  xcb, still overridable through `QT_QPA_PLATFORM`.

The messages are left as they are (seen only when started from a terminal); filtering them with `QT_LOGGING_RULES`
would hide real warnings as well.

**Qt6: editor font, menu bar and combo box lists (2026-11-20).** Found by the project owner on the desktop:
- The SQL editor showed wide gaps between the letters: the code font (Bitstream Vera Sans Mono, registered by
  `TMainForm.CheckFonts`) was only added to fontconfig, which Qt does not see, so Qt substituted a proportional font
  in the editor's fixed character grid. `AppFonts.AddApplicationFont` now also adds every file to Qt's font database
  once the QApplication exists (the same gap as the Tahoma stand-in the day before).
- The menu bar looked squeezed under its drop-down menus: it inherited the form's small Tahoma and Fusion adds only a
  few pixels to menu bar entries (bar 16 pixels, drop-down items 25). Menu bars of the original and under GTK2 use
  the system's menu font. `QtStyle.AdjustMenuBar` (called for the main form after `PrepareGUI`) gives the bar Qt's
  menu bar font and more padding (a style sheet on the bar, with the selection colours, which Fusion no longer
  draws once a rule applies); the bar is about 25 pixels high, bar and drop-down menus use the same font.
- The lists of combo boxes showed their rows without spacing (as tight as the original's on Windows, about 13 pixels
  for Tahoma 8 pt; GTK2: about 28). An application style sheet set in `UseFusionStyle` gives those lists a few pixels
  (rows about 22 pixels), again with the selection colours. It applies to the lists only; the main window, the
  result grid, the options dialog and the connect dialog look as before (checked by screenshot).
- Checked: menu smoke test (137 entries, the expected exception), the app self-tests on all six servers with Qt6 and
  with GTK2 (where nothing changes). The changes are guarded by `LCLQT6` or `MSWINDOWS`; no Win64 cross-build was done.

**Qt6, review of all forms (2026-11-20).** Every form the program opens, photographed with the GTK2 and the Qt6 build
side by side (developer modes `--shot-connect`, `--shot-main`, `--dialog optionpages:0,1,2,3,4|textsearch|regex|
schemasel|about|credits`, `--cmd ... --modal-shot` for the table editor, field viewer, bookmark, create view/schema
and drop dialogs; the connect dialog's details with `xdotool`). Not reachable that way: the "Compare Resultsets"
message (an exception the developer mode writes to the error file instead of showing it) and `Progress.lfm` (no
ported unit uses it). Found and fixed:
- Connect dialog, "Details >>": the first advanced option ("Use compression protocol") was cut off at the top. Qt6
  draws the tab row exactly `TabHeight` high, without the border of the original's tab control, so the page started
  5 pixels higher and the panel that covers the tabs cut into it. `HidePageControlTabs` (until now GTK2 only) also
  switches the tabs off under Qt6 and moves the page control down by the strip, the original's `TabHeight + 4` when
  no strip is given; the connect dialog hides the covering panel under Qt6 as under GTK2. The options pages (same
  pattern) now start where the original's value puts them, directly below the page title.
- Bookmark caption dialog: "Please enter the caption for this bookmark" wrapped its last word; `TMyxModalDialog`
  sizes the label to the measured text width, and Qt's fractional character advances need a pixel more than the
  whole-pixel measurement. Two pixels of slack under Qt6.
- About dialog: the lines of the copyright, licence and credits texts touched (9 pixels apart for a 10 pixel font).
  The Tahoma stand-in has embedded bitmap glyphs for small sizes, and FreeType takes the line metrics of the bitmap
  strike when there is one (ascent 8, descent 2, leading -1); Qt uses FreeType's metrics, cairo (GTK2) does not. A
  fontconfig rule `embeddedbitmap=false` does not help, it changes the drawing, not the metrics. `prepare_runtime.py`
  now installs the font without its bitmap tables (EBDT/EBLC/EBSC; the repository keeps Wine's files): line spacing
  12 pixels under Qt6; GTK2 is pixel for pixel the same as before (all review screenshots compared).
- Unchanged and fine under Qt6: main window, table editor, field viewer, text search, regex importer, schema
  selection, credits, options pages (Browser, General, Connections, Editors), create schema/view and drop dialogs.
  Lists (index columns, combo box lists) are tighter than under GTK2, as on Windows. The "FK naming" field still
  shows its text scrolled to the end.
- The "create view" developer run times out under both widgetsets after the screenshot (the dialog does not close
  on the helper's cancel); the dialog itself is fine.
- Checked: app self-tests on all six servers with GTK2 and Qt6; the Win64 executable is identical before and after
  (`.text`, `.data`, `.rdata`).

Reproducing under Xvfb with an open menu or list: start the program, then `xdotool` (`key alt+e`, or a click on the
combo box arrow) and `import -window root` (both in the freepascal container). A connect dialog with stored
connections needs a `mysqlx_user_connections.xml` in the data folder (`user_connection` elements with
`connection_name`, `username`, `hostname`, `port` and `storage_type` 1).

Still open, sporadic crash (2026-10-31): once, right after connecting through the connect dialog (typed
values, real KDE/XWayland session, 4K display) and the main window opening, the program aborted with
`double free or corruption (out)`. The core dump shows `g_free` called from
`gdk_window_process_updates_internal` in the GTK idle handler, i.e. the C heap was already corrupted
earlier; the program also printed `gtk_window_realize_icon: assertion 'info->icon_pixmap == NULL'`, which
appears on every start of the main window and is probably unrelated. Not reproducible since (same steps
under Xvfb at 1280x1024 and 3840x2160, at 192 dpi, with gdb; valgrind did not get past the dialog). A run
with `MALLOC_CHECK_=3` failed to connect with "MySQL Error Number 0" when no default schema was given; this
was not isolated further and may point at an uninitialised value in the connect code. If it happens
again: save the core (`coredumpctl dump <pid> -o core`), start with `QBR_TRACE=1` (flow trace in
`app/bin/querymole.trace.txt`) and note what was done in the last seconds.

Still open, sporadic hang (2026-11-03): once, while scrolling the Schemata tree of a database with many tables
(real KDE/XWayland session, remote server), the main window stopped responding; the console showed only the
`gtk_window_realize_icon` assertion above. Not reproduced: 25 rounds of wheel, page and scrollbar input against a
local schema with 3000 tables under Xvfb stayed responsive. Not known whether the hang is permanent, whether it
depends on the server's latency or the size of the schema. If it happens again: attach to the process while it
hangs (`gdb -batch -p <pid> -ex "set debuginfod enabled off" -ex "thread apply all bt 15"`), and start with
`QBR_TRACE=1`.

Crash while scrolling the Schemata tree (2026-11-12): the program aborted with
`Gdk:ERROR:gdkregion-generic.c:1110:miUnionNonO: assertion failed: (y1 < y2)`. The core dump's stack (scanned by hand,
GDK has no symbols) leads from the main loop through `TSchemataFrame.RefreshTableNames` (tables of a schema arriving
from the fetch thread) into a tree invalidation. The LCL's GTK2 `ScrollWindowEx` was suspected first;
`VTCompat.TVirtualStringTree` overrides `DoSetOffsetXY` outside Windows and repaints the whole tree instead of scrolling
pixels (no visible change; Windows unchanged). That was not the cause, see the next paragraph.

**Schemata tree hangs and crashes, reproduced and fixed (2026-11-13).** The developer mode `--stress-schemata <seconds>
<file>` (with `--shot-main`; `QBR_STRESS_OPS` picks from t(oggle) s(croll) r(eload) f(ind) c(ollapse)) drives the tree
in random order against a server with 8 schemata of 300 tables. Before the fix, every run with reloads hung within
90 s (8 of 12) or aborted with the GDK assertion above or `double free or corruption`; after it, 24 of 24 runs passed.
Four causes, all in the threads that fetch the schema data (the original code relied on the VCL tolerating them):

1. *GUI calls from worker threads.* `TFetchDataThread` set `Screen.Cursor` (GTK2: `gdk_window_set_cursor` on every
   window) and, through the `StatusBarText` property, repainted the status bar from the thread; `FetchSchemaTables`
   disabled the search field from the thread; the search thread changed the tree directly. Xlib/GDK are not used
   from two threads at once safely: this corrupted the C heap. Now all of it happens in the main thread
   (`Synchronize`); the search thread only waits for fetches and lets `SearchStart/SearchStep/SearchFetched` walk the
   tree in the main thread. **Changes the Windows build** (same behaviour, now correct there too).
2. *Lock held by the main thread while a worker waited for it.* `FSearchLock` was taken by the main thread for every
   tree change and held by the search and fetch threads during network work (main thread blocked, and a deadlock
   with `Synchronize`). It is gone; `FFetchLock` only serializes the fetching itself.
3. *Kept tree nodes and freed schema objects.* A fetch kept the `PVirtualNode` and `TMYX_SCHEMA` it was started for;
   a reload in the meantime freed both, and the refresh wrote into freed memory. The tree now has a generation
   counter (`ClearCatalogTree`), a late result looks the node up again (`FindTablesNode`) or is dropped, and
   replaced catalog lists are freed only when no fetch is pending (`RetireObject`). Fetch errors are kept and raised
   again in the main thread after cleaning up. Expanding a second schema while the first one loaded used to be
   dropped silently (empty node); both are fetched now, one after the other.
4. *Scroll bar loop in VirtualTreeView under GTK2.* `WMSize` updates the scroll bars, which changes the client size
   again. Windows sends that `WM_SIZE` inside `ShowScrollBar`, where the tree ignores it; GTK2 delivers it later, and
   since the horizontal range depends on the nodes in view, the bars could toggle forever (main loop busy in
   `WMSize`/`UpdateScrollBars`/`ShowScrollBar`). `VTCompat` lets a size change show bars but not hide them
   (non-Windows only).

Also: each reload of the tree queued another catalog fetch, and each of them rebuilt the tree in turn (after
many reloads the tree kept changing for up to two minutes). Reloads during a catalog fetch now only cause one more
fetch after it (`FCatalogFetching`, `FReloadAgain`); the final tree is the same, it settled after 6-12 s instead of
33-118 s in the stress test.

These most likely explain the crash of 2026-10-31 and the hang of 2026-11-03 above.

**Edited query ran the old command (2026-11-13, fixed).** After a table was double clicked into the editor and
executed (stopped or not), typing e.g. ` LIMIT 5` and executing again ran the old `SELECT *`. The compat
`UniCodeEditor` did not reset `lsValidated` when a line's text changed, so `OnValidateLine` never analyzed it again;
`UpdateCommandDisplay` kept the old command end and cut the new text to the old length. A changed line is now
validated again on its next access, as in the original. Reproduced and checked with the developer mode
`--stop-and-edit <schema> <table> <ms|-1> <addition> <file>` (double click, execute, stop after <ms>, type, execute);
the script tab (statement markers, error line, breakpoint) still works.

**Field popup editor did not open (2026-11-13, fixed).** "View/Edit Field in Popup Editor" in the result grid's
context menu did nothing: loading `MySQLResultSetFieldViewer.lfm` raised `EReadError: Unknown property "OnScroll"`
because the compat `TUniCodeEdit` had the event only as public. It is published now; both dialogs open and show
the field (checked with `--cmd viewfield` / `--cmd editfield` and `--modal-shot`).

**Dialogs on the wrong monitor (2026-11-13).** Most dialogs have `Position = poDesigned`. The VCL shows such a form
on the monitor that `DefaultMonitor` names (`dmActiveForm` by default); the LCL ignores `DefaultMonitor` for
`poDesigned` (`TCustomForm.MoveToDefaultPosition`), so with several monitors the dialogs opened at their designed
coordinates, usually on the primary monitor, wherever the main window was. The window manager does not correct this
because the program sets the position itself. `TTntForm` (generated by `tools/gen_tnt_shims.py`, now a class instead
of an alias of `TForm`) moves such a form on its first show to that monitor, keeping its position relative to the
monitor; positions restored from the options (`SetWinPos`) are left alone. **Changes the Windows build** (same LCL
behaviour there). Checked under Xvfb only that one monitor is unchanged: Xvfb puts its Xinerama screens on top of
each other, so two monitors side by side need a real desktop (or Xephyr / the Xorg dummy driver). `--modal-shot`
now also writes the positions of the dialog, the main window and the monitors next to the screenshot
(`<name>.txt`), and `--cmd mainmonitor:<n>` puts the main window on monitor n.

**Search fields lost their bottom line (2026-11-13, fixed).** The search fields above the schemata, bookmarks and
history trees (`TAdvancedEditFrame`, 23 pixels high) draw their own border around a borderless edit at `Top = 5`.
GTK2 makes that edit 20 pixels high instead of the original 15, so it covered the bottom line and the text sat low.
Outside Windows the edit is now centered within the border (`FrameResize`). Checked by screenshot (`--cmd search:<text>`
types into the schemata search field; `DevDump` writes the field's geometry). Not checked: a real desktop
session and a remote server with real latency.

**Search did not find names with non-ASCII characters (2026-11-14, fixed; all platforms).** `myx_match_pattern`
computed the end of the text and of the pattern from the number of characters instead of bytes, read the character
after `*` as a single byte and gave the text's character the pattern's remaining length. A schema `bär` was not found
even by `bär`. Fixed in `backend/src/base-library/source/myx_library.c`; ASCII behaviour unchanged (whole names, `*`
and `?`, see ADR-0029). FPCUnit test `test_match_pattern` (no server needed); checked in the app with `--cmd
search:<text>` (`searchall` selects the menu entry "All", `wait:<ms>` waits for background work).

**Menu smoke test (2026-11-14).** `--menu-smoke list|run <report>` (unit `DevMenuSmoke`, runs after the other
developer steps, e.g. `--sql`) clicks every entry of all main and popup menus, frames included, after running what
opening the menu runs (`OnPopup`, the parent entries' `OnClick`). A timer closes modal dialogs, exceptions are recorded
with a stack trace instead of ending the program, the report is written after every entry. Entries that open native
file dialogs or the browser, or end the program, are skipped. First run: 7 exceptions in 137 entries; fixed:

- *Table editor did not open* (Create New Table, Edit Table): `EditorTable.lfm` set `BevelOuter` on a `TScrollBox`,
  which the LCL does not have (the frame was never loaded by the converter's viewer). `dfm2lfm.py` drops it.
- *Create View from Select* without a result in the tab, *Refresh Parameters* without an active result set,
  *Edit All Stored Procedures / Functions* without loaded procedures: access violations, the same code as the
  original. Now the original's error message, the global parameters, and the procedures fetched on demand.
- *Freed schema objects*: `CurrentSchema`/`CurrentTable` and the default schema node kept pointing into the catalog
  list that a refresh of the tree had freed (found through "Edit All Stored Procedures" after "Refresh"). Reset when
  the tree is cleared.

Left as they are: "Copy Query as PHP/Java Code" crash without a pasted code template only when clicked while
disabled (the popup disables them, as in the original); "Compare Resultsets" with one grid raises the original's
message. `--cmd click:<menu entry name>` clicks one entry (with `--modal-shot` to photograph the window it opens).

**Security review (2026-11-14, fixed; all platforms, backend and Pascal).** Things that could read files or change
the database without the user asking for it:

- *LOAD DATA LOCAL*: the server may ask for a local file in the reply to any statement. Connector/C in its "auto"
  mode (the default of the builds used: Fedora 3.4, AlmaLinux 3.2, MSYS2) only answers after a statement starting with
  `LOAD`, but then sends whatever file the server names: a server could swap the user's file for another one (checked
  with a fake server). `myx_library.c` installs its own handler: a file is sent only while a statement runs through
  `myx_mysql_query`/`myx_mysql_real_query` and only the one that statement names after `LOCAL INFILE`
  (`tests/test_local_infile.pas`).
- *User data folder*: `~/.mysqlgui` (saved connections with obscured passwords, history) was created with the umask,
  usually `755`. The default folder is set to `700` at start; a folder given with `-datadir` is left alone.
- *Drop with several schemata selected*: tables, views and routines were dropped in `CurrentSchema` (the schema of
  the focused node), i.e. a same-named object in the wrong schema; the schema now comes from each node's parent.
  Names are quoted with doubled backticks, the schema name in the `mysql.db` queries is escaped.
- *Grid edits*: values of numeric, date, ENUM and SET columns went into UPDATE/INSERT/DELETE between quotes without
  escaping; a date typed as `2026-03-03' -- ` commented out the `WHERE` and changed every row
  (`tests/test_edit_escaping.pas`, which fails against the old library). All values are escaped now, column names
  quoted; table names come from the query parser already in quoted form.

Not changed: the plaintext fallback of ADR-0005 (a man in the middle can suppress TLS; needs its own ADR), and the
"obscured" password storage (reversible by design, as in the original). For checks of the drop: `--cmd
expand:<schema>,wait:3000,select:<schema>/<name>;<schema>[/<name>],click:DropMI --modal-shot x.png` with
`QBR_MODAL_ANSWER=1`, which answers the dialogs with their first button instead of cancelling them.

## AppImage (2026-11-04)

`tools/package-appimage.sh` builds `dist/MySQL_Query_Browser-<version>-x86_64.AppImage` (ADR-0027): backend and
bundled libraries from AlmaLinux 9 (glibc 2.34), the Pascal program from the `freepascal` container. Checked: every
bundled file needs glibc 2.34 at most; the program started from the AppDir and from the AppImage under Xvfb on
Fedora 44 and on Ubuntu 26.04 (no GTK2, no FUSE 2 there); only the C library, X11 core, font stack and libstdc++
come from the host (read from `/proc/<pid>/maps`); `tests/run-matrix.sh --app-only` with
`QBR_APP=dist/AppDir/AppRun` passes the application self-tests on all six servers. The first start of the bundled
libxml2 2.9 raised `EInvalidOp`/`EZeroDivide` (it computes NaN/infinity by dividing by zero): `qbr.lpr` initialises
it once with those traps masked.

Fixed, found with the AppImage on Ubuntu 26.04: the substitute for Tahoma there (DejaVu Sans) is wider than
Fedora's and cut off the connect dialog's "Stored Connection:" label. The program now ships Wine's Tahoma stand-in
and uses it for the forms (ADR-0028); the dialog fits on Ubuntu and Fedora. Not tried: the AppImage on a real desktop session
(mouse, themes, file dialog), on RHEL 9 / Ubuntu 22.04 / Debian 12 themselves.

## Updates with Velopack (2026-11-16)

`tools/package-appimage.sh --velopack` (ADR-0037) packs a copy of the AppDir with `vpk pack` 1.3.39 into
`dist/Releases-linux` (`QueryMole.AppImage`, full and delta packages, `releases.linux.json`). `libvelopack_libc.so`
comes from the velopack-pas release the submodule is pinned to (`v0.1.0-beta.1`, built on manylinux_2_28, newest
glibc symbol 2.28; `fetch-native.py --with-license`). If the submodule is not on a release tag, it is built from the
pinned Velopack commit in the AlmaLinux 9 container instead (`tools/appimage/build-velopack.sh`; glibc 2.34).
vpk's `UpdateNix` is statically linked. Checked under Xvfb in the `freepascal` container:
an alpha.2 AppImage with `QBR_UPDATE_URL` pointing at a feed holding alpha.2 and alpha.3 reported
`installed 0.1.0-alpha.2`, `available 0.1.0-alpha.3`, downloaded and started the updater; the file was replaced, the
next run reported `installed 0.1.0-alpha.3` and `no update`, and the connect dialog of the updated image opened.
With the library from the release, the packed image needs glibc 2.28 for it, reports `installed 0.1.0-alpha.2` and
`no update` against its own feed, and applied a staged alpha.3 package on startup. On a real desktop session the
project owner ran the whole cycle by hand through "Check for Updates ..." against a local feed (`QBR_UPDATE_URL`),
in a folder the user can write to: it worked. Through the GitHub feed (releases built by
`.github/workflows/release.yml`): an installed 0.1.0-alpha.3 updated to alpha.4, and on Windows alpha.4 to alpha.5
(2026-11-17).

**AppImage in a folder the user cannot write to (2026-11-16).** Velopack's `mv` fails there, as expected; before it
runs `pkexec` it asks for confirmation in its own dialog, and that dialog does not open (`NoBackendAvailable` in
`/tmp/velopack_QueryMole.log`, the same for the progress window). Velopack counts that as "User cancelled", so
`pkexec` is never run, and the downloaded package is tried again on every start. Most likely cause: vpk's `UpdateNix`
is a static musl program, and its dialog library loads `libX11`/`libwayland-client` at run time, which a static musl
program cannot do. QueryMole therefore checks the folder of the running AppImage (`$APPIMAGE`) before downloading
(`UpdateCheck.UpdateFolderWritable`): if it is not writable, "Check for Updates ..." names the folder and the
download page instead of downloading, and `--selftest-update` reports `not writable <folder>`. Checked under Xvfb:
in a read-only folder `available 0.1.0-alpha.3`, `not writable ...`, no download; in a writable one the update was
applied as before.

## Summary before the port (2026-10-30)

- 40 files have Windows units in their `uses` clauses.
- **22 files need only the `uses` clause changed** (plus the three with false positives).
- About **95 Windows-only identifiers** in 16 units remain, ~200 uses. `AuxFuncs` (46) and
  `QueryBrowser` (23) hold most of them.
- Four topics need a decision before code is written (section 4).

## 1. `uses` clause only

`ColorTools`, `CommonFuncs`, `AdvancedEdit`, `InstanceSections`, `MySQLResultSet`,
`MySQLResultSetFieldViewer`, `QueryBrowserOptionPages`, `RegExTextImporter`, `SQLErrorGrid`,
`SchemaSelection`, `ScriptPanel`, `Sections`, `SqlCmdPanel`, `StringContainers`, `TabHeader`,
`TableDrag`, `TextSearch`, `Toolbar`, `UniCodeConsole`, `qbr.lpr`, `compat/PNGImage`,
`compat/TntRegistry`; also `CommonTypes`, `OptionsEditor` (false positives only).

`Windows` becomes `LCLIntf, LCLType` (on all platforms, or `{$IFDEF MSWINDOWS}Windows,{$ENDIF}` where
Windows-only code stays); `Messages` can stay. FPC's `Registry` (and with it the `TntRegistry` shim)
compiles on Linux, where it stores into an XML file; units that use `HKEY_*` constants need `Registry`
in their own `uses`.

## 2. Direct replacements (same behaviour)

| Windows | Replacement | Where |
|---|---|---|
| `WM_DESTROY`/`TWMDestroy`, `WM_TIMER`/`TWMTimer` | `LM_DESTROY`/`TLMDestroy`, `LM_TIMER`/`TLMTimer` | grid edit links, `QueryBrowser`, `SchemataTreeView` |
| `CF_UNICODETEXT` | `CF_TEXT` (LCL clipboard text is UTF-8) | `Main`, `QueryBrowser` |
| `IDC_APPSTARTING`, `IDC_ARROW` + `SetCursor` | `Screen.Cursor := crAppStart / crDefault` | `QueryBrowser.DoQueryExecute(d)` |
| `MessageBoxW` | `Application.MessageBox` | `LexicalTools.TDelphiLexer.LexerError` |
| `IsEqualIID` | `IsEqualGUID` (SysUtils) | `QueryBrowser` |
| `IDataObject` (ActiveX) in VirtualTreeView handlers | the type from `laz.FakeActiveX`, e.g. an alias in `compat/VTCompat` | `EditorTable`, `MySQLResultSetControls`, `QueryBrowser`; check with `tools/check_handlers.py` |
| `ExtTextOutW`, `DrawTextW`, `GetTextExtentPoint32W`, `Get/SetTextAlign` | LCL `ExtTextOut`/`DrawText`/`GetTextExtentPoint` with UTF-8 strings | `AuxFuncs.DrawWideStringText`, `GetWideStringTextWidth`, `TMyxModalDialog.Create`, `MenuMeasureItem` (2x), `AutoAdjustSize` (3x) |
| `ShellExecuteW` | `LCLIntf.OpenURL` | `AuxFuncs.BrowseWebPage` |
| `SHGetSpecialFolderLocation(CSIDL_PERSONAL)` | `GetUserDir` | `AuxFuncs.GetHomeDir` |
| `WideCompareText(.., LOCALE_USER_DEFAULT)` | without the locale argument | `SchemataTreeView.CatalogVSTCompareNodes` |
| `GetLocaleFormatSettings(LANG_ENGLISH)` | explicit English `TFormatSettings` (must equal the Windows values) | `Options.TMyxOptions.Create` |
| `CreateProcessW` + `WaitForSingleObject` | `TProcess` (FCL); the old `{$IFDEF LINUX}` branch refers to Kylix's `TCmdExecThread` and has to go | `AuxFuncs.CreateSubProcess` (restart after error, new instance) |
| `PrintWindow` (user32.dll) | `TWinControl.PaintTo` / `GetFormImage` | `DevTools.CaptureWindowToPng` (developer modes only) |

## 3. Windows-only features: guard, no-op elsewhere

None of these changes what a Linux user sees compared to a feature that does not exist there; they
are listed so that each guard is a deliberate choice.

| Feature | Where | On Linux |
|---|---|---|
| Version checks `IsWinXP`, `IsWin2k`, `IsWinNT`, `IsWin2kOrXP`, `getXPStyleEnabled` (`Win32Platform`, `GetVersion(Ex)`) | `AuxFuncs`; callers in `About`, `AdvancedEdit`, `Options`, `Sections`, `QueryBrowser` | return False (`getXPStyleEnabled`: check what the themed drawing paths look like under GTK2 first) |
| Drop shadow `CS_DROPSHADOW` | `About.CreateParams` | skip |
| ClearType check `FE_FONTSMOOTHINGCLEARTYPE` | `AuxFuncs.InitGlobalVars` | skip |
| `GetSystemDirectory`, `GetWindowsDirectory` | `AuxFuncs`; `Main` checks for `cmd.exe` | return ''; the "Windows command line" menu item already disables itself when `cmd.exe` is missing |
| Online check `InternetGetConnectedState` (WinInet) | `AuxFuncs.IsConnectedToInternet` → `Main` (Report bug, Check for updates) | return True |
| File associations `RegisterFileType` (registry + `SHChangeNotify`) | `Main` | packaging (`.desktop`, MIME types) instead |
| MySQL installations from the registry (`RegOpenKeyExW`, ...; `mysql.exe`, Administrator path, `RegisterMySQLApplication`) | `MySQLCommonFuncs` | `RegisterMySQLApplication` no-op; command line client from `PATH` (`mysql`/`mariadb`) |
| Running-instance list in shared memory (`CreateFileMapping`, `MapViewOfFile`) | `AppInstanceMgmt`; `Main.WMInitMenuPopup` fills the Window menu | no-op. `RegisterApplication` is never called in the port, so the list is empty on Windows too |
| `EM_SETRECTNP`, `EM_SCROLLCARET`, `WM_SETREDRAW` on the inline editors | `EditorTableVTEdit`, `EditorTableVTFKEdit`, `MySQLResultSetControls` | skip; check the editors' margins and flicker visually |
| `GetCharFromVKey` (`ToAscii`, `MapVirtualKey`) to detect `(` while typing | `AuxFuncs`, used in `EditorTableVTEdit` | use the character from `KeyPress`/`UTF8KeyPress` instead of the virtual key |
| Private fonts `AddFontResourceExW` (gdi32.dll) | `Main.CheckFonts` | fontconfig: `FcConfigAppFontAddFile`, or ship the Vera fonts with the package |
| `GetTimeBias` | `AuxFuncs` | unused; remove (porting convention) |

## 4. Needs a decision (ADR candidates)

1. **User data directory (decided: ADR-0019, the original's folder; changed by ADR-0030 to
   `$XDG_CONFIG_HOME/querymole/` with a one-time import).** Windows: `%APPDATA%\MySQL\` (`Options.TMyxOptions.Create`). The original
   Linux Query Browser used `~/.mysqlgui` (`legacy/mysql-gui-common/source/linux/MGPreferences.cc`), the
   desktop convention is `$XDG_CONFIG_HOME/<name>`. Reading an existing `~/.mysqlgui` would carry
   over connections from the old Linux version.
2. **Stopping hanging threads (decided: ADR-0020, cancel on the server).** `TerminateThread` kills
   query, connect and ping threads after a timeout (`MySQLConnection.ClearWorkList`, `FetchData`,
   `StopCurrentThread`; `ConnectToInstance` 3x). POSIX has no safe equivalent. Options: cancel on
   the server (`KILL QUERY` over a second connection), close the socket (`mariadb_cancel`) and then
   wait, or abandon the thread. The same change would make Windows safer (killing a thread inside
   libmysql can leave locks held). Implemented for the `MySQLConnection` threads and the query Stop
   button (`app/src/QueryCancel.pas`, tests in `tests/test_cancel.pas`); the `ConnectToInstance`
   threads run no statement and are unchanged.
3. **Global copy/paste hotkeys (decided: ADR-0022, Windows only).** `QueryBrowser.FormCreate`/`WMHotKey` registers
   Ctrl+Alt+Shift+C/V system-wide and sends keystrokes to the foreground application (`RegisterHotKey`,
   `keybd_event`, `AttachThreadInput`). X11 can do something similar, Wayland cannot; the code is guarded
   and not compiled elsewhere. There is no option for it (the mode follows the foreign window).

4. **"OS specific" password storage (decided: ADR-0021, not offered outside Windows).** Windows uses DPAPI in the
   backend (`myx_xml_user_connections.c`); elsewhere the backend calls `os_password_store_function` /
   `os_password_retrieve_function` hooks, which the original Linux UI filled with GNOME Keyring and which the
   port never sets (a Linux build would have stored clear text). `Options` now lists the choice on Windows
   only; libsecret / Keychain are deferred.

## 5. Not visible to the script

- **Path separators.** Hard-coded `\` in paths: `Options` (`'MySQL\'`, `'XML\'`,
  `'locale\...\LC_MESSAGES\'`, the `-datadir` handling), `OptionsEditor` (`'fonts\VeraMono.ttf'`),
  `Main` (`'fonts\'`). Use `PathDelim` / `IncludeTrailingPathDelimiter`. `MySQLCommonFuncs` and the
  registry keys in `AuxFuncs` are Windows-only anyway.
- **Case-sensitive file names** for the runtime folder (`XML/`, `locale/`, `fonts/`) and resources.
- **Window messages through portable calls.** `SendMessage`/`PostMessage` with Windows messages
  compile but may do nothing under GTK2 (e.g. `WM_SETREDRAW`, `WM_COPY`/`WM_PASTE` to foreign
  windows); about 70 lines in `CommonTypes`, the grid edit links, `MySQLConnection`, `QueryBrowser`,
  `Main`. Messages the program posts to its own forms (`WM_USER + n`) work with the LCL.
- **`LoadCursor(HInstance, ...)`** for the drag cursors in `QueryBrowser.FormCreate`: declared by
  the LCL, but whether GTK2 loads cursors from the `.res` needs a test.
- **`CreateParams`** overrides (window class styles) have no effect outside Windows.

## Checking the Windows build

Inside the `freepascal` distrobox (`fpc-units-x86_64-win64` installed by `tools/distrobox-setup.sh`;
the first run compiles the LCL for Win64):

```
# reference: the previous commit, in a scratch copy with the same app/res and third_party
lazbuild -B --os=win64 --cpu=x86_64 --ws=win32 --opt=-FU<lib-a> --opt=-o<a.exe> app/qbr.lpi
# the working tree
lazbuild -B --os=win64 --cpu=x86_64 --ws=win32 --opt=-FU<lib-b> --opt=-o<b.exe> app/qbr.lpi
# compare the stripped executables section by section
x86_64-w64-mingw32-strip -o a-s.exe a.exe   # same for b
x86_64-w64-mingw32-objcopy -O binary -j .text a-s.exe a.text   # .data .rdata .idata .rsrc likewise; cmp
# per unit, when they differ:
x86_64-w64-mingw32-objdump -d --no-addresses <lib-a>/Unit.o > a.dis   # same for b; diff
```

## Suggested order

1. ~~Sections 1 and 2 plus the `AuxFuncs` guards from section 3: the program compiles and the
   connect dialog runs.~~ Done, together with the rest of section 3 and the path separators.
2. ~~The 64-bit pointer arithmetic, so that results show.~~ ~~Check the main window's features by
   screenshot under GTK2.~~ Done (see "State"); interactive use on a real desktop is next.
3. ~~Decide 4.1 (data directory).~~ Done, ADR-0019.
4. ~~Decide and implement 4.2~~ (ADR-0020); ~~decide and implement 4.4~~ (ADR-0021); decide 4.3.
