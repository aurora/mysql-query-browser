# MySQL Query Browser, revived

A revival of the classic **MySQL Query Browser** (2006) as a cross-platform program for current MySQL (5.7 to 9)
and MariaDB (10.11, 11.4): the original Windows user interface, rebuilt with Free Pascal and Lazarus, so that it
runs on Windows and Linux (macOS later).

> **Status: alpha (0.1.0-alpha.1).** The program connects, runs queries, shows and edits results, runs scripts and
> exports. It has known faults and is not yet worked through on every platform; see "Known problems" below. The
> name "MySQL Query Browser" is a working title: "MySQL" is a trademark of Oracle, this project is not affiliated
> with it, and it will get its own name.

## What works

Checked against MySQL 5.7, 8.0, 8.4, 9 and MariaDB 10.11 and 11.4 (an automated test suite and the application's
self-tests run against all six):

- connect dialog with stored connections, TLS "preferred" with fallback to an unencrypted connection;
- the schema tree, SQL editor with highlighting, running queries, the result grid with editing (apply and
  discard), several result tabs, EXPLAIN, scripts with breakpoints;
- export of results to CSV, HTML, XML, Excel and PLIST;
- the help panel, whose reference comes from the connected server;
- the options dialog, text search, regular expression importer.

## Known problems of this alpha

- **Linux (GTK2): a crash after connecting** was seen once (heap corruption, not reproduced) and **the window froze
  once while scrolling the schema tree** of a database with many tables (not reproduced). If it happens to you, see
  "Reporting problems".
- **Not worked through on a desktop yet:** real mouse and keyboard use, drag and drop, bookmarks and history, the
  field viewer; the checklist is in [docs/linux-manual-test.md](docs/linux-manual-test.md).
- **Linux on a scaled (HiDPI) desktop:** the program uses pixel layouts for 96 dpi and pins GTK's dpi to 96; use the
  desktop's scaling for X11 applications (KDE: "Legacy applications: scaled by the system"). Real HiDPI support
  comes later (ADR-0009).
- **Linux:** no "OS specific" password storage (only "Plaintext" and "Obscured", ADR-0021); no global hot keys
  (ADR-0022); GTK2 is used for this release, a Qt version is planned afterwards (ADR-0024).
- **No update mechanism** in the alpha: download the new version and replace the old one (ADR-0026). No macOS
  build yet.
- The user interface is the original's, including its look and its English texts; some parts look different under
  GTK2 than on Windows.

Details and the state of the Linux port: [docs/linux-port.md](docs/linux-port.md).

## Download and run

Releases are published as GitHub pre-releases at
<https://github.com/aurora/mysql-query-browser/releases>.

- **Windows (64 bit):** unpack the zip and run `qbr.exe`. Settings and connections are kept in
  `%APPDATA%\MySQL\`, the folder of the original, so a configuration of the old program is found as it is.
- **Linux (x86_64):** make the AppImage executable and run it. Settings are kept in `~/.mysqlgui/`, the folder of
  the original Linux version. (The AppImage is still to be built; until it is published, build from source.)

Use a throw-away or test account when you try the alpha on a server that matters.

## Reporting problems

Please report them at <https://github.com/aurora/mysql-query-browser/issues> with:

- the version (Help > About), the operating system and, on Linux, the desktop;
- the server and its version;
- what you did in the last seconds before the problem;
- if the program ended: the file `qbr.error.txt` next to the program, if there is one, and, if you can, a run with
  `QBR_TRACE=1` (this writes `qbr.trace.txt` next to the program).

## Building from source

See [AGENTS.md](AGENTS.md) ("Toolchain" and "Everyday commands") for Windows (Lazarus, MSYS2) and Linux (the
distrobox set up by `tools/distrobox-setup.sh`).

## How it is made

The program is a port of the original sources (kept unchanged in `legacy/`), done by Harald Lapp **with the help
of Claude Code** (Anthropic), an AI coding assistant, which wrote and changed a large part of the code and
documentation under the owner's direction. The decisions behind the project are written down in
[docs/adr/](docs/adr/README.md), the plan is in [ROADMAP.md](ROADMAP.md). The original authors are credited in the
About dialog.

## Layout

| Directory  | Purpose |
|------------|---------|
| `legacy/`  | Original sources (GPL), kept unchanged as reference |
| `backend/` | New CMake build of the C libraries the Query Browser needs |
| `bindings/`| Generated Pascal bindings for the backend |
| `app/`     | Lazarus / Free Pascal application (ported from the Delphi UI) |
| `docs/`    | Reference screenshots of the original, porting notes |

## Plan

The plan and the backlog are in [ROADMAP.md](ROADMAP.md). A thin database-driver interface is planned so that other
databases (e.g. PostgreSQL) can follow later (ADR-0010).

## License

GPL-2.0-or-later, like the original MySQL Query Browser; see [LICENSE](LICENSE) and
[NOTICE](NOTICE) (inherited PCRE exception, third-party components). "MySQL" is a trademark
of Oracle; this project is not affiliated with it and needs its own name.
