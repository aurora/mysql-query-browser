{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replacement for the EmbeddedWB Internet Explorer wrapper that the Query Browser used for its inline
  help pane. The LCL has no web browser control and the reference text no longer comes as HTML pages
  (ADR-0016): it is plain text from the connected server's help tables. The pane is therefore a read-only
  SynEdit that shows a topic as text (heading, syntax, description, examples, a link line that opens the
  full documentation in the system browser). The program's own quick start guide (a small HTML file) is
  shown as text, too, converted by a minimal HTML-to-text routine. The class keeps the members the ported
  code calls. }
unit EmbeddedWB;

{$mode delphi}

interface

uses
  Classes, SysUtils, Variants, Controls, Graphics, StdCtrls, LCLIntf, SynEdit, SynEditHighlighter, SynEditTypes, SynEditMiscClasses,
  HelpHighlighter;

type
  TUserInterfaceOption = (uioNo3DBorder, uioScrollNo);
  TUserInterfaceOptions = set of TUserInterfaceOption;

const
  NO3DBORDER = uioNo3DBorder;
  SCROLL_NO = uioScrollNo;

type
  TDocumentCompleteEvent = procedure(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant) of object;

  TEmbeddedWB = class(TSynEdit)
  private
    FKinds: array of THelpLineKind;
    FLinkURLs: TStringList;            // "line index=URL"
    FOnDocumentComplete: TDocumentCompleteEvent;
    FUserInterfaceOptions: TUserInterfaceOptions;
    FHighlighter: THelpHighlighter;
    FVendorDocs: String;
    function LineKind(LineIndex: Integer): THelpLineKind;
    function GetSql: TSynCustomHighlighter;
    procedure SetSql(Value: TSynCustomHighlighter);
    procedure AddLine(const S: String; Kind: THelpLineKind; const URL: String = '');
    procedure Reset;
    procedure ShowNote(const Title, Text: String);
    procedure AddMarkupText(const Description: String);
  protected
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    { accepts file:// URLs and plain file names (HTML, shown as text) and http(s) URLs (system browser) }
    procedure Navigate(const URL: OleVariant);
    { a topic of the server's help: name, description (first paragraph is the syntax), examples, URL }
    procedure ShowTopic(const Name, Description, Example, URL: String);
    { the original returned the IE automation object; nothing to automate here }
    function OleObject: Variant;
    { the SQL editor's highlighter: the examples are coloured by it }
    property SqlHighlighter: TSynCustomHighlighter read GetSql write SetSql;
    { where the vendor documentation of the connected server is online (named in the "no reference text" note) }
    property VendorDocs: String read FVendorDocs write FVendorDocs;
    property OnDocumentComplete: TDocumentCompleteEvent read FOnDocumentComplete write FOnDocumentComplete;
    property UserInterfaceOptions: TUserInterfaceOptions read FUserInterfaceOptions write FUserInterfaceOptions;
  end;

{ minimal HTML to text: headings, paragraphs, list items, entities; for the program's own small guides }
function HtmlToText(const Html: String): String;

implementation

procedure WrapInto(Target: TStringList; const S: String; Width: Integer);
// wraps a long line at spaces; bullet lines get a hanging indent
var
  Rest, Indent, Head: String;
  P: Integer;
begin
  Rest := S;
  Indent := '';
  if Copy(S, 1, 4) = '  * ' then
    Indent := '    ';
  while Length(Rest) > Width do
  begin
    P := Width;
    while (P > 1) and (Rest[P] <> ' ') do
      Dec(P);
    if P <= Length(Indent) + 1 then
      P := Width;
    Head := Copy(Rest, 1, P);
    Target.Add(TrimRight(Head));
    Rest := Indent + TrimLeft(Copy(Rest, P + 1, MaxInt));
  end;
  Target.Add(Rest);
end;

function DecodeEntities(const S: String): String;
var
  I, J, Code: Integer;
  Name: String;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '&' then
    begin
      J := I + 1;
      while (J <= Length(S)) and (J - I < 10) and (S[J] <> ';') do
        Inc(J);
      if (J <= Length(S)) and (S[J] = ';') then
      begin
        Name := Copy(S, I + 1, J - I - 1);
        if Name = 'amp' then
          Result := Result + '&'
        else if Name = 'lt' then
          Result := Result + '<'
        else if Name = 'gt' then
          Result := Result + '>'
        else if Name = 'quot' then
          Result := Result + '"'
        else if Name = 'nbsp' then
          Result := Result + ' '
        else if (Length(Name) > 1) and (Name[1] = '#') then
        begin
          Code := StrToIntDef(Copy(Name, 2, MaxInt), 0);
          if Code > 0 then
            Result := Result + UTF8Encode(WideChar(Code));
        end
        else
          Result := Result + Copy(S, I, J - I + 1);
        I := J + 1;
        Continue;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

function IsBlockTag(const Tag: String): Boolean;
begin
  Result := (Tag = 'P') or (Pos('P ', Tag) = 1) or (Tag = '/P') or (Pos('BR', Tag) = 1) or (Tag = 'UL') or
    (Tag = 'OL') or (Tag = '/UL') or (Tag = '/OL') or (Tag = '/LI') or (Tag = 'LI') or (Pos('LI ', Tag) = 1) or
    (Pos('H', Tag) = 1) and (Length(Tag) >= 2) and (Tag[2] in ['1'..'6']) or
    (Pos('/H', Tag) = 1) and (Length(Tag) >= 3) and (Tag[3] in ['1'..'6']);
end;

function HtmlToText(const Html: String): String;
var
  I, P: Integer;
  Tag, Upper, Text, Buf: String;
  InBody, InPre, InHeading: Boolean;
begin
  InHeading := False;
  Upper := UpperCase(Html);
  P := Pos('<BODY', Upper);
  InBody := P = 0;
  if P > 0 then
    I := P
  else
    I := 1;
  Result := '';
  Buf := '';
  InPre := False;
  while I <= Length(Html) do
  begin
    if Html[I] = '<' then
    begin
      P := I;
      while (P <= Length(Html)) and (Html[P] <> '>') do
        Inc(P);
      Tag := UpperCase(Trim(Copy(Html, I + 1, P - I - 1)));
      I := P + 1;
      if Pos('BODY', Tag) = 1 then
        InBody := True
      else
        if InBody then
        begin
          if Tag = 'PRE' then
            InPre := True
          else
            if Tag = '/PRE' then
              InPre := False;
          if IsBlockTag(Tag) then
          begin
            // a heading's text is marked with #1 in front so that the view can set it bold
            if InHeading and (Trim(Buf) <> '') then
              Result := Result + #1;
            Result := Result + Trim(Buf) + #10;
            Buf := '';
            if (Length(Tag) = 2) and (Tag[1] = 'H') then
              InHeading := True
            else
              InHeading := False;
            if (Length(Tag) = 3) and (Pos('/H', Tag) = 1) then
              Result := Result + #10
            else
              if (Tag = 'LI') or (Pos('LI ', Tag) = 1) then
                Buf := '  * ';
          end;
        end;
      Continue;
    end;
    if InBody then
    begin
      if InPre or not (Html[I] in [#9, #10, #13, ' ']) then
        Buf := Buf + Html[I]
      else
        if (Buf <> '') and (Buf[Length(Buf)] <> ' ') then
          Buf := Buf + ' ';
    end;
    Inc(I);
  end;
  Result := Result + Trim(Buf);
  Text := DecodeEntities(Result);
  // the guides are Latin-1 encoded
  Result := '';
  for I := 1 to Length(Text) do
    if Ord(Text[I]) < 128 then
      Result := Result + Text[I]
    else
      Result := Result + UTF8Encode(WideChar(Ord(Text[I])));
  while Pos(#10#10#10, Result) > 0 do
    Result := StringReplace(Result, #10#10#10, #10#10, [rfReplaceAll]);
end;

constructor TEmbeddedWB.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLinkURLs := TStringList.Create;
  ReadOnly := True;
  Gutter.Visible := False;
  Options := Options + [eoHideRightMargin];
  BorderStyle := bsNone;
  Color := clWindow;
  Font.Name := 'Courier New';
  Font.Height := -13;
  ScrollBars := ssAutoBoth;
  FHighlighter := THelpHighlighter.Create(Self);
  FHighlighter.OnGetLineKind := LineKind;
  Highlighter := FHighlighter;
end;

destructor TEmbeddedWB.Destroy;
begin
  FLinkURLs.Free;
  inherited Destroy;
end;

procedure TEmbeddedWB.Loaded;
begin
  inherited Loaded;
end;

procedure TEmbeddedWB.Reset;
begin
  Lines.Clear;
  SetLength(FKinds, 0);
  FLinkURLs.Clear;
end;

procedure TEmbeddedWB.AddLine(const S: String; Kind: THelpLineKind; const URL: String);
begin
  Lines.Add(S);
  SetLength(FKinds, Length(FKinds) + 1);
  FKinds[High(FKinds)] := Kind;
  if URL <> '' then
    FLinkURLs.Values[IntToStr(High(FKinds))] := URL;
end;

function TEmbeddedWB.GetSql: TSynCustomHighlighter;
begin
  Result := FHighlighter.SqlHighlighter;
end;

procedure TEmbeddedWB.SetSql(Value: TSynCustomHighlighter);
begin
  FHighlighter.SqlHighlighter := Value;
  Invalidate;
end;

function TEmbeddedWB.LineKind(LineIndex: Integer): THelpLineKind;
begin
  if (LineIndex >= 0) and (LineIndex < Length(FKinds)) then
    Result := FKinds[LineIndex]
  else
    Result := hlProse;
end;

procedure TEmbeddedWB.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Line: Integer;
  URL: String;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then
    Exit;
  Line := PixelsToRowColumn(Point(X, Y)).Y;       // one based
  if (Line >= 1) and (Line <= Length(FKinds)) and (FKinds[Line - 1] = hlLink) then
  begin
    URL := FLinkURLs.Values[IntToStr(Line - 1)];
    if URL <> '' then
      LCLIntf.OpenURL(URL);
  end;
end;

function IsUnderline(const S: String): Boolean;
// the "-----" line below a heading (MariaDB's texts are written like that)
var
  I: Integer;
begin
  Result := Length(Trim(S)) >= 3;
  for I := 1 to Length(S) do
    if S[I] <> '-' then
      Exit(False);
end;

function IsTableLine(const S: String): Boolean;
begin
  Result := (Copy(S, 1, 2) = '+-') or (Copy(S, 1, 2) = '| ') or (Copy(S, 1, 2) = '|-');
end;

function StartsStatement(const S: String): Boolean;
const
  Words: array[0..17] of String = ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'ALTER', 'SET', 'SHOW',
    'WITH', 'CALL', 'USE', 'EXPLAIN', 'REPLACE', 'GRANT', 'TRUNCATE', 'DESC', 'LOAD');
var
  I, P: Integer;
  W: String;
begin
  P := Pos(' ', S);
  if P = 0 then
    P := Length(S) + 1;
  W := Copy(S, 1, P - 1);
  Result := False;
  for I := Low(Words) to High(Words) do
    if W = Words[I] then
      Exit(True);
end;

procedure TEmbeddedWB.AddMarkupText(const Description: String);

// MariaDB's help texts are small documents: "Title" lines underlined with dashes, SQL statements with their
// result tables, prose paragraphs.

var
  L: TStringList;
  I, J: Integer;
  Section: String;
  InSql, ParaStart, Found: Boolean;
begin
  L := TStringList.Create;
  try
    L.Text := StringReplace(Description, #13#10, #10, [rfReplaceAll]);
    Section := '';
    InSql := False;
    ParaStart := True;
    I := 0;
    while I < L.Count do
    begin
      if (Trim(L[I]) <> '') and (I + 1 < L.Count) and IsUnderline(L[I + 1]) and not IsTableLine(L[I]) then
      begin
        AddLine(L[I], hlHeading);
        Section := Trim(L[I]);
        Inc(I, 2);
        InSql := False;
        ParaStart := False;
        Continue;
      end;
      if Trim(L[I]) = '' then
      begin
        AddLine('', hlProse);
        InSql := False;
        ParaStart := True;
      end
      else
        if Copy(L[I], 1, 5) = 'URL: ' then
          // shown as a link at the end instead
        else
          if IsTableLine(L[I]) then
          begin
            AddLine(L[I], hlTable);
            InSql := False;
            ParaStart := False;
          end
          else
          begin
            if SameText(Section, 'Syntax') then
              AddLine(L[I], hlCode)
            else
            begin
              if ParaStart and StartsStatement(L[I]) then
              begin
                // a statement if some line of the paragraph ends with the delimiter
                Found := False;
                J := I;
                while (J < L.Count) and (Trim(L[J]) <> '') and not IsTableLine(L[J]) do
                begin
                  if Copy(TrimRight(L[J]), Length(TrimRight(L[J])), 1) = ';' then
                    Found := True;
                  Inc(J);
                end;
                InSql := Found;
              end;
              if InSql then
                AddLine(L[I], hlSql)
              else
                AddLine(L[I], hlProse);
            end;
            ParaStart := False;
          end;
      Inc(I);
    end;
  finally
    L.Free;
  end;
end;

procedure TEmbeddedWB.ShowTopic(const Name, Description, Example, URL: String);
var
  Para: TStringList;
  I, J: Integer;
  Kind: THelpLineKind;
begin
  BeginUpdate;
  try
    Reset;
    AddLine(Name, hlHeading);
    AddLine('', hlProse);

    if (Pos(#10 + '------', Description) > 0) or (Pos('Syntax' + #10 + '---', Description) = 1) then
      AddMarkupText(Description)
    else
    begin
    // The server texts are hard wrapped plain text. The first paragraph is the syntax; later paragraphs
    // that start with an indent (grammar continuation, tables) are shown as code, the rest as prose.
    Para := TStringList.Create;
    try
      Para.Text := StringReplace(Description, #13#10, #10, [rfReplaceAll]);
      I := 0;
      while I < Para.Count do
      begin
        J := I;
        while (J < Para.Count) and (Trim(Para[J]) <> '') do
          Inc(J);
        if J > I then
        begin
          if I = 0 then
            Kind := hlCode
          else
            if Copy(Para[I], 1, 1) = ' ' then
              Kind := hlCode
            else
              Kind := hlProse;
          // the server appends its own "URL: ..." line; the link is shown at the end instead
          if (J = I + 1) and (Copy(Para[I], 1, 5) = 'URL: ') then
            I := J
          else
          begin
            while I < J do
            begin
              if Trim(Para[I]) = 'Syntax:' then
                AddLine(Para[I], hlHeading)
              else
                AddLine(Para[I], Kind);
              Inc(I);
            end;
            AddLine('', hlProse);
          end;
        end;
        while (I < Para.Count) and (Trim(Para[I]) = '') do
          Inc(I);
      end;
    finally
      Para.Free;
    end;
    end;

    if Trim(Example) <> '' then
    begin
      AddLine('Examples', hlHeading);
      AddLine('', hlProse);
      Para := TStringList.Create;
      try
        Para.Text := StringReplace(Example, #13#10, #10, [rfReplaceAll]);
        for I := 0 to Para.Count - 1 do
          AddLine(Para[I], hlExample);
      finally
        Para.Free;
      end;
      AddLine('', hlProse);
    end;

    if URL <> '' then
    begin
      AddLine('Full documentation (opens in the browser):', hlProse);
      AddLine(URL, hlLink, URL);
    end;
  finally
    EndUpdate;
  end;
  TopLine := 1;
  CaretXY := Point(1, 1);
end;

procedure TEmbeddedWB.ShowNote(const Title, Text: String);
var
  L: TStringList;
  I: Integer;
begin
  BeginUpdate;
  try
    Reset;
    AddLine(Title, hlHeading);
    AddLine('', hlProse);
    L := TStringList.Create;
    try
      L.Text := Text;
      for I := 0 to L.Count - 1 do
        AddLine(L[I], hlProse);
    finally
      L.Free;
    end;
  finally
    EndUpdate;
  end;
end;

procedure TEmbeddedWB.Navigate(const URL: OleVariant);
var
  S, Raw: String;
  P, I, J: Integer;
  FS: TFileStream;
  L, Wrapped: TStringList;
begin
  S := VarToStr(URL);
  if (Pos('http://', LowerCase(S)) = 1) or (Pos('https://', LowerCase(S)) = 1) then
  begin
    LCLIntf.OpenURL(S);
    Exit;
  end;
  if Pos('file://', LowerCase(S)) = 1 then
    Delete(S, 1, 7);
  P := Pos('#', S);
  if P > 0 then
    S := Copy(S, 1, P - 1);
  S := StringReplace(S, '\', '/', [rfReplaceAll]);
  if not FileExists(S) then
  begin
    ShowNote('No reference text', 'The reference text for this entry is not available. It comes from the' + #10 +
      'help tables of the connected server; this server has none or does not allow reading them.' + #10#10 +
      'The vendor documentation is online: ' + FVendorDocs);
    Exit;
  end;
  FS := TFileStream.Create(S, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Raw, FS.Size);
    if FS.Size > 0 then
      FS.ReadBuffer(Raw[1], FS.Size);
  finally
    FS.Free;
  end;
  L := TStringList.Create;
  try
    L.Text := HtmlToText(Raw);
    BeginUpdate;
    try
      Reset;
      Wrapped := TStringList.Create;
      try
        for I := 0 to L.Count - 1 do
        begin
          if (L[I] <> '') and (L[I][1] = #1) then
            AddLine(Copy(L[I], 2, MaxInt), hlHeading)
          else
          begin
            Wrapped.Clear;
            WrapInto(Wrapped, L[I], 90);
            for J := 0 to Wrapped.Count - 1 do
              AddLine(Wrapped[J], hlProse);
          end;
        end;
      finally
        Wrapped.Free;
      end;
    finally
      EndUpdate;
    end;
  finally
    L.Free;
  end;
  TopLine := 1;
end;

function TEmbeddedWB.OleObject: Variant;
begin
  Result := Unassigned;
end;

end.
