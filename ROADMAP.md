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
  driving the dialog (`qbr --selftest-connect/--selftest-dialog`, part of `tests/run-matrix.ps1`).
- **Main window ported and running** (`qbr -h ... --shot-main file.png` writes a screenshot):
  all units of the main window compile (`LexicalTools` without its x86 assembler, `ScriptPanel`,
  `SqlCmdPanel`, `QueryBrowser`, `Main`, `TableDrag`, `StringContainers`), the editor layer on SynEdit
  has per-line data/states/styles/gutter markers, and the schema tree, tabs, toolbar and help pane
  placeholder show against a live server. Queries run and fill the result grid (`--sql "..."` dev mode);
  toolbar icons/labels and SQL token colours work. Known gaps: line-number font and gutter width,
  token colours for embedded commands/variables, bottom-right result buttons clipped. Checked by
  screenshot: query run on 5.7 and 8.x, schema tree expansion, script tab with breakpoint stop and
  progress bar (`--script`, `--expand`, `--sql` dev hooks). Not yet checked: real keyboard/mouse
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
   work, platform guards for Windows API use).

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
- Dark mode; MySQL 8 specifics the original never had (JSON, CTEs and window
  functions in highlighting and statement splitting; `utf8mb4` collations).

## Open questions

- **Name.** "MySQL" cannot be used. Working name `query-browser-revival`;
  candidates floated: SeaQuel, Querius, Plainbrowser. Needs a trademark check.
- Where the project is hosted; copyright holder line and contribution policy
  (licence is decided: ADR-0011).
- Whether to ship an installer that bundles glib/libxml2/PCRE/Connector DLLs or
  link statically.
