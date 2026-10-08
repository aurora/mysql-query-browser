# ADR-0003 — Keep the C backend as a transitional layer, built with CMake

- Status: Accepted (transitional)
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

The Delphi UI does not talk to the MySQL client library directly. It calls
`libmysqlx` (connection handling, catalogs, recordsets, query parsing,
options files), `libmysqlutil`, `libmysqlqb` and an SQL parser through
several hundred `myx_*` functions. The relevant part is tens of thousands of lines of C
and C++ (the largest piece is a generated SQL parser) using glib, libxml2 and PCRE (v1), written around 2005, with
autotools/Visual Studio build files.

Bringing it up on a current toolchain showed how far it has aged: lexer
declarations without return types, `NULL` assigned to integer fields,
`&vec.front()` on empty vectors (undefined behaviour that aborts with modern
libstdc++), an `iconv` call with the wrong signature, a catalog function that
returned no schemata for server versions `>= 6` (written for the unreleased
MySQL 6; it hid every schema on MySQL 8), and POSIX-only socket code.

## Decision

- Keep the C backend for now. It is copied into `backend/src/` (the originals
  under `legacy/` stay untouched), built with **CMake and MinGW-w64
  (gcc 16)** against MariaDB Connector/C (ADR-0004).
- Libraries built: `mysqlutil`, `mysqlsqlparser`, `mysqlx`, `mysqlqb`.
  `myx_pdf.c` (needs the "panda" PDF library) and `myx_live_profiling.c`
  (POSIX sockets) are not built yet.
- Compatibility shims instead of edits where possible (`backend/compat/`:
  `config.h`, `mysql_version.h`, `my_global.h`); real bugs are fixed in place.
- The C layer is **transitional**: pieces are to be replaced by Pascal behind
  a driver interface (ADR-0010), starting with connection and catalog code,
  with the generated SQL parser last. When or whether each piece is replaced
  is not decided.

## Consequences

Positive:

- The UI can be ported against the real behaviour of the original library,
  which is what "exactly as before" needs.
- A running end-to-end result (Pascal → C → server) exists early; it is
  covered by tests on six server versions.
- No up-front rewrite of the backend.

Negative / costs:

- A 20-year-old, memory-unsafe C code base stays in the product, with more
  latent bugs of the kind listed above.
- Every platform needs glib, libxml2 and PCRE (v1, long unmaintained) as
  dependencies.
- The CMake build adds a second build system next to Lazarus.
- Parts of the backend serve Workbench-era features (GRT, canvas, Java/PHP/Lua
  bindings) that the Query Browser does not need; they are deliberately left
  out of `backend/`.

## Alternatives considered

- **Port the whole backend to Pascal first.** Rejected: delays the first
  running result substantially and the UI calls the `myx_*` surface everywhere, so
  the interface would have to be rebuilt before anything runs.
- **Use FPC's own MySQL units / SQLdb directly.** Rejected for now: loses
  behaviours the UI relies on (statement splitting, query analysis for
  editable result sets, option files).
- **Rewrite in another language (Rust, Go).** Rejected: adds a third language
  and a rewrite with no benefit to the first milestone.

## Related

- ADR-0004 (client library), ADR-0006 (Pascal bindings), ADR-0010 (driver
  seam that lets the C code be replaced piecewise).
