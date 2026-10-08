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

## Next (in this order)

1. Port the units of the connect dialog: `MyxError`, `AuxApplicationFuncs`,
   `Options`, `AuxFuncs` (Windows API heavy), `MySQLConnection`, `OptionsEditor`,
   `ConnectToInstance`. Goal: a running Lazarus program whose dialog connects
   to the test server through the generated bindings.
2. Code-built parts of the main window: `Toolbar`, `TabHeader`, `SqlCmdPanel`,
   `ScriptPanel`, result grid, schema tree (`SchemataTreeView`).
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
- Where the project is hosted and under which GPL header policy (files carry
  "(C) MySQL AB" headers; new files need a convention).
- Whether to ship an installer that bundles glib/libxml2/PCRE/Connector DLLs or
  link statically.
