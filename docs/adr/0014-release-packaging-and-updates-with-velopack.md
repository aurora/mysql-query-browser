# ADR-0014 — Release packaging and updates with Velopack

- Status: Proposed (packaging implemented; update check and feed open)
- Date: 2026-10-11
- Deciders: Harald Lapp (project owner)

## Context

The application runs from `app/bin` with the backend DLLs found through `PATH`. A
release needs a self-contained folder, an installer, and a way to update. The project
owner is developing a Free Pascal library that makes Velopack (installer and update
framework with Windows, Linux and macOS support, one CLI `vpk`) usable from Pascal,
and suggested it for install and update.

What a package has to contain, found by running the staged program with a minimal
`PATH`: `qbr.exe`, the four backend DLLs, the MSYS2 DLLs they need (glib, libxml2,
libmariadb with libcurl, OpenSSL, pcre, zlib, ...), `XML/`, `doc/`, `fonts/`,
`locale/`. Pitfall: `ldd` and the Windows loader resolve some names to
`C:\Windows\System32` first (other software leaves OpenSSL copies there), so the
package script copies by name from MSYS2; a clean machine has no such copies.

User data lives outside the program folder (`%APPDATA%\MySQL\`), which is what an
update model that replaces the program folder needs.

## Decision

- `tools/package.sh` builds the package: staged folder `dist/app` (debug info stripped,
  12 MB instead of 65 MB; the unstripped build stays in `app/bin` for stack traces),
  a portable zip, and with `--velopack` the Velopack release (`Setup.exe`, full
  package, `RELEASES`) via `vpk pack`.
- The version comes from the `VERSION` file and is written into the executable's
  version resource together with the icon (`tools/build_resources.py`, from the
  original icon file).
- Velopack is the installer/update mechanism for Windows; the Linux and macOS builds
  will use the same tool when those ports exist. Velopack's update client is not
  linked yet: it needs the Pascal binding being developed separately, and a decision
  where the update feed is hosted. Until then updates are installs of newer
  `Setup.exe` files.

## Consequences

Positive:

- A one-command release for Windows; the package starts with a minimal `PATH` and connects
  (including TLS).
- The same mechanism can be reused for the other platforms.

Negative / costs:

- The package is 14 MB zipped (21 MB setup) mostly because of the MSYS2 DLL chain; trimming
  needs the backend to stop depending on libcurl/glib (ADR-0003 transitional layer).
- The shipped DLLs carry their own licences; `THIRD-PARTY-DLLS.txt` lists them but is not
  a licence review. Needed before a public release.
- No code signing: Windows SmartScreen will warn on the installer.
- The product name in the version resource is still "MySQL Query Browser" (open naming
  question, `ROADMAP.md`).

## Alternatives considered

- **Inno Setup / WiX.** Familiar installer tools; no update mechanism and no cross-platform
  story. Rejected in favour of Velopack, which the owner is already building tooling for.
- **Portable zip only.** Implemented as a by-product; no shortcuts or updates.

## Related

- ADR-0003 (backend DLLs), ADR-0011 (licence), `ROADMAP.md` (name decision, copyright holder).
