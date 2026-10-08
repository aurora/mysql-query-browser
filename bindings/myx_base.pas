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

implementation

end.
