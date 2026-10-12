{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replacement for the EmbeddedWB Internet Explorer wrapper that the Query Browser used for its
  HTML help pane (syntax, functions, parameters). The LCL has no web browser control; the help
  pages (app/bin/doc/*.html, a MySQL 5.0 manual extract in plain HTML) are shown with the IpHtml
  viewer from Lazarus' TurboPower Internet Professional package. It keeps the members the ported
  code calls.
  ROADMAP: the reference text is MySQL 5.0; version/vendor specific reference packs are an open
  question (see ADR-0013). }
unit EmbeddedWB;

{$mode delphi}

interface

uses
  Classes, SysUtils, Variants, Controls, ExtCtrls, IpHtml, IpFileBroker, LCLIntf;

type
  TUserInterfaceOption = (uioNo3DBorder, uioScrollNo);
  TUserInterfaceOptions = set of TUserInterfaceOption;

const
  NO3DBORDER = uioNo3DBorder;
  SCROLL_NO = uioScrollNo;

type
  TDocumentCompleteEvent = procedure(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant) of object;

  { Links with an anchor are not handled by the file provider but reported through OnHotClick, so that
    TEmbeddedWB can show just the addressed section (see Navigate) }
  TDocFileProvider = class(TIpFileDataProvider)
  public
    function CanHandle(const URL: string): Boolean; override;
  end;

  TEmbeddedWB = class(TIpHtmlPanel)
  private
    FCurFile: String;
    FFileText: String;
    FFileName: String;
    procedure ShowSection(const FileName, Anchor: String);
    procedure DoLinkClick(Sender: TObject);
  private
    FOnDocumentComplete: TDocumentCompleteEvent;
    FUserInterfaceOptions: TUserInterfaceOptions;
    FProvider: TDocFileProvider;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    { accepts file:// URLs (with #anchor) and plain file names }
    procedure Navigate(const URL: OleVariant);
    { shows HTML text (UTF-8) that the program made itself }
    procedure ShowHtml(const Html: String);
    { the original returned the IE automation object; nothing to automate here }
    function OleObject: Variant;
    property OnDocumentComplete: TDocumentCompleteEvent read FOnDocumentComplete write FOnDocumentComplete;
    property UserInterfaceOptions: TUserInterfaceOptions read FUserInterfaceOptions write FUserInterfaceOptions;
  end;

implementation

const
  // IpHtml lays out roughly 10 KB of these pages per second; the reference files are 280-380 KB, so
  // only the addressed section is shown.
  SectionLimit = 24000;
  FileLimit = 40000;

function DecodePreEntities(const Html: String): String;
// IpHtml does not decode entities inside <PRE>; do it here for the characters these pages use.
var
  Upper, Block: String;
  P, Q: Integer;
begin
  Result := '';
  Upper := UpperCase(Html);
  P := 1;
  while P <= Length(Html) do
  begin
    Q := Pos('<PRE>', Copy(Upper, P, MaxInt));
    if Q = 0 then
      Break;
    Inc(Q, P - 1);
    Result := Result + Copy(Html, P, Q - P);
    P := Pos('</PRE>', Copy(Upper, Q, MaxInt));
    if P = 0 then
      P := Length(Html) + 1
    else
      P := Q + P - 1;
    Block := Copy(Html, Q, P - Q);
    Block := StringReplace(Block, '&#62;', '>', [rfReplaceAll]);
    Block := StringReplace(Block, '&gt;', '>', [rfReplaceAll]);
    Block := StringReplace(Block, '&#60; ', '< ', [rfReplaceAll]);
    Block := StringReplace(Block, '&#60;=', '<=', [rfReplaceAll]);
    Block := StringReplace(Block, '&lt; ', '< ', [rfReplaceAll]);
    Block := StringReplace(Block, '&lt;=', '<=', [rfReplaceAll]);
    Block := StringReplace(Block, '&#38;', '&', [rfReplaceAll]);
    Block := StringReplace(Block, '&amp;', '&', [rfReplaceAll]);
    Result := Result + Block;
  end;
  Result := Result + Copy(Html, P, MaxInt);
end;

function TDocFileProvider.CanHandle(const URL: string): Boolean;
begin
  Result := (Pos('#', URL) = 0) and inherited CanHandle(URL);
end;

constructor TEmbeddedWB.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProvider := TDocFileProvider.Create(Self);
  DataProvider := FProvider;
  BorderStyle := bsNone;
  OnHotClick := DoLinkClick;
end;

destructor TEmbeddedWB.Destroy;
begin
  DataProvider := nil;
  FreeAndNil(FProvider);
  inherited Destroy;
end;

procedure TEmbeddedWB.Loaded;
begin
  inherited Loaded;
end;

procedure TEmbeddedWB.Navigate(const URL: OleVariant);
var
  S: String;
  Anchor: String;
  P: Integer;
  Info: TSearchRec;
  Big: Boolean;
begin
  S := VarToStr(URL);
  if Pos('file://', LowerCase(S)) = 1 then
    Delete(S, 1, 7);
  Anchor := '';
  P := Pos('#', S);
  if P > 0 then
  begin
    Anchor := Copy(S, P + 1, MaxInt);
    S := Copy(S, 1, P - 1);
  end;
  S := StringReplace(S, '\', '/', [rfReplaceAll]);
  FCurFile := S;

  Big := False;
  if FindFirst(S, faAnyFile, Info) = 0 then
  begin
    Big := Info.Size > FileLimit;
    FindClose(Info);
  end;
  if Big and (Anchor <> '') then
    ShowSection(S, Anchor)
  else
  begin
    if Anchor <> '' then
      Anchor := '#' + Anchor;
    OpenURL(S + Anchor);
  end;
end;

procedure TEmbeddedWB.ShowSection(const FileName, Anchor: String);
var
  Upper: String;
  A, StartPos, EndPos, Q: Integer;
  Stream: TStringStream;
  Html: String;
  FS: TFileStream;
begin
  if FFileName <> FileName then
  begin
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(FFileText, FS.Size);
      if FS.Size > 0 then
        FS.ReadBuffer(FFileText[1], FS.Size);
    finally
      FS.Free;
    end;
    FFileName := FileName;
  end;

  Upper := UpperCase(FFileText);
  A := Pos('NAME="' + UpperCase(Anchor) + '"', Upper);
  if A = 0 then
    A := 1;

  // start at the closest heading before the anchor, or a little before the anchor
  StartPos := A;
  while (StartPos > 1) and (A - StartPos < SectionLimit) and
    not ((Copy(Upper, StartPos, 2) = '<H') and (Upper[StartPos + 2] in ['1'..'6'])) do
    Dec(StartPos);
  if A - StartPos >= SectionLimit then
  begin
    StartPos := A - 4000;
    if StartPos < 1 then
      StartPos := 1;
    Q := StartPos;
    while (Q < A) and (Copy(Upper, Q, 3) <> '<P>') do
      Inc(Q);
    if Q < A then
      StartPos := Q;
  end;

  // end at the next heading, at most SectionLimit characters later (on a paragraph end)
  EndPos := A + 1;
  while (EndPos < Length(Upper)) and (EndPos - A < SectionLimit) and
    not ((Copy(Upper, EndPos, 2) = '<H') and (Upper[EndPos + 2] in ['1'..'6'])) do
    Inc(EndPos);
  if (EndPos < Length(Upper)) and (EndPos - A >= SectionLimit) then
  begin
    Q := Pos('</P>', Copy(Upper, EndPos, MaxInt));
    if (Q > 0) and (Q < 4000) then
      Inc(EndPos, Q + 3);
  end;

  Html := '<HTML><HEAD><TITLE></TITLE></HEAD><BODY>' + Copy(FFileText, StartPos, EndPos - StartPos) +
    '</BODY></HTML>';
  Html := DecodePreEntities(Html);
  Stream := TStringStream.Create(Html);
  try
    SetHtmlFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TEmbeddedWB.DoLinkClick(Sender: TObject);
var
  U, FileName: String;
  P: Integer;
begin
  U := HotURL;
  if (Pos('http://', LowerCase(U)) = 1) or (Pos('https://', LowerCase(U)) = 1) then
  begin
    LCLIntf.OpenURL(U);      // the system browser
    Exit;
  end;
  P := Pos('#', U);
  if P = 0 then
    Exit;
  FileName := Copy(U, 1, P - 1);
  // keep the file part's name only; the pages live in one folder
  P := LastDelimiter('/\', FileName);
  if P > 0 then
    FileName := Copy(FileName, P + 1, MaxInt);
  if FileName <> '' then
    FileName := ExtractFilePath(FCurFile) + FileName
  else
    FileName := FCurFile;
  if FileExists(FileName) then
    Navigate(FileName + Copy(U, Pos('#', U), MaxInt));
end;

procedure TEmbeddedWB.ShowHtml(const Html: String);
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create(DecodePreEntities(Html));
  try
    SetHtmlFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TEmbeddedWB.OleObject: Variant;
begin
  Result := Unassigned;
end;

end.
