<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# Other databases: what is MySQL-specific today

Inventory for supporting PostgreSQL, SQLite and Microsoft SQL Server later (ADR-0010; possible since parity,
ADR-0047). Taken on 2026-11-20 from the code; counts are from grep, so they are rough. It is the input for the ADR
that will settle the driver seam, not a decision.

## Summary

- **The UI is mostly neutral.** Editor, result tabs, toolbar, tabs, options, export formats, bookmarks, history and
  stored connections do not depend on MySQL beyond the data they show. Even the original's connection format already
  has `MYX_ODBC_CONN`, `MYX_ORACLE_CONN`, `MYX_MSSQL_CONN` and `MYX_SQLITE_CONN` next to `MYX_MYSQL_CONN`.
- **Everything below it is MySQL:** 18 Pascal units call 102 different `myx_*` functions (227 call sites), and
  the C backend they call (about 66,000 lines, of which about 40,000 are a generated MySQL grammar) talks to
  Connector/C and writes MySQL SQL.
- **The seam therefore belongs in Pascal, above `myx_*`:** the program talks to a driver interface; the MySQL driver
  wraps today's `myx_*` calls (so nothing changes for MySQL), the others are new Pascal code on their client
  libraries (or on FPC's SQLDB). This also fits ADR-0003 (the C backend is transitional).

## By area

Size: S = days, M = a week or two, L = several weeks, each for the first other database; later ones are cheaper.

| Area | Where today | MySQL-specific in it | For other databases | Size |
|---|---|---|---|---|
| Connection and session: connect, close, ping, errors, version, default schema, cancel (`KILL QUERY`), keep-alive, reconnect, SSH tunnel | `MySQLConnection.pas` (1,800 lines, 42 calls), `ConnectToInstance.pas`, `QueryCancel.pas`, `SSHConnect.pas`; C `myx_library.c` (2,350 lines, 98 Connector/C calls) | Connector/C, `mysql_*` options, thread id and `KILL`, version checks (`MajorVersion < 5`) | driver methods: Connect, Close, Ping, Cancel, LastError, ServerVersion, Capabilities, UseSchema; PostgreSQL cancels through `PQcancel`, SQLite has no server; the SSH tunnel stays as it is (it forwards any TCP port) | M |
| Executing statements and reading results, with progress and stop | `MySQLResultSet.pas` (1,700 lines, 17 calls); C `myx_recordset.c` (2,570), `myx_query.cpp` (3,220) | the fetch loop on Connector/C, MySQL type codes in the column metadata | a result set interface (columns with neutral types, rows, fetch in a thread, stop); the grid (`MySQLResultSetControls.pas`, 4,500 lines) only reads the result | M |
| Editing results (insert, update, delete in the grid, apply, discard, compare) | C `myx_query.cpp` (actions, `myx_query_apply_actions`), the SQL parser to find the table and primary key | which table a result comes from is found by parsing the MySQL query; the generated `UPDATE`/`INSERT` use MySQL quoting | per driver: where a column comes from (PostgreSQL gives the table of each column, `PQftable`; SQLite only through parsing or `sqlite3_column_table_name`), quoting, key detection; read-only at first | L |
| SQL parsing: statement splitting, tables of a query, the query builder (adding tables and columns), parameters | C `sql-parser` (bison/flex, ~40,000 generated lines, MySQL grammar), `myx_strip_query.cpp` (1,270), `myx_simple_sql_parsing.c`; Pascal `LexicalTools.pas` (3,430, MySQL identifiers) | the whole grammar | splitting per dialect is enough at first (PostgreSQL `$$` bodies, SQL Server `GO`, SQLite plain `;`); query builder and parameters MySQL-only until a neutral parser exists | M (splitting), L (builder) |
| Schema tree: catalogs, schemas, tables, views, columns, indices, routines | `SchemataTreeView.pas` (3,190 lines, 27 calls, 24 dialect places), `TableDrag.pas`; C `myx_catalogs.c` (1,630, 13 SQL texts) | `SHOW ...` and MySQL's `information_schema` | per driver: a catalog interface; PostgreSQL and SQL Server have `information_schema` (plus their own catalogs), SQLite has `sqlite_schema` and `PRAGMA` | M |
| Table editor and DDL (create, alter, `SHOW CREATE`) | `EditorTable*.pas` (5,230 lines), C `myx_database_model.c` (3,370, 17 SQL texts), `app/xml/mysqlx_dbm_datatypes.xml` | MySQL data types, engines, charsets, DDL syntax | already planned as a Pascal model with dialects (ADR-0036); for other databases first only showing the DDL | L |
| Syntax highlighting, function list | `app/compat/UCESQLHighlighter.pas` (over SynEdit's SQL highlighter), C `myx_sql_highlighting.c`, the function list XML | MySQL keywords and functions | SynEdit's highlighter has dialects (PostgreSQL, MS SQL, SQLite among them); function lists per dialect | S |
| Scripts | `ScriptPanel.pas` (2,120), `myx_process_sql_statements` | `DELIMITER`, MySQL splitting | the dialect's splitting (see parsing) | S–M |
| Inline help | `ServerHelp.pas` (`help_topic` tables of the server) | MySQL and MariaDB only | hidden for other databases | S |
| `EXPLAIN` view, profiling | `QueryBrowser.pas`, C `myx_profiling.c` | MySQL's `EXPLAIN` columns, `SHOW PROFILE` | hidden at first; PostgreSQL's `EXPLAIN` is text or JSON | S (hide) |
| Export (CSV, HTML, XML, Excel, PLIST) | C `myx_exporter.c` | none beyond the result set structure | neutral once the result set interface exists | S |
| Stored connections, options, history, bookmarks | C `myx_xml_*` | none (the connection type field exists) | a driver choice in the connect dialog and the stored connections; per-driver options (SQLite: a file instead of host and port) | S–M |
| Main window | `QueryBrowser.pas` (8,950 lines, 51 calls), `Main.pas` | mostly through the units above; a few direct SQL texts and version checks | follows the seam; enabling and hiding by driver capabilities | M |

## Client libraries

| Database | Library | Licence | Notes |
|---|---|---|---|
| PostgreSQL | libpq (FPC units `postgres3`) | PostgreSQL licence | packaged everywhere; cancel, column origin, async queries |
| SQLite | sqlite3 (FPC units `sqlite3`) | public domain | no server: tests need no container |
| SQL Server | FreeTDS (`dblib`/`ct-lib`) or ODBC (unixODBC + Microsoft's driver) | FreeTDS LGPL-2.0+; Microsoft's ODBC driver is proprietary, the user installs it | `GO` batches, Windows authentication; the test container (`mcr.microsoft.com/mssql/server`) is large and under Microsoft's licence |
| all four | FPC's SQLDB (`TPQConnection`, `TSQLite3Connection`, `TMSSQLConnection`, `TODBCConnection`) | FPC's LGPL with linking exception | one API for all; whether its metadata is enough for the schema tree and editable results needs a check |

## Order that the inventory suggests

1. **The seam with MySQL only:** driver, result set and catalog interfaces; the MySQL implementation wraps `myx_*`;
   the server matrix must stay green with no visible change. The largest and riskiest step, independent of any
   other database.
2. **PostgreSQL, read-only:** connect, schema tree, queries, results, export, scripts with PostgreSQL splitting,
   highlighting; help, `EXPLAIN` view, query builder and table editor hidden. PostgreSQL containers join the matrix.
3. **Editing results on PostgreSQL** (column origin from libpq), then **SQLite** (cheap once 1 and 2 stand).
4. **Table editor dialects** with ADR-0036.
5. **SQL Server** last.

## Not looked at yet

- How much of `QueryBrowser.pas` would change for step 1; its 51 calls go to many areas.
- Whether SQLDB covers what the schema tree and editable results need, or whether direct client units are simpler.
- Performance of a Pascal fetch loop against the C one for large results (2 million rows load in about a minute
  today).
