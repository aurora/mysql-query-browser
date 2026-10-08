{ Hand-written. Types from system and MySQL headers that the generated
  myx_*.pas units refer to. They are only ever used behind pointers, so they
  are opaque here. }
unit myx_types;

{$mode objfpc}{$H+}

interface

type
  PMYSQL = Pointer;
  PMYSQL_RES = Pointer;
  PMYSQL_FIELD = Pointer;
  PMYSQL_STMT = Pointer;
  PFILE = Pointer;

implementation

end.
