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
  Classes, SysUtils, Variants, Controls, ExtCtrls, IpHtml, IpFileBroker;

type
  TUserInterfaceOption = (uioNo3DBorder, uioScrollNo);
  TUserInterfaceOptions = set of TUserInterfaceOption;

const
  NO3DBORDER = uioNo3DBorder;
  SCROLL_NO = uioScrollNo;

type
  TDocumentCompleteEvent = procedure(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant) of object;

  TEmbeddedWB = class(TIpHtmlPanel)
  private
    FOnDocumentComplete: TDocumentCompleteEvent;
    FUserInterfaceOptions: TUserInterfaceOptions;
    FProvider: TIpFileDataProvider;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Loaded; override;
    { accepts file:// URLs (with #anchor) and plain file names }
    procedure Navigate(const URL: OleVariant);
    { the original returned the IE automation object; nothing to automate here }
    function OleObject: Variant;
    property OnDocumentComplete: TDocumentCompleteEvent read FOnDocumentComplete write FOnDocumentComplete;
    property UserInterfaceOptions: TUserInterfaceOptions read FUserInterfaceOptions write FUserInterfaceOptions;
  end;

implementation

constructor TEmbeddedWB.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProvider := TIpFileDataProvider.Create(Self);
  DataProvider := FProvider;
  BorderStyle := bsNone;
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
begin
  S := VarToStr(URL);
  if Pos('file://', LowerCase(S)) = 1 then
    Delete(S, 1, 7);
  Anchor := '';
  P := Pos('#', S);
  if P > 0 then
  begin
    Anchor := Copy(S, P, MaxInt);
    S := Copy(S, 1, P - 1);
  end;
  S := StringReplace(S, '\', '/', [rfReplaceAll]);
  OpenURL(S + Anchor);
end;

function TEmbeddedWB.OleObject: Variant;
begin
  Result := Unassigned;
end;

end.
