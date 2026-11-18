<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0043 — Dead connections do not block the window

- Status: Accepted
- Date: 2026-11-18
- Deciders: Harald Lapp (project owner)

## Context

The original pings the server every second from a timer in the GUI thread (`TMySQLConn.KeepAliveTrigger`), with
`MYSQL_OPT_RECONNECT` on, so a ping on a lost connection also tries to reconnect. The client library is used
without read or write timeouts, which is what users value: a query may run for hours and is never cut off.

A QueryMole window left open over night froze for good: the computer had been in standby and the VPN to the server
was gone in the morning (2026-11-18). The stack showed the keep-alive ping in `pvio_socket_read`. The peer of a TCP
connection that vanishes without a reset is only given up after the retransmission timeout, about 15 minutes on
Linux (`tcp_retries2` = 15), and each reconnect attempt then waits for the SYN retries (about two minutes). All of
that happened in the GUI thread, every second.

A read timeout would detect the dead peer, but it would also end every query that computes longer than the timeout
(a long `SELECT` sends nothing until its first row), which is exactly what must keep working.

## Decision

- **Socket level (backend, `myx_library.c`).** After every connect and every successful ping (a reconnect opens a
  new socket) the TCP socket gets:
  - a limit for data the server does not acknowledge: `TCP_USER_TIMEOUT` 30 s on Linux, `TCP_MAXRT` 30 s on
    Windows. A server that is reachable acknowledges a query at once, however long it then computes, so long queries
    are unaffected;
  - TCP keep-alives (60 s idle, then every 10 s, 3 probes), so that a connection that dies while idle or while
    waiting for a long query is noticed;
  - a default connect timeout of 20 s (`MYSQL_OPT_CONNECT_TIMEOUT`); `CONNECT_TIMEOUT` in the advanced connection
    options still overrides it.
  Unix sockets and named pipes ignore these options; failures to set them are ignored.
- **Keep-alive ping in a thread (`MySQLConnection.pas`).** Each `TMySQLConn` has one `TKeepAliveThread`. The timer
  only asks it to ping when the previous ping has returned; the thread takes the connection lock with `TryEnter` as
  the original `Ping` did, and hands the result to the main thread (`TThread.Queue`), where the original state
  machine (connected → unclear → disconnected, `WM_CONNECTION_LOST`/`WM_CONNECTION_ESTABLISHED`) runs unchanged.
  When `Disconnect` or the destructor closes the `MYSQL` structure while a ping runs on it, the thread closes it (and
  frees the lock, on destroy) after the ping instead; nobody waits for it.
- `TMySQLConn.Ping`, which the result set calls before running a query, stays synchronous, as in the original.

## Consequences

Measured with a MariaDB 11.4 container whose packets were dropped with nft (`podman pause` is not a test: the kernel
still acknowledges), in the GUI under xvfb (`--watch-connection`) and with a small C program against the backend:

- The window keeps responding during the outage (longest pause of the message loop 12 ms, was minutes).
- The first ping fails after 50 s (30 s unacknowledged data plus one reconnect attempt); the state goes to
  "disconnected" after the second failed ping, about 90 s after the network went away (was about 15 minutes); a
  query on the dead connection fails after 73 s with "Lost connection to server during query".
- `SELECT SLEEP(150)` on a working connection completes; long queries are not limited.
- When the network comes back, the running ping reconnects and the state returns to "connected".
- Quitting while a ping hangs does not wait for it.
- A connection attempt to a host that does not answer now fails after 20 s instead of after the system's SYN
  retries (about two minutes on Linux).
- A query started during an outage still waits for the ping in `Ping` (main thread) before it runs, up to about
  40 s per attempt; that is a user action with a visible cause, unlike the timer.
- New threads touch the C library concurrently with the fetch threads; the connection lock serialises them as
  before, and the ping thread never touches the LCL.
- The Windows path of the socket options is guarded with `#ifdef` but was not compiled yet with MSYS2.

## Alternatives

- **Read/write timeouts** (`MYSQL_OPT_READ_TIMEOUT`): detect the dead peer, but end long queries.
- **Ping less often while disconnected**: shorter freezes, still freezes of 40 s.
- **Keep-alives only**: detect a dead idle connection, but not one with unacknowledged data in flight (the ping
  itself), which retransmits for 15 minutes regardless of keep-alives.
- **A ping without reconnect, reconnecting on demand**: changes when the original reconnects and what the user
  sees after an outage.

## Related

ADR-0020 (queries are cancelled on the server, the same connection lock), ADR-0001 (no visible change: the state
machine and its messages are the original's).
