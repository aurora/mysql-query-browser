unit Main;

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
  TntMenus, TntComCtrls, TntForms, Windows, Messages, SysUtils,
  Variants, Classes, Graphics, Controls, Forms, Options,
  Dialogs, Menus, MySQLConnection, AuxFuncs, ComCtrls, Sections,
  gnugettext, QueryBrowser, Contnrs, StdCtrls, Clipbrd,
  OptionsEditor, QueryBrowserOptionPages, PNGImage, CommonFuncs,
  TntDialogs, SchemaSelection, myx_public_interface, About,
  UniCodeEditor, MySQLCommonFuncs, RegExTextImporter, Types, ExtCtrls,
  AppInstanceMgmt;

{$include Consts.ini}

type
  TMainForm = class(TTntForm)
    MainMenu: TTntMainMenu;
    FileMI: TTntMenuItem;
    Edit1: TTntMenuItem;
    ToolsMI: TTntMenuItem;
    HelpMI: TTntMenuItem;
    StatusBar: TTntStatusBar;
    ViewMenuItem: TTntMenuItem;
    ChangeDefaultSchemaMI: TTntMenuItem;
    NewInstanceConnectionMI: TTntMenuItem;
    N2: TTntMenuItem;
    ManageConnectionsMI: TTntMenuItem;
    SavecurrentConnectionMI: TTntMenuItem;
    N3: TTntMenuItem;
    N4: TTntMenuItem;
    CloseMI: TTntMenuItem;
    CutMI: TTntMenuItem;
    CopyMI: TTntMenuItem;
    PasteMI: TTntMenuItem;
    OptionsMI: TTntMenuItem;
    LaunchHelpMI: TTntMenuItem;
    N6: TTntMenuItem;
    VisitMySQLcomMI: TTntMenuItem;
    ReportBugMI: TTntMenuItem;
    N7: TTntMenuItem;
    AboutMI: TTntMenuItem;
    OnlineDocsMI: TTntMenuItem;
    OnlineReferenceCAPIMI: TTntMenuItem;
    OnlineDocsPHPAPIMI: TTntMenuItem;
    SelectAllMI: TTntMenuItem;
    NewResultsetTabMI: TTntMenuItem;
    NewSQLScriptTabMI: TTntMenuItem;
    N1: TTntMenuItem;
    PageSetupMI: TTntMenuItem;
    N10: TTntMenuItem;
    PrintMI: TTntMenuItem;
    PrinttoPDFMI: TTntMenuItem;
    MySQLAdministratorMI: TTntMenuItem;
    MySQLCommandLineClientMI: TTntMenuItem;
    N11: TTntMenuItem;
    WindowsCommandLineMI: TTntMenuItem;
    OpenSQLScriptMI: TTntMenuItem;
    N12: TTntMenuItem;
    N13: TTntMenuItem;
    ListreportedBugsMI: TTntMenuItem;
    ReconnectMI: TTntMenuItem;
    N5: TTntMenuItem;
    SaveMI: TTntMenuItem;
    OpenQueryMI: TTntMenuItem;
    ReopenMI: TTntMenuItem;
    SaveAsMI: TTntMenuItem;
    CloseTabMI: TTntMenuItem;
    ExportResultsetMI: TTntMenuItem;
    FindMI: TTntMenuItem;
    QuickStartGuideMI: TTntMenuItem;
    N8: TTntMenuItem;
    RegExTextImporterMI: TTntMenuItem;
    N9: TTntMenuItem;
    WindowMI: TTntMenuItem;
    WindowDummyMI: TTntMenuItem;
    N14: TTntMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    procedure PrepareGUI;

    procedure BuildSectionTree;
    procedure DoCurrentSectionChanging(Sender: TObject);
    procedure DoCurrentSectionChanged(Sender: TObject);
    procedure ShowSection(SectionNr: integer);

    procedure UpdateMenuItems;

    function CreateSectionForm(AOwner: TComponent;
      SidebarSectionType: integer): TSectionForm;
    procedure CloseMIClick(Sender: TObject);
    procedure OptionsMIClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);

    procedure ReportBugMIClick(Sender: TObject);
    procedure VisitMySQLcomMIClick(Sender: TObject);
    procedure ActivateQueryBrowserSection;
    procedure OnlineDocsMIClick(Sender: TObject);
    procedure OnlineReferenceCAPIMIClick(Sender: TObject);
    procedure OnlineDocsPHPAPIMIClick(Sender: TObject);

    procedure HandleIdle(Sender: TObject; var Done: Boolean);
    procedure CutMIClick(Sender: TObject);
    procedure CopyMIClick(Sender: TObject);
    procedure PasteMIClick(Sender: TObject);
    procedure FindMIClick(Sender: TObject);
    procedure NewInstanceConnectionMIClick(Sender: TObject);
    procedure ManageConnectionsMIClick(Sender: TObject);
    procedure SavecurrentConnectionMIClick(Sender: TObject);
    procedure SelectAllMIClick(Sender: TObject);

    procedure CheckFonts;
    procedure NewResultsetTabMIClick(Sender: TObject);
    procedure NewSQLScriptTabMIClick(Sender: TObject);

    procedure MySQLAdministratorMIClick(Sender: TObject);
    procedure MySQLCommandLineClientMIClick(Sender: TObject);
    procedure WindowsCommandLineMIClick(Sender: TObject);
    procedure ChangeDefaultSchemaMIClick(Sender: TObject);
    procedure OpenSQLScriptMIClick(Sender: TObject);
    procedure AboutMIClick(Sender: TObject);
    procedure ListreportedBugsMIClick(Sender: TObject);

    procedure DefaultSchemaChanged(var Message: TMessage); message WM_DefaultSchemaChanged;
    procedure ReconnectMIClick(Sender: TObject);
    procedure SaveMIClick(Sender: TObject);
    procedure OpenQueryMIClick(Sender: TObject);
    procedure SaveAsMIClick(Sender: TObject);
    procedure QuickStartGuideMIClick(Sender: TObject);
    procedure LaunchHelpMIClick(Sender: TObject);
    procedure CloseTabMIClick(Sender: TObject);
    procedure TntFormActivate(Sender: TObject);
    procedure TntFormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure RegExTextImporterMIClick(Sender: TObject);

    procedure DoException(Sender: TObject; E: Exception);
    procedure StatusBarDrawPanel(StatusBar: TStatusBar;
      Panel: TStatusPanel; const Rect: TRect);
    procedure StatusBarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TntFormCloseQuery(Sender: TObject; var CanClose: Boolean);

    procedure WMInitMenuPopup(var MSG: TWMInitMenuPopup); message WM_INITMENUPOPUP;
  private
    FTextToClear: Boolean;
    FStatusbarClearPNGImg: TPNGObject;
  public
    MySQLConn: TMySQLConn;

    SectionControls: TSectionControls;

    procedure UpdateActions; override;
  end;

