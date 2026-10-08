{ Hand-written Pascal bindings for the subset of libmysqlx used so far.
  Mirrors backend/src/base-library/include/myx_public_interface.h.
  To be replaced by generated bindings. }
unit myx_base;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

const
  LIB_MYSQLX = 'libmysqlx.dll';

type
  PMYSQL = Pointer;

  { enum myx_lib_error }
  TMYX_LIB_ERROR = LongInt;

const
  MYX_NO_ERROR = 0;
  MYX_SQL_ERROR = 6;

  MYX_MYSQL_CONN = 0;
  MYX_FAVORITE_USER_CONNECTION = 1;

type
  PPAnsiChar = ^PAnsiChar;

  PMYX_USER_CONNECTION = ^TMYX_USER_CONNECTION;
  TMYX_USER_CONNECTION = record
    connection_name: PAnsiChar;
    username: PAnsiChar;
    password: PAnsiChar;
    hostname: PAnsiChar;
    port: LongWord;
    schema: PAnsiChar;
    advanced_options_num: LongWord;
    advanced_options: PPAnsiChar;
    storage_path: PAnsiChar;
    notes: PAnsiChar;
    connection_type: LongInt;
    storage_type: LongInt;
  end;

  PMYX_RS_COLUMN = ^TMYX_RS_COLUMN;
  TMYX_RS_COLUMN = record
    table: Pointer;
    table_column: Pointer;
    column_type: LongInt;
    type_size: LongWord;
    name: PAnsiChar;
    editable: LongWord;
  end;

  PMYX_RS_FIELD = ^TMYX_RS_FIELD;
  TMYX_RS_FIELD = record
    value_length: LongWord;
    value: PAnsiChar;
  end;

  PMYX_RS_ROW = ^TMYX_RS_ROW;
  TMYX_RS_ROW = record
    fields: PMYX_RS_FIELD;
    diff: Int64;
  end;

  PMYX_RESULTSET = ^TMYX_RESULTSET;
  TMYX_RESULTSET = record
    mysql: PMYSQL;
    query: Pointer;
    editable: LongWord;
    has_more: LongWord;
    columns_num_to_display: LongWord;
    columns_num: LongWord;
    columns: PMYX_RS_COLUMN;
    rows_num: LongWord;
    rows: PMYX_RS_ROW;
    actions: Pointer;
    memory_used: Int64;
    query_time: Double;
    fetch_time: Double;
  end;

  { catalogs / schemata / tables }
  PMYX_SCHEMA_TABLE_COLUMN = ^TMYX_SCHEMA_TABLE_COLUMN;
  TMYX_SCHEMA_TABLE_COLUMN = record
    column_name: PAnsiChar;
    column_type: PAnsiChar;
    default_value: PAnsiChar;
    extra: PAnsiChar;
    primary_key: LongWord;
    not_null: LongWord;
  end;

const
  MSTT_BASE_TABLE = 0;
  MSTT_VIEW = 1;

type
  PMYX_SCHEMA_TABLE = ^TMYX_SCHEMA_TABLE;
  TMYX_SCHEMA_TABLE = record
    table_name: PAnsiChar;
    columns_num: LongWord;
    columns: PMYX_SCHEMA_TABLE_COLUMN;
    table_type: LongInt;
  end;

  PMYX_SCHEMA_TABLES = ^TMYX_SCHEMA_TABLES;
  TMYX_SCHEMA_TABLES = record
    schema_tables_num: LongWord;
    schema_tables: PMYX_SCHEMA_TABLE;
  end;

  PMYX_SCHEMA = ^TMYX_SCHEMA;
  TMYX_SCHEMA = record
    schema_name: PAnsiChar;
    escaped_schema_name: PAnsiChar;
    catalog_name: PAnsiChar;
    schema_tables: Pointer;
    schema_indices: Pointer;
    schema_sps: Pointer;
  end;

  PMYX_CATALOG = ^TMYX_CATALOG;
  TMYX_CATALOG = record
    catalog_name: PAnsiChar;
    schemata_num: LongWord;
    schemata: PMYX_SCHEMA;
  end;

  PMYX_CATALOGS = ^TMYX_CATALOGS;
  TMYX_CATALOGS = record
    catalogs_num: LongWord;
    catalogs: PMYX_CATALOG;
  end;

function myx_get_public_interface_version: LongInt; cdecl; external LIB_MYSQLX;
function myx_mysql_init: PMYSQL; cdecl; external LIB_MYSQLX;
function myx_connect_to_instance(conn: PMYX_USER_CONNECTION; mysql: PMYSQL): LongInt; cdecl; external LIB_MYSQLX;
function myx_mysql_close(mysql: PMYSQL): LongInt; cdecl; external LIB_MYSQLX;
function myx_mysql_error(mysql: PMYSQL): PAnsiChar; cdecl; external LIB_MYSQLX;
function myx_mysql_errno(mysql: PMYSQL): LongInt; cdecl; external LIB_MYSQLX;
function myx_query_execute(mysql: PMYSQL; sql: PAnsiChar; enforce_editable: LongInt;
  params: Pointer; var error_code: TMYX_LIB_ERROR; user_data: Pointer;
  progress_row_fetch, resultset_realloc_before, resultset_realloc_after: Pointer): PMYX_RESULTSET; cdecl; external LIB_MYSQLX;
function myx_query_free_resultset(rs: PMYX_RESULTSET): LongInt; cdecl; external LIB_MYSQLX;

function myx_mysql_query(mysql: PMYSQL; cmd: PAnsiChar): LongInt; cdecl; external LIB_MYSQLX;
function myx_get_catalogs(mysql: PMYSQL): PMYX_CATALOGS; cdecl; external LIB_MYSQLX;
function myx_free_catalogs(catalogs: PMYX_CATALOGS): LongInt; cdecl; external LIB_MYSQLX;
function myx_get_schema_tables(mysql: PMYSQL; catalog_name, schema_name: PAnsiChar): PMYX_SCHEMA_TABLES; cdecl; external LIB_MYSQLX;
function myx_free_schema_tables(tables: PMYX_SCHEMA_TABLES): LongInt; cdecl; external LIB_MYSQLX;

implementation

end.
