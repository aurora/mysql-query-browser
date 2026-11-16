# Roadmap

Where the project is, what comes next, and ideas that are written down so they
are not lost. Decisions live in [`docs/adr/`](docs/adr/README.md); this file is
the plan and the backlog and changes often.

Guiding rule (ADR-0001): **the first milestone is the original Query Browser,
unchanged, on current platforms and servers.** Anything that changes the UX
waits until after parity and gets its own decision.

## Done

- Repo layout; original sources preserved unchanged in `legacy/`.
- **Backend:** C libraries built with CMake/MinGW-w64 against MariaDB Connector/C;
  legacy bugs fixed (ADR-0003). Connection, catalogs, indices, table status,
  routines, recordsets work.
- **Server matrix:** MySQL 5.7, 8.0, 8.4, 9 and MariaDB 10.11, 11.4 pass the test
  suite (`tests/run-matrix.ps1`) (ADR-0004, ADR-0005).
- **Pascal interface layer:** generated under the original names, layout verified
  against C (ADR-0006).
- **Forms:** 12 Query Browser forms converted and reviewed (ADR-0008);
  `docs/reconstructed/` has screenshots of every form and tab.
- **Third-party replacements:** TNT aliases, PNG, gettext `.po` reader
  (ADR-0007); PNG and other resources embedded and loadable.
- **Connect dialog ported and running:** `ConnectToInstance`, `MySQLConnection`, `Options`,
  `OptionsEditor`, `AuxFuncs` (pruned to what the Query Browser uses), `CommonFuncs`, `About`,
  `MyxError`, `AuxApplicationFuncs`. The dialog shows with the original banner and translations,
  and the original code path connects to all six matrix servers, both from the command line and by
  driving the dialog (`querymole --selftest-connect/--selftest-dialog`, part of `tests/run-matrix.ps1`).
- **Main window ported and running** (`querymole -h ... --shot-main file.png` writes a screenshot):
  all units of the main window compile (`LexicalTools` without its x86 assembler, `ScriptPanel`,
  `SqlCmdPanel`, `QueryBrowser`, `Main`, `TableDrag`, `StringContainers`), the editor layer on SynEdit
  has per-line data/states/styles/gutter markers, and the schema tree, tabs, toolbar and help pane
  placeholder show against a live server. Queries run and fill the result grid (`--sql "..."` dev mode);
  toolbar icons/labels and SQL token colours work. Known gaps: line-number font and gutter width,
  token colours for embedded commands/variables, script toolbar labels touch each other with the German texts (probably as in the original). Checked by
  screenshot: query run on 5.7 and 8.x, schema tree expansion, script tab with breakpoint stop and
  progress bar (`--script`, `--expand`, `--sql` dev hooks). Also checked by screenshot or file output: EXPLAIN panel, edit/apply with server error, all five result exporters (CSV, HTML, XML, Excel, PLIST), table double click and drop, the edit/error message dialogs, options pages, text search, schema selection, RegEx importer. Not yet checked: real keyboard/mouse
  interaction, bookmarks, history, the console tab (`SqlCmdPanel` is not used by the Query Browser).

## Next (in this order)

1. ~~Port the units of the connect dialog.~~ Done. Remaining for the dialog: the busy
   animation (`TAnimate` placeholder), the options dialog opened from it, and review of the
   `Windows`-API code that is still in the ported units (`AuxFuncs`, `Options`).
2. Main window. Its closure is 79 units / ~145k lines, of which roughly 35k are the project's own
   code and ~11k small Mike Lischke helper libraries; the rest is third-party that is replaced
   (ADR-0007). Own code still to port, with sizes (lines):
   - application shell: `ApplicationDataModule` 561, `QueryBrowserOptionPages` 182, `Main` 1318,
     `AppInstanceMgmt` 212, `MySQLCommonFuncs` 252, `CommonTypes` 174
   - UI building blocks: `Sections` 1803, `InstanceSections` 60, `Toolbar` 1901, `TabHeader` 1295,
     `AdvancedEdit` 197, `TableDrag` 457, `TextSearch` 343, `SchemaSelection` 92
   - data and results: `MySQLResultSet` 1636, `MySQLResultSetControls` 4525,
     `MySQLResultSetFieldViewer` 307, `SQLErrorGrid` 384, `SchemataTreeView` 2670
   - editing and scripting: `ScriptPanel` 2118, `RegExTextImporter` 1728, `EditorTable` 3709
     (+ `EditorTableVTEdit` 657, `EditorTableVTFKEdit` 691)
   - the main form: `QueryBrowser` 8149 (the largest single unit)
   Suggested order: shell → building blocks → results/tree → main form last, running the
   self-tests after each step.
3. SQL editor on SynEdit with a highlighter that matches the original colours.
4. Remaining dialogs and flows: options pages, RegEx importer, field viewer,
   about, text search, schema selection.
5. Packaging for Windows (installer); then Linux and macOS builds (widgetset
   work, platform guards for Windows API use). Linux so far: development container
   (`tools/distrobox-setup.sh`), backend, bindings layout check and the test suite on all six matrix
   servers (`tests/run-matrix.sh`); `build.sh` and the tools run there. The Linux release is an AppImage
   (`tools/package-appimage.sh`, ADR-0027); with `--velopack` it updates itself (ADR-0037, update cycle
   checked locally; first release through the GitHub feed and the Windows cycle open). The application compiles
   with GTK2, connects on all six servers, and the main window's features (results, editing,
   scripts, export, dialogs, help) work by screenshot. State and next steps: `docs/linux-port.md`.

