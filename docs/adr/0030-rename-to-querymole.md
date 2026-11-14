# ADR-0030 — Rename the application to QueryMole before the public announcement

- Status: Accepted (implemented; QueryMole icon and busy animation open; About picture replaced by ADR-0032)
- Date: 2026-11-14
- Deciders: Harald Lapp (project owner)

## Context

The program is still called "MySQL Query Browser" (window title, `Application.Title`, About dialog, AppImage
`qbr.desktop`, README). "MySQL" is a trademark of Oracle; the project is not affiliated with it, and ADR-0001
already said that a new name is unavoidable. The working title "QueryMole" has been in use since ADR-0019 and
ADR-0025, which planned the rename for *after* the first release and wrote down two consequences for that case:
keep the Velopack package id `QueryBrowserRevival` (ADR-0025), and decide the user data folder with the rename
(ADR-0019).

What changed:

- The project is about to be announced publicly (a LinkedIn post). A rename after the announcement costs links,
  recognition and possibly installations; before it, almost nothing.
- The plans after parity (Qt, ADR-0024; PostgreSQL, ADR-0010) make "MySQL" in the name wrong on its own, apart
  from the trademark.
- No Velopack package has been published: the alpha ships as a portable zip and an AppImage without an update
  mechanism (ADR-0026). The reason for keeping the package id (installed versions must be able to update) does not
  apply yet.
- The name was checked by the owner on 2026-11-14: no application of that name was found, and no mark in the
  DPMA or EUIPO registers. This is not a legal clearance.

Alpha builds tagged `v0.1.0-alpha.1` and `v0.1.0-alpha.2` exist under the old name; they stay as they are.

## Decision

- **Name.** The application is called **QueryMole**. Every place where the product names itself uses it: window
  and application title, About dialog caption, splash, AppImage `.desktop` entry and file name, release archives,
  `--packTitle`, README and the other current documentation. The GitHub repository is renamed accordingly (GitHub
  redirects the old address); `UpdateRepositoryUrl` follows.
- **Origin and credits** (exception to ADR-0001, like ADR-0017 and ADR-0026). The About dialog keeps the
  original's copyright line and credits unchanged (GPLv2 §2(c) asks interactive programs to show the copyright
  notice), says "based on MySQL Query Browser 1.2.4 beta" in the version line, and ends the licence note with "Not
  affiliated with Oracle." (the label has room for no more); README and `NOTICE` carry the full trademark note. File headers, `NOTICE` and `legacy/` are not touched (AGENTS.md).
- **Package id.** The Velopack package id becomes `QueryMole` (`tools/package.sh`). This supersedes ADR-0025, which
  is only sound once a Velopack package has been released; from the first such release on, ADR-0025's rule (the id
  never changes again) applies to the new id.
- **User data folder** (supersedes ADR-0019 in part):

  | Platform | New folder | Imported from |
  |---|---|---|
  | Windows | `%APPDATA%\QueryMole\` | `%APPDATA%\MySQL\` |
  | macOS | `~/Library/Application Support/QueryMole/` | `~/Library/Application Support/MySQL/` |
  | Linux | `$XDG_CONFIG_HOME/querymole/` (default `~/.config/querymole/`) | `~/.mysqlgui/` |

  On start, if the new folder does not exist and the old one does, the Query Browser's files (`mysqlqb_*.xml`,
  `mysqlx_common_options.xml`, `mysqlx_user_connections.xml`) are **copied** once. The old folder is only read, never
  changed or deleted, so an installed original (or MySQL Workbench/Administrator, which share `%APPDATA%\MySQL\`)
  keeps working. `-datadir` still overrides the folder and skips the import. File names and formats stay as they
  are.
- **Logo.** The MySQL logo (wordmark and dolphin) is trademark material and goes. Where it appears:
  - the About/splash picture (`about`, `about.png`) and the header of the connect dialog
    (`connection_dialog_header`, `connect_header_qb.png`): the logo and the words "MySQL Query Browser" are
    removed and "QueryMole" is set in their place; gradient and lightning bolt stay (`tools/make_branding.sh`
    writes `app/images/`, `tools/build_resources.py` uses those files instead of the originals);
  - the dolphin's still picture top right in the main window (`sakila`; overlooked at first, added the same day):
    replaced by the lightning bolt of the application icon on a transparent background;
  - the busy animation (`dolphin_loop`, an AVI) and `mysql_logo`: left out of the resources. `TAnimate` does not
    play animations yet, so nothing visible is lost; a neutral animation comes with it.

  The application icon (`MySQLQueryBrowser.ico`, a lightning bolt) shows no MySQL logo and stays for now.
  A QueryMole logo and icon are a later, separate piece of work.
- **What does not change:** unit, type and routine names of the ported code (ADR-0006), the `mysqlqb_`/`mysqlx_`
  file names, the lookup of an installed original in the registry (`GetMySQLQueryBrowserCmd`), the texts of
  existing ADRs and release notes, the tags of the old alphas.
- **Deferred:** the executable name (`qbr`/`qbr.exe`) and the final logo.

## Consequences

Positive:

- The project is announced under the name it will keep; no second rename, no "name follows" notice.
- The trademark question is settled before the project becomes visible, and the name no longer ties it to one
  database.
- Settings of the original and of the alphas are found on first start without touching the original's folder.
- Linux gets an XDG location instead of a dotfile in the home directory (a cost listed in ADR-0019).

Negative / costs:

- Visible changes against the original (title, About dialog, icon, busy animation), which ADR-0001 otherwise
  forbids; listed here as the exception.
- Recognisability: people looking for "MySQL Query Browser" have to find the project through its description.
- New code for the import (one routine at start, tests for: new folder exists, old exists, neither, `-datadir`).
- After the import the two folders diverge: changes made in the original are no longer seen, and vice versa.
- Neutral placeholders look worse than the dolphin until a logo exists.
- Testers of the alphas see a different folder; their settings are imported, but two copies exist from then on.
- The name check is the owner's search, not a legal opinion.

## Alternatives considered

- **Rename after the announcement, as ADR-0025 planned.** Rejected: the cost of a rename grows with every link and
  download, and the announcement is the point of largest visibility.
- **Keep the package id `QueryBrowserRevival` (ADR-0025).** Rejected while no Velopack package exists: it would keep
  the old working name in the install folder for good, for a benefit (seamless updates of installed versions) that
  no user can have yet.
- **Keep the original's data folders (ADR-0019).** Simplest, and settings stay shared with an installed original.
  Rejected: the folder is named after another vendor's product, shared with Workbench/Administrator, and a dotfile on
  Linux; the copy keeps the "found as it is" property for the first start.
- **Move instead of copy the old files.** Rejected: an installed original would lose its connections.
- **Wait for a QueryMole logo before renaming.** Rejected: the logo is not on the critical path; placeholders remove
  the trademark material now.
- **Keep the name, add a disclaimer.** Rejected: the disclaimer stays (About, README), but it does not solve the
  name containing the trademark, nor the PostgreSQL plan.

## Related

- ADR-0001 — "the product needs a new name"; no UX changes without an ADR (this is an exception).
- ADR-0019 — user data folder; superseded in part (folder and import) by this ADR.
- ADR-0025 — package id kept on rename; superseded by this ADR.
- ADR-0026 — the alpha without updater, the About dialog's credits.
- ADR-0010, ADR-0024 — PostgreSQL and Qt, the plans the name has to fit.
- ADR-0017 — another deliberate deviation from the original.
