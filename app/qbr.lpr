{ SPDX-License-Identifier: GPL-2.0-or-later }
program qbr;

{$mode delphi}

{$R res/mysqlcommon.res}
{$R res/mysqlqb.res}

uses
  Interfaces, Classes, Forms, SysUtils, Windows, Messages, OptionsEditor,
  TntClasses, TntStdCtrls, TntCheckLst, TntExtCtrls, TntForms, TntComCtrls, TntButtons, TntGrids,
  TntMenus, TntActnList, TntDialogs, TntRegistry, TntSysUtils, TntSystem, TntClipBrd,
  gnugettext, PNGImage, PNGTools, ResSelfTest, AuxFuncs, Options, MyxError, AuxApplicationFuncs,
  MySQLConnection, ConnectToInstance, CommonFuncs, About, DevTools,
  CommonTypes, MySQLCommonFuncs, AppInstanceMgmt, TextSearch, AdvancedEdit, TabHeader,
  QueryBrowserOptionPages, ApplicationDataModule,
  Sections, InstanceSections, Toolbar, RegExTextImporter, ColorTypes, ColorTools,
  UCEShared, UCEHighlighter, UniCodeEditor, UCEEditorKeyCommands, UniCodeConsole,
  StringContainers, UCESQLHighlighter, MySQLResultSet, MySQLResultSetFieldViewer, MySQLResultSetControls, EditorTableVTEdit, EditorTableVTFKEdit, EditorTable, SQLErrorGrid, SchemataTreeView, SchemaSelection, EmbeddedWB, LexicalTools, SqlCmdPanel, ScriptPanel, TableDrag, QueryBrowser, Main;

var
  I: Integer;
  ExeDir: String;
  Res: Integer;
  ShotFile: String;
  K, J: Integer;
  Dlg: TForm;

procedure LogUnhandled(E: Exception);
var
  I: Integer;
begin
  // GUI program without console: write the problem next to the executable instead of
  // showing a modal error dialog that would block automated runs
  with TStringList.Create do
  try
    Add(E.ClassName + ': ' + E.Message);
    Add(BackTraceStrFunc(ExceptAddr));
    for I := 0 to ExceptFrameCount - 1 do
      Add(BackTraceStrFunc(ExceptFrames[I]));
    SaveToFile(ChangeFileExt(ParamStr(0), '.error.txt'));
  finally
    Free;
  end;
end;

type
  TExceptionLogger = class
    procedure Handle(Sender: TObject; E: Exception);
  end;

procedure TExceptionLogger.Handle(Sender: TObject; E: Exception);
begin
  LogUnhandled(E);
  Halt(3);                      // do not sit in a modal error dialog
end;

type
  TMsgCounter = class
    Counts: array[0..2047] of Integer;
    Old: TWndMethod;
    procedure Hook(var Msg: TMessage);
  end;

procedure TMsgCounter.Hook(var Msg: TMessage);
begin
  if Msg.Msg < 2048 then
    Inc(Counts[Msg.Msg]);
  Old(Msg);
end;

var
  Logger: TExceptionLogger;
  Counter: TMsgCounter;

