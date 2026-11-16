# ADR-0036 — Table editor: a Pascal table model with server dialects

- Status: Proposed (after functional parity; refines ADR-0010 for the table editor)
- Date: 2026-11-16
- Deciders: Harald Lapp (project owner)

## Context

The table editor's model is C code in `myx_database_model.c` (ADR-0003), from the MySQL 5.0 era:

- It reads a table by parsing `SHOW CREATE TABLE` with hand-written string scanning, and writes `CREATE`/`ALTER
  TABLE` by string building. Every newer server feature needed a fix there (the `revival:` changes tested by
  `tests/test_table_editor.pas`), and each new field goes through the C struct, the generated bindings
  (ADR-0006) and `tools/check_bindings.py`.
- It knows one SQL dialect. MySQL and MariaDB have drifted apart (CHECK placement, `INVISIBLE` versions,
  MariaDB's Aria/SEQUENCE, UUID/INET6 types, MySQL's VECTOR), and other databases (PostgreSQL, ADR-0010) differ
  completely.
- The data type list (`app/xml/mysqlx_dbm_datatypes.xml`, ADR-0034) and the engine list are the same for every
  server of a family; per-server types are missing because there is nowhere to say which server has them.

ADR-0010 proposes a driver seam but leaves its shape open. The table editor is a well-bounded place to try it:
one form, one model, a test that checks the model against real servers.

This is stage 3 of the table editor work (stage 1: ADR-0034; stage 2, the controls: ADR-0035).

## Decision

Proposed, not before functional parity:

- **A table model in Pascal** (table, columns, indices, foreign keys, CHECK constraints, options) replaces
  `MYX_DBM_TABLE_DATA` and friends for the editor. It is plain data with no SQL in it.
- **A dialect per server family and version range** (MySQL, MariaDB; later PostgreSQL) behind one interface:
  - reading a table into the model, preferably from `information_schema` rather than by parsing `SHOW CREATE
    TABLE`, where the server's catalog is complete enough;
  - writing `CREATE TABLE` and the `ALTER TABLE` difference between two models;
  - capabilities: the data types (taking over the type list of ADR-0034, with server-specific types), engines,
    which column and table features exist (used by ADR-0035's controls).
- `tests/test_table_editor.pas` stays the acceptance test: the same checks (no SQL for an unchanged table, edits
  equal to plain `ALTER TABLE`, `CREATE` equals the twin) run against the new model on the whole matrix before
  the C model is removed from the editor.
- The C model stays until then; the switch happens per editor, not piece by piece inside it.

Not decided: whether this interface becomes part of ADR-0010's driver seam or stays editor-local; whether the
schema editor (and other `myx_dbm_*` users) move at the same time; how much of `SHOW CREATE TABLE` parsing is still
needed (e.g. for partitioning, which `information_schema` describes only partly).

## Consequences

Positive:

- New server features are a change in one Pascal dialect, not in C, bindings and Pascal.
- Per-server types and features have a place; the editor can offer exactly what the server supports.
- A tested first slice of ADR-0010's seam, and part of replacing the C backend (ADR-0003).

Negative / costs:

- A rewrite of working (now tested) code, with the risk of new differences; the matrix test is the guard.
- Two models exist side by side during the transition.
- `information_schema` differs between versions and is slow on servers with many tables; reading may need
  both sources.

## Alternatives considered

- **Keep extending the C model.** Works, as stage 1 showed, but each feature costs C, bindings and Pascal, and
  dialects do not fit its single-dialect design.
- **Use an existing library's schema model (e.g. ZEOS metadata).** Not examined in depth; their models target
  reading, not generating `ALTER TABLE` faithfully, and add a dependency (`docs/licenses.md`).
- **Generate SQL from templates per server.** Rejected as the main approach: the hard part is the difference
  between two models, not the text.

## Related

- ADR-0003 — the C backend as a transitional layer; this replaces one part of it.
- ADR-0010 — the driver/dialect seam; this ADR proposes its first concrete piece.
- ADR-0034 — stage 1; its type list moves into the dialects.
- ADR-0035 — stage 2; its controls use the capabilities defined here.
- ADR-0006 — generated bindings, which this part no longer needs.
