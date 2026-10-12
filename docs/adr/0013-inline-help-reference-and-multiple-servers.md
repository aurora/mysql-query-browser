# ADR-0013 — Inline help (reference) with several servers and versions

- Status: Superseded in part by ADR-0016 (content now comes from the server; the IpHtml viewer was removed)
- Date: 2026-10-11
- Deciders: Harald Lapp (project owner)

## Context

The Query Browser has an inline reference: the "Syntax" and "Functions" tabs on the
right list statements and functions (from `XML/mysqlqb_statements.xml` and
`XML/mysqlqb_functions.xml`); a double click opens the matching section of
`doc/mysqlqb_statements.html` or `doc/mysqlqb_functions.html` in an embedded
browser. The shipped pages are an extract of the **MySQL 5.0.0-alpha reference
manual**.

Two separate problems:

1. **Technical.** The original embedded Internet Explorer (`TEmbeddedWB`). The LCL
   has no web browser control. Solved in the port: `app/compat/EmbeddedWB.pas`
   is now a thin wrapper around `TIpHtmlPanel` (Lazarus' TurboPower Internet
   Professional, `IpHtml`), which renders the plain HTML 3.2-style pages and
   follows `#anchor` links. The pages and the quirks of IpHtml (limited CSS, no
   scripting) are acceptable for these documents.
2. **Content.** The project targets MySQL 5.7-9 and MariaDB (ADR-0004). A 5.0
   reference is wrong or silent for much of it: functions and statements added
   since 5.0 are missing (window functions, CTEs, JSON, `GRANT`/`CREATE USER`
   changes, ...), removed features are still described, and MariaDB differs from
   MySQL in syntax and functions. Rewriting or generating up-to-date text per
   server is a large content task, not a porting task, and has licensing
   questions: the MySQL manual is not under a free licence that allows us to
   redistribute modified extracts (to be checked before any use); the MariaDB
   Knowledge Base is published under a Creative Commons licence (to be verified,
   with attribution requirements).

## Decision

- For functional parity the shipped 5.0 pages stay as they are (ADR-0001), shown
  through the IpHtml-based `TEmbeddedWB`. They are labelled as a MySQL 5.0 reference
  when this is made visible in the UI (a UX change, so only after parity).
- The reference is treated as **data selected by the connected server**, not as
  code: statement/function index XML plus HTML pages in a folder per "reference
  pack" (e.g. `doc/mysql-5.0`, later `doc/mariadb-11`). The code that opens a
  help page asks a small seam for the pack of the current connection and falls
  back to the 5.0 pack. The seam is introduced together with the first
  additional pack, not before.
- Further packs are decided one at a time, each after a licence review. The
  alternative that avoids redistribution is a pack that only holds the index and
  opens the vendor's online page (`dev.mysql.com/doc/refman/<version>/en/...`,
  `mariadb.com/kb/en/...`) in the system browser.

## Consequences

Positive:

- Help works again with no UX change and no new runtime dependency beyond a
  Lazarus package.
- The pack seam keeps the later multi-vendor story (ADR-0010) possible without
  committing to content we cannot license.

Negative / costs:

- Until a pack for the connected server exists, users of 8.x/9/MariaDB see 5.0
  text, partly misleading (the main reason this ADR exists).
- IpHtml renders the old pages acceptably but not like a modern browser; newer,
  CSS-heavy pages would not render well in it, which also pushes towards the
  "open online page in the system browser" variant for new packs.
- Index XML and HTML are tied by anchors; a new pack needs both generated
  consistently.

## Alternatives considered

- **Embed a full browser engine (CEF/WebView2/WebKit).** Faithful for any web
  content, but heavy, platform-specific and a large dependency for a pane that
  shows static pages. Rejected for now.
- **Drop the inline help.** Removes a signature feature; against ADR-0001.
- **Only online links.** Always current and no licence issue, but needs network
  and is a visible change from the inline pane; kept as the fallback for new
  packs.

## Related

- ADR-0001 (no UX changes before parity), ADR-0004 (supported servers), ADR-0007
  (replacement of third-party libraries), ADR-0010 (other RDBMS).
