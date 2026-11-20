<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0047 — Functional parity is reached; new features follow, each with its own decision

- Status: Accepted
- Date: 2026-11-20
- Deciders: Harald Lapp (project owner)

## Context

ADR-0001 made the original Windows Query Browser the blueprint and ruled out UX changes "in the first milestone":
first the original, unchanged, on current platforms and servers; anything else later, by separate decision. Several
ADRs wait for that point: HiDPI and vector icons (ADR-0009), other databases (ADR-0010), the TLS option in the
connection dialog (ADR-0005), the table editor stages 2 and 3 (ADR-0035, ADR-0036), and the "Product" list of the
ROADMAP. Users now ask for features the original never had; the first is an SSH tunnel for connections (with
OpenSSH and PuTTY keys).

Where the port stands at 0.1.0-alpha.7:

- Every function of the original Query Browser has been ported and runs on Windows and on Linux (Qt6): connect
  dialog and stored connections, schema tree, SQL editor, result grid with editing, several result tabs, EXPLAIN,
  scripts with breakpoints, the five exporters, help from the server, table editor, options, text search, RegEx
  importer. Menus without a product behind them were removed on purpose (ADR-0017).
- Every push is built for both platforms and tested against MySQL 5.7, 8.0, 8.4, 9 and MariaDB 10.11, 11.4
  (ADR-0046); releases update themselves (ADR-0037).
- Open are checks and fidelity work, not missing functions: real mouse and keyboard use, drag and drop, bookmarks,
  history and the field viewer have not been worked through on every platform; reference screenshots of the
  original for a side-by-side review are missing (ADR-0008); a few things the form conversion drops are not rebuilt
  yet (connect animation, menu owner draw; ROADMAP "Fidelity"); macOS is deferred (ADR-0039).

Waiting until every one of these is closed would hold features back for items that may never close (the reference
screenshots depend on someone who still runs the original), while those items do not need the feature freeze to
get done.

## Decision

- **The first milestone of ADR-0001 is reached** (functional parity, at alpha quality, on Windows and Linux) with
  0.1.0-alpha.7. The open checks and fidelity items stay on the ROADMAP and continue; a place where the port behaves
  differently from the original is a bug and is fixed without an ADR.
- **The blueprint stays.** The original's screens, texts, shortcuts and behaviour remain the reference; nothing is
  restyled or rearranged for its own sake.
- **New features are allowed under these rules:**
  1. **One ADR per feature** (or per visible change), written before it is built, with a mock-up or screenshot when
     it adds or changes UI. It says where the feature appears and what the user sees when not using it.
  2. **Additive and off by default.** Someone who does not use a feature sees the original screens and gets the
     original behaviour; existing controls keep their place, text and shortcuts. New controls follow the original's
     style (fonts, spacing, wording, dialog layout) and sit where the original would have put them.
  3. **Stored data stays compatible.** Connection profiles and option files gain fields; they do not change or drop
     existing ones, and a file written by a new release can still be read by the release before it (the fields it
     does not know are ignored).
  4. **Tested like the rest.** A feature that talks to a server or another service gets tests in `tests/` that run
     on the matrix; if it needs more infrastructure (an SSH server, say), `tests/ci.sh` provides it.
  5. **New texts are marked for translation** like the original's (gettext); until a translation exists they show
     in English.
  6. **New libraries** pass the licence check of `docs/licenses.md` and go into `NOTICE` and the packages of both
     platforms.
- The owner picks the order. The first candidates are the connection options: an SSH tunnel and the TLS mode in the
  connection dialog (ADR-0005), both in the same part of the dialog.

## Consequences

Positive:
- Features users ask for (SSH tunnel first) can start now, each with a reviewable decision, without giving up the
  "as you knew it" promise for those who want just that.
- The deferred ADRs (0009, 0010, 0035, 0036, the TLS option of 0005) have a defined way forward.
- The rules give contributors a test for a proposal: is it additive, off by default, in the original's style, and
  does it keep old files readable?

Negative:
- Each feature moves the program away from the original, even when off by default: more code paths, more dialog
  area, more to test on every server and platform.
- Feature work competes with the open checks and fidelity items for the same time; those can slip further.
- New texts are English-only in the localised versions until someone translates them.
- "Parity" is declared with checks still open: a missing piece of the original found later is fixed as a bug, but
  it was not caught before features were added.
- Keeping files readable by the previous release limits how stored settings can be reorganised.

## Alternatives considered

- **Keep the freeze until every check and fidelity item is closed.** Rejected: some items depend on outside help
  (reference screenshots) and may never close; the freeze would block features without making those items happen
  sooner.
- **Drop the blueprint and allow free UX changes after parity.** Rejected: the original experience is the reason
  the project exists (ADR-0001); users who want a different tool have Workbench and others.
- **Features only in a separate edition or as plugins.** Rejected: two editions double packaging and testing, and a
  plugin interface is a large design of its own; "off by default" gives the same protection to users who want the
  original.

## Related

- ADR-0001 — the blueprint and the first milestone; its milestone is completed by this ADR, the blueprint principle
  stays.
- ADR-0005 (TLS option in the dialog), ADR-0009 (HiDPI, icons), ADR-0010 (other databases), ADR-0035 and ADR-0036
  (table editor stages): deferred until after parity, now possible under these rules.
- ADR-0008 — fidelity review by screenshots; continues.
- ADR-0017 — menus trimmed for the first release; not a feature in the sense of this ADR.
- ADR-0046 — the test workflow that rule 4 relies on.
