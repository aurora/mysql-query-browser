# ADR-0004 — MariaDB Connector/C as client library; server support matrix

- Status: Accepted
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

The C backend (ADR-0003) links a MySQL client library. The original used
Oracle's libmysqlclient 5.0. The product must work against MySQL 8, which
defaults to `caching_sha2_password`, and should keep working against MySQL
5.7 and MariaDB. Long term other servers may be added (ADR-0010).

## Decision

- Link **MariaDB Connector/C** (3.4.9 from MSYS2 at the time of writing). It
  speaks the protocol of MySQL 5.x/8.x and MariaDB; `caching_sha2_password`
  works through the bundled auth plugin.
- Support matrix, enforced by `tests/run-matrix.ps1` (throw-away Podman
  containers, 14 tests per server):
  - **supported, tested:** MySQL 5.7, 8.0, 8.4, 9.x; MariaDB 10.11, 11.4.
  - **best effort, not tested:** MySQL 5.5 and 5.6.
  - **not a goal:** 5.1 and older (missing features, TLS problems).
- **One MySQL driver with a capability layer** keyed on server version and
  flavour (MySQL/MariaDB), not a driver per version. Version differences are
  local branches (catalog queries, keywords, types, removed features).

## Consequences

Positive:

- LGPL licence and a small CMake build; Oracle's client would need most of the
  MySQL source tree or its binaries shipped alongside.
- The same binary serves old and new servers.
- The matrix catches version-specific regressions; it has already found a
  catalog bug that only appeared on MySQL 8 (ADR-0003) and a TLS issue on
  MariaDB 10.11 (ADR-0005).

Negative / costs:

- Connector/C is not API-identical to Oracle's client (`my_bool` handling,
  option constants); the few call sites are isolated in `myx_library.c`.
- MariaDB servers report their version as `5.5.5-10.x`; the existing version
  detection reads that as 5.5. Known and **not yet fixed**.
- Connector/C >= 3.4 defaults changed in ways that matter (TLS, ADR-0005);
  future upgrades need the matrix re-run.
- 5.5/5.6 are promised only as best effort because no CI image runs them.

## Alternatives considered

- **Oracle libmysqlclient.** Rejected: GPL with FOSS exception and a heavy
  build; no technical advantage here.
- **A client protocol implementation in Pascal.** Rejected: large effort for
  no gain.
- **A driver per server version.** Rejected: the protocol is stable; the
  differences are SQL-level, which a capability layer handles.

## Related

- ADR-0003, ADR-0005, ADR-0010.
