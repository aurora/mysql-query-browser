<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# Linux: manual test checklist

What the automated checks (`tests/run-matrix.sh`, screenshots under Xvfb) cannot cover: real mouse and
keyboard use on a desktop session. Work through it on a real GTK2 session (X11 or XWayland), note the
result in the table and file each failure as a line in `docs/linux-port.md` ("Still open").

A failure only counts as a port bug if the same step works in the Windows build; compare with
`docs/reconstructed/` or the Windows program (ADR-0001: nothing is "improved" while porting).

## Setup

Test server (throw-away data, see `tests/README.md`):

```bash
podman run -d --name qbr-manual -p 34300:3306 -e MYSQL_ROOT_PASSWORD=qbr-test docker.io/library/mysql:8.4
```

Wait until it accepts connections, then create a small schema with a non-ASCII value, NULLs, a view and
a procedure (for example the `qbrtest` schema of the development container `qbr-linux-dev`, port 34200,
user `root`, password `qbr-test`, tables `kunde`, view `v_kunde`, procedure `p_count`, can be used as it is).

Build and start, with its own data folder so that `~/.mysqlgui` stays untouched:

```bash
distrobox enter freepascal -- ./build.sh
LD_LIBRARY_PATH=backend/build-linux app/bin/qbr -datadir /tmp/qbr-manual-data
```

Run once more without `-datadir` on a scratch `HOME` to check that `~/.mysqlgui/` is created and used
(ADR-0019).

## Checklist

Mark each row `ok`, `bug` (what happened) or `n/a`.

### Connect dialog

| # | Step | Expected | Result |
|---|---|---|---|
| 1 | Tab through all fields; Enter in the password field | focus order as on Windows; Enter connects | |
| 2 | Wrong password | server error shown, dialog stays open | |
| 3 | Save a connection, restart, pick it from the list | fields restored; password per storage type | |
| 4 | Options > storage type list | `Plaintext` and `Obscured` only (ADR-0021) | |
| 5 | Cancel while connecting to an unreachable host | the dialog stays usable | |

### Main window: mouse and keyboard

| # | Step | Expected | Result |
|---|---|---|---|
| 6 | Expand a schema, double-click a table | a `SELECT` is generated and run | |
| 7 | Type SQL: completion, highlighting, undo/redo (Ctrl+Z/Y), Ctrl+A, Tab/Shift+Tab | as in the Windows editor | |
| 8 | Run with Ctrl+Enter and with the Execute button | result grid fills | |
| 9 | Long query (`SELECT SLEEP(30)`), press Stop | cancelled on the server, UI stays responsive (ADR-0020) | |
| 10 | Result grid: select cells, rows, columns; Ctrl+C; scroll with wheel; resize columns | clipboard contents and behaviour as on Windows | |
| 11 | Edit mode: change a cell, NULL, apply, discard | row changed in the database only on apply | |
| 12 | Inline editors: arrow keys, Esc, Enter, a `(` typed in a combo | no stuck focus, no crash | |
| 13 | Field viewer (text, binary, image) for a cell | content shown, editing keys work | |
| 14 | Tabs: open, close, drag to reorder, switch with Ctrl+Tab | | |
| 15 | Splitters between tree, editor and result: drag | sizes follow the mouse | |
| 16 | Menus and context menus: open with mouse and with Alt+accelerator | every item enabled/disabled as on Windows | |

### Drag and drop

| # | Step | Expected | Result |
|---|---|---|---|
| 17 | Drag a table from the tree into the SQL editor | name inserted at the drop position | |
| 18 | Drag a column from the tree into the editor | | |
| 19 | Drag a table onto the query area / a result tab (table drag) | drag cursor shows (`LoadCursor` from the `.res`), a query is created | |
| 20 | Drag a bookmark within the bookmark tree | order changes | |
| 21 | Drop a `.sql` file on the window | n/a if the Windows build has no such feature | |

### Bookmarks, history, scripts

| # | Step | Expected | Result |
|---|---|---|---|
| 22 | Add a bookmark, restart, open it | persisted in the data folder | |
| 23 | History: run, browse, double-click an entry | | |
| 24 | Script tab: run with breakpoint, step, stop | | |
| 25 | Open / Save As for a script and for results (CSV, HTML, XML) | native file dialog, UTF-8 content | |

### Dialogs, fonts, clipboard

| # | Step | Expected | Result |
|---|---|---|---|
| 26 | Options: every page, change a font, Apply/Discard | changes take effect | |
| 27 | Options: the strip above the page header (cosmetic, open) | note how many pixels of the hidden tabs show | |
| 28 | Text search, RegEx importer, schema selection | | |
| 29 | Help: inline help for a keyword; online links open the default browser | | |
| 30 | Copy from another program, paste into the editor and back (also non-ASCII) | text identical; no global hot keys (ADR-0022) | |
| 31 | Mono font and tab/space widths in the editor (Vera Mono) | | |

### Window and system

| # | Step | Expected | Result |
|---|---|---|---|
| 32 | Maximise, restore, minimise, move to another screen; restart | window position and size remembered | |
| 33 | HiDPI (scaling 150 %/200 %) | usable; note what is too small (ADR-0009 defers the fix) | |
| 34 | Dark desktop theme | still readable; note painted areas that ignore the theme | |
| 35 | Quit with the window button, with the menu, with Ctrl+Q; unsaved changes prompt | no hang, exit code 0 | |

### Qt5 widgetset (optional)

`QBR_WIDGETSET=qt5 ./build.sh` in the distrobox, then repeat rows 6 to 20 and 26. Qt5 is not a goal
for the first release; this only records how far it is from working.

| # | Step | Expected | Result |
|---|---|---|---|
| 36 | Builds and connects | | |
| 37 | Rows 6 to 20 | | |

## Afterwards

- Remove the test container: `podman rm -f qbr-manual`.
- Copy failures into `docs/linux-port.md` ("Still open") with the row number and, when it needs a fix,
  a ROADMAP line. Rows marked `ok` need no entry.
