# ADR-0021 — No "OS Specific" password storage outside Windows (for now)

- Status: Accepted (implemented on Linux, built and checked)
- Date: 2026-10-31
- Deciders: Harald Lapp (project owner)

## Context

The connection list can store passwords as `Plaintext`, `Obscured` or `OS Specific`
(`MYX_PASSWORD_OS_SPECIFIC`). On Windows the backend implements the last with DPAPI
(`win_store_password` in `myx_xml_user_connections.c`). Elsewhere the backend calls the hooks
`os_password_store_function` / `os_password_retrieve_function`, which the original Linux UI filled with
GNOME Keyring through `set_os_specific_password_functions`. The port never sets them.

`Options.TMyxOptions.Create` offers the choice when `IsWinNT` is False (it is True only on Windows NT 4,
where DPAPI does not exist), and `IsWinNT` answers False outside Windows. A Linux build would therefore
offer "OS Specific", and without hooks the backend falls through to `xmlStrdup(password)`: the password
is written in clear text under a name that promises protection.

## Decision

- Outside Windows the list of storage types is `Plaintext` and `Obscured` only. The Windows list is
  unchanged. This is a deliberate deviation from ADR-0001: a choice that does not do what it says is
  not shown.
- An OS-specific store for Linux (libsecret / the Secret Service) and macOS (Keychain) is deferred; it
  would fill the backend hooks and bring the choice back on that platform. It gets an ADR when someone
  needs it.

## Consequences

Positive:
- No silent clear text behind a protective-sounding option.
- No code in the backend; the Windows build does not change.

Negative:
- Linux and macOS users have only two choices, and `Obscured` is not encryption (the hex-encoded,
  XOR-style `obscure()` of the original).
- A `mysqlx_user_connections.xml` written elsewhere with type "OS Specific" (Windows, or the old Linux
  version with GNOME Keyring) is read, but the stored value is not a password here: connecting with it
  fails and the user types the password again. The options page shows no entry for the saved type until
  another one is chosen.

## Alternatives considered

- **Implement libsecret now:** a new dependency on every Linux system and a second platform path to test
  (no desktop session in the container); nobody has asked for it.
- **Keep showing the choice:** stores clear text, see Context.
- **Map type 4 to `Obscured` on read:** hides the problem for files written elsewhere, but the value
  cannot be decoded either way.

## Related

- ADR-0001 — no UX changes; this is a listed exception.
- ADR-0019 — the data folder is shared with the original, which is how a type-4 file can appear.
- `docs/linux-port.md`, section 4.4.
