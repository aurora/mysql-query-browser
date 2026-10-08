# ADR-0011 — License: GPL-2.0-or-later, as the original

- Status: Accepted
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

The original MySQL Query Browser is released under the GNU GPL version 2 (the
`COPYING` file in both `legacy/mysql-gui-common/` and
`legacy/mysql-query-browser/` is the June 1991 text). A scan of the file
headers shows 410 files with a GPL notice, 384 of them "either version 2 of
the License, or (at your option) any later version". The ones that say "version
2" without "or later" are not in code this project uses: in `backend/src` (59
GPL-headed files), the Delphi sources of the shared GUI library (24) and of the
Query Browser (4) every GPL notice includes "or later". Many source files have
no notice at all and are covered by the repository's `COPYING`.

Third-party code in `legacy/` has its own terms (e.g. the TNT Unicode Controls'
"retain the copyright" licence, VirtualTreeView, UniCodeEditor); it is not
copied into the new code base (ADR-0007).

## Decision

- The project is licensed **GPL-2.0-or-later**. `LICENSE` is the plain GPLv2 text.
- The original `COPYING` ends with a "special exception" by MySQL AB that
  permits linking with PCRE. It is preserved word for word in `NOTICE`, together
  with the third-party list; it belongs to the original grant and is not
  extended to new code (PCRE is BSD licensed, so linking does not depend on it).
- New files carry the one-line header
  `SPDX-License-Identifier: GPL-2.0-or-later` in the file's comment syntax.
  Ported files keep their original header (including the "(C) MySQL AB"
  notice) and are not rewritten. Generated files get the SPDX line from the
  generator.
- Dependencies are used under their own licences: Lazarus LCL (LGPL with
  static-linking exception), VirtualTreeView and SynEdit (dual licences that
  include LGPL/GPL options), MariaDB Connector/C (LGPL), glib (LGPL), libxml2
  (MIT), PCRE (BSD). To be re-checked when a distributable is built.

Not decided: the copyright holder line for new files (the SPDX line carries no
holder) and how contributions are accepted (DCO or similar).

## Consequences

Positive:

- Same licence as the original: no relicensing question, no permission needed
  from former copyright holders; "or later" keeps GPLv3 combinations possible.
- A single machine-readable licence marker per file.

Negative / costs:

- Copyleft: distributed binaries must offer their source, and the project
  cannot incorporate code under GPL-incompatible licences (for instance
  MPL-only components without a GPL option).
- A name change (ADR-0001) does not change the licence obligations; "MySQL"
  trademark use is a separate issue.
- This record is not legal advice; a distribution should be reviewed once the
  dependency set is final.

## Alternatives considered

- **GPL-2.0-only.** Rejected: needlessly narrower than what the original
  grants.
- **GPL-3.0-or-later for new code.** Legally possible, because the inherited
  code is "version 2 or later". Not chosen: it would exclude GPL-2.0-only
  combinations, differ from the original for no present benefit, and anyone
  downstream can still pick version 3 from "or later".
- **LGPL or a permissive licence.** Not available: the new code is derived from
  GPL code.

## Related

- ADR-0001 (fork), ADR-0007 (third-party code is replaced, not copied).