begin
  Logger := TExceptionLogger.Create;
  Application.OnException := Logger.Handle;
  try
  if (ParamCount = 2) and (ParamStr(1) = '--selftest-resources') then
  begin
    Application.Initialize;
    RunResourceSelfTest(ParamStr(2));
    Exit;
  end;

  // Create common options (as the original program file does)
  MYXCommonOptions := TMYXCommonOptions.Create('query-browser');
  MYXCommonOptionProvider := MYXCommonOptions;

  // Bind to our own text domains instead of the default one
  ExeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  bindtextdomain('query-browser', ExeDir + 'locale');
  bindtextdomain('mysql-gui-common', ExeDir + 'locale');
  textdomain('query-browser');

  MYXCommonOptions.LoadOptions;
  if MYXCommonOptions.Language <> '-' then
    UseLanguage(MYXCommonOptions.Language);

  Application.Title := 'MySQL Query Browser';
  Application.Initialize;

  Trace('options loaded, command line checked; ppi=' + IntToStr(Screen.PixelsPerInch));
  CheckCommonCommandlineParameter;
  Trace('user=' + MYXCommonOptions.ConnectionUsername + ' host=' + MYXCommonOptions.ConnectionHost);

  // developer modes
  for I := 1 to ParamCount - 1 do
    if ParamStr(I) = '--shot-connect' then
    begin
      RunConnectDialogScreenshot(ParamStr(I + 1));
      Exit;
    end
    else if ParamStr(I) = '--shot-options' then
    begin
      RunOptionsScreenshot(ParamStr(I + 1));
      Exit;
    end
    else if ParamStr(I) = '--selftest-dialog' then
    begin
      RunDialogConnectSelftest(ParamStr(I + 1));
      Exit;
    end
    else if ParamStr(I) = '--selftest-connect' then
    begin
      RunConnectSelftest(ParamStr(I + 1));
      Exit;
    end;

  // normal start, as the original program file
  ApplicationDM := TApplicationDM.Create(nil);
  ApplicationDM.LoadOptions;
  ApplicationDM.CheckCommandlineParameter;

  Application.CreateForm(TMainForm, MainForm);
  Trace('main form created');
  if ApplicationDM.Options.StartScriptFile <> '' then
    Res := 1
  else
    Res := MainForm.MySQLConn.ConnectToServer(True, True, True);
  Trace('connect result ' + IntToStr(Res));

  if Res = 1 then
  begin
    MainForm.PrepareGUI;
    Trace('gui prepared');
    ShotFile := '';
    for I := 1 to ParamCount - 1 do
      if ParamStr(I) = '--shot-main' then
        ShotFile := ParamStr(I + 1);
    if ShotFile <> '' then
    begin
      // developer mode: let the window settle, write a screenshot and quit
      Trace('shot: show');
      MainForm.Show;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--expand' then
        begin
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevExpandSchema(StrToIntDef(ParamStr(I + 1), 0));
          for K := 1 to 60 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevDump;
        end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--script' then
        begin
          // --script "<sql separated by |>" <breakline or -1>
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevScript(
            UTF8Decode(StringReplace(ParamStr(I + 1), '|', #13#10, [rfReplaceAll])), StrToIntDef(ParamStr(I + 2), -1), True);
          for K := 1 to 40 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
        end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--type' then
        begin
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevType(ParamStr(I + 1));
          for K := 1 to 20 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevExecute;
          for K := 1 to 40 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
        end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--mouse-test' then
        begin
          // posts WM_MOUSEMOVE to our own main window over several areas and reports paint-related messages
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          Counter := TMsgCounter.Create;
          Counter.Old := MainForm.WindowProc;
          MainForm.WindowProc := Counter.Hook;
          with TStringList.Create do
          try
            for J := 0 to 4 do
            begin
              FillChar(Counter.Counts, SizeOf(Counter.Counts), 0);
              for K := 1 to 100 do
              begin
                PostMessage(MainForm.Handle, $0200, 0, ((70 + J * 150) shl 16) or (60 + K * 5 + J * 100));
                Application.ProcessMessages;
                MainForm.DevIdle;
              end;
              Add(Format('area %d: paint=%d ncpaint=%d erase=%d mousemove=%d setcursor=%d timer=%d',
                [J, Counter.Counts[$000F], Counter.Counts[$0085], Counter.Counts[$0014], Counter.Counts[$0200],
                 Counter.Counts[$0020], Counter.Counts[$0113]]));
            end;
            SaveToFile('mousetest.txt');
          finally
            Free;
          end;
        end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--help-page' then
        begin
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          Trace('help: start');
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevHelp(UTF8Decode(ParamStr(I + 1)));
          Trace('help: returned');
          for K := 1 to 40 do begin Application.ProcessMessages; CheckSynchronize; MainForm.DevIdle; Sleep(50); end;
        end;
      for I := 1 to ParamCount - 1 do
        if (ParamStr(I) = '--upper-tab') or (ParamStr(I) = '--lower-tab') then
        begin
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevTab(
            ParamStr(I) = '--upper-tab', StrToIntDef(ParamStr(I + 1), 0));
          for K := 1 to 20 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
        end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--dblclick-table' then
        begin
          // --dblclick-table <schema index> <table index>
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevDblClickTable(
            StrToIntDef(ParamStr(I + 1), 0), StrToIntDef(ParamStr(I + 2), 0), (I + 3 <= ParamCount) and (ParamStr(I + 3) = 'drop'));
          for K := 1 to 60 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
        end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--sql' then
        begin
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevSetText(UTF8Decode(ParamStr(I + 1)));
          for K := 1 to 20 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevExecute;
          for K := 1 to 60 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevDump;
        end;
      for I := 1 to 40 do
      begin
        Application.ProcessMessages;
        CheckSynchronize;
        Sleep(50);
      end;
      for I := 1 to ParamCount - 1 do
        if ParamStr(I) = '--cmd' then
        begin
          // runs after --sql/--type; repeatable only once per run
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevCommand(ParamStr(I + 1));
          if (I + 2 <= ParamCount) and (Copy(ParamStr(I + 2), 1, 5) = 'then:') then
          begin
            for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
            TQueryBrowserForm(MainForm.SectionControls.CurrentSidebarSection.SectionForm).DevCommand(Copy(ParamStr(I + 2), 6, MaxInt));
          end;
          for K := 1 to 60 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
        end;
      for I := 1 to ParamCount - 2 do
        if ParamStr(I) = '--dialog' then
        begin
          // --dialog textsearch|optionpages|regex|schemasel <png file>
          for K := 1 to 10 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
          Dlg := nil;
          if ParamStr(I + 1) = 'textsearch' then
            Dlg := TTextSearchForm.Create(MainForm, MYXCommonOptionProvider)
          else if ParamStr(I + 1) = 'optionpages' then
            Dlg := TOptionsForm.Create(MainForm, TQueryBrowserOptionPagesForm.Create(MainForm))
          else if ParamStr(I + 1) = 'regex' then
            Dlg := TRegExTextImporterForm.Create(MainForm)
          else if ParamStr(I + 1) = 'schemasel' then
            Dlg := TSchemaSelectionForm.Create(MainForm, MainForm.MySQLConn);
          if Dlg <> nil then
          begin
            Dlg.Show;
            for K := 1 to 20 do begin Application.ProcessMessages; CheckSynchronize; Sleep(50); end;
            CaptureWindowToPng(Dlg, ParamStr(I + 2));
            Dlg.Close;
          end;
        end;
      Trace('shot: capture');
      CaptureWindowToPng(MainForm, ShotFile);
      Trace('shot: done');
      Exit;
    end;
    Application.Run;
  end;
  except
    on E: Exception do
      LogUnhandled(E);
  end;
end.
