# ADR-0001 — Revive the Query Browser as a fork; the Windows UI is the blueprint

- Status: Accepted
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

MySQL Query Browser was discontinued years ago and replaced by MySQL
Workbench, which has a different UX. Users who liked the original are still
running the last release (1.2.x) on machines that cannot be updated forever:
the bundled client library cannot do `caching_sha2_password` (MySQL 8), and
the build toolchain (Delphi 2006) is no longer obtainable.

The source is GPLv2 (`legacy/*/COPYING`). The repository contains three
separate UIs for the same product, which have drifted apart slightly: the
Windows UI (Delphi 2006 VCL, ~15k lines of own code in the Query Browser plus
~17k in the shared GUI library), a gtkmm UI for Linux (~45k lines) and a Cocoa
UI for macOS (~31k lines). They share a C backend.

The stated goal is that users get the tool *exactly as they knew it*, running
on current platforms against current servers.

## Decision

- Fork the code base. The original sources are kept unmodified under
  `legacy/` as the reference; new code lives next to them (`backend/`,
  `bindings/`, `app/`, `tools/`, `tests/`, `docs/`).
- The **Windows UI is the blueprint** for all platforms. The gtkmm and Cocoa
  UIs are not carried forward.
- **No UX changes in the first milestone.** Layout, menus, shortcuts, icons
  and behaviour stay as they were. Anything that would change them (modern
  icons, HiDPI, new connection options) is a later, separate decision.
- Targets: Windows first, then Linux and macOS from the same code base; MySQL
  5.7 and later plus MariaDB (see ADR-0004).
- The product needs a **new name**: "MySQL" is an Oracle trademark. The
  working name of the repository is `query-browser-revival`; the final name is
  not decided.

## Consequences

Positive:

- One UI code base instead of three; every fix lands on all platforms.
- The Windows UI is the one most users remember, so it is the right
  reference for "exactly as before".
- The GPL permits the fork; keeping `legacy/` untouched gives a stable
  reference to diff against.

Negative / costs:

- Linux and macOS users of the old native UIs lose those UIs; their
  platform-specific behaviour (GTK look and feel, Cocoa integration) is gone
  until the LCL widgetsets provide an acceptable equivalent.
- A rename is unavoidable and breaks recognisability of the name.
- "No UX changes" also means shipping known UX warts (fixed-size dialogs,
  96-dpi bitmaps) until later ADRs address them.

## Alternatives considered

- **Rewrite with a new UX.** Rejected: the explicit requirement is the
  original experience; a rewrite is also far more work than a port.
- **Maintain the three native UIs.** Rejected: three times the work for a
  volunteer-sized project, and the UIs already diverged.
- **Point users to MySQL Workbench or another tool.** Rejected as the premise
  of the project: users have already decided they do not want that.

## Related

- ADR-0002 (how the UI is ported), ADR-0004 (server support).