## Backlog and ideas

**Compatibility and quality**
- CI (hosted runner with MSYS2 + Lazarus; server matrix as containers). No
  remote exists yet, so this is not written.
- MariaDB version detection: `5.5.5-10.x` is read as 5.5 (ADR-0004).
- Look for further undefined behaviour in the C backend with sanitizers; more
  tests per `myx_*` area (query analysis, editable result sets, import/export).
- `myx_pdf.c` (needs the "panda" library) and `myx_live_profiling.c` (POSIX
  sockets) are not built; decide whether the features are needed.
- Review each of the 29 `char*`-returning functions for the `g_free` contract
  (ADR-0006).
- **Table editor on current servers.** `tests/test_table_editor.pas` reads a table through the editor's model
  (`myx_database_model.c` and the Pascal class) and checks on the matrix that an unchanged table gives no SQL, that
  editing the table comment and a comment on every column has the same effect as plain `ALTER TABLE` on a twin
  table, and that the table written as a new one (`CREATE TABLE`) equals the twin. It covers InnoDB, MyISAM,
  MEMORY, Aria, foreign keys with actions, many data types, JSON, generated, invisible and `ON UPDATE` columns,
  CHECK, column collations and functional indices; all pass on the six servers since 2026-11-15 (fixes in the
  backend, marked `revival:`). Still open:
  - the model has no table CHECK constraints: edits keep them, the editor cannot create them;
  - generated expressions, `ON UPDATE`, `INVISIBLE` and column CHECKs are kept but not shown or editable in the
    editor; expression defaults (`DEFAULT (expr)`, MySQL 8.0.13+) are not tested;
  - not tested: editing indices and foreign keys in the editor;
  - data types and engines: ADR-0034 (JSON, YEAR, BINARY, VARBINARY added; engines from `SHOW ENGINES`).
    Server-specific types (MariaDB UUID, INET4/6; MySQL 9 VECTOR) wait for the dialects of ADR-0010.
    `myx_dbm_get_default_storage_engine` still reads `storage_engine` (gone since 5.7) but is not used;
  - the editor itself was checked by opening a table, not by editing through its grid; the Windows backend build
    with these changes is not checked yet.
  The model is the natural seam for other databases later (ADR-0010). Showing and editing the newer features is
  stage 2 (ADR-0035), the Pascal model with dialects stage 3 (ADR-0036), both after parity (see "Product").

**Fidelity**
- Reference screenshots from a user who still runs the original, for side by
  side review (ADR-0008).
- Rebuild what the conversion drops: SQL editor configuration, `TAnimate`
  connect animation, menu owner draw, toolbar image lists (from PNGs), form
  icons, version info and manifest.

**Product (after parity; each needs a decision)**
- TLS mode in the connection dialog: required / preferred / off (ADR-0005).
- HiDPI scaling, then optional vector-rendered icon set (ADR-0009).
- PostgreSQL and other databases via a driver seam (ADR-0010); candidate
  libraries: FPC `postgres` units, ZEOS.
- Replace C pieces by Pascal behind that seam, SQL parser last (ADR-0003).
- Table editor, stage 3 (ADR-0036): a Pascal table model with a dialect per server family (reading, `CREATE`/
  `ALTER` generation, capabilities incl. server-specific types such as UUID, INET6, VECTOR) replaces
  `myx_database_model.c` for the editor; `tests/test_table_editor.pas` must pass on it on the whole matrix first.
- Table editor, stage 2 (ADR-0035): controls for generated columns, `ON UPDATE`, `INVISIBLE`, CHECK (column and
  table), expression defaults and functional index parts, shown by server capability. Needs a mock-up and an
  amending ADR for the layout; preferably built on the stage 3 model.
- Show what the connection is to in the picture top right of the main window (where the original had the
  dolphin): server type and version as text or tooltip ("MariaDB 11.4"). Not the databases' logos: the MySQL
  logo needs a written agreement with Oracle outside websites; the MariaDB sea lion is CC BY-SA 4.0 as a picture
  but a trademark of MariaDB Corporation, and CC BY-SA 4.0 does not combine with GPL-2.0 (checked 2026-11-14).
- Dark mode; MySQL 8 specifics the original never had (JSON, CTEs and window
  functions in highlighting and statement splitting; `utf8mb4` collations).

## Open questions

- ~~**Name.**~~ Decided: **QueryMole** (ADR-0030). The About dialog shows the QueryMole artwork (ADR-0032), the
  icon replaces the lightning bolt everywhere (ADR-0033). Open: a neutral busy
  animation, renaming the GitHub repository to `querymole` (the program already links there).
- Where the project is hosted; copyright holder line and contribution policy
  (licence is decided: ADR-0011).
- Whether to ship an installer that bundles glib/libxml2/PCRE/Connector DLLs or
  link statically.
- **Licence decisions before a public release** (`docs/licenses.md`): three SynEdit units are MPL-1.1 only
  (not GPL-compatible by the FSF's reading; ask the Lazarus maintainers); "or later" in GPL-2.0-or-later must stay (OpenSSL is Apache-2.0); legal review and code
  signing.
