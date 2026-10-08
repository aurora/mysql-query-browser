{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Compatibility layer for Mike Zinner's / Mike Lischke's UniCodeEditor (ADR-0012), implemented on
  SynEdit. It offers the members the ported Query Browser code uses, with the original names;
  members are added when the compiler asks for them, not speculatively.

  The original UniCodeEditor is released under the MIT licence (see NOTICE). }
unit UniCodeEditor;

{$mode delphi}

interface

uses
  Classes, SysUtils, SynEdit, SynEditTypes;

type
  TCustomUnicodeEdit = class;

  { The original's TUCEContent/line list: the part of its API that is used }
  TUCEContent = class
  private
    FEdit: TCustomUnicodeEdit;
    function GetCount: Integer;
    function GetText: WideString;
    procedure SetText(const Value: WideString);
  public
    constructor Create(AEdit: TCustomUnicodeEdit);
    procedure AddLine(const S: WideString);
    procedure Clear;
    property Count: Integer read GetCount;
    property Text: WideString read GetText write SetText;
  end;

  TUCEScrollEvent = procedure(Sender: TCustomUnicodeEdit; DeltaX, DeltaY: Integer) of object;

  TCustomUnicodeEdit = class(TSynEdit)
  private
    FContent: TUCEContent;
    FOnScroll: TUCEScrollEvent;
    FLastTopLine, FLastLeftChar: Integer;
    function GetOffsetY: Integer;
    procedure SetOffsetY(const Value: Integer);
    procedure StatusChanged(Sender: TObject; Changes: TSynStatusChanges);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { text lines of the editor }
    property Content: TUCEContent read FContent;
    { first visible line, zero based }
    property OffsetY: Integer read GetOffsetY write SetOffsetY;
    property OnScroll: TUCEScrollEvent read FOnScroll write FOnScroll;
  end;

  TUniCodeEdit = class(TCustomUnicodeEdit)
  end;

implementation

{ TUCEContent }

constructor TUCEContent.Create(AEdit: TCustomUnicodeEdit);
begin
  inherited Create;
  FEdit := AEdit;
end;

function TUCEContent.GetCount: Integer;
begin
  Result := FEdit.Lines.Count;
end;

function TUCEContent.GetText: WideString;
begin
  Result := UTF8Decode(FEdit.Lines.Text);
end;

procedure TUCEContent.SetText(const Value: WideString);
begin
  FEdit.Lines.Text := UTF8Encode(Value);
end;

procedure TUCEContent.AddLine(const S: WideString);
begin
  FEdit.Lines.Add(UTF8Encode(S));
end;

procedure TUCEContent.Clear;
begin
  FEdit.Lines.Clear;
end;

{ TCustomUnicodeEdit }

constructor TCustomUnicodeEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FContent := TUCEContent.Create(Self);
  FLastTopLine := TopLine;
  FLastLeftChar := LeftChar;
  OnStatusChange := StatusChanged;
end;

destructor TCustomUnicodeEdit.Destroy;
begin
  FContent.Free;
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

procedure TCustomUnicodeEdit.StatusChanged(Sender: TObject; Changes: TSynStatusChanges);
var
  DX, DY: Integer;
begin
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