const
  SSTQB_QueryBrowser = 1;

var
  MainForm: TMainForm;

//----------------------------------------------------------------------------------------------------------------------

implementation

uses
  ApplicationDataModule, MyxError, PNGTools;

{$R ../forms/Main.lfm}

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormCreate(Sender: TObject);

begin
  InitForm(self);

  if (Not(MYXCommonOptions.NoRegistry)) then
    RegisterMySQLApplication(Application.Title,
      product_version, ExtractFilePath(Application.ExeName));

  Application.Title := _('MySQL Query Browser');

  if (not (ApplicationDM.Options.RestoreWindowPos(self))) then
  begin
    if (Screen.Width >= 1024) then
    begin
      Width := 1024;
      Height := 768 - 48;

      Left := (Screen.Width + Width) div 2 - Width;
      Top := 0;
    end
    else
    begin
      Width := 800;
      Height := 572;

      Left := (Screen.Width + Width) div 2 - Width;
      Top := 0;

      WindowState := wsMaximized;
    end;
  end;

  // Port: MainMenu.AutoHotkeys has no LCL equivalent (menu accelerators are given explicitly).

  MySQLConn := TMySQLConn.Create(StatusBar);
  MySQLConn.AllowConnectionSkip := False;

  SectionControls := TSectionControls.Create(self,
    CreateSectionForm,
    nil,
    True,
    0,
    nil,
    1,
    False,
    False);

  Application.OnIdle := HandleIdle;

  // Let the application show an error box if something bad happens instead only a easy to miss statusbar message.
  // Application.OnException := DoException;

  Application.HintHidePause := 1000000;

  CheckFonts;

  // Enable Tools Menu Items
  MySQLAdministratorMI.Enabled := (GetMySQLAdministratorCmd <> '');
  MySQLCommandlineclientMI.Enabled := (GetMySQLCommandLineClientPath <> '');
  WindowsCommandLineMI.Enabled := FileExists(GetSystemDir + 'cmd.exe');

  FTextToClear := False;
  FStatusbarClearPNGImg := LoadPNGImageFromResource('statusbar_clear');
  StatusBar.Font.Size := ((MYXCommonOptions.DefaultFontHeight * 10) div 12);
  StatusBar.Font.Color := clGray;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormDestroy(Sender: TObject);

