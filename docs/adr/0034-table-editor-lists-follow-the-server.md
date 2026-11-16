# ADR-0034 — Table editor: data types and storage engines follow current servers

- Status: Accepted
- Date: 2026-11-16
- Deciders: Harald Lapp (project owner)

## Context

The table editor offers two fixed lists from the MySQL 5.0 era:

- **Data types** come from `mysqlx_dbm_datatypes.xml` (`legacy/mysql-gui-common/res`). JSON, YEAR, BINARY and
  VARBINARY are missing although every supported server (MySQL 5.7–9, MariaDB 10.11, 11.4; ADR-0004) has them.
  Columns of these types keep their type as plain text (since the fixes tested by `tests/test_table_editor.pas`),
  but they cannot be chosen for a new column, and they get no type group (defaults, flags).
- **Storage engines** are a list in `EditorTable.pas` with descriptions: InnoDB, Falcon, MyISAM, Merge, Memory, BDB,
  NDB, Archive, CSV, Blackhole. Falcon and BDB never shipped in a supported server, NDB only in MySQL Cluster; choosing
  them fails. Engines the server has but the list does not (MariaDB's Aria, MyRocks, ...) cannot be chosen, and a
  table that uses one is shown as "MyISAM" (the backend maps unknown engines to MyISAM; since the same fixes it
  keeps the server's engine name, so the table is not converted).

Both lists change what the user sees, so this needs a decision under ADR-0001. No control is added, moved or
renamed; only the entries of existing lists change.

## Decision

- **Data types:** the program ships its own copy of the data type list, `app/xml/mysqlx_dbm_datatypes.xml`, taken
  from `legacy/` and extended by the types all supported servers know: JSON, YEAR, BINARY, VARBINARY.
  `tools/prepare_runtime.py` installs it instead of the original. Types only one server family has (MariaDB's UUID,
  INET4/INET6; MySQL 9's VECTOR) are not added: the list is the same for every server, and offering them would let
  the user pick a type the server rejects. They wait for per-server capabilities (the dialect seam of ADR-0010).
- **Storage engines:** when the editor opens, it asks the server (`SHOW ENGINES`) and shows only the engines with
  `Support` `YES` or `DEFAULT`. Engines from the original list keep their caption and description; engines the
  server has beyond them are appended with the server's own name and comment as description, except those that
  only serve the server's own tables (PERFORMANCE_SCHEMA, MariaDB's SEQUENCE). The table's engine is
  selected by its name, so an Aria table shows "Aria". Choosing such an engine writes its name (`engine_name` in the
  backend's table model); the backend compares and writes engine names, not only its engine enumeration. Without an
  answer from the server (no privilege, error) the original list is shown unchanged.
- The default engine for new tables stays the program's option (Options › Editors), as in the original. If the
  server lacks that engine, the editor selects the server's default.

## Consequences

Positive:

- New columns can use the common modern types; the editor no longer offers engines that cannot work and offers the
  ones the server has.
- Aria tables (and other engines unknown to the original) are shown and kept as what they are.

- Opening the editor on MariaDB 10.10+ crashed silently before (the character set query, which the editor runs
  first, did not expect collations without a character set); fixed in the backend with this change.

Negative / costs:

- The engine list differs between servers and is one query more when the editor opens.
- Appended engines have English descriptions from the server, not translated ones.
- `app/xml/` is a second copy of a legacy data file; changes to the type list go there, not to `legacy/`.
- Server-specific types (UUID, INET6, VECTOR) are still missing until ADR-0010's dialects exist.

## Alternatives considered

- **Keep both lists (ADR-0001 strictly).** Rejected: the lists offer engines that fail and lack types every server
  has; that is a compatibility defect, not a design the original chose for today's servers.
- **Take all data types from the server.** Not possible: neither MySQL nor MariaDB lists its data types in a query;
  the list has to be maintained.
- **Show all engines `SHOW ENGINES` reports, also those with `Support` `NO`.** Rejected: choosing one fails.
- **New controls for newer column features (generated columns, INVISIBLE, CHECK).** Deferred: they change the layout
  and come after parity, best on the Pascal table model of ADR-0010 (see `ROADMAP.md`).

## Related

- ADR-0001 — no UX changes without an ADR; this one changes list contents only.
- ADR-0004 — the supported servers, whose common types define the list.
- ADR-0010 — the driver/dialect seam where per-server types and capabilities belong.
- ADR-0003 — the C backend, where the engine name is kept.
