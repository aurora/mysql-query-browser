# ADR-0025 — Keep the Velopack package id and the update feed when the application is renamed

- Status: Accepted (principle); the behaviour of Velopack on a changed title and executable name is not verified
- Date: 2026-11-02
- Deciders: Harald Lapp (project owner)

## Context

The application is to be renamed (working title "QueryMole") after the first release of the revival. Releases
are installed and updated with Velopack (ADR-0014, ADR-0018). An installed version looks for updates at a fixed
address: the GitHub releases of the repository named in `UpdateRepositoryUrl` (`app/src/UpdateCheck.pas`). The
package is built with `--packId QueryBrowserRevival --packTitle "Query Browser" --mainExe qbr.exe`
(`tools/package.sh`).

As far as is known (Velopack documentation and behaviour, not tested in this project) the package id
identifies the application for the updater and names the install location, while the title (shown to the
user, used for shortcuts) and the executable name are properties of each package that may change between
versions.

## Decision

- The package id stays `QueryBrowserRevival` for the lifetime of the product, also after the rename. It is not
  shown to users and contains no product name that would have to change.
- The renamed application is delivered as a normal update of the installed one: a new version with the new
  `--packTitle` (and, if wanted, `--mainExe`), published in the same feed.
- The update feed stays reachable for installed versions: the GitHub repository may be renamed (GitHub redirects
  the old address), but no new repository replaces it. `UpdateRepositoryUrl` of already released versions is
  never relied on to change.
- Before the rename is released, an installation of the last old version is updated to a test build with the
  new title and executable name, and shortcuts, the start menu entry, the data folder and the next update are
  checked. If Velopack does not handle the renamed executable, the executable name stays and only the title changes.
- The user data folder is a separate question (ADR-0019): a rename of the folder comes with an import of the old
  one, decided then.

## Consequences

Positive:
- Users of the first release get the renamed application through their normal update; nothing to reinstall.
- The choice is made before the first public package exists, while it is still free.

Negative:
- The install folder and internal identifiers keep the old working name (`QueryBrowserRevival`) for good.
- The feed ties the project to GitHub's redirect for a renamed repository; moving the feed elsewhere would
  need a last release that points the old address to the new one.
- The behaviour on a renamed executable is an assumption until the test update has been done.

## Alternatives considered

- **New package id with the new name:** cleaner names, but installed versions cannot update to it; users would
  have to install again, and the data folder would have to be found again.
- **Keep title and executable name too:** no risk with Velopack, but the product would keep a name it is meant to
  lose (ADR-0001 only forbids UX changes until parity, not renaming afterwards).

## Related

- ADR-0014 — packaging and updates with Velopack.
- ADR-0018 — the update check and the GitHub feed.
- ADR-0019 — the user data folder and its deferred rename.