begin
  ApplicationDM.Options.AddWindowPos(self);

  FStatusbarClearPNGImg.Free;

  MySQLConn.Free;

  // Shutdown embedded server
  if (ApplicationDM.Options.Embedded) then
    myx_mysql_embedded_shutdown;

  ApplicationDM.Free;
  MYXCommonOptions := nil;
  MYXCommonOptionProvider := nil; // Sets the ref count to 0 and frees the class.
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);

var
  i: integer;

begin
  try
    ApplicationDM.ApplicationIsTerminating := True;

    //Close all Sub-windows
    for i := 0 to SectionControls.SectionList.Count - 1 do
      if (TSidebarSection(SectionControls.SectionList[i]).SectionForm <> nil) then
        TSidebarSection(SectionControls.SectionList[i]).SectionForm.Close;
  except
    //Allow close even when there was an exception
  end;

  Action := caFree;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.TntFormCloseQuery(Sender: TObject; var CanClose: Boolean);

var
  i: integer;

begin
  //try
    //Check if all Sub-Windows can be closed
  for i := 0 to SectionControls.SectionList.Count - 1 do
    if (TSidebarSection(SectionControls.SectionList[i]).SectionForm <> nil) and
      (Assigned(TSidebarSection(SectionControls.SectionList[i]).SectionForm.OnCloseQuery)) then
    begin
      TSidebarSection(SectionControls.SectionList[i]
        ).SectionForm.OnCloseQuery(self, CanClose);

      if not (CanClose) then
        break;
    end;
  {except
    //Allow close even when there was an exception
    CanClose := True;
  end;}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.PrepareGUI;

begin
  Caption := _('MySQL Query Browser') + ' - ' + MySQLConn.GetConnectionCaption;

  //Build the Section List
  BuildSectionTree;

  ShowSection(0);

  UpdateMenuItems;

  if (ApplicationDM.Options.AssociateFileExtensions) then
  begin
    RegisterFileType('qbquery', Application.ExeName, 1, '"-qb %1"');
    RegisterFileType('sql', Application.ExeName, 2, '"-qs %1"');
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.BuildSectionTree;

begin
  SectionControls.AddSection(_('Query Browser'),
    TSidebarSection.Create(SSTQB_QueryBrowser,
    0, 1, True, False));

  SectionControls.OnCurrentSectionChanged := DoCurrentSectionChanged;
  SectionControls.OnCurrentSectionChanging := DoCurrentSectionChanging;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.DoCurrentSectionChanging(Sender: TObject);

begin
  {if(SectionControls.CurrentSidebarSection.SidebarSectionType=SSTQB_QueryBrowser)then
    MainMenu.UnMerge(TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).Menu);}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.DoCurrentSectionChanged(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    MainMenu.Merge(TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).Menu);

  StatusBar.Invalidate;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ShowSection(SectionNr: integer);

begin
  if (SectionNr < SectionControls.SectionList.Count) then
    SectionControls.ShowSidebarSection(SectionControls.SectionList[SectionNr] as TSidebarSection);
end;

//----------------------------------------------------------------------------------------------------------------------

function TMainForm.CreateSectionForm(AOwner: TComponent; SidebarSectionType: integer): TSectionForm;

begin
  Result := nil;

  case SidebarSectionType of
    SSTQB_QueryBrowser:
      Result := TQueryBrowserForm.Create(AOwner, MySQLConn, StatusBar);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.UpdateMenuItems;

begin
  if (SectionControls <> nil) then
    if (SectionControls.CurrentSidebarSection <> nil) then
      if (SectionControls.CurrentSidebarSection.SectionForm is TQueryBrowserForm) then
      begin
        with TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm) do
        begin
          self.ExportResultsetMI.Clear;
          AddResultsetExporterMenuItems(self.ExportResultsetMI);
        end;
      end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CloseMIClick(Sender: TObject);

