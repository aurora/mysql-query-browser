{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Compatibility layer for UniCodeEditor's SQL highlighter (ADR-0012), on SynEdit's SQL highlighter.
  The token classes and colours of the original are applied here as the port progresses. }
unit UCESQLHighlighter;

{$mode delphi}

interface

uses
  Classes, SynHighlighterSQL;

type
  TUCESQLHighlighter = class(TSynSQLSyn)
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

constructor TUCESQLHighlighter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SQLDialect := sqlMySQL;
end;

initialization
  RegisterClasses([TUCESQLHighlighter]);

end.
