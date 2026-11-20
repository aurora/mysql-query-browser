{ SPDX-License-Identifier: GPL-2.0-or-later }
unit DevTools;

{ Developer modes of the executable (not part of the original program):

    querymole --shot-connect out.png     show the connect dialog, save a screenshot of it (and out_details.png with
                                         "Details >>" open), exit
    querymole --selftest-test-connection <name> out.txt
                                         the connection manager's "Test" (ADR-0051) for the stored connection
                                         <name>: "ok: ..." or "failed: ..." in out.txt
    querymole --shot-ssh out.png         the same for the SSH tunnel dialog (ADR-0048), filled from the stored
                                         connection named with -c
    querymole -u root -p ... -h ... -P ... --selftest-connect out.txt
                                   connect like the original does for command line
                                   parameters (no dialog) and report the result in out.txt

  A GUI program has no console, so results go to files. }

{$mode delphi}

interface

procedure Trace(const Msg: String);
procedure EnsureMainForm;
procedure CaptureWindowToPng(Wnd: TObject; const FileName: String);
procedure RunConnectDialogScreenshot(const FileName: String);
procedure RunOptionsScreenshot(const FileBase: String);
procedure RunSSHDialogScreenshot(const FileName: String);
procedure RunTestConnectionSelftest(const Name, ReportFile: String);
procedure RunConnectSelftest(const ReportFile: String);
procedure RunDialogConnectSelftest(const ReportFile: String);

implementation

uses
  {$IFDEF MSWINDOWS}Windows{$ELSE}LCLIntf, LCLType, WinAliases, Types{$ENDIF}, Classes, SysUtils, Forms, Graphics, Controls, MySQLConnection, ConnectToInstance, Options,
  OptionsEditor, SSHTunnelDialog, ConnectionTest,
  myx_types, myx_util_public_interface, myx_public_interface;