begin
  Close;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.OptionsMIClick(Sender: TObject);

var
  OptionsForm: TOptionsForm;

begin
  OptionsForm := TOptionsForm.Create(self, TQueryBrowserOptionPagesForm.Create(self));
  try
    OptionsForm.ShowModal;
  finally
    OptionsForm.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

var
  NewCursor: TCursor;

begin
  if (Key = VK_F1) then
    ShowHelp;

  if ((Key = Ord('I')) and (Shift = [ssCtrl])) then
  begin
    RegExTextImporterMIClick(self);
    Key := 0;
  end;

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
  begin
    if (Shift = []) then
    begin
      with TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm) do
      begin
        if (Key = VK_F12) then
        begin
          ApplicationDM.Options.OnlyTabsheets :=
            not (ApplicationDM.Options.OnlyTabsheets);

          DoOptionsChanged;

          Key := 0;
        end
        else
          if (Key = VK_F11) then
          begin
            SQLEditorMaximized := not (SQLEditorMaximized);

            DoOptionsChanged;

            Key := 0;
          end;
      end;
    end
    else
    begin
      if (Shift = [ssAlt, ssCtrl]) {or
      (CurrentControl=TQueryBrowserForm(
        SectionControls.CurrentSidebarSection.SectionForm
          ).SchemataFrame.CatalogVST.Handle)}then
      begin
        if (Key = Ord('X')) then
          NewCursor := crDefault
        else
          if (Key = Ord('S')) then
            NewCursor := crSQLSelect
          else
            if (Key = Ord('F')) then
              NewCursor := crSQLFrom
            else
              if (Key = Ord('W')) then
                NewCursor := crSQLWhere
              else
                if (Key = Ord('G')) then
                  NewCursor := crSQLGroup
                else
                  if (Key = Ord('H')) then
                    NewCursor := crSQLHaving
                  else
                    if (Key = Ord('O')) then
                      NewCursor := crSQLOrder
                    else
                      if (Key = Ord('T')) then
                        NewCursor := crSQLSet
                      else
                        NewCursor := crNo;

        if (NewCursor <> crNo) then
        begin
          MessageToAllForms(WM_CursorChanged, NewCursor, 0);
          Key := 0;
        end;

        if (Key = VK_Return) then
        begin                                
          TQueryBrowserForm(
            SectionControls.CurrentSidebarSection.SectionForm
            ).QuerySplitAndExecuteClick(self);
        end;
      end
      else
      begin
        if (ssAlt in Shift) then
        begin
          with TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm) do
          begin
        //History Nav
            if (Key = VK_LEFT) then
              QueryGoBackClick(self);

            if (Key = VK_Right) then
              QueryNextClick(self);

        //Jump to specific Tab
            if (Key >= Ord('1')) and (Key <= Ord('9')) then
            begin
              DoSetActiveRSTab(Key - Ord('1'));
              Key := 0;
            end;
          end;
        end
        else
        begin
          if (ssCtrl in Shift) then
          begin
            with TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm) do
            begin
              if (Key = 17) then
                ShowResultsetHits;

              if (Key = Ord('N')) then
              begin
                ClearQueryEditorMIClick(self);
                Key := 0;
              end;

              if (Key = Ord('O')) then
              begin
                OpenScript('', ssShift in Shift);
                Key := 0;
              end;

              if (Key = Ord('S')) then
              begin
                Save;
                Key := 0;
              end;

              if (Key = Ord('T')) then
              begin
                if ssShift in Shift then
                  AddNewScriptTabMIClick(self)
                else
                  AddNewRSTabMIClick(self);
                Key := 0;
              end;

              if (Key = Ord('L')) then
              begin
                SQLEditor.SetFocus;
                SQLEditor.SelectAll;
              end;

              if (Key = Ord('B')) and (CurrentPerspective = apResultSet) then
              begin
                AddBookmarkMIClick(self);
                Key := 0;
              end;

              if (Key = Ord('W')) then
              begin
                // Close tab
                MainTabHeaderFrame.DeleteTab(MainTabHeaderFrame.SelectedTab);
                Key := 0;
              end;

              // Move to next tab.
              if (Key = VK_TAB) or (Key = VK_NEXT) then
              begin
                if ssShift in Shift then
                  MainTabHeaderFrame.SelectPreviousTabSheet
                else
                  MainTabHeaderFrame.SelectNextTabSheet;
                Key := 0;
              end;

              if (Key = VK_PRIOR) then
              begin
                MainTabHeaderFrame.SelectPreviousTabSheet;
                Key := 0;
              end;

              if (Key = Ord('0')) then
              begin
                DoSetActiveRSTab(10);
                Key := 0;
              end;
            end;
          end
        end;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.TntFormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
  begin
    with TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm) do
    begin
      if (Key = 17) then
        HideResultsetHits;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ReportBugMIClick(Sender: TObject);

