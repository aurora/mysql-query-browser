{ SPDX-License-Identifier: GPL-2.0-or-later }
unit DevTools;

{ Developer modes of the executable (not part of the original program):

    qbr --shot-connect out.png     show the connect dialog, save a screenshot of it, exit
    qbr -u root -p ... -h ... -P ... --selftest-connect out.txt
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
procedure RunConnectSelftest(const ReportFile: String);
procedure RunDialogConnectSelftest(const ReportFile: String);

implementation

uses
  Windows, Classes, SysUtils, Forms, Graphics, Controls, MySQLConnection, ConnectToInstance, Options,
  OptionsEditor,
  myx_types, myx_public_interface;

function PrintWindow(hwnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall; external 'user32.dll';

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
  Bmp, Crop: TBitmap;
  Png: TPortableNetworkGraphic;
  R: TRect;
  ScreenDC, MemDC: HDC;
  HBmp: HBITMAP;
  OldBmp: HGDIOBJ;
  L, Rr, Bt: Integer;
begin
  Form := TCustomForm(Wnd);
  Form.Invalidate;
  Application.ProcessMessages;
  Sleep(150);
  Application.ProcessMessages;
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
  finally
    Dlg.Free;
  end;
end;

procedure RunOptionsScreenshot(const FileBase: String);
var
  Dlg: TOptionsForm;
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