{$IFDEF MSWINDOWS}
function PrintWindow(hwnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall; external 'user32.dll';
{$ENDIF}

procedure Trace(const Msg: String);
var
  F: TextFile;
  Name: String;
begin
  // opt-in: set QBR_TRACE=1 to log program flow next to the executable
  if GetEnvironmentVariable('QBR_TRACE') = '' then
    Exit;
  Name := ChangeFileExt(ParamStr(0), '.trace.txt');
  AssignFile(F, Name);
  if FileExists(Name) then Append(F) else Rewrite(F);
  WriteLn(F, FormatDateTime('hh:nn:ss.zzz', Now), ' ', Msg);
  CloseFile(F);
end;

var
  DummyMainForm: TForm;

procedure EnsureMainForm;
begin
  // Forms positioned relative to the main form (poMainFormCenter) need one in the LCL. The
  // real program has it; the developer modes create a hidden stand-in.
  if Application.MainForm = nil then
    Application.CreateForm(TForm, DummyMainForm);
end;

function BlackColumn(B: TBitmap; X: Integer): Boolean;
var
  Y: Integer;
begin
  for Y := B.Height div 3 to B.Height - 1 do      // the title bar spans the black border
    if B.Canvas.Pixels[X, Y] <> clBlack then
      Exit(False);
  Result := True;
end;

procedure CaptureWindowToPng(Wnd: TObject; const FileName: String);
var
  Form: TCustomForm;
  {$IFDEF MSWINDOWS}
  Bmp, Crop: TBitmap;
  Png: TPortableNetworkGraphic;
  R: TRect;
  ScreenDC, MemDC: HDC;
  HBmp: HBITMAP;
  OldBmp: HGDIOBJ;
  L, Rr, Bt: Integer;
  {$ELSE}
  Bmp, Shot: TBitmap;
  Png: TPortableNetworkGraphic;
  R: TRect;
  ScreenDC: HDC;
  L: Integer;
  {$ENDIF}
begin
  Form := TCustomForm(Wnd);
  Form.Invalidate;
  Application.ProcessMessages;
  Sleep(150);
  Application.ProcessMessages;
  {$IFNDEF MSWINDOWS}
  // No PrintWindow outside Windows, and the LCL's PaintTo/GetFormImage leaves out native GTK widgets: copy
  // the window's area from the screen. Works on X11 (also Xvfb, as the self-tests use), not on Wayland.
  for L := 1 to 20 do                   // let the window be mapped and painted
  begin
    Application.ProcessMessages;
    Sleep(25);
  end;
  Bmp := TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    GetWindowRect(Form.Handle, R);
    ScreenDC := GetDC(0);
    Shot := TBitmap.Create;
    try
      Bmp.SetSize(R.Right - R.Left, R.Bottom - R.Top);
      {$IFDEF DARWIN}
      // Port: on macOS the screen copy shows whatever window is in front (a program started from a terminal
      // does not come to the front); the Cocoa widgetset's PaintTo takes an image of this window only
      Form.PaintTo(Bmp.Canvas, 0, 0);
      {$ELSE}
      Shot.LoadFromDevice(ScreenDC);
      Bmp.Canvas.CopyRect(Rect(0, 0, Bmp.Width, Bmp.Height), Shot.Canvas, R);
      {$ENDIF}
    finally
      Shot.Free;
      ReleaseDC(0, ScreenDC);
    end;
    Png.Assign(Bmp);
    Png.SaveToFile(FileName);
  finally
    Png.Free;
    Bmp.Free;
  end;
  {$ELSE}
  Bmp := TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    GetWindowRect(Form.Handle, R);
    ScreenDC := GetDC(0);
    MemDC := CreateCompatibleDC(ScreenDC);
    HBmp := CreateCompatibleBitmap(ScreenDC, R.Right - R.Left, R.Bottom - R.Top);
    OldBmp := SelectObject(MemDC, HBmp);
    PrintWindow(Form.Handle, MemDC, 2);                  // PW_RENDERFULLCONTENT
    SelectObject(MemDC, OldBmp);
    DeleteDC(MemDC);
    ReleaseDC(0, ScreenDC);
    Bmp.Handle := HBmp;
    // Windows 10/11: invisible resize border is left black by PrintWindow
    L := 0;
    Rr := Bmp.Width;
    Bt := Bmp.Height;
    while (L < Rr - 1) and BlackColumn(Bmp, L) do Inc(L);
    while (Rr > L + 1) and BlackColumn(Bmp, Rr - 1) do Dec(Rr);
    if (L > 0) or (Rr < Bmp.Width) then
    begin
      Crop := TBitmap.Create;
      try
        Crop.SetSize(Rr - L, Bt);
        Crop.Canvas.CopyRect(Rect(0, 0, Crop.Width, Crop.Height), Bmp.Canvas, Rect(L, 0, Rr, Bt));
        Bmp.Assign(Crop);
      finally
        Crop.Free;
      end;
    end;
    Png.Assign(Bmp);
    Png.SaveToFile(FileName);
  finally
    Png.Free;
    Bmp.Free;
  end;
  {$ENDIF}
end;

procedure RunConnectDialogScreenshot(const FileName: String);
var
  Dlg: TConnectToInstanceForm;
begin
  Dlg := TConnectToInstanceForm.Create(nil, True, False);
  try
    Dlg.Left := 40;
    Dlg.Top := 40;
    Dlg.Position := poDesigned;
    Dlg.Show;
    CaptureWindowToPng(Dlg, FileName);
    Dlg.DetailsBtn.Click;
    CaptureWindowToPng(Dlg, ChangeFileExt(FileName, '') + '_details.png');
  finally
    Dlg.Free;
  end;
end;

procedure RunSSHDialogScreenshot(const FileName: String);
var
  Dlg: TSSHTunnelForm;
  Stored: TConnectToInstanceForm;
begin
  EnsureMainForm;   // the dialog is centred on the main form
  Dlg := TSSHTunnelForm.Create(nil);
  try
    // the SSH settings of the stored connection the dialog picks (the last one, or the one named with -c)
    Stored := TConnectToInstanceForm.Create(nil, True, False);
    try
      if (Stored.User_Connection <> nil) then
        Dlg.LoadOptions(Stored.User_Connection.advanced_options);
    finally
      Stored.Free;
    end;
    Dlg.Left := 40;
    Dlg.Top := 40;
    Dlg.Position := poDesigned;
    Dlg.Show;
    CaptureWindowToPng(Dlg, FileName);
  finally
    Dlg.Free;
  end;
end;

procedure WriteReport(const FileName, Msg: String); forward;

procedure RunTestConnectionSelftest(const Name, ReportFile: String);
var
  Conns: PMYX_USER_CONNECTIONS;
  Stored: TMYX_USER_CONNECTIONS;
  Error: MYX_LIB_ERROR;
  I: Integer;
  Outcome: TConnectionTestResult;
begin
  Conns := myx_load_user_connections(MYXCommonOptions.UserDataDir + 'mysqlx_user_connections.xml', @Error);
  if Error <> MYX_NO_ERROR then
  begin
    WriteReport(ReportFile, 'failed: the stored connections could not be read');
    Exit;
  end;
  try
    Stored := TMYX_USER_CONNECTIONS.Create(Conns);
    try
      for I := 0 to Stored.user_connections.Count - 1 do
        if Stored.user_connections[I].connection_name = Name then
        begin
          Outcome := TestConnection(Stored.user_connections[I]);
          if Outcome.OK then
            WriteReport(ReportFile, 'ok: ' + StringReplace(Outcome.Text, LineEnding, ' ', [rfReplaceAll]))
          else
            WriteReport(ReportFile, 'failed: ' + StringReplace(Outcome.Text, LineEnding, ' ', [rfReplaceAll]));
          Exit;
        end;
      WriteReport(ReportFile, 'failed: no stored connection named ' + Name);
    finally
      Stored.Free;
    end;
  finally
    myx_free_user_connections(Conns);
  end;
end;

procedure RunOptionsScreenshot(const FileBase: String);
var
  Dlg: TOptionsForm;
  I: Integer;
begin
  EnsureMainForm;
  Dlg := TOptionsForm.Create(nil, nil);
  try
    Dlg.Left := 40;
    Dlg.Top := 40;
    Dlg.Position := poDesigned;
    Dlg.Show;
    CaptureWindowToPng(Dlg, FileBase + '_default.png');
    Dlg.ShowOptionPage(ConnectionsPage);
    CaptureWindowToPng(Dlg, FileBase + '_connections.png');
    // the first stored connection selected, when there is one
    for I := 0 to Dlg.ConnsTreeView.Items.Count - 1 do
      if Dlg.ConnsTreeView.Items[I].Data <> nil then
      begin
        Dlg.ConnsTreeView.Selected := Dlg.ConnsTreeView.Items[I];
        CaptureWindowToPng(Dlg, FileBase + '_connection.png');
        Break;
      end;
  finally
    Dlg.Free;
  end;
end;

procedure WriteReport(const FileName, Msg: String);
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.Add(Msg);
    List.SaveToFile(FileName);
  finally
    List.Free;
  end;
end;

procedure RunConnectSelftest(const ReportFile: String);
var
  Conn: TMySQLConn;
  Res: Integer;
begin
  Trace('selftest: creating connection');
  Conn := TMySQLConn.Create(nil);
  try
    try
      Res := Conn.ConnectToServer(True, True, False);
      Trace('selftest: ConnectToServer returned ' + IntToStr(Res));
      if Res = 1 then
        WriteReport(ReportFile, Format('connected: server %d.%d', [Conn.MajorVersion, Conn.MinorVersion]))
      else
        WriteReport(ReportFile, 'not connected, result ' + IntToStr(Res));
    except
      on E: Exception do
        WriteReport(ReportFile, 'exception ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    Conn.Free;
  end;
end;

procedure RunDialogConnectSelftest(const ReportFile: String);
var
  Dlg: TConnectToInstanceForm;
  Started: QWord;
  Result: String;
begin
  Dlg := TConnectToInstanceForm.Create(nil, True, False);
  try
    Dlg.Show;
    Dlg.HostnameCBox.Text := MYXCommonOptions.ConnectionHost;
    Dlg.PortEd.Text := IntToStr(MYXCommonOptions.ConnectionPort);
    Dlg.UsernameCBox.Text := MYXCommonOptions.ConnectionUsername;
    Dlg.PasswordEd.Text := MYXCommonOptions.ConnectionPassword;
    Dlg.CheckBtnState;
    Trace('dialog: OK enabled = ' + BoolToStr(Dlg.OKBtn.Enabled, True));
    Dlg.OKBtnClick(nil);                      // starts the connect thread like a click would
    Started := GetTickCount64;
    while (Dlg.ModalResult = 0) and (Dlg.PMySQL = nil) and (GetTickCount64 - Started < 15000) do
    begin
      Application.ProcessMessages;
      CheckSynchronize(10);                   // the thread reports through Synchronize
    end;
    Application.ProcessMessages;
    if Dlg.PMySQL <> nil then
      Result := 'dialog connected, server ' + IntToStr(myx_get_mysql_major_version(Dlg.PMySQL)) + '.' +
        IntToStr(myx_get_mysql_minor_version(Dlg.PMySQL)) + ', ModalResult=' + IntToStr(Dlg.ModalResult)
    else
      Result := 'dialog did not connect, ModalResult=' + IntToStr(Dlg.ModalResult);
  finally
    Dlg.Free;
  end;
  WriteReport(ReportFile, Result);
end;

end.