begin
  BrowseWebPage('http://bugs.mysql.com');
  //CreateSubProcess(GetDefaultBrowser+' http://bugs.mysql.com', '');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.VisitMySQLcomMIClick(Sender: TObject);

begin
  BrowseWebPage('http://www.mysql.com');
  //CreateSubProcess(GetDefaultBrowser+' http://www.mysql.com', '');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ActivateQueryBrowserSection;

var
  i: integer;

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType <> SSTQB_QueryBrowser) then
  begin
    for i := 0 to SectionControls.SectionList.Count - 1 do
      if (TSidebarSection(SectionControls.SectionList[i]).SidebarSectionType = SSTQB_QueryBrowser) then
      begin
        SectionControls.ShowSidebarSection(TSidebarSection(SectionControls.SectionList[i]));
        break;
      end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.OnlineDocsMIClick(Sender: TObject);

begin
  ActivateQueryBrowserSection;

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).ShowHelpTabSheet(
      'http://dev.mysql.com/doc/mysql/en/index.html');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.OnlineReferenceCAPIMIClick(Sender: TObject);

begin
  ActivateQueryBrowserSection;

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).ShowHelpTabSheet(
      'http://dev.mysql.com/doc/mysql/en/C.html');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.OnlineDocsPHPAPIMIClick(Sender: TObject);

begin
  ActivateQueryBrowserSection;

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).ShowHelpTabSheet(
      'http://www.php.net/manual/en/ref.mysqli.php');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CutMIClick(Sender: TObject);

begin
  SendMessage(ActiveControl.Handle, WM_Cut, 0, 0);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CopyMIClick(Sender: TObject);

begin
  SendMessage(ActiveControl.Handle, WM_COPY, 0, 0);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.PasteMIClick(Sender: TObject);

begin
  SendMessage(ActiveControl.Handle, WM_Paste, 0, 0);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.SelectAllMIClick(Sender: TObject);

begin
  if (ActiveControl is TCustomEdit) then
    TCustomEdit(ActiveControl).SelectAll;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.FindMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).FindMIClick(Sender);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.HandleIdle(Sender: TObject; var Done: Boolean);

var
  Enable: Boolean;
  EnableSave, EnableSaveAs, EnableCloseTab: Boolean;
  i: integer;

