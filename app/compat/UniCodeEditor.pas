{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Compatibility layer for Mike Zinner's / Mike Lischke's UniCodeEditor (ADR-0012), implemented on
  SynEdit. It offers the members the ported Query Browser code uses, with the original names and
  the original conventions (lines and columns are ZERO based, SynEdit's are one based);
  members are added when the compiler asks for them, not speculatively.

  The original UniCodeEditor is released under the MIT licence (see NOTICE). }
unit UniCodeEditor;

{$mode delphi}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Clipbrd, LazUTF8, SynEdit, SynEditTypes, SynEditKeyCmds,
  SynEditMiscClasses, SynEditMarks, SynEditPointClasses, LCLType, SynGutterBase, LazSynEditText, UCEShared;

type
  // Option names of the original; applied to SynEdit where there is an equivalent (see ApplyOptions)
  TUniCodeEditOption = (
    eoAutoExtendWorkWidth, eoAutoIndent, eoAutoUnindent, eoCursorThroughTabs, eoGroupUndo, eoHideSelection,
    eoInserting, eoKeepTrailingBlanks, eoLineNumbers, eoLineNumbersZeroBased, eoOptimalFill, eoReadOnly,
    eoReadOnlySelection, eoScrollPastEOL, eoShowControlChars, eoShowCursorWhileReadOnly, eoShowScrollHint,
    eoSmartTabs, eoTripleClicks, eoUndoAfterSave, eoUseUndoRedo, eoUseTabs, eoUseSyntaxHighlighting, eoWantTabs);
  TUniCodeEditOptions = set of TUniCodeEditOption;

const
  DefaultOptions = [eoAutoExtendWorkWidth, eoAutoIndent, eoAutoUnindent, eoCursorThroughTabs, eoGroupUndo,
    eoHideSelection, eoInserting, eoScrollPastEOL, eoSmartTabs, eoTripleClicks, eoUseSyntaxHighlighting, eoWantTabs];

const
  ctVerticalLine = SynEditPointClasses.ctVerticalLine;
  ctHorizontalLine = SynEditPointClasses.ctHorizontalLine;
  ctHalfBlock = SynEditPointClasses.ctHalfBlock;
  ctBlock = SynEditPointClasses.ctBlock;

type
  TReplaceAction = (raCancel, raSkip, raReplace, raReplaceAll);

  // The format of the text to load or write.
  TTextFormat = (tfANSI, tfUTF8, tfUTF16, tfUTF16LE, tfUTF16BE);

  TSearchOption = (soBackwards, soEntireScope, soIgnoreNonSpacing, soMatchCase, soPrompt, soRegularExpression,
    soReplace, soReplaceAll, soSelectedOnly, soSpaceCompress, soWholeWord);
  TSearchOptions = set of TSearchOption;

  TCustomUnicodeEdit = class;
  TUCEContent = class;

  TUCELineState = (lsValidated);
  TUCELineStates = set of TUCELineState;

  { One line of the content. Unlike SynEdit's plain strings the original keeps per-line data, states,
    styles and gutter markers; the objects are created on demand and follow their line when lines are
    inserted or deleted. }
  TUCELine = class
  private
    FOwner: TUCEContent;
    FIndex: Integer;
    FData: TObject;
    FStates: TUCELineStates;
    FStyles: TInterfaceList;
    FMarkers: TInterfaceList;
    function GetText: WideString;
    procedure SetText(const Value: WideString);
  public
    constructor Create(AOwner: TUCEContent; AIndex: Integer);
    destructor Destroy; override;
    procedure AddMarker(const Marker: IUCELineMarker);
    procedure RemoveMarker(const Marker: IUCELineMarker);
    procedure ClearMarkers;
    procedure ReplaceMarker(const OldMarker, NewMarker: IUCELineMarker);
    procedure PushStyle(const Style: IUCELineStyle);
    procedure RemoveStyle(const Style: IUCELineStyle);
    procedure Invalidate;
    property Data: TObject read FData write FData;
    property Index: Integer read FIndex;
    property States: TUCELineStates read FStates;
    property Text: WideString read GetText write SetText;
  end;

  TUCELineEvent = procedure(Sender: TObject; Line: TUCELine) of object;

  { The original's TUCEContent/line list: the part of its API that is used }
  TUCEContent = class
  private
    FEdit: TCustomUnicodeEdit;
    FLines: TList;                      // TUCELine or nil, parallel to the editor's lines
    FOnChangeLine: TUCELineEvent;
    FOnDeleteLine: TUCELineEvent;
    FOnValidateLine: TUCELineEvent;
    function GetCount: Integer;
    function GetText: WideString;
    procedure SetText(const Value: WideString);
    function GetItem(Index: Integer): TUCELine;
    function GetLineNoInit(Index: Integer): TUCELine;
    procedure LineCountChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
    procedure LineChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
    procedure LinesCleared(Sender: TObject);
    procedure RemoveLines(AIndex, ACount: Integer);
    procedure Renumber(From: Integer);
  public
    constructor Create(AEdit: TCustomUnicodeEdit);
    destructor Destroy; override;
    procedure AddLine(const S: WideString);
    procedure DeleteLine(Index: Integer);
    procedure Clear;
    { text between two zero based positions, end excluded, lines separated by CR LF }
    function CollectTextFromPosition(Start, Stop: TPoint): WideString;
    { the line object if it exists, otherwise nil }
    function PeekLine(Index: Integer): TUCELine;
    property Count: Integer read GetCount;
    property Text: WideString read GetText write SetText;
    { validates the line on first access (OnValidateLine) }
    property Items[Index: Integer]: TUCELine read GetItem; default;
    { like Items but without validation }
    property LineNoInit[Index: Integer]: TUCELine read GetLineNoInit;
    property OnChangeLine: TUCELineEvent read FOnChangeLine write FOnChangeLine;
    property OnDeleteLine: TUCELineEvent read FOnDeleteLine write FOnDeleteLine;
    property OnValidateLine: TUCELineEvent read FOnValidateLine write FOnValidateLine;
  end;

  { colour pair of the original (scroll hint, selection) }
  TUCEColors = class(TPersistent)
  private
    FForeground, FBackground: TColor;
  published
    property Foreground: TColor read FForeground write FForeground;
    property Background: TColor read FBackground write FBackground;
  end;

  TUCEProcessCommandEvent = procedure(Sender: TCustomUnicodeEdit; var Command: TSynEditorCommand;
    var AChar: WideChar; Data: Pointer) of object;
  TUCECaretEvent = procedure(Sender: TCustomUnicodeEdit; X, Y: Integer) of object;
  TUCEGutterMouseEvent = procedure(Sender: TCustomUnicodeEdit; Button: TMouseButton; Shift: TShiftState;
    X, Y, Line: Integer) of object;

  { Gutter part drawing the markers of the lines (IUCELineMarker) }
  TUCEGutterMarkers = class(TSynGutterPartBase)
  protected
    function PreferedWidth: Integer; override;
  public
    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: Integer); override;
  end;

  TUCEScrollEvent = procedure(Sender: TCustomUnicodeEdit; DeltaX, DeltaY: Integer) of object;

  TCustomUnicodeEdit = class(TSynEdit)
  private
    FContent: TUCEContent;
    FOnScroll: TUCEScrollEvent;
    FLastTopLine, FLastLeftChar: Integer;
    FUCEOptions: TUniCodeEditOptions;
    FOnProcessUserCommand: TUCEProcessCommandEvent;
    FOnGutterMouseDown: TUCEGutterMouseEvent;
    FScrollHintColor: TUCEColors;
    FLineNumberFont: TFont;
    FCharWidth: Integer;
    FGutterWidth: Integer;
    FRightMargin: Integer;
    FDefaultStyle: IUCELineStyle;
    FOnCaretChange: TUCECaretEvent;
    FLastCaret: TPoint;
    procedure SetSelectedText(const Value: WideString);
    function GetGutterColor: TColor;
    procedure SetGutterColor(const Value: TColor);
    function GetBlockBegin: TPoint;
    procedure SetBlockBegin(const Value: TPoint);
    function GetBlockEnd: TPoint;
    procedure SetBlockEnd(const Value: TPoint);
    function GetSelectionAvailable: Boolean;
    function GetTabSize: Integer;
    procedure SetTabSize(const Value: Integer);
    procedure SetRightMargin(const Value: Integer);
    procedure SetGutterWidth(const Value: Integer);
    procedure UserCommandBridge(Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer);
    procedure GutterClickBridge(Sender: TObject; X, Y, Line: Integer; Mark: TSynEditMark);
    procedure SpecialLineBridge(Sender: TObject; Line: Integer; var Special: Boolean; Markup: TSynSelectedColor);
    function GetOffsetY: Integer;
    procedure SetOffsetY(const Value: Integer);
    function GetUCECaretX: Integer;
    procedure SetUCECaretX(const Value: Integer);
    function GetUCECaretY: Integer;
    procedure SetUCECaretY(const Value: Integer);
    function GetUCECaretXY: TPoint;
    procedure SetUCECaretXY(const Value: TPoint);
    function GetSelectedText: WideString;
    procedure SetUCEOptions(const Value: TUniCodeEditOptions);
    procedure ApplyOptions;
    procedure StatusChanged(Sender: TObject; Changes: TSynStatusChanges);
  protected
    { UCE column/line are zero based; the line is clamped to the existing lines }
    procedure SetCaretToEditorBottom;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefreshLine(Index: Integer);
    { the editor's line buffer with change notifications }
    function LinkedLines: TSynEditStringsLinked;
    procedure InsertText(const S: WideString);
    { number of replacements/matches, like SynEdit's SearchReplace but with the original's options }
    function SearchReplace(const ASearch, AReplace: WideString; AOptions: TSearchOptions): Integer; overload;
    function TextFromClipboard: WideString;
    property CaretX: Integer read GetUCECaretX write SetUCECaretX;
    property CaretY: Integer read GetUCECaretY write SetUCECaretY;
    property CaretXY: TPoint read GetUCECaretXY write SetUCECaretXY;
    property SelectedText: WideString read GetSelectedText write SetSelectedText;
    { text lines of the editor }
    property Content: TUCEContent read FContent;
    { first visible line, zero based }
    property OffsetY: Integer read GetOffsetY write SetOffsetY;
    property OnScroll: TUCEScrollEvent read FOnScroll write FOnScroll;
    property Options: TUniCodeEditOptions read FUCEOptions write SetUCEOptions;
    { selection start and end, zero based (SynEdit's are one based) }
    property BlockBegin: TPoint read GetBlockBegin write SetBlockBegin;
    property BlockEnd: TPoint read GetBlockEnd write SetBlockEnd;
    property SelectionAvailable: Boolean read GetSelectionAvailable;
    property TabSize: Integer read GetTabSize write SetTabSize;
    { stored for the original's option page; SynEdit has no fixed character width }
    property CharWidth: Integer read FCharWidth write FCharWidth;
    property GutterWidth: Integer read FGutterWidth write SetGutterWidth;
    property RightMargin: Integer read FRightMargin write SetRightMargin;
    property ScrollHintColor: TUCEColors read FScrollHintColor;
    { stored only: SynEdit draws line numbers in the editor font (see ADR-0012 review list) }
    property LineNumberFont: TFont read FLineNumberFont;
    property OnProcessUserCommand: TUCEProcessCommandEvent read FOnProcessUserCommand write FOnProcessUserCommand;
    property OnGutterMouseDown: TUCEGutterMouseEvent read FOnGutterMouseDown write FOnGutterMouseDown;
    property OnCaretChange: TUCECaretEvent read FOnCaretChange write FOnCaretChange;
    { style of the lines that have no style of their own }
    property DefaultStyle: IUCELineStyle read FDefaultStyle write FDefaultStyle;
    property GutterColor: TColor read GetGutterColor write SetGutterColor;
    { positions the caret Offset characters behind the zero based position Start (line breaks count 2) }
    procedure CaretOffset(Start: TPoint; Offset: Integer);
    procedure ClearAll(ClearUndoList: Boolean); overload;
    procedure LoadFromFile(const AFileName: WideString; Format: TTextFormat); overload;
    procedure SaveToFile(const AFileName: WideString; Format: TTextFormat); overload;
  end;

  TUniCodeEdit = class(TCustomUnicodeEdit)
  end;

implementation

{ TUCELine }

constructor TUCELine.Create(AOwner: TUCEContent; AIndex: Integer);
begin
  inherited Create;
  FOwner := AOwner;
  FIndex := AIndex;
end;

destructor TUCELine.Destroy;
begin
  FStyles.Free;
  FMarkers.Free;
  inherited Destroy;
end;

function TUCELine.GetText: WideString;
begin
  Result := UTF8Decode(FOwner.FEdit.Lines[FIndex]);
end;

procedure TUCELine.SetText(const Value: WideString);
begin
  FOwner.FEdit.Lines[FIndex] := UTF8Encode(Value);     // the change handler reports it to OnChangeLine
end;

procedure TUCELine.AddMarker(const Marker: IUCELineMarker);
begin
  if FMarkers = nil then
    FMarkers := TInterfaceList.Create;
  FMarkers.Add(Marker);
  FOwner.FEdit.RefreshLine(FIndex);
end;

procedure TUCELine.RemoveMarker(const Marker: IUCELineMarker);
begin
  if FMarkers <> nil then
    FMarkers.Remove(Marker);
  FOwner.FEdit.RefreshLine(FIndex);
end;

procedure TUCELine.ClearMarkers;
begin
  if FMarkers <> nil then
  begin
    FMarkers.Clear;
    FOwner.FEdit.RefreshLine(FIndex);
  end;
end;

procedure TUCELine.ReplaceMarker(const OldMarker, NewMarker: IUCELineMarker);
var
  I: Integer;
begin
  if FMarkers <> nil then
  begin
    I := FMarkers.IndexOf(OldMarker);
    if I >= 0 then
    begin
      FMarkers[I] := NewMarker;
      FOwner.FEdit.RefreshLine(FIndex);
      Exit;
    end;
  end;
  AddMarker(NewMarker);
end;

procedure TUCELine.PushStyle(const Style: IUCELineStyle);
begin
  if FStyles = nil then
    FStyles := TInterfaceList.Create;
  FStyles.Add(Style);
  FOwner.FEdit.RefreshLine(FIndex);
end;

procedure TUCELine.RemoveStyle(const Style: IUCELineStyle);
begin
  if FStyles <> nil then
    FStyles.Remove(Style);
  FOwner.FEdit.RefreshLine(FIndex);
end;

procedure TUCELine.Invalidate;
begin
  Exclude(FStates, lsValidated);
end;

{ TUCEContent }

constructor TUCEContent.Create(AEdit: TCustomUnicodeEdit);
begin
  inherited Create;
  FEdit := AEdit;
  FLines := TList.Create;
  FEdit.LinkedLines.AddChangeHandler(senrLineCount, LineCountChanged);
  FEdit.LinkedLines.AddChangeHandler(senrLineChange, LineChanged);
  FEdit.LinkedLines.AddNotifyHandler(senrCleared, LinesCleared);
end;

destructor TUCEContent.Destroy;
var
  I: Integer;
begin
  for I := 0 to FLines.Count - 1 do
    TUCELine(FLines[I]).Free;
  FLines.Free;
  inherited Destroy;
end;

function TUCEContent.GetCount: Integer;
begin
  Result := FEdit.Lines.Count;
end;

function TUCEContent.GetText: WideString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FEdit.Lines.Count - 1 do
  begin
    if I > 0 then
      Result := Result + #13#10;
    Result := Result + UTF8Decode(FEdit.Lines[I]);
  end;
end;

procedure TUCEContent.SetText(const Value: WideString);
begin
  FEdit.Lines.Text := UTF8Encode(Value);
end;

function TUCEContent.PeekLine(Index: Integer): TUCELine;
begin
  if (Index >= 0) and (Index < FLines.Count) then
    Result := TUCELine(FLines[Index])
  else
    Result := nil;
end;

function TUCEContent.GetLineNoInit(Index: Integer): TUCELine;
begin
  if (Index < 0) or (Index >= FEdit.Lines.Count) then
    raise EListError.CreateFmt('Line index %d out of bounds', [Index]);
  while FLines.Count <= Index do
    FLines.Add(nil);
  if FLines[Index] = nil then
    FLines[Index] := TUCELine.Create(Self, Index);
  Result := TUCELine(FLines[Index]);
end;

function TUCEContent.GetItem(Index: Integer): TUCELine;
begin
  Result := GetLineNoInit(Index);
  if not (lsValidated in Result.FStates) then
  begin
    Include(Result.FStates, lsValidated);
    if Assigned(FOnValidateLine) then
      FOnValidateLine(Self, Result);
  end;
end;

procedure TUCEContent.Renumber(From: Integer);
var
  I: Integer;
begin
  for I := From to FLines.Count - 1 do
    if FLines[I] <> nil then
      TUCELine(FLines[I]).FIndex := I;
end;

procedure TUCEContent.RemoveLines(AIndex, ACount: Integer);
var
  I: Integer;
  Line: TUCELine;
begin
  for I := AIndex + ACount - 1 downto AIndex do
    if I < FLines.Count then
    begin
      Line := TUCELine(FLines[I]);
      if Line <> nil then
      begin
        if Assigned(FOnDeleteLine) then
          FOnDeleteLine(Self, Line);
        Line.Free;
      end;
      FLines.Delete(I);
    end;
  Renumber(AIndex);
end;

procedure TUCEContent.LineCountChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
var
  I: Integer;
begin
  if ACount > 0 then
  begin
    while FLines.Count < AIndex do
      FLines.Add(nil);
    for I := 1 to ACount do
      FLines.Insert(AIndex, nil);
    Renumber(AIndex);
  end
  else if ACount < 0 then
    RemoveLines(AIndex, -ACount);
end;

procedure TUCEContent.LineChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
var
  I: Integer;
begin
  if not Assigned(FOnChangeLine) then
    Exit;
  for I := AIndex to AIndex + ACount - 1 do
    if (I >= 0) and (I < FLines.Count) and (FLines[I] <> nil) then
      FOnChangeLine(Self, TUCELine(FLines[I]));
end;

procedure TUCEContent.LinesCleared(Sender: TObject);
begin
  RemoveLines(0, FLines.Count);
end;

function TUCEContent.CollectTextFromPosition(Start, Stop: TPoint): WideString;
var
  Y: Integer;
  S: WideString;
begin
  Result := '';
  for Y := Start.Y to Stop.Y do
  begin
    S := UTF8Decode(FEdit.Lines[Y]);
    if Y = Stop.Y then
      S := Copy(S, 1, Stop.X);
    if Y = Start.Y then
      S := Copy(S, Start.X + 1, MaxInt);
    Result := Result + S;
    if Y < Stop.Y then
      Result := Result + #13#10;
  end;
end;

procedure TUCEContent.AddLine(const S: WideString);
begin
  FEdit.Lines.Add(UTF8Encode(S));
end;

procedure TUCEContent.DeleteLine(Index: Integer);
begin
  FEdit.Lines.Delete(Index);
end;

procedure TUCEContent.Clear;
begin
  FEdit.Lines.Clear;
end;

{ TUCEGutterMarkers }

function TUCEGutterMarkers.PreferedWidth: Integer;
begin
  Result := 16;
end;

procedure TUCEGutterMarkers.Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: Integer);
var
  Edit: TCustomUnicodeEdit;
  I, Line, K, X, LineCount: Integer;
  Top: Integer;
  UL: TUCELine;
begin
  if not Visible then
    Exit;
  PaintBackground(Canvas, AClip);
  Edit := TCustomUnicodeEdit(SynEdit);
  LineCount := Edit.Lines.Count;
  Top := AClip.Top;
  for I := (GutterArea.TextArea.TopLine - 1) + FirstLine to (GutterArea.TextArea.TopLine - 1) + LastLine do
  begin
    Line := ViewedTextBuffer.DisplayView.ViewToTextIndex(I);
    if (Line < 0) or (Line >= LineCount) then
      Break;
    UL := Edit.Content.PeekLine(Line);
    if (UL <> nil) and (UL.FMarkers <> nil) then
    begin
      X := AClip.Left;
      for K := 0 to UL.FMarkers.Count - 1 do
      begin
        (UL.FMarkers[K] as IUCELineMarker).Draw(Line, Canvas, X, Top);
        Inc(X, (UL.FMarkers[K] as IUCELineMarker).GetSize(Line).cx);
      end;
    end;
    Inc(Top, Edit.LineHeight);
  end;
end;

{ TCustomUnicodeEdit }

constructor TCustomUnicodeEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FContent := TUCEContent.Create(Self);
  FScrollHintColor := TUCEColors.Create;
  FLineNumberFont := TFont.Create;
  FRightMargin := -1;
  inherited OnProcessUserCommand := UserCommandBridge;
  inherited OnGutterClick := GutterClickBridge;
  inherited OnSpecialLineMarkup := SpecialLineBridge;
  TUCEGutterMarkers.Create(Gutter.Parts);
  FLastTopLine := TopLine;
  FLastLeftChar := LeftChar;
  OnStatusChange := StatusChanged;
  FUCEOptions := DefaultOptions;
  ApplyOptions;
end;

destructor TCustomUnicodeEdit.Destroy;
begin
  FContent.Free;
  FScrollHintColor.Free;
  FLineNumberFont.Free;
  inherited Destroy;
end;

function TCustomUnicodeEdit.GetOffsetY: Integer;
begin
  Result := TopLine - 1;
end;

procedure TCustomUnicodeEdit.SetOffsetY(const Value: Integer);
begin
  TopLine := Value + 1;
end;

function TCustomUnicodeEdit.GetUCECaretX: Integer;
begin
  Result := inherited CaretX - 1;
end;

procedure TCustomUnicodeEdit.SetUCECaretX(const Value: Integer);
begin
  inherited CaretX := Value + 1;
end;

function TCustomUnicodeEdit.GetUCECaretY: Integer;
begin
  Result := inherited CaretY - 1;
end;

procedure TCustomUnicodeEdit.SetUCECaretY(const Value: Integer);
var
  Line: Integer;
begin
  Line := Value + 1;
  if Line > Lines.Count then
    Line := Lines.Count;            // the original clamps, e.g. CaretY := Content.Count after AddLine
  if Line < 1 then
    Line := 1;
  inherited CaretY := Line;
end;

function TCustomUnicodeEdit.GetUCECaretXY: TPoint;
begin
  Result := Point(GetUCECaretX, GetUCECaretY);
end;

procedure TCustomUnicodeEdit.SetUCECaretXY(const Value: TPoint);
begin
  SetUCECaretY(Value.Y);
  SetUCECaretX(Value.X);
end;

function TCustomUnicodeEdit.GetSelectedText: WideString;
begin
  Result := UTF8Decode(SelText);
end;

procedure TCustomUnicodeEdit.SetCaretToEditorBottom;
begin
  if Lines.Count = 0 then
    Exit;
  inherited CaretY := Lines.Count;
  inherited CaretX := UTF8Length(Lines[Lines.Count - 1]) + 1;
end;

function TCustomUnicodeEdit.LinkedLines: TSynEditStringsLinked;
begin
  Result := ViewedTextBuffer;
end;

procedure TCustomUnicodeEdit.RefreshLine(Index: Integer);
begin
  InvalidateLine(Index + 1);
end;

procedure TCustomUnicodeEdit.InsertText(const S: WideString);
begin
  InsertTextAtCaret(UTF8Encode(S));
end;

function TCustomUnicodeEdit.SearchReplace(const ASearch, AReplace: WideString; AOptions: TSearchOptions): Integer;
var
  O: TSynSearchOptions;
begin
  O := [];
  if soBackwards in AOptions then Include(O, ssoBackwards);
  if soEntireScope in AOptions then Include(O, ssoEntireScope);
  if soMatchCase in AOptions then Include(O, ssoMatchCase);
  if soPrompt in AOptions then Include(O, ssoPrompt);
  if soRegularExpression in AOptions then Include(O, ssoRegExpr);
  if soReplace in AOptions then Include(O, ssoReplace);
  if soReplaceAll in AOptions then Include(O, ssoReplaceAll);
  if soSelectedOnly in AOptions then Include(O, ssoSelectedOnly);
  if soWholeWord in AOptions then Include(O, ssoWholeWord);
  Result := inherited SearchReplace(UTF8Encode(ASearch), UTF8Encode(AReplace), O);
end;

function TCustomUnicodeEdit.TextFromClipboard: WideString;
begin
  Result := UTF8Decode(Clipboard.AsText);
end;

procedure TCustomUnicodeEdit.SetUCEOptions(const Value: TUniCodeEditOptions);
begin
  FUCEOptions := Value;
  ApplyOptions;
end;

procedure TCustomUnicodeEdit.SetSelectedText(const Value: WideString);
begin
  SelText := UTF8Encode(Value);
end;

function TCustomUnicodeEdit.GetGutterColor: TColor;
begin
  Result := Gutter.Color;
end;

procedure TCustomUnicodeEdit.SetGutterColor(const Value: TColor);
begin
  Gutter.Color := Value;
end;

procedure TCustomUnicodeEdit.CaretOffset(Start: TPoint; Offset: Integer);
var
  Y, X, Len: Integer;
begin
  Y := Start.Y;
  X := Start.X;
  while Y < Lines.Count do
  begin
    Len := UTF8Length(Lines[Y]);
    if X + Offset <= Len then
    begin
      CaretXY := Point(X + Offset, Y);
      Exit;
    end;
    Dec(Offset, Len - X + 2);            // rest of the line and the CR LF
    X := 0;
    Inc(Y);
    if Offset < 0 then
    begin
      CaretXY := Point(0, Y);
      Exit;
    end;
  end;
  SetCaretToEditorBottom;
end;

procedure TCustomUnicodeEdit.ClearAll(ClearUndoList: Boolean);
begin
  inherited ClearAll;
  if ClearUndoList then
    ClearUndo;
end;

procedure TCustomUnicodeEdit.LoadFromFile(const AFileName: WideString; Format: TTextFormat);
var
  Raw: RawByteString;
  Stream: TFileStream;
  W: UnicodeString;
  I: Integer;
begin
  Stream := TFileStream.Create(UTF8Encode(AFileName), fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Raw, Stream.Size);
    if Length(Raw) > 0 then
      Stream.ReadBuffer(Raw[1], Length(Raw));
  finally
    Stream.Free;
  end;
  case Format of
    tfANSI:
      Lines.Text := WinCPToUTF8(Raw);
    tfUTF8:
      begin
        if (Length(Raw) >= 3) and (Raw[1] = #$EF) and (Raw[2] = #$BB) and (Raw[3] = #$BF) then
          Delete(Raw, 1, 3);
        Lines.Text := Raw;
      end;
  else
    SetLength(W, Length(Raw) div 2);
    if Length(W) > 0 then
      Move(Raw[1], W[1], Length(W) * 2);
    if (Length(W) > 0) and (W[1] = #$FFFE) or (Format = tfUTF16BE) then
      for I := 1 to Length(W) do
        W[I] := WideChar(Swap(Word(W[I])));
    if (Length(W) > 0) and (W[1] = #$FEFF) then
      Delete(W, 1, 1);
    Lines.Text := UTF8Encode(W);
  end;
  ClearUndo;
  Modified := False;
end;

procedure TCustomUnicodeEdit.SaveToFile(const AFileName: WideString; Format: TTextFormat);
var
  Raw: RawByteString;
  W: UnicodeString;
  Stream: TFileStream;
  I: Integer;
begin
  case Format of
    tfANSI:
      Raw := UTF8ToWinCP(Lines.Text);
    tfUTF8:
      Raw := #$EF#$BB#$BF + Lines.Text;
  else
    W := #$FEFF + UTF8Decode(Lines.Text);
    if Format = tfUTF16BE then
      for I := 1 to Length(W) do
        W[I] := WideChar(Swap(Word(W[I])));
    SetLength(Raw, Length(W) * 2);
    Move(W[1], Raw[1], Length(Raw));
  end;
  Stream := TFileStream.Create(UTF8Encode(AFileName), fmCreate);
  try
    if Length(Raw) > 0 then
      Stream.WriteBuffer(Raw[1], Length(Raw));
  finally
    Stream.Free;
  end;
  Modified := False;
end;

function TCustomUnicodeEdit.GetBlockBegin: TPoint;
begin
  Result := inherited BlockBegin;
  Dec(Result.X);
  Dec(Result.Y);
end;

procedure TCustomUnicodeEdit.SetBlockBegin(const Value: TPoint);
begin
  inherited BlockBegin := Point(Value.X + 1, Value.Y + 1);
end;

function TCustomUnicodeEdit.GetBlockEnd: TPoint;
begin
  Result := inherited BlockEnd;
  Dec(Result.X);
  Dec(Result.Y);
end;

procedure TCustomUnicodeEdit.SetBlockEnd(const Value: TPoint);
begin
  inherited BlockEnd := Point(Value.X + 1, Value.Y + 1);
end;

function TCustomUnicodeEdit.GetSelectionAvailable: Boolean;
begin
  Result := SelAvail;
end;

function TCustomUnicodeEdit.GetTabSize: Integer;
begin
  Result := TabWidth;
end;

procedure TCustomUnicodeEdit.SetTabSize(const Value: Integer);
begin
  TabWidth := Value;
end;

procedure TCustomUnicodeEdit.SetRightMargin(const Value: Integer);
var
  O: TSynEditorOptions;
begin
  FRightMargin := Value;
  O := inherited Options;
  if Value < 0 then
    Include(O, SynEditTypes.eoHideRightMargin)
  else
  begin
    Exclude(O, SynEditTypes.eoHideRightMargin);
    RightEdge := Value;
  end;
  inherited Options := O;
end;

procedure TCustomUnicodeEdit.SetGutterWidth(const Value: Integer);
begin
  FGutterWidth := Value;      // SynEdit sizes its gutter from the parts (see ADR-0012 review list)
  Gutter.Visible := Value > 0;
end;

procedure TCustomUnicodeEdit.UserCommandBridge(Sender: TObject; var Command: TSynEditorCommand;
  var AChar: TUTF8Char; Data: Pointer);
var
  C: WideChar;
  W: WideString;
begin
  if Assigned(FOnProcessUserCommand) then
  begin
    W := UTF8Decode(AChar);
    if W <> '' then
      C := W[1]
    else
      C := #0;
    FOnProcessUserCommand(Self, Command, C, Data);
  end;
end;

procedure TCustomUnicodeEdit.GutterClickBridge(Sender: TObject; X, Y, Line: Integer; Mark: TSynEditMark);
begin
  if Assigned(FOnGutterMouseDown) then
    FOnGutterMouseDown(Self, mbLeft, [], X, Y, Line - 1);
end;

procedure TCustomUnicodeEdit.SpecialLineBridge(Sender: TObject; Line: Integer; var Special: Boolean;
  Markup: TSynSelectedColor);
var
  UL: TUCELine;
  Style: IUCELineStyle;
begin
  UL := FContent.PeekLine(Line - 1);
  Style := nil;
  if (UL <> nil) and (UL.FStyles <> nil) and (UL.FStyles.Count > 0) then
    Style := UL.FStyles[UL.FStyles.Count - 1] as IUCELineStyle
  else
    Style := FDefaultStyle;
  if Style <> nil then
  begin
    Special := True;
    // clDefault means "leave the token's own colour" in the original, clNone in SynEdit
    if Style.Foreground = clDefault then
      Markup.Foreground := clNone
    else
      Markup.Foreground := Style.Foreground;
    if Style.Background = clDefault then
      Markup.Background := clNone
    else
      Markup.Background := Style.Background;
    Markup.Style := Style.FontStyles;
    if Style.ForceFontStyles then
      Markup.StyleMask := Style.FontStyles
    else
      Markup.StyleMask := [];
  end;
end;

procedure TCustomUnicodeEdit.ApplyOptions;
// The UniCodeEditor options that have a SynEdit equivalent. The others (work width, trailing blanks,
// triple clicks, scroll hint, ...) are SynEdit defaults or are not needed yet.
var
  O: TSynEditorOptions;
begin
  O := inherited Options;
  Gutter.LineNumberPart.Visible := eoLineNumbers in FUCEOptions;
  ReadOnly := eoReadOnly in FUCEOptions;
  if eoAutoIndent in FUCEOptions then Include(O, SynEditTypes.eoAutoIndent) else Exclude(O, SynEditTypes.eoAutoIndent);
  if eoGroupUndo in FUCEOptions then Include(O, SynEditTypes.eoGroupUndo) else Exclude(O, SynEditTypes.eoGroupUndo);
  if eoScrollPastEOL in FUCEOptions then Include(O, SynEditTypes.eoScrollPastEol) else Exclude(O, SynEditTypes.eoScrollPastEol);
  if eoSmartTabs in FUCEOptions then Include(O, SynEditTypes.eoSmartTabs) else Exclude(O, SynEditTypes.eoSmartTabs);
  if eoShowControlChars in FUCEOptions then Include(O, SynEditTypes.eoShowSpecialChars) else Exclude(O, SynEditTypes.eoShowSpecialChars);
  if eoUseTabs in FUCEOptions then Exclude(O, SynEditTypes.eoTabsToSpaces) else Include(O, SynEditTypes.eoTabsToSpaces);
  inherited Options := O;
end;

procedure TCustomUnicodeEdit.StatusChanged(Sender: TObject; Changes: TSynStatusChanges);
var
  DX, DY: Integer;
  P: TPoint;
begin
  if (scCaretX in Changes) or (scCaretY in Changes) then
  begin
    P := CaretXY;
    if (P.X <> FLastCaret.X) or (P.Y <> FLastCaret.Y) then
    begin
      FLastCaret := P;
      if Assigned(FOnCaretChange) then
        FOnCaretChange(Self, P.X, P.Y);
    end;
  end;
  if (scTopLine in Changes) or (scLeftChar in Changes) then
  begin
    DX := LeftChar - FLastLeftChar;
    DY := TopLine - FLastTopLine;
    FLastLeftChar := LeftChar;
    FLastTopLine := TopLine;
    if Assigned(FOnScroll) and ((DX <> 0) or (DY <> 0)) then
      FOnScroll(Self, DX, DY);
  end;
end;

initialization
  RegisterClasses([TUniCodeEdit]);

end.
