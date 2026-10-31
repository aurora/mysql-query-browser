# ADR-0020 — Cancel queries on the server, never the wrong one

- Status: Accepted (implemented; checked on Linux against the server matrix, Windows cross-built only)
- Date: 2026-10-31
- Deciders: Harald Lapp (project owner)

## Context

The original stops long work by killing the client thread: `TerminateThread` in
`MySQLConnection` (`ClearWorkList`, `FetchData` with a control thread, `StopCurrentThread`) after a
timeout, followed by a reconnect. POSIX has no equivalent (`docs/linux-port.md`, 4.2), so the Linux
build waits for the thread instead, and a long statement cannot be stopped there.

Killing the thread was never a real cancel:

- The statement keeps running on the server. The server only notices a lost client when it reads
  from or writes to the socket. A sorting `SELECT` computes to the end, `SELECT SLEEP(30)` sleeps
  30 s, and an `UPDATE` with autocommit finishes and **commits** although the user stopped it.
- `TerminateThread` can stop the thread inside libmariadb or the heap with a lock held and leaves the
  `MYSQL` structure in an undefined state, on Windows too.
- The Stop button of a query (`QueryBrowser.QueryStopClick`) only sets `TMySQLRS.StopQuery`, which the
  backend reads between fetched rows (`MYX_STOP_EXECUTION`). While the server is still executing,
  Stop has no effect on any platform.

The MySQL protocol has no message to interrupt a running statement on its own connection. Every
client (the `mysql` command line on Ctrl+C, Workbench) sends `KILL QUERY <id>` over a second
connection. That has a race: the statement can end between the decision and the moment the server
executes the `KILL`, and the `KILL` then hits whatever runs next on that connection. The project
owner's requirement: **a statement other than the one being cancelled must never be killed.**

## Decision

Cancelling is done on the server with `KILL QUERY` over a second, short-lived connection, guarded so
that it can only hit the statement it was meant for. Where that cannot be guaranteed, nothing is
killed on the server.

1. **One canceller per connection** (`app/src/QueryCancel.pas`, no LCL dependency). It is attached
   after the connection is made and detached before it is closed. On attach it reads the connection
   id with `SELECT CONNECTION_ID()` (not `mysql_thread_id()`, which is 32 bits on Windows) and the
   server identity: `@@hostname`, `@@port`, `@@server_id` and the user name of the session.
2. **Tickets.** Each cancellable operation gets a unique ticket. The thread that owns the connection
   brackets its statements with `BeginStatement(Ticket)` / `EndStatement(Ticket)`. Both and `Cancel`
   take a small lock in the canceller; the work itself runs without it.
3. **The `KILL` is sent under that lock and only while the ticket is running.** The second
   connection is opened and checked first, outside the lock; then, holding the lock, the canceller
   checks that exactly this ticket is still between `BeginStatement` and `EndStatement` and sends
   `KILL QUERY` and waits for its reply. The owner cannot end the ticket and start anything else on the
   connection while the `KILL` is in flight. A `Cancel` that arrives before `BeginStatement` makes
   `BeginStatement` refuse to start.