begin
  // TODO: Reimplement this all using actions.
  if (ActiveControl is TCustomEdit) then
  begin
    Enable := TCustomEdit(Self.ActiveControl).SelLength > 0;
    CutMI.Enabled := Enable;
    CopyMI.Enabled := Enable;
    Enable := Clipboard.HasFormat(CF_TEXT);
    PasteMI.Enabled := Enable;
    SelectAllMI.Enabled := Enable;
  end
  else
    if (ActiveControl is TCustomUniCodeEdit) then
    begin
      Enable := TCustomUniCodeEdit(Self.ActiveControl).SelectionAvailable;
      CutMI.Enabled := Enable;
      CopyMI.Enabled := Enable;
      Enable := (Clipboard.HasFormat(CF_TEXT)) or
        (Clipboard.HasFormat(CF_UNICODETEXT));
      PasteMI.Enabled := Enable;
      SelectAllMI.Enabled := Enable;
    end
    else
    begin
      CutMI.Enabled := False;
      CopyMI.Enabled := False;
      PasteMI.Enabled := False;
    end;

  Enable := IsConnectedToInternet;
  OnlineDocsMI.Enabled := Enable;
  OnlineReferenceCAPIMI.Enabled := Enable;
  OnlineDocsPHPAPIMI.Enabled := Enable;
  ReportBugMI.Enabled := Enable;
  VisitMySQLcomMI.Enabled := Enable;

  if (MySQLConn.Connected) then
  begin
    if (ReconnectMI.Caption <> _('Reconnect')) then
      ReconnectMI.Caption := _('Reconnect');
  end
  else
  begin
    if (ReconnectMI.Caption <> _('Connect')) then
      ReconnectMI.Caption := _('Connect');
  end;

  // Port: collect the states and assign once; flipping the items False/True on every idle redraws the menu bar
  EnableSave := False;
  EnableSaveAs := False;
  EnableCloseTab := False;
  if (SectionControls <> nil) then
    if (SectionControls.CurrentSidebarSection <> nil) then
      if (SectionControls.CurrentSidebarSection.SectionForm is TQueryBrowserForm) then
      begin
        with TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm) do
        begin
          if (CurrentPerspective = apScript) and Assigned(ActiveScriptPanel) then
          begin
            EnableSave := True;
            EnableSaveAs := True;
          end
          else
            if (CurrentPerspective = apResultset) then
            begin
              if (SQLEditor.Content.Count > 0) then
                EnableSaveAs := True;

              if Assigned(ActiveResultset) then
              begin
                for I := 0 to self.ExportResultsetMI.Count - 1 do
                  self.ExportResultsetMI.Items[i].Enabled := (ActiveResultset.RowCount > 0);
              end
              else
                for I := 0 to self.ExportResultsetMI.Count - 1 do
                  self.ExportResultsetMI.Items[i].Enabled := False;
            end;

          EnableCloseTab := (MainTabHeaderFrame.TabCount > 1);

          for i := 0 to ScriptMI.Count - 1 do
            if (ScriptMI.Items[i].Tag = 1) then
              ScriptMI.Items[i].Enabled := (CurrentPerspective = apScript);

          if (MySQLConn <> nil) then
            if (MySQLConn.MajorVersion < 5) then
            begin
              CreateStoredProcedureFunctionMI.Enabled := False;
              EditAllStoredProceduresFunctionsMI.Enabled := False;
            end
            else
            begin
              CreateStoredProcedureFunctionMI.Enabled := True;
              EditAllStoredProceduresFunctionsMI.Enabled := True;
            end;
        end;
      end;

  SaveMI.Enabled := EnableSave;
  SaveAsMI.Enabled := EnableSaveAs;
  CloseTabMI.Enabled := EnableCloseTab;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.NewInstanceConnectionMIClick(Sender: TObject);

begin
  CreateSubProcess(Application.ExeName, '');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ManageConnectionsMIClick(Sender: TObject);

var
  OptionsForm: TOptionsForm;

begin
  OptionsForm := TOptionsForm.Create(self, TQueryBrowserOptionPagesForm.Create(self));
  try
    //Select Connections Page
    OptionsForm.ShowOptionPage(ConnectionsPage);

    OptionsForm.ShowModal;
  finally
    OptionsForm.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.SavecurrentConnectionMIClick(Sender: TObject);

var
  OptionsForm: TOptionsForm;

begin
  OptionsForm := TOptionsForm.Create(self, TQueryBrowserOptionPagesForm.Create(self));
  try
    //Select Connections Page
    OptionsForm.ShowOptionPage(ConnectionsPage);

    OptionsForm.AddConnection(MySQLConn.UserConnection);
    OptionsForm.ActiveControl := OptionsForm.ConnectionEd;

    OptionsForm.ShowModal;
  finally
    OptionsForm.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CheckFonts;

var
  I: integer;
  FontsInstalled: Boolean;

