{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Highlighter for the help pane (EmbeddedWB.pas, ADR-0016). The pane shows plain text from the server's
  help tables, so the structure is not in the text but in the line kinds that the view assigns:

    heading  the whole line, bold
    link     the whole line, blue underlined
    code     syntax blocks and examples: UPPERCASE words are keywords, lower case words with an
             underscore (tbl_name) are placeholders, quoted strings, numbers, brackets and bars,
             "mysql>" / "->" prompts of the examples
    prose    running text; UPPERCASE words (function and statement names, as the vendor's manual
             sets them in a code font) are emphasised, URLs are links

  The colours follow the SQL editor's. }
unit HelpHighlighter;

{$mode delphi}

interface

uses
  Classes, SysUtils, Graphics, SynEditHighlighter, SynEditTypes;

type
  THelpLineKind = (hlProse, hlHeading, hlCode, hlLink, hlExample, hlSql, hlTable);

  THelpLineKindEvent = function(LineIndex: Integer): THelpLineKind of object;

  TTokenKind = (tkNull, tkText, tkHeading, tkLink, tkKeyword, tkPlaceholder, tkString, tkNumber, tkSymbol,
    tkPrompt, tkEmphasis, tkSql);

  THelpHighlighter = class(TSynCustomHighlighter)
  private
    FLineStr: String;
    FLine: PChar;
    FRun: Integer;
    FTokenPos: Integer;
    FToken: TTokenKind;
    FKind: THelpLineKind;
    FLineNo: Integer;
    FOnGetLineKind: THelpLineKindEvent;
    FAttri: array[TTokenKind] of TSynHighlighterAttributes;
    FSql: TSynCustomHighlighter;       // the editor's SQL highlighter, used for the examples
    FSqlLine: String;
    FPhase: Integer;                   // 2: the rest of an example line is scanned by FSql
    FSqlFresh: Boolean;
    FSqlOffset: Integer;               // where the SQL part of the line starts (7 after a "mysql> " prompt)
    procedure ScanCode;
    procedure ScanProse;
    function IsWordChar(C: Char): Boolean;
  protected
    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetLine(const NewValue: String; LineNumber: Integer); override;
    procedure Next; override;
    function GetEol: Boolean; override;
    function GetToken: String; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function GetTokenPos: Integer; override;
    property OnGetLineKind: THelpLineKindEvent read FOnGetLineKind write FOnGetLineKind;
    { highlighter (and so the colours) of the SQL editor; examples ("mysql> ...") are handed to it }
    property SqlHighlighter: TSynCustomHighlighter read FSql write FSql;
  end;

implementation

const
  AttrNames: array[TTokenKind] of String = ('Null', 'Text', 'Heading', 'Link', 'Keyword', 'Placeholder', 'String',
    'Number', 'Symbol', 'Prompt', 'Emphasis', 'Sql');

constructor THelpHighlighter.Create(AOwner: TComponent);
var
  K: TTokenKind;
begin
  inherited Create(AOwner);
  for K := Low(TTokenKind) to High(TTokenKind) do
  begin
    FAttri[K] := TSynHighlighterAttributes.Create(AttrNames[K], AttrNames[K]);
    AddAttribute(FAttri[K]);
  end;
  FAttri[tkHeading].Style := [fsBold];
  FAttri[tkLink].Foreground := clBlue;
  FAttri[tkLink].Style := [fsUnderline];
  FAttri[tkKeyword].Foreground := clBlue;
  FAttri[tkPlaceholder].Foreground := $00606000;      // dark teal
  FAttri[tkPlaceholder].Style := [fsItalic];
  FAttri[tkString].Foreground := $000080FF;
  FAttri[tkNumber].Foreground := clFuchsia;
  FAttri[tkSymbol].Foreground := clGray;
  FAttri[tkPrompt].Foreground := clGray;
  FAttri[tkEmphasis].Foreground := clNavy;
  FAttri[tkEmphasis].Style := [fsBold];
end;

function THelpHighlighter.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  Result := FAttri[tkText];
end;

function THelpHighlighter.IsWordChar(C: Char): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

procedure THelpHighlighter.SetLine(const NewValue: String; LineNumber: Integer);
begin
  inherited SetLine(NewValue, LineNumber);
  FLineStr := NewValue;
  FLine := PChar(FLineStr);
  FRun := 0;
  FPhase := 0;
  FLineNo := LineNumber;
  if Assigned(FOnGetLineKind) then
    FKind := FOnGetLineKind(LineNumber)
  else
    FKind := hlProse;
  Next;
end;

procedure THelpHighlighter.ScanCode;
var
  Start, Len: Integer;
  HasLower, HasUpper, HasUnderscore: Boolean;
begin
  case FLine[FRun] of
    ' ', #9:
      begin
        FToken := tkText;
        while FLine[FRun] in [' ', #9] do
          Inc(FRun);
      end;
    '''', '"':
      begin
        FToken := tkString;
        Start := FRun;
        Inc(FRun);
        while (FLine[FRun] <> #0) and (FLine[FRun] <> FLine[Start]) do
          Inc(FRun);
        if FLine[FRun] <> #0 then
          Inc(FRun);
      end;
    '0'..'9':
      begin
        FToken := tkNumber;
        while FLine[FRun] in ['0'..'9', '.'] do
          Inc(FRun);
      end;
    'A'..'Z', 'a'..'z', '_':
      begin
        Start := FRun;
        HasLower := False;
        HasUpper := False;
        HasUnderscore := False;
        while IsWordChar(FLine[FRun]) do
        begin
          if FLine[FRun] in ['a'..'z'] then
            HasLower := True
          else
            if FLine[FRun] in ['A'..'Z'] then
              HasUpper := True
            else
              if FLine[FRun] = '_' then
                HasUnderscore := True;
          Inc(FRun);
        end;
        Len := FRun - Start;
        if (Len >= 2) and HasUpper and not HasLower then
          FToken := tkKeyword
        else
          if HasLower and (HasUnderscore or (Len > 1)) and (FKind in [hlCode, hlExample]) then
            FToken := tkPlaceholder
          else
            FToken := tkText;
        // the prompt of the examples
        if (Start = 0) and (Len = 5) and (Copy(FLineStr, 1, 6) = 'mysql>') then
        begin
          FToken := tkPrompt;
          Inc(FRun);
        end;
      end;
    '-':
      begin
        if FLine[FRun + 1] = '>' then
        begin
          FToken := tkPrompt;
          Inc(FRun, 2);
        end
        else
        begin
          FToken := tkSymbol;
          Inc(FRun);
        end;
      end;
    else
    begin
      FToken := tkSymbol;
      Inc(FRun);
    end;
  end;
end;

procedure THelpHighlighter.ScanProse;
var
  Start: Integer;
  HasLower: Boolean;
begin
  case FLine[FRun] of
    'h':
      if (Copy(FLineStr, FRun + 1, 7) = 'http://') or (Copy(FLineStr, FRun + 1, 8) = 'https://') then
      begin
        FToken := tkLink;
        while not (FLine[FRun] in [#0, ' ', ')', '>']) do
          Inc(FRun);
        Exit;
      end;
    'A'..'Z':
      begin
        Start := FRun;
        HasLower := False;
        while IsWordChar(FLine[FRun]) do
        begin
          if FLine[FRun] in ['a'..'z'] then
            HasLower := True;
          Inc(FRun);
        end;
        if (FRun - Start >= 3) and not HasLower then
          FToken := tkEmphasis
        else
          FToken := tkText;
        Exit;
      end;
  end;
  // anything else up to the start of the next word that needs a style
  FToken := tkText;
  Inc(FRun);
  while FLine[FRun] <> #0 do
  begin
    if not IsWordChar(FLine[FRun - 1]) then
    begin
      if FLine[FRun] in ['A'..'Z'] then
        Break;
      if (FLine[FRun] = 'h') and ((Copy(FLineStr, FRun + 1, 7) = 'http://') or
        (Copy(FLineStr, FRun + 1, 8) = 'https://')) then
        Break;
    end;
    Inc(FRun);
  end;
end;

procedure THelpHighlighter.Next;
begin
  if FPhase = 2 then
  begin
    // the statement after the prompt belongs to the SQL highlighter
    if FSqlFresh then
      FSqlFresh := False
    else
      FSql.Next;
    if FSql.GetEol then
    begin
      FToken := tkNull;
      FRun := Length(FLineStr);
      FTokenPos := FRun;
      Exit;
    end;
    FTokenPos := FSqlOffset + FSql.GetTokenPos;
    FToken := tkSql;
    FRun := FTokenPos + FSql.GetTokenLen;
    Exit;
  end;
  FTokenPos := FRun;
  if FLine[FRun] = #0 then
  begin
    FToken := tkNull;
    Exit;
  end;
  if (FKind = hlExample) and (FRun = 0) and (FSql <> nil) and (Copy(FLineStr, 1, 6) = 'mysql>') then
  begin
    FToken := tkPrompt;
    FRun := 7;
    if FRun > Length(FLineStr) then
      FRun := Length(FLineStr);
    FSqlLine := Copy(FLineStr, 8, MaxInt);
    FSqlOffset := 7;
    FSql.ResetRange;
    FSql.SetLine(FSqlLine, FLineNo);
    FPhase := 2;
    FSqlFresh := True;
    Exit;
  end;
  if (FKind = hlSql) and (FSql <> nil) and (FRun = 0) then
  begin
    // a whole line of SQL (statements in the MariaDB texts have no prompt)
    FSqlLine := FLineStr;
    FSqlOffset := 0;
    FSql.ResetRange;
    FSql.SetLine(FSqlLine, FLineNo);
    FPhase := 2;
    FSqlFresh := True;
    Next;
    Exit;
  end;
  case FKind of
    hlTable:
      begin
        FToken := tkText;
        FRun := Length(FLineStr);
      end;
    hlHeading:
      begin
        FToken := tkHeading;
        FRun := Length(FLineStr);
      end;
    hlLink:
      begin
        FToken := tkLink;
        FRun := Length(FLineStr);
      end;
    hlCode, hlExample, hlSql:
      ScanCode;
  else
    ScanProse;
  end;
end;

function THelpHighlighter.GetEol: Boolean;
begin
  Result := FToken = tkNull;
end;

function THelpHighlighter.GetToken: String;
begin
  SetString(Result, FLine + FTokenPos, FRun - FTokenPos);
end;

procedure THelpHighlighter.GetTokenEx(out TokenStart: PChar; out TokenLength: Integer);
begin
  TokenStart := FLine + FTokenPos;
  TokenLength := FRun - FTokenPos;
end;

function THelpHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin
  if (FToken = tkSql) and (FSql <> nil) then
    Result := FSql.GetTokenAttribute
  else
    Result := FAttri[FToken];
end;

function THelpHighlighter.GetTokenKind: Integer;
begin
  Result := Ord(FToken);
  if (FToken = tkSql) and (FSql <> nil) then
    Result := 100 + FSql.GetTokenKind;
end;

function THelpHighlighter.GetTokenPos: Integer;
begin
  Result := FTokenPos;
end;

end.
