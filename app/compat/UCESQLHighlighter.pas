{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Compatibility layer for UniCodeEditor's SQL highlighter (ADR-0012), on SynEdit's SQL highlighter.
  The token classes and colours of the original are applied here as the port progresses. }
unit UCESQLHighlighter;

{$mode delphi}

interface

uses
  Classes, SynEditHighlighter, SynHighlighterSQL;

type
  { The attribute names of the original. The first group maps to SynEdit's SQL highlighter; the
    second group exists so the ported setup code runs, but SynEdit's tokenizer does not yet produce
    these token kinds (embedded commands, version comments, variables); see ADR-0012 review list. }
  TUCESQLHighlighter = class(TSynSQLSyn)
  private
    function GetComment: TSynHighlighterAttributes;
    function GetKey: TSynHighlighterAttributes;
    function GetString: TSynHighlighterAttributes;
    function GetIdentifier: TSynHighlighterAttributes;
    function GetNumber: TSynHighlighterAttributes;
    function GetSpace: TSynHighlighterAttributes;
    function GetSymbol: TSynHighlighterAttributes;
  private
    FCommentWithCommandAttributes, FEmbeddedCommandAttributes, FSystemVariableAttributes,
      FUserVariableAttributes: TSynHighlighterAttributes;
  public
    constructor Create(AOwner: TComponent); override;
    property CommentAttributes: TSynHighlighterAttributes read GetComment;
    property KeyAttributes: TSynHighlighterAttributes read GetKey;
    property StringAttributes: TSynHighlighterAttributes read GetString;
    property IdentifierAttributes: TSynHighlighterAttributes read GetIdentifier;
    property NumberAttributes: TSynHighlighterAttributes read GetNumber;
    property SpaceAttributes: TSynHighlighterAttributes read GetSpace;
    property SymbolAttributes: TSynHighlighterAttributes read GetSymbol;
    property CommentWithCommandAttributes: TSynHighlighterAttributes read FCommentWithCommandAttributes;
    property EmbeddedCommandAttributes: TSynHighlighterAttributes read FEmbeddedCommandAttributes;
    property SystemVariableAttributes: TSynHighlighterAttributes read FSystemVariableAttributes;
    property UserVariableAttributes: TSynHighlighterAttributes read FUserVariableAttributes;
  end;

implementation

function TUCESQLHighlighter.GetComment: TSynHighlighterAttributes;
begin
  Result := CommentAttri;
end;

function TUCESQLHighlighter.GetKey: TSynHighlighterAttributes;
begin
  Result := KeyAttri;
end;

function TUCESQLHighlighter.GetString: TSynHighlighterAttributes;
begin
  Result := StringAttri;
end;

function TUCESQLHighlighter.GetIdentifier: TSynHighlighterAttributes;
begin
  Result := IdentifierAttri;
end;

function TUCESQLHighlighter.GetNumber: TSynHighlighterAttributes;
begin
  Result := NumberAttri;
end;

function TUCESQLHighlighter.GetSpace: TSynHighlighterAttributes;
begin
  Result := SpaceAttri;
end;

function TUCESQLHighlighter.GetSymbol: TSynHighlighterAttributes;
begin
  Result := SymbolAttri;
end;

constructor TUCESQLHighlighter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SQLDialect := sqlMySQL;
  // the original's attributes start without styles (SynEdit makes keywords bold)
  KeyAttri.Style := [];
  FunctionAttri.Style := [];
  DataTypeAttri.Style := [];
  FCommentWithCommandAttributes := TSynHighlighterAttributes.Create('CommentWithCommand', 'CommentWithCommand');
  FEmbeddedCommandAttributes := TSynHighlighterAttributes.Create('EmbeddedCommand', 'EmbeddedCommand');
  FSystemVariableAttributes := TSynHighlighterAttributes.Create('SystemVariable', 'SystemVariable');
  FUserVariableAttributes := TSynHighlighterAttributes.Create('UserVariable', 'UserVariable');
  AddAttribute(FCommentWithCommandAttributes);
  AddAttribute(FEmbeddedCommandAttributes);
  AddAttribute(FSystemVariableAttributes);
  AddAttribute(FUserVariableAttributes);
end;

initialization
  RegisterClasses([TUCESQLHighlighter]);

end.
