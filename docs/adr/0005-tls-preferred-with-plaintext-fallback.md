# ADR-0005 — TLS "preferred" with fallback to an unencrypted connection

- Status: Accepted (default); UI option deferred
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

MariaDB Connector/C >= 3.4 verifies the server certificate by default
(`MYSQL_OPT_SSL_VERIFY_SERVER_CERT`), which makes TLS mandatory: connecting to
a server that offers no TLS fails with `SSL is required, but the server does
not support it` (error 2026). This broke the matrix test against MariaDB
10.11 in its default container. Measured behaviour (`SHOW SESSION STATUS LIKE
'Ssl_cipher'`):

- `MYSQL_OPT_SSL_ENFORCE = 0` has no effect on this.
- Turning verification off lets the connection succeed, but then **no
  encryption is used at all**, also against servers that offer TLS (empty
  `Ssl_cipher` on MySQL 5.7, 8.4 and MariaDB 10.11).

The original Query Browser used TLS only when the user asked for it via the
advanced connection options. Modern clients default to a "preferred" mode.

## Decision

- Connect with the library default first (TLS). **Only if that fails with
  error 2026**, retry the same connection with certificate verification
  switched off, i.e. unencrypted. Implemented in `myx_connect_to_instance`
  (`backend/src/base-library/source/myx_library.c`).
- The existing advanced option that requests TLS keeps its meaning; when it is
  set, no fallback happens.
- No user-visible setting is added now, because that would be a UI change
  (ADR-0001). A "TLS: required / preferred / off" choice is a candidate for a
  later UI decision.

## Consequences

Positive:

- Servers with TLS are still reached encrypted; servers without TLS (old
  MariaDB, MySQL 5.x without certificates) keep working like in the original.
- No UX change.

Negative / costs:

- **Downgrade is possible:** an attacker who can make the TLS handshake fail
  with error 2026 gets a plaintext connection, including the password hash
  exchange. The original had the same exposure (it never used TLS unless
  asked), but "preferred" mode does not give the protection a user might
  assume.
- The default attempt connected to servers with auto-generated self-signed
  certificates, so the effective strength of certificate verification on that
  path was **not examined**; it should not be assumed to authenticate the
  server.
- Two connection attempts when the fallback triggers (a few ms on a LAN).

## Alternatives considered

- **Require TLS.** Rejected as a default: breaks every server without
  certificates, which includes many development servers.
- **Disable verification globally.** Rejected: silently turns encryption off
  everywhere (measured above).
- **Make it a setting in the connection dialog.** Deferred: UI change; see
  ADR-0001 and ADR-0009 for the process.

## Related

- ADR-0004 (client library), ADR-0001 (no UX change in the first milestone).
