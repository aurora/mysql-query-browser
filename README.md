# query-browser-revival

Revival of the classic MySQL Query Browser: cross-platform (Windows, Linux, macOS),
MySQL 8 compatible, with the original UX unchanged.

Status: porting in progress. The backend, tests, bindings and form conversion work;
the application itself is not usable yet. See [ROADMAP.md](ROADMAP.md) for the plan and
[docs/adr/](docs/adr/README.md) for the decisions behind it.

## Layout

| Directory  | Purpose |
|------------|---------|
| `legacy/`  | Original sources (GPL), kept unchanged as reference |
| `backend/` | New CMake build of the C libraries the Query Browser needs |
| `bindings/`| Generated Pascal bindings for the backend |
| `app/`     | Lazarus / Free Pascal application (ported from the Delphi UI) |
| `docs/`    | Reference screenshots of the original, porting notes |

## Plan

1. Backend: build `libmysqlx`, `libmysqlutil`, `libmysqlqb`, sql-parser with CMake against MariaDB Connector/C.
2. Bindings: generate Pascal units from the C headers.
3. UI port: Delphi VCL -> Lazarus LCL, Windows first, UI is the blueprint for Linux/macOS.
4. Packaging.

A thin database-driver interface is planned so other RDBMS (e.g. PostgreSQL) can follow later.
