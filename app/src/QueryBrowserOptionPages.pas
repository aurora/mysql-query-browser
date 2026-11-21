unit QueryBrowserOptionPages;

{$mode delphi}

// Copyright (C) 2003, 2004 MySQL AB
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


interface

uses
  {$IFDEF MSWINDOWS}Windows{$ELSE}LCLIntf, LCLType, WinAliases, Types{$ENDIF}, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, Options, TntStdCtrls, AuxFuncs, TntComCtrls, Math;

type
  TQueryBrowserOptionPagesForm = class(TApplicationOptionsForm)
    OptionPageControl: TTntPageControl;
    BrowserTabSheet: TTntTabSheet;
    GroupBox4: TTntGroupBox;
    HideTabWhenOneOpenCBox: TTntCheckBox;
    ToolbarGradientCBox: TTntCheckBox;
    TntGroupBox1: TTntGroupBox;
    EnforceEditableQueriesCBox: TTntCheckBox;
    OpenExportedResultsetCBox: TTntCheckBox;
    TntGroupBox2: TTntGroupBox;
    AssociateFileExtensionsCBox: TTntCheckBox;
    ShowAdvancedToolbarMI: TTntCheckBox;
    ShowFieldOverlayImagesCBox: TTntCheckBox;
    EnableFriendlyLineBreaksCBox: TTntCheckBox;
    SubstLFLU: TTntComboBox;
    TntLabel1: TTntLabel;
    TntLabel2: TTntLabel;
    SubstCRLU: TTntComboBox;
    CreateWindowsStyleLineBreaksCBox: TTntCheckBox;
    ShowMouseCursorToolbarGroupCBox: TTntCheckBox;
    AlignNumericColsRightCBox: TTntCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    procedure SetControls(PageNr: integer); override;
    procedure ApplyChanges(PageNr: integer); override;

    procedure DoChange(Sender: TObject);
    procedure EnableDisableControls;
  private
    { Private declarations }
    // revival: CSV and TSV export settings, built in code below "Various" (ADR-0050)
    FExportGB: TTntGroupBox;
    FSeparatorCB, FQuotingCB, FLineBreaksCB: TTntComboBox;
    FHeaderCBox, FBOMCBox: TTntCheckBox;
    procedure CreateExportControls;
  public
    { Public declarations }
  end;

//----------------------------------------------------------------------------------------------------------------------

implementation

//----------------------------------------------------------------------------------------------------------------------

uses
  ApplicationDataModule, CommonFuncs, gnugettext;

const
  // stored values of the export settings, in the order of the combo box items (ADR-0050)
  SeparatorValues: array[0..2] of WideString = (',', ';', 'tab');
  QuotingValues: array[0..2] of WideString = ('text', 'needed', 'all');
  LineBreakValues: array[0..2] of WideString = ('system', 'lf', 'crlf');

{$R ../forms/QueryBrowserOptionPages.lfm}

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.FormCreate(Sender: TObject);

begin
  // revival: before InitForm, so that the new group gets the same font and group box adjustments (ADR-0050)
  CreateExportControls;
  InitForm(self);
  // Port: the product's name in the (translated) caption (ADR-0030)
  AssociateFileExtensionsCBox.Caption := StringReplace(AssociateFileExtensionsCBox.Caption, 'Query Browser',
    RevivalProductName, []);

  OptionsImgNames.Add('options_querybrowser');

  DockOptionPageControl := OptionPageControl;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.CreateExportControls;

  function AddLabel(const Caption: String; ALeft, AWidth, ATop: Integer): TTntLabel;
  begin
    Result := TTntLabel.Create(Self);
    Result.Parent := FExportGB;
    Result.AutoSize := False;
    Result.Alignment := taRightJustify;
    Result.SetBounds(ALeft, ATop + 4, AWidth, 16);
    Result.Caption := Caption;
  end;

  function AddCombo(ALeft, AWidth, ATop: Integer; AStyle: TComboBoxStyle; const Items: array of String): TTntComboBox;
  var
    I: Integer;
  begin
    Result := TTntComboBox.Create(Self);
    Result.Parent := FExportGB;
    Result.Style := AStyle;
    Result.SetBounds(ALeft, ATop, AWidth, 24);
    for I := 0 to High(Items) do
      Result.Items.Add(Items[I]);
    Result.OnChange := DoChange;
  end;

  function AddCheck(const Caption: String; ALeft, AWidth, ATop: Integer): TTntCheckBox;
  begin
    Result := TTntCheckBox.Create(Self);
    Result.Parent := FExportGB;
    Result.SetBounds(ALeft, ATop, AWidth, 17);
    Result.Caption := Caption;
    Result.OnClick := DoChange;
  end;

begin
  // like the page's other groups: same width and spacing, below "Various"; coordinates as in the original's forms
  // (counted from the frame's top, AdjustGroupBoxes moves them)
  FExportGB := TTntGroupBox.Create(Self);
  FExportGB.Parent := BrowserTabSheet;
  FExportGB.SetBounds(TntGroupBox2.Left, TntGroupBox2.Top + TntGroupBox2.Height + 9, TntGroupBox2.Width, 75);
  FExportGB.Anchors := [akLeft, akTop, akRight];
  FExportGB.Caption := _('CSV / TSV Export');

  AddLabel(_('Separator:'), 8, 70, 17);
  FSeparatorCB := AddCombo(82, 100, 17, csDropDown, [_('Comma'), _('Semicolon'), _('Tab')]);
  AddLabel(_('Quotes:'), 188, 52, 17);
  FQuotingCB := AddCombo(244, 120, 17, csDropDownList, [_('Text columns'), _('When needed'), _('All values')]);
  AddLabel(_('Line breaks:'), 370, 76, 17);
  FLineBreaksCB := AddCombo(450, 95, 17, csDropDownList, [_('System'), 'LF', 'CR LF']);

  FHeaderCBox := AddCheck(_('Column names in the first line'), 16, 270, 48);
  FBOMCBox := AddCheck(_('UTF-8 byte order mark (for Excel)'), 290, 260, 48);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.FormDestroy(Sender: TObject);

