# ADR-0010 — Other RDBMS (PostgreSQL) via a driver seam, after parity

- Status: Proposed (design seam only; no second driver planned before parity)
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

Supporting other relational databases (PostgreSQL first) is a long-term wish.
The current backend is tied to MySQL: schema browsing uses `SHOW ...` and
`information_schema` in MySQL dialect, statement splitting and highlighting use
a MySQL grammar, and result editing relies on MySQL column metadata. A
multi-database change made at the same time as the port would endanger both
(ADR-0001: first milestone is the original behaviour).

FPC ships `postgres` and `mysql` units; ZEOS or similar libraries could be
candidates later.

## Decision

Proposed, no implementation now:

- Define a **driver interface** between UI logic and database access: connect,
  list catalogs/schemata/tables/columns/indices/routines, execute a statement,
  read a resultset (with column metadata), server version and capabilities.
- The first and only implementation is the existing MySQL/MariaDB path
  (ADR-0003/0004), including its version/flavour capability layer. Replacing
  C code piecewise (ADR-0003) happens behind this interface.
- A PostgreSQL driver is a separate implementation of the same interface, to
  be started only after functional parity of the MySQL path.

Not decided: the shape of the interface (whether the existing `myx_*` surface
is that seam or a new Pascal interface is introduced above it), how much of the
UI (e.g. query builder, SQL highlighting, `EXPLAIN` view) is database neutral,
and which Postgres access library to use.

## Consequences

Positive:

- The port is not slowed down by speculative generality; the seam is a design
  constraint, not a feature.
- Replacing the C backend and adding a second database use the same boundary.

Negative / costs:

- A seam designed before a second implementation exists may be wrong; the
  first Postgres driver is likely to force changes.
- Parts of the UI are inherently MySQL specific (the original product *is* the
  MySQL query browser); a Postgres variant will either hide them or diverge
  from "as before".

## Alternatives considered

- **Multi-database from the start.** Rejected: doubles the problem space
  during a port whose goal is fidelity.
- **Fork a separate Postgres product later.** Possible, but wastes the UI
  work; revisit if the seam turns out too costly.
- **Never support other databases.** Not rejected, just not decided; the
  seam costs little if kept in mind.

## Related

- ADR-0003, ADR-0004.
