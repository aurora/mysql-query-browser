{ SPDX-License-Identifier: GPL-2.0-or-later }
program qbr;

{$mode delphi}

{$R res/mysqlcommon.res}
{$R res/mysqlqb.res}

uses
  Interfaces, Classes, Forms, SysUtils,
  TntClasses, TntStdCtrls, TntCheckLst, TntExtCtrls, TntForms, TntComCtrls, TntButtons, TntGrids,
  TntMenus, TntActnList, TntDialogs, TntRegistry, TntSysUtils, TntSystem, TntClipBrd,
  gnugettext, PNGImage, PNGTools, ResSelfTest, AuxFuncs, Options, MyxError, AuxApplicationFuncs,
  MySQLConnection, ConnectToInstance, CommonFuncs, About, DevTools,
  CommonTypes, MySQLCommonFuncs, AppInstanceMgmt, TextSearch, AdvancedEdit, TabHeader,
  QueryBrowserOptionPages, ApplicationDataModule,
  Sections, InstanceSections, Toolbar, RegExTextImporter, ColorTypes, ColorTools;

var
  I: Integer;
  ExeDir: String;
  Conn: TMySQLConn;
  Res: Integer;

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

var
  Logger: TExceptionLogger;

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

  Trace('options loaded, command line checked');
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

  // normal start: connect (shows the dialog unless the command line says where to connect)
  Conn := TMySQLConn.Create(nil);
  try
    Res := Conn.ConnectToServer(True, True, True);
    if Res = 1 then
      Application.MessageBox('Connected. The main window is not ported yet.', 'MySQL Query Browser', 0);
  finally
    Conn.Free;
  end;
  except
    on E: Exception do
      LogUnhandled(E);
  end;
end.
