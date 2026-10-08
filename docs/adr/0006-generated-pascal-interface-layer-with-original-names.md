# ADR-0006 — Generate the Pascal interface layer under the original unit and type names

- Status: Accepted
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

The ported UI code does not call the C library with raw pointers. It uses a
layer that the original Windows-only tool `LibInterfaceMapper` generated from
the C headers (`/// [SCRIPT::LibInterfaceMapper] -generate_classes X`
annotations): raw records `MYX_USER_CONNECTION`, wrapper classes
`TMYX_USER_CONNECTION` and `TMYX_USER_CONNECTION_List` that copy a C record
into Pascal fields (`Create(PMYX_...)`) and build one again for calls into the
library (`get_record_pointer`), and wrapper functions that take `WideString`
and return `WideString` for `char*` results (freeing them with `g_free`).

The generated `.pas` files are not in the repository, only the tool (a 64 KB
Delphi program) and its templates. The code that uses them is large (e.g. `ConnectToInstance.pas` builds `TMYX_USER_CONNECTION.Create(name,
user, ..., type, storage_type)`).

## Decision

- Replace the mapper with `tools/gen_bindings.py` and `tools/gen_classes.py`,
  which parse the four public headers and write
  `bindings/myx_util_public_interface.pas`, `myx_public_interface.pas`,
  `myx_sql_parser_public_interface.pas` and `myx_qb_public_interface.pas` —
  **the same unit names and the same type names as before**:
  - records `MYX_FOO`, pointers `PMYX_FOO`, enums as `cint` aliases;
  - for the 56 structs marked `-generate_classes`: `TMYX_FOO` and
    `TMYX_FOO_List` with the original constructor shapes, `get_record_pointer`
    and `Assign`;
  - `String`-returning wrappers (raw function `_name`) for `char*` results;
    non-`const` results are `g_free`d, as in the original.
- Strings in the wrapper classes are `String` (UTF-8 under Lazarus), not
  `WideString`.
- Pointer arithmetic uses `{$POINTERMATH ON}` (the originals cast pointers to
  `Integer`, which breaks on 64 bit); counters (`unsigned int`) are handled so
  that `for I := 0 to num - 1` cannot run 2^32 times for `num = 0`.
- Generated files are committed so that building the Pascal side needs no
  Python.
- `tools/check_bindings.py` compiles a C and a Pascal program that print
  `sizeof` and `offsetof` of every struct field and fails on any difference
  (531 values compared, all identical).
- The generator understands only the C subset the headers use and **aborts on
  anything else** instead of guessing.

## Consequences

Positive:

- Ported units compile with few edits.
- Struct layout errors, the worst kind of binding bug, are caught by a test
  instead of surfacing as crashes.
- A header change is a re-run of the generator, not a hand edit.

Negative / costs:

- The "`char*` results are `g_free`-able" contract comes from the original
  mapper; it was verified for `myx_mysql_error` (returns `g_strdup`) but not
  for each of the 29 wrapped functions. A violation would corrupt the heap.
- The wrapper classes copy data in and out (the original design); large
  recordsets are not meant to go through them.
- The generator is another tool to maintain, and the wrapper design (shallow
  record copies owned by nested objects) has to be understood to change it.

## Alternatives considered

- **h2pas.** Rejected: produces raw bindings only; the wrapper classes the UI
  code needs would still be hand-written.
- **Raw records in the ported code.** Rejected: rewrites thousands of lines
  and changes memory ownership everywhere; high regression risk.
- **Port the Delphi mapper itself.** Rejected: Windows-only Delphi tool of
  64 KB with its own parser and template engine; a new generator was smaller.
- **Hand-written bindings per use.** Rejected: the first test bindings were
  written that way; they covered only connect, query and the catalog basics
  and would not scale to 212 functions and 133 types.

## Related

- ADR-0003 (the C layer these bindings sit on), ADR-0007 (the other shims),
  `tests/test_classes.pas` for behavioural coverage.
