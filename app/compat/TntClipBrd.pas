{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces the TNT unit of the same name. The LCL clipboard is Unicode. }
unit TntClipBrd;

{$mode delphi}

interface

uses
  Clipbrd;

type
  { TNT's clipboard had Unicode text properties; the LCL's AsText is Unicode already (UTF-8) }
  TClipboardWideTextHelper = class helper for TClipboard
  private
    function GetAsWideText: WideString;
    procedure SetAsWideText(const Value: WideString);
  public
    property AsWideText: WideString read GetAsWideText write SetAsWideText;
  end;

function TntClipboard: TClipboard;

implementation

function TClipboardWideTextHelper.GetAsWideText: WideString;
begin
  Result := UTF8Decode(AsText);
end;

procedure TClipboardWideTextHelper.SetAsWideText(const Value: WideString);
begin
  AsText := UTF8Encode(Value);
end;

function TntClipboard: TClipboard;
begin
  Result := Clipboard;
end;

end.
