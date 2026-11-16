# ADR-0035 — Table editor: controls for newer server features, after parity

- Status: Proposed (after functional parity; layout not designed)
- Date: 2026-11-16
- Deciders: Harald Lapp (project owner)

## Context

Since the fixes tested by `tests/test_table_editor.pas` (and ADR-0034), the table editor reads and keeps what
MySQL 5.7–9 and MariaDB 10.11/11.4 (ADR-0004) add to a table: generated columns, `ON UPDATE` expressions,
`INVISIBLE` columns, column and table CHECK constraints, expression defaults (`DEFAULT (expr)`, MySQL 8.0.13+),
functional indices. "Keeps" means that an edit elsewhere in the table does not drop them. The backend's model has
fields for the column features (`generated`, `on_update`, `invisible`, `check_constraint` in
`MYX_DBM_COLUMN_DATA`), but the editor shows none of them and cannot create them; table CHECK constraints are not
in the model at all.

The editor's form is the original's: tabs "Columns and Indices" (with "Indices", "Foreign Keys", "Column
Details"), "Table Options" and "Advanced Options". Any control for these features changes what the user sees, so
it needs a decision under ADR-0001.

This is stage 2 of the table editor work; stage 1 is ADR-0034 (list contents only), stage 3 is ADR-0036 (the
table model with server dialects).

## Decision

Proposed, not before functional parity:

- Add controls to the existing tabs, keeping their structure:
  - **Column Details:** generated column (expression, `VIRTUAL`/`STORED`), `ON UPDATE`, `INVISIBLE`, column
    CHECK, expression default.
  - **A list of table CHECK constraints**, like the foreign keys list (name, expression); the model gets these
    first.
  - **Functional index parts** in the index columns list.
- A control is shown, enabled or hidden according to what the connected server supports (e.g. `INVISIBLE` on
  MySQL 8.0.23+ and MariaDB 10.3+, expression defaults on MySQL 8.0.13+ and MariaDB 10.2+). These capabilities
  come from the dialect of ADR-0036; until it exists, from the server version.
- Build it on the model of ADR-0036 if that exists by then; otherwise on the C model's existing fields.

Not decided: where each control goes and whether the form grows or gets a new tab; whether unsupported controls
are hidden or disabled; texts and their translations. A mock-up (screenshots via `tools/lfmview`) is to be
reviewed before the implementation, and an amending ADR records the layout.

## Consequences

Positive:

- Tables using the features of today's servers can be created and changed in the editor, not only kept.
- Hiding by capability keeps the editor usable on servers without the feature.

Negative / costs:

- The first deliberate change of an original form; the reference screenshots (ADR-0008) no longer cover it.
- New texts need translations for every shipped language.
- The visible controls differ between servers, which needs testing on the whole matrix per control.

## Alternatives considered

- **Do it now, before parity.** Rejected: ADR-0001; parity first.
- **Never add controls; users write `ALTER TABLE` in the SQL editor.** Possible, but the editor would stay a
  MySQL 5.0 tool on servers people use today.
- **A separate "Extended" dialog instead of controls in the existing tabs.** Not rejected; to compare in the
  mock-up stage.

## Related

- ADR-0001 — no UX changes without an ADR; this ADR proposes one and defers the layout.
- ADR-0034 — stage 1 (list contents).
- ADR-0036 — stage 3, the table model and per-server capabilities these controls depend on.
- ADR-0008 — fidelity by screenshots; the changed form leaves that baseline.
