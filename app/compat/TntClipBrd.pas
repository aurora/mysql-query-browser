{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces the TNT unit of the same name. The LCL clipboard is Unicode. }
unit TntClipBrd;

{$mode delphi}

interface

uses
  Clipbrd;

function TntClipboard: TClipboard;

implementation

function TntClipboard: TClipboard;
begin
  Result := Clipboard;
end;

end.