4. **No leftover kill flag.** If the statement ended on the server just before the `KILL` arrived,
   the server may have set the kill flag on an idle connection, where it could interrupt the next
   statement. After a `KILL` was sent, `EndStatement` therefore runs `DO 0` on the owner's connection
   (still under the canceller's lock, before the owner releases the connection to anyone else) and
   ignores the "interrupted" error it may get.
5. **Same server, own session, no proxy.** Before the `KILL` the second connection must report the
   same `@@hostname`, `@@port`, `@@server_id`, and `information_schema.PROCESSLIST` must list the
   target id with the session's own user. Both connections must also report a handshake thread id
   equal to `CONNECTION_ID()` (low 32 bits); a proxy (ProxySQL, MaxScale) gives the client its own
   id there and may share backend connections between clients, so a `KILL` behind it could hit
   someone else. If any check fails, no `KILL` is sent.
6. **Fallback: cut the own socket.** Where the `KILL` is not possible (checks failed, no second
   connection), the canceller may instead shut down the socket of the owner's connection
   (`mariadb_cancel`, via `myx_mysql_cancel`). That never stops another session's statement; the
   statement may go on running on the server, and the connection has to be reopened. The caller
   decides whether cutting is allowed: not for a statement that runs inside the user's transaction
   on the main connection, because that would lose the transaction.
7. **Where it is used.**
   - The query Stop button: Stop also cancels the running statement (in a background thread, so the
     UI does not wait for the second connection). An "interrupted" error after Stop is reported
     through the existing "stopped" path (`QueryStopped`), not as an error.
   - `TMySQLConn` fetch threads (`ClearWorkList`, `StopCurrentThread`, `FetchData` with a control
     thread): ask the thread to stop, wait the original timeout, then `Cancel`, wait again, then cut
     the socket, and wait for the thread to end. `TerminateThread` is no longer used there, on
     Windows either.
8. **Not covered:** the connect and ping threads of `ConnectToInstance`. They run no statement that a
   `KILL` could stop; they keep `TerminateThread` on Windows and wait elsewhere, as now (a separate
   decision if they turn out to hang in practice).

## Consequences

Positive:
- A long statement stops on the server within the time the server needs to notice the kill flag,
  and a stopped `UPDATE` is rolled back instead of committed.
- No thread is killed any more in these paths, so no locks are left held; the Linux and Windows
  builds behave the same.
- The Stop button works during execution, not only while rows are fetched. This changes behaviour
  that users can notice, but not the UI; it is what the button promised (ADR-0001 is about the UI).

Negative:
- A cancel opens a second connection: one login more, it needs a free connection slot
  (`max_connections`), and it takes as long as connecting takes.
- Behind a proxy or a load balancer that sends the second connection to another server the `KILL`
  is refused by design; there the Stop button only cuts the own connection (or, inside a
  transaction, does nothing until the statement ends).
- A statement only stops where the server checks its kill flag; some long phases (e.g. parts of
  `ALTER TABLE`, a rollback after the kill) take their time.
- `DO 0` adds a round trip after each cancel. Checked 2026-10-31: none of the supported servers
  (MySQL 5.7, 8.0, 8.4, 9, MariaDB 10.11, 11.4) keeps the kill flag on an idle connection, so it is
  a safeguard, not a fix for an observed problem; it stays because the behaviour is not documented.
- Code that uses the shared main connection without taking `TMySQLConn.Lock` is outside the
  guarantee (it would already break the protocol if it ran in parallel with a fetch thread).

Checked 2026-10-31 (`tests/test_cancel.pas`, whole server matrix): `SELECT SLEEP(30)` stops within
about 0.1 s of the cancel, an autocommitted `UPDATE` is rolled back, and in 300 rounds of short
statements raced against cancels no statement outside the cancelled ticket was hit. The same test
with the ticket check removed hit the following statement in 63 of 300 rounds. In the application
(GTK2), Stop on a slow `UPDATE` reports "Query aborted." and leaves the table unchanged. Note that
MySQL ends an interrupted `SLEEP()` with the value 1 instead of an error, so a stopped `SELECT
SLEEP(n)` shows a row and not "Query aborted.".

## Alternatives considered

- **Keep `TerminateThread` (Windows) / wait (Linux):** the statement keeps running and commits; on
  Linux nothing can be stopped.
- **Only cut the socket (`mariadb_cancel`, `shutdown()`):** the client is free at once, but the
  statement keeps running on the server, as with killing the thread. Used only as the fallback.
- **Non-blocking client API** (`mysql_real_query_start` / `_cont`): frees the client thread without
  killing it, but does not stop the server either; a `KILL` is still needed. A larger change to the
  backend for no gain here.
- **`max_execution_time` / `max_statement_time`:** a server-side limit, not a cancel by the user;
  `SELECT` only in MySQL.
- **`KILL QUERY ID <query_id>` (MariaDB):** would make the target exact on MariaDB, but MySQL has no
  equivalent, and the lock, the ticket and `DO 0` give the same guarantee on both.

## Related

- ADR-0001 — no UI changes while porting.
- ADR-0004 — supported servers (the tests run on the whole matrix).
- `docs/linux-port.md`, section 4.2 (the open question this settles).
