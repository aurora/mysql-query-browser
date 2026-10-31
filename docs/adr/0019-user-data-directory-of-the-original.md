# ADR-0019 — User data directory: the original's folder on each platform

- Status: Accepted (implemented and checked on Linux; macOS not built)
- Date: 2026-10-31
- Deciders: Harald Lapp (project owner)

## Context

The Linux port needed a place for the user's files (`mysqlqb_options.xml`, `mysqlqb_history.xml`,
`mysqlqb_bookmark.xml`, `mysqlx_common_options.xml`, `mysqlx_user_connections.xml`). The original
chose per platform (`myx_grt_base.c`, `MGPreferences.cc`):

| Platform | Original |
|---|---|
| Windows | `%APPDATA%\MySQL\` |
| macOS | `~/Library/Application Support/MySQL/` |
| Linux | `~/.mysqlgui/` |

The Linux port first used `$XDG_CONFIG_HOME/MySQL/` (default `~/.config/MySQL/`) as an interim. A new
name for the application (QueryMole) is being prepared; the application is for internal use only for
now. The file formats are unchanged from the original, so an existing folder can be used as it is.

## Decision

- The application keeps using the folder of the original on every platform (table above). No new
  name, no copying, no migration. `-datadir` still overrides it.
- Linux therefore uses `~/.mysqlgui/` and not the XDG location. `Options.TMyxOptions.Create` selects
  the folder; `AuxFuncs.GetApplicationDataDir` knows `%APPDATA%` and (on macOS) `~/Library/Application
  Support`.
- Renaming the folder to the product's new name (and a one-time import from the old folder) is
  deferred to the rename of the application, in an ADR of its own.

## Consequences

Positive:
- Existing configurations, connections and history of the original are found on all platforms,
  without a migration step; the Windows behaviour does not change (ADR-0001).
- Nothing to undo when the application gets its new name.

Negative:
- A dotfile directly in the home directory, which XDG-aware desktops and backup tools do not expect.
- The folder is shared with other tools that use the same name (MySQL Workbench and MySQL
  Administrator on Windows/macOS use `MySQL\` too). Files are not prefixed per application, apart from
  the `mysqlqb_` / `mysqlx_` prefixes the original already had.
- Checked 2026-10-31: the Linux build starts with an empty `HOME` and creates `~/.mysqlgui/`; the server
  matrix passes (it uses `-datadir`, so it does not cover the default folder); the Win64 objects of
  `Options` are identical to the previous commit. The macOS branch was not compiled.

## Alternatives considered

- **`$XDG_CONFIG_HOME/MySQL/`** (the interim): the current convention for Linux, but not found by an
  existing Linux installation of the original and the same name as other MySQL tools.
- **`$XDG_CONFIG_HOME/QueryMole/` with an import of the old folder**: the cleanest end state, but it
  changes the folder on Windows as well (migration, ADR-0001) and the name is not in use yet.
  Deferred, not rejected.
- **Splitting into XDG config/data/state folders**: the code assumes one folder (`UserDataDir`).

## Related

- ADR-0001 — no changes visible to users while porting.
- `docs/linux-port.md`, section 4.1 (the open question this settles).