begin
  //
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.FormClose(Sender: TObject; var Action: TCloseAction);

begin
  //
end;

//----------------------------------------------------------------------------------------------------------------------

function IndexOfValue(const Values: array of WideString; const Value: WideString): Integer;

begin
  for Result := 0 to High(Values) do
    if Values[Result] = Value then
      Exit;
  Result := -1;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.SetControls(PageNr: integer);

begin
  if (PageNr = 0) then
  begin
    ToolbarGradientCBox.Checked := ApplicationDM.Options.UseToolbarGradient;
    HideTabWhenOneOpenCBox.Checked := ApplicationDM.Options.HideTabWhenOneOpen;
    ShowFieldOverlayImagesCBox.Checked := ApplicationDM.Options.ShowFieldOverlayImages;
    ShowMouseCursorToolbarGroupCBox.Checked := ApplicationDM.Options.ShowMouseCursorToolbarGroup;

    EnforceEditableQueriesCBox.Checked := ApplicationDM.Options.EnforceEditableQueries;
    OpenExportedResultsetCBox.Checked := ApplicationDM.Options.OpenExportedResultset;

    EnableFriendlyLineBreaksCBox.Checked := ApplicationDM.Options.FriendlyLineBreaks;
    SubstLFLU.Text := ApplicationDM.Options.FriendlyLineBreaksLF;
    SubstCRLU.Text := ApplicationDM.Options.FriendlyLineBreaksCR;
    CreateWindowsStyleLineBreaksCBox.Checked := ApplicationDM.Options.CreateWindowsStyleLineBreaks;

    AlignNumericColsRightCBox.Checked := ApplicationDM.Options.AlignNumericColsRight;

    AssociateFileExtensionsCBox.Checked := ApplicationDM.Options.AssociateFileExtensions;

    ShowAdvancedToolbarMI.Checked := ApplicationDM.Options.ShowAdvancedToolbar;

    // revival: ADR-0050; a separator that is none of the items stays as typed
    FSeparatorCB.ItemIndex := IndexOfValue(SeparatorValues, ApplicationDM.Options.CSVSeparator);
    if FSeparatorCB.ItemIndex < 0 then
      FSeparatorCB.Text := ApplicationDM.Options.CSVSeparator;
    FQuotingCB.ItemIndex := Max(0, IndexOfValue(QuotingValues, ApplicationDM.Options.CSVQuoting));
    FLineBreaksCB.ItemIndex := Max(0, IndexOfValue(LineBreakValues, ApplicationDM.Options.ExportLineBreaks));
    FHeaderCBox.Checked := ApplicationDM.Options.ExportHeader;
    FBOMCBox.Checked := ApplicationDM.Options.ExportBOM;

    EnableDisableControls;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.ApplyChanges(PageNr: integer);

var
  I: Integer;

begin
  if (PageNr = 0) then
  begin
    ApplicationDM.Options.UseToolbarGradient := ToolbarGradientCBox.Checked;
    ApplicationDM.Options.HideTabWhenOneOpen := HideTabWhenOneOpenCBox.Checked;
    ApplicationDM.Options.ShowFieldOverlayImages := ShowFieldOverlayImagesCBox.Checked;
    ApplicationDM.Options.ShowMouseCursorToolbarGroup := ShowMouseCursorToolbarGroupCBox.Checked;


    ApplicationDM.Options.EnforceEditableQueries := EnforceEditableQueriesCBox.Checked;
    ApplicationDM.Options.OpenExportedResultset := OpenExportedResultsetCBox.Checked;

    ApplicationDM.Options.FriendlyLineBreaks := EnableFriendlyLineBreaksCBox.Checked;
    ApplicationDM.Options.FriendlyLineBreaksLF := SubstLFLU.Text[1];
    ApplicationDM.Options.FriendlyLineBreaksCR := SubstCRLU.Text[1];
    ApplicationDM.Options.CreateWindowsStyleLineBreaks := CreateWindowsStyleLineBreaksCBox.Checked;

    ApplicationDM.Options.AlignNumericColsRight := AlignNumericColsRightCBox.Checked;

    ApplicationDM.Options.ShowAdvancedToolbar := ShowAdvancedToolbarMI.Checked;

    ApplicationDM.Options.AssociateFileExtensions := AssociateFileExtensionsCBox.Checked;

    // revival: ADR-0050
    I := FSeparatorCB.Items.IndexOf(FSeparatorCB.Text);
    if I >= 0 then
      ApplicationDM.Options.CSVSeparator := SeparatorValues[I]
    else
      if FSeparatorCB.Text = '' then
        ApplicationDM.Options.CSVSeparator := ','
      else
        ApplicationDM.Options.CSVSeparator := FSeparatorCB.Text;
    ApplicationDM.Options.CSVQuoting := QuotingValues[Max(0, FQuotingCB.ItemIndex)];
    ApplicationDM.Options.ExportLineBreaks := LineBreakValues[Max(0, FLineBreaksCB.ItemIndex)];
    ApplicationDM.Options.ExportHeader := FHeaderCBox.Checked;
    ApplicationDM.Options.ExportBOM := FBOMCBox.Checked;

    ApplicationDM.Options.StoreOptions;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.DoChange(Sender: TObject);

begin
  if (@DoPageContentChanged <> nil) then
    DoPageContentChanged(Sender);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.EnableDisableControls;

begin
  //
end;

//----------------------------------------------------------------------------------------------------------------------

end.

