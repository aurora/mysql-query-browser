# ADR-0016 — Help reference from the connected server

- Status: Proposed (prototype running; supersedes the content plan of ADR-0013 if accepted)
- Date: 2026-10-12
- Deciders: Harald Lapp (project owner)

## Context

ADR-0013 left the reference content open: the shipped pages are a MySQL 5.0 manual extract that is wrong
for 5.7-9 and MariaDB, and that is not GPL licensed (`docs/licenses.md` §4). ADR-0015 describes a second
problem, the MPL-1.1-only IpHtml viewer. The project owner wants to keep the feature (help directly in
the program) but a 5.0-only text makes no sense for a program that targets several servers.

Observation: MySQL and MariaDB servers carry their own reference in `mysql.help_category` and
`mysql.help_topic`, in the version of the server. Checked on the test containers: MySQL 5.7.44 has 660
topics in 50 categories, 8.4.10 has 695 in 53. The content differs accordingly (`ROW_NUMBER` exists in 8.4
only), each topic has syntax, description, examples and a URL of the full documentation page for that
version. The category tree has the same shape as the original's "Syntax" and "Functions" trees (the
original XML was made from the same data). `HELP '<topic>'` returns the same text as a statement.
MariaDB ships the tables too; whether they are filled depends on the installation (not verified here).

## Decision

Proposed:

- The Syntax and Functions trees and the help pane get their content **from the connected server's help
  tables**. Nothing of the reference text is shipped; the 5.0 pages and, if ADR-0015 is decided that way,
  the IpHtml viewer are not needed.
- A small provider seam (`ServerHelp.pas` is the first provider) produces the same group/entry structure
  the original loaded from XML, so the tree code and the double click handler stay as they are. If the
  server has no usable help tables (other RDBMS, empty tables, no rights) the shipped XML index remains
  the fallback until a better one exists; later providers (PostgreSQL: statement list written by us plus
  links to the online manual) follow ADR-0010.
- The topic page is plain text (syntax, description, examples) with a "Full documentation" link to the
  URL stored with the topic, opened in the system browser. In the prototype the page is shown by the
  existing IpHtml pane (`TEmbeddedWB.ShowHtml`); replacing it by a read-only text control (SynEdit with SQL
  highlighting) is the intended final form and is independent of this ADR's decision.
- This is a visible change from the original (new content, text pane instead of HTML pages), accepted as a
  deliberate exception to ADR-0001 because the original content cannot be both correct and licensed for
  this project.

## Consequences

Positive:

- The reference always matches the server version in use, for MySQL 5.7-9 and probably MariaDB.
- No third-party documentation is redistributed; the licence question of ADR-0013 disappears.
- Small code: ~250 lines plus a few lines in `QueryBrowser.pas`; the original trees are reused.

Negative / costs:

- Depends on what the server provides: community builds of some versions carry shortened texts
  or only URLs; content quality varies by vendor and version.
- Reading `mysql.help_*` needs the privilege; the `HELP` statement may be less demanding (not checked).
- The topic text is hard-wrapped plain text (blank lines are lost by IpHtml's `<PRE>`); formatting is
  simple compared with the old HTML.
- No offline reference when not connected (the XML index fallback has names only).

## Alternatives considered

- **Ship a reference pack per server version** (ADR-0013): large content and licence work for every version.
- **Online links only** (ADR-0015 C): no content shipped, but no inline help and needs network.
- **Parse the vendor's HTML manual at build time:** same licence problem as the 5.0 extract.

## Related

- ADR-0001 (exception), ADR-0010 (other RDBMS), ADR-0013 (superseded in part), ADR-0015 (viewer),
  `docs/licenses.md`.
