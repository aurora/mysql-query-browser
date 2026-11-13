# ADR-0029 — Search fields: input without wildcards matches parts of names

- Status: Proposed
- Date: 2026-11-14
- Deciders: Harald Lapp (project owner)

## Context

The search fields above the Schemata, Bookmarks and History trees (`TAdvancedEditFrame`) filter the tree 500 ms after
each key press. Whether a node stays visible is decided by the C function `myx_match_pattern` (`myx_library.c`),
called from `TSchemataFrame.DoSearch`/`SearchStep` and `StrMatchesSearchStr` (Schemata, also the schema selection
dialog, non-strict) and from the bookmark and history filters in `QueryBrowser` (strict). Both the Pascal calls and
the C function are unchanged from the original.

`myx_match_pattern` matches the **whole** name. `*` stands for any number of characters, `?` for one; otherwise the
text must match from its first to its last character, ignoring case. Measured against the library:

| Input | `shop` | `sys` | `mysql` | `information_schema` |
|---|---|---|---|---|
| `s` | – | – | – | – |
| `s*` | match | match | – | – |
| `*s*` | match | match | match | match |

Typing a letter or a part of a name therefore hides everything, which reads as "the search is broken" (reported
2026-11-13). Only users who know that wildcards are expected get results. By default only schema names are searched
(`SchemaSearchTargets = smSchemata`); tables, columns etc. only when chosen in the field's menu.

ADR-0001 rules out visible changes until functional parity unless an ADR decides them.

Found on the way, and not part of this decision: `myx_match_pattern` cannot match names with non-ASCII characters at
all, not even exactly (`bär` against `bär` gives no match): the end pointers `tend`/`send` are computed from the
character count instead of the byte count, so `g_utf8_get_char_validated` gets too short a length. That is a bug
in the original; it was fixed separately on 2026-11-14 (`tests/test_match_pattern.pas`), independent of this ADR.

## Decision

Proposed, not decided:

- If the input contains neither `*` nor `?`, it is searched as `*input*`, i.e. it matches any name that contains it
  (ignoring case). An input with a wildcard is passed on unchanged, so the original's behaviour stays available to
  everyone who uses it.
- The rule lives in one Pascal function used by all four callers (Schemata search, `StrMatchesSearchStr`, bookmarks,
  history); `myx_match_pattern` and its semantics stay as they are.
- What is searched (schema names by default, the field's menu) is not changed.

## Consequences

Positive:

- The fields behave like the filters of current programs: a few letters narrow the tree down. The common case needs
  no knowledge of wildcards.
- Inputs with wildcards keep their meaning (`shop*`, `s?op`, `*s*` give the same result as before), so habits
  from the original still work.
- Small and local: one function, four call sites, no change to the C library or to the forms.

Negative / costs:

- A visible change of behaviour against the original, which ADR-0001 asks to avoid: someone used to the original
  who types a full name expecting only that name now also sees longer names containing it.
- "Exactly this name" can no longer be expressed: without a wildcard the input becomes `*input*`, and every wildcard
  widens the match (`shop` also finds `myshop`). Judged rare for a tree filter, where the exact name is usually
  visible anyway once the list is short.
- In large schemata with the targets "All", a short input matches many tables and columns; the tree then shows more
  than before, where it showed nothing.

## Alternatives considered

- **Keep the original behaviour.** The faithful option, and the default if this ADR is not accepted. Rejected in this
  proposal because a filter that shows nothing for anything but a complete name is close to useless, and the
  behaviour is undocumented in the program.
- **Prefix match (`input*`).** Matches how many name filters work and keeps the list shorter. Rejected because it
  does not find names by an inner part (`order` in `customer_orders`), which is a common way to look for a table.
- **Change `myx_match_pattern` (non-strict mode = substring).** Rejected: changes the library's semantics for every
  caller instead of the one UI rule, and the strict/non-strict distinction of the original would lose its meaning.
- **An option in the Options dialog.** Rejected: a new setting is itself a visible change, and two behaviours have to
  be maintained for a detail most users never think about.

## Related

- ADR-0001 (no UX changes without an ADR).
- ADR-0017 (another deliberate deviation from the original, trimmed menus).
- `docs/linux-port.md`, schemata tree section (the search's rebuild in the main thread, 2026-11-13).
