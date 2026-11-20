{ SPDX-License-Identifier: GPL-2.0-or-later }
{ File dialog filters (QBFileDialogs); no LCL here, so the tests can use it. }
unit FileFilters;

{$mode objfpc}{$H+}

interface

// the filter without a trailing "(...)" in its descriptions; the patterns stay:
// 'CSV File (*.csv)|*.csv|Any File (*.*)|*.*' -> 'CSV File|*.csv|Any File|*.*'
function FilterWithoutPatternsInDescriptions(const Filter: String): String;

implementation

uses
  SysUtils;

function FilterWithoutPatternsInDescriptions(const Filter: String): String;
var
  Part, S: String;
  Rest: String;
  Index, P: Integer;
begin
  Result := '';
  Rest := Filter;
  Index := 0;
  repeat
    P := Pos('|', Rest);
    if P > 0 then
    begin
      Part := Copy(Rest, 1, P - 1);
      Delete(Rest, 1, P);
    end
    else
    begin
      Part := Rest;
      Rest := '';
    end;
    // even parts are descriptions, odd ones the patterns
    if not Odd(Index) then
    begin
      S := TrimRight(Part);
      if (S <> '') and (S[Length(S)] = ')') and (LastDelimiter('(', S) > 1) then
        Part := TrimRight(Copy(S, 1, LastDelimiter('(', S) - 1));
    end;
    if Index > 0 then
      Result := Result + '|';
    Result := Result + Part;
    Inc(Index);
  until P = 0;
end;

end.
