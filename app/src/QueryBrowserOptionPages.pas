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
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, Options, TntStdCtrls, AuxFuncs, TntComCtrls;

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
  public
    { Public declarations }
  end;

//----------------------------------------------------------------------------------------------------------------------

implementation

//----------------------------------------------------------------------------------------------------------------------

uses
  ApplicationDataModule;

{$R ../forms/QueryBrowserOptionPages.lfm}

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.FormCreate(Sender: TObject);

begin
  InitForm(self);

  OptionsImgNames.Add('options_querybrowser');

  DockOptionPageControl := OptionPageControl;
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

    EnableDisableControls;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryBrowserOptionPagesForm.ApplyChanges(PageNr: integer);

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