begin
  FontsInstalled := False;
  for I := 0 to Screen.Fonts.Count - 1 do
    if (CompareText(Screen.Fonts[I], 'Bitstream Vera Sans Mono') = 0) then
      FontsInstalled := True;

  if not FontsInstalled then
  begin
    if (not (FileExists(ExtractFilePath(Application.ExeName) + 'fonts\VeraMoBd.ttf'))) then
      raise EInOutError.Create(Format(_('The Bitstream Vera Sans Mono fonts cannot be found. Please download ' +
        'the font files from http://www.gnome.org/fonts and copy them into the fonts directory %s. The following files are needed: VeraMoBd.ttf, ' +
        'VeraMoBI.ttf, VeraMoIt.ttf, VeraMono.ttf.'),
        [ExtractFilePath(Application.ExeName) + 'fonts\']));

    if not FileExists(GetWindowsDir + 'fonts\VeraMoBd.ttf') then
    begin
      CopyDiskFile(ExtractFilePath(Application.ExeName) + 'fonts\VeraMoBd.ttf', GetWindowsDir + 'fonts\VeraMoBd.ttf',
        False);
      AddFontResourceW(PWideChar(GetWindowsDir + 'fonts\VeraMoBd.ttf'));
    end;

    if not FileExists(GetWindowsDir + 'fonts\VeraMoBI.ttf') then
    begin
      CopyDiskFile(ExtractFilePath(Application.ExeName) + 'fonts\VeraMoBI.ttf', GetWindowsDir + 'fonts\VeraMoBI.ttf',
      False);
    end;

    if not FileExists(GetWindowsDir + 'fonts\VeraMoIt.ttf') then
    begin
      CopyDiskFile(ExtractFilePath(Application.ExeName) + 'fonts\VeraMoIt.ttf', GetWindowsDir + 'fonts\VeraMoIt.ttf',
      False);
    end;

    if not FileExists(GetWindowsDir + 'fonts\VeraMono.ttf') then
    begin
      CopyDiskFile(ExtractFilePath(Application.ExeName) + 'fonts\VeraMono.ttf', GetWindowsDir + 'fonts\VeraMono.ttf',
      False);
    end;

    PostMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);

    // Port: the LCL has no Screen.ResetFonts.
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.NewResultsetTabMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType <> SSTQB_QueryBrowser) then
    ShowSection(0);

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).AddNewRSTabMIClick(self);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.NewSQLScriptTabMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType <> SSTQB_QueryBrowser) then
    ShowSection(0);

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).AddNewScriptTabMIClick(self);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.MySQLAdministratorMIClick(Sender: TObject);

  //---------------------------------------------------------------------------

  function ConvertToHex(const S: WideString): string;

  var
    Utf8String: string;
    
  begin
    Utf8String := Utf8Encode(S);
    SetLength(Result, 2 * Length(Utf8String));
    BinToHex(PChar(Utf8String), PChar(Result), Length(Utf8String));
  end;

  //---------------------------------------------------------------------------

var
  cmd: WideString;

begin
  cmd := GetMySQLAdministratorCmd;
  if cmd <> '' then
  begin
    if (MySQLConn.UserConnection <> nil) then
    begin
      cmd := cmd + ' "-u' + MySQLConn.UserConnection.username + '"';
      if MySQLConn.UserConnection.password <> '' then
        cmd := cmd + ' -x' + ConvertToHex(MySQLConn.UserConnection.password);
      cmd := cmd + ' "-h' + MySQLConn.UserConnection.hostname + '"';
      cmd := cmd + ' "-P' + IntToStr(MySQLConn.UserConnection.port) + '"';
    end;

    CreateSubProcess(cmd, '');
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.MySQLCommandLineClientMIClick(Sender: TObject);

var
  cmd: WideString;

begin
  cmd := GetMySQLCommandLineClientPath;
  if (cmd <> '') then
    CreateSubProcess(cmd + ' -h' + MySQLConn.UserConnection.hostname +
      ' -u' + MySQLConn.UserConnection.username +
      ' -p' + MySQLConn.UserConnection.password +
      ' -P' + IntToStr(MySQLConn.UserConnection.port), '');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.WindowsCommandLineMIClick(Sender: TObject);

var
  cmd: WideString;

begin
  cmd := GetSystemDir + 'cmd.exe';
  if (FileExists(cmd)) then
    CreateSubProcess(cmd, GetHomeDir);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ChangeDefaultSchemaMIClick(Sender: TObject);

var
  SchemaSelectionForm: TSchemaSelectionForm;

begin
  SchemaSelectionForm := TSchemaSelectionForm.Create(self, MySQLConn);
  try
    if (SchemaSelectionForm.ShowModal = mrOK) then
    begin
      if (SchemaSelectionForm.SelectedSchema <> nil) then
      begin
        MySQLConn.DefaultSchema := SchemaSelectionForm.SelectedSchema.schema_name;
        MySQLConn.UserConnection.schema := SchemaSelectionForm.SelectedSchema.schema_name;
        Application.MainForm.Caption := _('MySQL Query Browser') + ' - ' + MySQLConn.GetConnectionCaption;
      end;
    end;
  finally
    SchemaSelectionForm.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.OpenQueryMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SectionForm is TQueryBrowserForm) then
  begin
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).OpenQuery;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.OpenSQLScriptMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SectionForm is TQueryBrowserForm) then
  begin
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).OpenScript('', True);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.AboutMIClick(Sender: TObject);

