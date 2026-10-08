{ Replaces the TNT unit of the same name: Unicode command line access. }
unit TntSystem;

{$mode delphi}

interface

function WideParamStr(Index: Integer): WideString;
function WideParamCount: Integer;

implementation

uses
  SysUtils;

function WideParamStr(Index: Integer): WideString;
begin
  Result := UTF8Decode(ParamStr(Index));      // the RTL returns UTF-8 under Lazarus
end;

function WideParamCount: Integer;
begin
  Result := ParamCount;
end;

end.
