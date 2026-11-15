# ADR-0033 — The QueryMole icon replaces the lightning bolt

- Status: Accepted (implemented; Windows not verified; wordmark in the connect header added the same day)
- Date: 2026-11-15
- Deciders: Harald Lapp (project owner)

## Context

ADR-0030 kept the original's application icon, a blue lightning bolt (`MySQLQueryBrowser.ico`), because it shows no
MySQL logo, and used the same bolt as placeholder for the dolphin's picture top right in the main window; the
connect dialog header still showed it next to the word "QueryMole". A QueryMole icon was deferred. The owner has now
supplied one (`assets/querymole-icon.png`, about 304x301, generated with an OpenAI image model like the About
artwork, ADR-0032): the mole with glasses, a database and a magnifier, white and orange on a navy rounded square.

## Decision

The QueryMole icon replaces the bolt everywhere the program or its packages show it. `tools/make_branding.sh`
makes the master square and writes, into `app/images/`:

| File | Used for |
|---|---|
| `querymole.ico` (256, 128, 64, 48, 32, 24, 16) | `MAINICON` of `qbr.exe` (`build_resources.py`): Explorer, task bar, window icon on every platform (the LCL loads `MAINICON`); Velopack `--icon` (`package.sh`) |
| `querymole.png` (256x256) | AppImage icon and `.DirIcon` (`package-appimage.sh`) |
| `sakila.png` (56x54) | the picture top right in the main window: the icon at 48 pixels |
| `connect_header_qb.png` | connect dialog header: the bolt painted over with the gradient left of it, the icon at 50 pixels in its place; on the left the QueryMole wordmark (`assets/querymole-text.png`, background made transparent, 30 pixels high) instead of the word set in Liberation Sans by ADR-0030 (added the same day) |

All sizes are scaled from the one master (the wordmark from its own); there is no hand-drawn small variant. `icotool` and the Liberation Sans font are no
longer needed for the branding or the AppImage.

Not changed: the document icons `QueryFile.ico` and `SQLScriptFile.ico` (a page with a small bolt) are not compiled
into the program and not used by anything; they stay in `legacy/`.

## Consequences

Positive:

- The program has one recognisable mark in all places, its own, and the last piece of the original's branding
  (the bolt) is gone from what the user sees.
- The icon carries sizes up to 256 pixels; the original's stopped at 48 (blurry on HiDPI and in the AppImage).

Negative / costs:

- At 16 pixels the detailed picture is only the orange nose and the database on navy; a simplified small variant
  (e.g. only the head) would read better. Left for later.
- The 256-pixel frame is PNG-compressed inside the `.ico` (the standard since Windows Vista); checked with windres
  and the LCL under Linux, not yet in Windows Explorer.
- Another visible deviation from the original (ADR-0001), like ADR-0030.
- Users of the alphas see a different icon; pinned shortcuts update with the new executable.

## Alternatives considered

- **Keep the bolt as application icon (ADR-0030).** Rejected now that the project has its own icon: the bolt is the
  original's mark and recognisably "MySQL Query Browser".
- **Hand-drawn 16 and 24 pixel variants.** Better, but needs drawing work; can replace the scaled frames later without
  changing anything else.
- **Leave the connect header with the bolt.** Rejected: the header would show the word "QueryMole" next to the
  original's mark.

## Related

- ADR-0030 — the rename; kept the bolt and deferred the logo. This ADR replaces that part.
- ADR-0032 — the QueryMole artwork in the About dialog (same origin, `docs/licenses.md`).
- ADR-0027 — the AppImage, whose icon this changes.
- ADR-0001 — no UX changes without an ADR.
