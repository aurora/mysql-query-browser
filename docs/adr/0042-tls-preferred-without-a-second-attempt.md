<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0042 — TLS "preferred" in one attempt, without certificate verification

- Status: Accepted
- Date: 2026-11-17
- Deciders: Harald Lapp (project owner)

## Context

ADR-0005 keeps TLS "preferred": MariaDB Connector/C 3.4 verifies the server certificate by default, which makes
TLS mandatory, so `myx_connect_to_instance` connected with that default first and, only after error 2026, connected
a second time with verification switched off.

The first Windows release built by CI (0.1.0-alpha.4, Connector/C 3.4.11 from MSYS2 with OpenSSL) could not connect
to MySQL 8 instances of a cloud provider: "MySQL Error Number 2006, Server has gone away". HeidiSQL connected from the
same machine (without TLS), and QueryMole connected when `MARIADB_TLS_DISABLE_PEER_VERIFICATION=1` was set, i.e. with
verification off in the first attempt. So the second attempt failed: it reuses the `MYSQL` handle of the failed
first attempt. On Windows the first attempt always fails, because the bundled OpenSSL does not know the system's
certificate store, so every connection went through that second attempt. The Linux AppImage was not affected: its
Connector/C 3.2.6 (AlmaLinux 9) does not verify by default.

The verifying first attempt gave no protection: whoever can make it fail (error 2026) gets the unverified second
attempt, as ADR-0005 already notes.

## Decision

- Unless TLS is requested explicitly (the existing advanced option), the connection sets
  `MYSQL_OPT_SSL_VERIFY_SERVER_CERT` off **before** the first and only attempt: TLS when the server offers it, without
  verifying the certificate, otherwise unencrypted. This is the "preferred" mode of ADR-0005 in one attempt, and the
  behaviour of Connector/C before 3.4.
- The second attempt after error 2026 is removed. The original's last attempt without the default schema stays.
- When TLS is requested explicitly, the library default (verification on) stays, as before.

This replaces the mechanism of ADR-0005 (attempt with verification, then without); its decision for "preferred" and
its consequences (downgrade possible, the server is not authenticated) stand.

## Consequences

- Windows connects to servers whose certificates OpenSSL cannot verify, which on Windows is every server.
- One connection attempt instead of two where the fallback used to trigger.
- No change in what is protected: the server's certificate was never effectively checked in the default mode.
- Verifying certificates for real needs a CA store on Windows (the system's, or a bundled one) and a user-visible
  setting; that is a later decision (the "TLS: required / preferred / off" option of ADR-0005).

## Alternatives

- **Keep the second attempt with a fresh handle** (close and initialise the `MYSQL` structure again). Two attempts
  and more code for the same result.
- **Give OpenSSL the Windows certificate store** so that the first attempt succeeds. Needed for real verification,
  but servers with self-signed certificates (the default of MySQL 8) would still fail and need the fallback.

## Related

ADR-0005, ADR-0040.
