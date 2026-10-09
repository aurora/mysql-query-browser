{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Placeholder for the EmbeddedWB Internet Explorer wrapper that the Query Browser used for its
  HTML help pane (syntax, functions, parameters). The LCL has no web browser control. The class
  keeps the members the ported code calls and shows nothing yet.
  ROADMAP: render the local help pages (res/doc/*.html), e.g. with Lazarus' IpHtml. }
unit EmbeddedWB;

{$mode delphi}

interface

uses
  Classes, SysUtils, Variants, Controls, ExtCtrls;

type
  TUserInterfaceOption = (uioNo3DBorder, uioScrollNo);
  TUserInterfaceOptions = set of TUserInterfaceOption;

const
  NO3DBORDER = uioNo3DBorder;
  SCROLL_NO = uioScrollNo;

type
  TDocumentCompleteEvent = procedure(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant) of object;

  TEmbeddedWB = class(TPanel)
  private
    FUrl: String;
    FOnDocumentComplete: TDocumentCompleteEvent;
    FUserInterfaceOptions: TUserInterfaceOptions;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Loaded; override;
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
  BevelOuter := bvNone;
  Caption := '';
end;

procedure TEmbeddedWB.Loaded;
begin
  inherited Loaded;
end;

procedure TEmbeddedWB.Navigate(const URL: OleVariant);
begin
  FUrl := VarToStr(URL);
end;

function TEmbeddedWB.OleObject: Variant;
begin
  Result := Unassigned;
end;

end.
