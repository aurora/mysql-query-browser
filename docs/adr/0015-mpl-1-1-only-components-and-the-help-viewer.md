# ADR-0015 — MPL-1.1-only components and the help viewer

- Status: Proposed; the IpHtml part was resolved by ADR-0016 (viewer removed); the SynEdit part is still open
- Date: 2026-10-12
- Deciders: Harald Lapp (project owner)

## Context

The licence review (`docs/licenses.md`) found two groups of statically linked Pascal units whose
headers grant only the Mozilla Public License 1.1:

1. **IpHtml** (TurboPower Internet Professional: `IpHtml`, `IpFileBroker`, `IpMsg`, `IpStrms`,
   `IpUtils`, `IpAnim`). It is the viewer behind the inline help pane (`app/compat/EmbeddedWB.pas`,
   ADR-0013). Without the help pane nothing else uses it.
2. **Three SynEdit units** in the Lazarus copy: `SynEditHighlighter`, `SynEditHighlighterFoldBase`,
   `SynTextDrawer`. SynEdit is otherwise dual licensed MPL-1.1 / GPL-2.0-or-later and is used under the
   GPL (ADR-0012); these three headers lack the "alternatively GPL" paragraph that the other 29 linked
   units have. The editor cannot work without them.

The FSF classifies MPL-1.1 as a free licence that is **not compatible with the GPL** (MPL-2.0 is). The
program is GPL-2.0-or-later (ADR-0011). Statically linking MPL-1.1-only code into it is therefore, on
the FSF's reading, a combination the GPL cannot cover. Points that weigh the other way: the Lazarus IDE,
which is GPL, ships both components itself, and MPL-1.1's "Larger Work" clause permits combining as long
as the MPL files stay under the MPL with source available (they do, in the Lazarus distribution). Neither
settles the question; for a hobby project distributed with source the practical risk is modest, for a
broader public release it is not something to leave implicit.

This ADR does not decide the legal question. It decides what to do about it.

## Decision

Proposed, to be confirmed by the project owner:

- **Until the first public release:** keep IpHtml and SynEdit as they are; `docs/licenses.md`, `NOTICE`
  and this ADR record the situation. No code change.
- **Before the first public release:**
  - **IpHtml:** do not ship it linked into `qbr.exe` unless the copyright holders (or the Lazarus
    maintainers, who redistribute it) confirm in writing that it may be combined with GPL code. If no
    such confirmation exists, ship the **system-browser variant** (alternative B below): the reference
    pages open in the user's browser; `EmbeddedWB` becomes a small shim that opens the file URL, and
    IpHtml leaves the package list. This is a visible change (ADR-0001) and is recorded as the one
    deliberate exception for licence reasons.
  - **SynEdit's three units:** ask the Lazarus/SynEdit maintainers whether the header omission is
    intended or an oversight (upstream SynEdit carries the dual statement) and ask for the
    header to be restored; there is no technical alternative to these units short of replacing the
    editor (alternative E).
- The switch from IpHtml to the browser variant is a compile-time choice (`{$IFDEF QBR_INLINE_HELP}`
  around the IpHtml-based `TEmbeddedWB`), so the inline pane can come back as soon as the licensing is
  clear, or be kept in builds that are not distributed.

## Consequences

Positive:

- The risk is stated once, with a defined trigger and a defined fallback.
- The fallback (system browser) removes six units, the `TurboPowerIPro` package dependency and the
  help-loading performance work (ADR-0013) at once.
- Development continues unchanged.

Negative / costs:

- The fallback changes the user experience of the help (a separate window instead of the inline pane),
  against ADR-0001, and depends on the system browser rendering local files (it does, including
  `#anchor`).
- The 5.0 reference pages (ADR-0013, `docs/licenses.md` §4) have their own licence problem; the browser
  variant does not remove it. Online links (alternative C) would remove both.
- Contacting maintainers costs time and may get no answer.

## Alternatives considered

- **A. Keep everything, accept the risk.** Cheapest and what other GPL projects using Lazarus do,
  but leaves a known, documented incompatibility in every release. Acceptable for private/development
  use, not recommended as the release position.
- **B. Open help in the system browser (recommended fallback).** Removes the IpHtml question. Costs
  the inline pane.
- **C. Online help pages per server version** (`dev.mysql.com/doc/refman/<ver>`,
  `mariadb.com/kb/...`) in the system browser. Removes IpHtml *and* the shipped manual extract, and
  fixes the outdated 5.0 content (ADR-0013), at the price of needing network access. Combines well with B.
- **D. Ask the IpHtml copyright holders for a GPL-compatible grant (or relicense).** Clean if it
  works; the original company (TurboPower) no longer exists as such and Lazarus contributors hold
  parts, so finding every holder may not be possible.
- **E. Replace the SynEdit units / the editor** (e.g. another editor component). Large effort,
  ADR-0012 would be superseded; only worth it if the maintainers refuse and the risk is judged
  unacceptable.
- **F. Replace IpHtml by another in-process HTML viewer.** Candidates exist in the Lazarus ecosystem
  (e.g. HtmlViewer, a web view wrapper) but none was evaluated for licence or for how it renders these
  pages; a web-view wrapper also brings a platform dependency. Possible later; not a reason to wait.
- **G. Put the IpHtml viewer in a separate helper executable** that shows the page in its own window
  (a separate program, so no linking). Keeps an in-app viewer but not an embedded pane, adds a second
  binary to package and update; offers little over B.
- **H. Render the pages with our own minimal code.** The pages are plain HTML 3.2 (headings,
  paragraphs, lists, `<pre>`, tables). Doable, but it is writing and maintaining an HTML renderer for
  one set of pages; only if B is unacceptable.

## Related

- ADR-0001 (no UX changes; this would be a licence-driven exception), ADR-0011 (GPL-2.0-or-later;
  "or later" is also needed for OpenSSL), ADR-0012 (SynEdit), ADR-0013 (inline help content),
  ADR-0014 (packaging), `docs/licenses.md`.
