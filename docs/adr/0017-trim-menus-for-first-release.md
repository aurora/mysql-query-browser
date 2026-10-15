# ADR-0017 — Trim the menus for the first release

- Status: Accepted
- Date: 2026-10-15
- Deciders: Harald Lapp (project owner)

## Context

ADR-0001 freezes the UI of the original Windows program until functional parity. Preparing the first
release shows that a few menu entries of the original no longer make sense in this revival:

- **Tools > MySQL Administrator** and **MySQL Command Line Client** start other products. The
  Administrator is discontinued and not part of this project; the command line client is looked up in
  the registry paths of the old MySQL installers, and its entry passed the password on the command line.
- **Help > Online Docs, Online Docs - C API, Online Docs - PHP API** open `dev.mysql.com/doc/mysql/en/`
  pages of MySQL 4.1/5.0 (and a PHP manual page) inside the help tab. The reference now comes from the
  connected server (ADR-0016) and matches its version.
- **Help > Launch MySQL.com Site** only opens a web site.

## Decision

These entries are removed, together with the separators that only delimited them:

- Tools: `MySQL Administrator`, `MySQL Command Line Client` (and the separator after them).
- Help: `Online Docs`, `Online Docs - C API`, `Online Docs - PHP API`, `Launch MySQL.com Site`
  (and the two separators around that group).

All other entries stay. This is a deliberate exception to ADR-0001.

`app/forms/Main.lfm` is generated, so the removal is done in the converter (`DROP_OBJECTS` in
`tools/dfm2lfm.py`), not by editing the form; `legacy/` is untouched. The handlers, fields and enable
logic in `app/src/Main.pas` are removed with the items.

## Consequences

- Fewer entries that depend on Windows registry lookups, on external programs, or on the network.
- `GetMySQLAdministratorCmd` and `GetMySQLCommandLineClientPath` in `MySQLCommonFuncs.pas` are now
  unused; they can be dropped with `tools/drop_routines.py` in a later cleanup.
- `TQueryBrowserForm.ShowHelpTabSheet(Url)` lost its callers in `Main.pas`.
- Users who want the old behaviour can still reach the manuals through the help pane (ADR-0016) and
  the vendor's site.

## Alternatives considered

- **Keep the entries, disabled:** still shows items that can never work.
- **Edit `Main.lfm` by hand:** the next `convert_forms.py` run would bring the entries back.

## Related

- ADR-0001 (exception), ADR-0016 (help from the server).