begin
  ShowAboutDialog('MySQL Query Browser',
    product_version + ' ' + product_build_level,
    'Michael G. Zinner, graphical design, ' +
    'Windows development, library coding | ' +
    'Alfredo Kengi Kojima, Linux development, library coding | ' +
    'Mike Lischke, Windows development, library coding | ' +
    'Victor Vagin, library coding, QA | ' +
    'Ulrich Bayer, library coding, WIX | ' +
    'Brian Aker, main concept | ' +
    'Mike Hillyer, documentation');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ListreportedBugsMIClick(Sender: TObject);

begin
  BrowseWebPage('http://bugs.mysql.com/search.php?search_for=&limit=All&order_by=&direction=ASC&cmd=display&status=Active&severity=&showstopper=&bug_type=MySQL+Query+Browser&php_os=&phpver=&assign=&bug_age=0');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.DefaultSchemaChanged(var Message: TMessage);

begin
  if MySQLConn.GetConnectionCaption <> '' then
    MainForm.Caption := _('MySQL Query Browser') + ' - ' +
      MySQLConn.GetConnectionCaption
  else
    MainForm.Caption := _('MySQL Query Browser');
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.ReconnectMIClick(Sender: TObject);

begin
  // First try to reconnect with the current user connection. If that fails ask the user for details.
  if not MySQLConn.Reconnect then
    MySQLConn.ConnectToServer(True, True, True);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.SaveMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SectionForm is TQueryBrowserForm) then
  begin
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).Save;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.SaveAsMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SectionForm is TQueryBrowserForm) then
  begin
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).SaveAs;
  end;

end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.QuickStartGuideMIClick(Sender: TObject);

begin
  ActivateQueryBrowserSection;

  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
    TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).ShowQuickStartGuide;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.LaunchHelpMIClick(Sender: TObject);

begin
  ShowHelp;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.CloseTabMIClick(Sender: TObject);

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
  begin
    with TQueryBrowserForm(
      SectionControls.CurrentSidebarSection.SectionForm).MainTabHeaderFrame do
    begin
      if (TabCount > 1) then
        DeleteTab(SelectedTab);
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.TntFormActivate(Sender: TObject);

begin
  DoCurrentSectionChanged(self);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.RegExTextImporterMIClick(Sender: TObject);

begin
  if RegExTextImporterForm = nil then
  begin
    RegExTextImporterForm := TRegExTextImporterForm.Create(Self);
    RegExTextImporterForm.MySQLConn := MySQLConn;
  end;

  RegExTextImporterForm.Show;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.DoException(Sender: TObject; E: Exception);

begin
  if E is EMyxError then
    StatusBar.Panels[2].Text := EMyxError(E).FormattedMessage
  else
    StatusBar.Panels[2].Text := E.Message;
  FTextToClear := True;
  StatusBar.Invalidate;

  {ShowModalDialog(Application.Title+' '+_('Exception'),
    E.Message, myx_mtError, _('OK'));}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.StatusBarDrawPanel(StatusBar: TStatusBar; Panel: TStatusPanel; const Rect: TRect);

begin
  if (FTextToClear) then
    FStatusbarClearPNGImg.Draw(StatusBar.Canvas,
      Types.Rect(StatusBar.Panels[0].Width + 4, 4,
      StatusBar.Panels[0].Width + 4 + FStatusbarClearPNGImg.Width,
      4 + FStatusbarClearPNGImg.Height));
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.StatusBarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

begin
  if (X > StatusBar.Panels[0].Width) and
    (X < StatusBar.Panels[0].Width + StatusBar.Panels[1].Width) then
  begin
    StatusBar.Panels[2].Text := '';
    FTextToClear := False;
    StatusBar.Invalidate;
    StatusBar.Update;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.UpdateActions;

begin
  if (SectionControls.CurrentSidebarSection.SidebarSectionType = SSTQB_QueryBrowser) then
  begin
    TQueryBrowserForm(SectionControls.CurrentSidebarSection.SectionForm).UpdateActions;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMainForm.WMInitMenuPopup(var MSG: TWMInitMenuPopup);

begin
  if (Msg.MenuPopup = WindowMI.Handle) then
    BuildRegisterApplicationMenuItems(WindowMI);

  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

end.

