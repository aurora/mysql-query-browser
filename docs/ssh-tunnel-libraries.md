<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# SSH tunnel: libssh or libssh2

Working notes for the SSH tunnel feature (the first feature under ADR-0047), gathered on 2026-11-20 as input for
its ADR. The tunnel is meant to run inside the program: a thread accepts connections on a local port and forwards
them through SSH to the database server; Connector/C connects to that local port as before.

## Comparison

| | libssh | libssh2 |
|---|---|---|
| Licence | LGPL-2.1-or-later (fine with GPL-2.0-or-later) | BSD-3-Clause |
| Fedora 44 (development, CI) | 0.12.2 | 1.11.1 |
| AlmaLinux 9 (AppImage build) | 0.10.4 in BaseOS/AppStream | not in the base repositories (EPEL), or built ourselves |
| MSYS2 mingw64 (Windows build) | `mingw-w64-x86_64-libssh` 0.12.0 | `mingw-w64-x86_64-libssh2` (curl uses it) |
| Agent on Linux (`SSH_AUTH_SOCK`) | yes | yes |
| Windows OpenSSH agent (named pipe) | yes, default `\\.\pipe\openssh-ssh-agent` | yes, same pipe |
| **PuTTY Pageant** | **no**; but `ssh_set_agent_socket()` / `ssh_set_agent_channel()` let the program supply the agent connection, so a small Pageant bridge is possible | **yes** (WM_COPYDATA, tried before the OpenSSH pipe) |
| **PuTTY `.ppk` keys** | no | no |
| OpenSSH key files (new format, Ed25519, ECDSA, RSA) | yes | yes (depends on the crypto backend) |
| `~/.ssh/config` (Host aliases, User, Port, IdentityFile) | yes, `ssh_options_parse_config` | no |
| ProxyJump (jump host) | yes, `SSH_OPTIONS_PROXYJUMP` (version to check, see below) | no; would be our own code (a second session through a channel) |
| `known_hosts` check | `ssh_session_is_known_server`, `ssh_session_update_known_hosts`: reads and writes the OpenSSH file | `libssh2_knownhost_*`: lower level, file handling and the decision logic are ours |
| Local port forwarding | `ssh_channel_open_forward`; the local listener and copying are ours | `libssh2_channel_direct_tcpip_ex`; the same |

Both need our own code for the listening socket and for copying data between it and the channel. Neither reads
`.ppk` files: a reader for PuTTY's format is our own code either way (format 2: SHA-1 and AES-256-CBC for encrypted
keys; format 3, PuTTY 0.75 and later: Argon2 for the passphrase), handing the key to the library in OpenSSH form
in memory. PuTTY itself recommends converting with `puttygen` (`-O private-openssh`), which the dialog can mention.

## Assessment

- **libssh** does more of the security-relevant and convenience work: host key checking against the user's own
  `known_hosts`, the user's `~/.ssh/config` and jump hosts behave as with the `ssh` command. It is in the base
  repositories of the AppImage build. Missing is Pageant; its agent socket hook allows a bridge (a thread that
  passes agent requests from a local socket pair to Pageant by WM_COPYDATA, Windows only, about the size of
  libssh2's Pageant code).
- **libssh2** has Pageant built in and a permissive licence, but leaves host key policy, config files and jump
  hosts to us, and the AppImage build would have to build or fetch it.

Recommendation: **libssh**, with a Pageant bridge on Windows and our own `.ppk` reader. If Pageant support out of
the box matters more than config files and jump hosts, libssh2 is the alternative.

Decision: libssh (ADR-0048, 2026-11-20).

## Checked after the comparison

- AlmaLinux 9's libssh 0.10.4 has `ssh_options_parse_config`, `SSH_OPTIONS_IDENTITY_AGENT`, the known-hosts
  functions, `ssh_set_agent_socket` and `ssh_channel_open_forward` (its header, 2026-11-20). ProxyJump is
  implemented by libssh itself only from 0.11.0 (CHANGELOG: "Implemented proxy jump using libssh"); 0.10 builds a
  ProxyCommand around the `ssh` program. IdentityAgent came with 0.10.0.
- Pageant 0.75 and later listens on a named pipe that the Windows OpenSSH client uses directly (PuTTY manual,
  section 9.3.3), so libssh's pipe client should reach it given the pipe name; `pageant --openssh-config` writes a
  configuration line telling `ssh.exe` where Pageant is. The pipe name's construction could not be read from the
  PuTTY source here (its git host refused the request).

## Still to check

- Pageant's pipe name construction (PuTTY `windows/utils/agent_named_pipe_name.c`) and a test on Windows.
- Which crypto backend the MSYS2 and AlmaLinux packages use (OpenSSL is already in both packages for Connector/C).
- Argon2 for `.ppk` format 3: OpenSSL 3.2 and later has an Argon2 KDF (AlmaLinux 9 has 3.5); otherwise a small
  implementation or libargon2.
- Tests: an OpenSSH server container next to the database containers in `tests/run-matrix.sh`, with key, password
  and jump host cases.

## Sources

- libssh agent code (Windows pipe, agent socket and channel hooks, no Pageant):
  <https://github.com/libssh/libssh-mirror/blob/master/src/agent.c>; header with `ssh_options_parse_config`,
  `SSH_OPTIONS_PROXYJUMP`, the known-hosts functions and `ssh_channel_open_forward`:
  <https://github.com/libssh/libssh-mirror/blob/master/include/libssh/libssh.h>; Pageant request:
  <https://gitlab.com/libssh/libssh-mirror/-/issues/45>, agent callback request:
  <https://gitlab.com/libssh/libssh-mirror/-/issues/277>
- libssh2 agent code (Pageant first, then the OpenSSH pipe): <https://github.com/libssh2/libssh2/blob/master/src/agent.c>;
  forwarding: <https://github.com/libssh2/libssh2/blob/master/src/channel.c>; no `.ppk` support (2013, still no ppk
  reader in the source tree): <https://libssh2.org/mail/libssh2-devel-archive-2013-07/0011.shtml>
- libssh CHANGELOG (IdentityAgent in 0.10.0, ProxyJump in 0.11.0): <https://github.com/libssh/libssh-mirror/blob/master/CHANGELOG>;
  config keywords: <https://github.com/libssh/libssh-mirror/blob/master/src/config.c>
- Pageant and Windows OpenSSH: <https://the.earth.li/~sgtatham/putty/latest/htmldoc/Chapter9.html> (9.3.3)
- PuTTY key formats and Argon2 in format 3: <https://putty.cs.utah.edu/0.83/htmldoc/AppendixC.html>,
  <https://putty.cs.utah.edu/wishlist/ppk3.html>; Pageant and the OpenSSH pipe:
  <https://putty.cs.utah.edu/wishlist/win-pageant-openssh-interop.html>
- MSYS2 package: <https://packages.msys2.org/package/mingw-w64-x86_64-libssh>
- Package versions on Fedora 44 and AlmaLinux 9: `dnf list` on 2026-11-20.
