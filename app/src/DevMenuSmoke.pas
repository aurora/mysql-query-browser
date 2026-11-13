{ SPDX-License-Identifier: GPL-2.0-or-later }
unit DevMenuSmoke;

{ Developer mode (--menu-smoke list|run <report>): clicks every menu entry of the open forms (main menus and popup
  menus, also those of frames) and reports what happened. A timer closes modal dialogs; exceptions are recorded
  instead of ending the program; the report is written after every entry, so a hang shows as its last line.
  Entries that open native file dialogs, the browser, or end the program are left out (Skipped). }

{$mode delphi}

interface

procedure RunMenuSmoke(const Mode, ReportFile: String);

implementation

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Menus, ExtCtrls;

const
  // parts of captions (lower case, without "&") whose entries are not clicked
  Skipped: array[0..22] of String = ('exit', 'quit', 'close', 'open', 'save', 'load', 'import', 'export', 'print',
    'drop', 'delete', 'remove', 'kill', 'help', 'online', 'website', 'bug', 'forum', 'update', 'browse', 'font',
    'color', 'guide');

type
  TSmoke = class
    Report: TStringList;
    ReportFile: String;
    Errors: Integer;
    Timer: TTimer;
    Closed: TStringList;
    procedure HandleException(Sender: TObject; E: Exception);
    procedure CloseDialogs(Sender: TObject);
    procedure Settle(Ms: Integer);
    procedure Save;
  end;

procedure AddBacktrace(Report: TStrings);
var
  I: Integer;
begin
  Report.Add('      ' + Trim(BackTraceStrFunc(ExceptAddr)));
  for I := 0 to ExceptFrameCount - 1 do
    if I < 12 then
      Report.Add('      ' + Trim(BackTraceStrFunc(ExceptFrames[I])));
end;

procedure TSmoke.HandleException(Sender: TObject; E: Exception);
begin
  Inc(Errors);
  Report.Add('    EXCEPTION ' + E.ClassName + ': ' + E.Message);
  AddBacktrace(Report);
  Save;
end;

procedure TSmoke.CloseDialogs(Sender: TObject);
var
  F: TCustomForm;
begin
  F := Screen.ActiveCustomForm;
  if (F <> nil) and (F <> Application.MainForm) and (fsModal in F.FormState) then
  begin
    Closed.Add(F.ClassName);
    F.ModalResult := mrCancel;
  end;
end;

procedure TSmoke.Settle(Ms: Integer);
var
  T: QWord;
begin
  T := GetTickCount64;
  repeat
    Application.ProcessMessages;
    CheckSynchronize(10);
    Sleep(5);
  until GetTickCount64 - T >= QWord(Ms);
end;

procedure TSmoke.Save;
begin
  Report.SaveToFile(ReportFile);
end;

function CleanCaption(const S: String): String;
begin
  Result := StringReplace(S, '&', '', [rfReplaceAll]);
end;

function IsSkipped(const Caption: String): Boolean;
var
  S: String;
  I: Integer;
begin
  S := LowerCase(CleanCaption(Caption));
  for I := Low(Skipped) to High(Skipped) do
    if Pos(Skipped[I], S) > 0 then
      Exit(True);
  Result := False;
end;

procedure CollectMenus(Owner: TComponent; Menus: TList);
var
  I: Integer;
begin
  for I := 0 to Owner.ComponentCount - 1 do
  begin
    if (Owner.Components[I] is TMenu) and (Menus.IndexOf(Owner.Components[I]) < 0) then
      Menus.Add(Owner.Components[I]);
    if Owner.Components[I].ComponentCount > 0 then
      CollectMenus(Owner.Components[I], Menus);
  end;
end;

procedure CollectItems(Item: TMenuItem; const Path: String; Items, Paths: TStrings);
var
  I: Integer;
  P: String;
begin
  for I := 0 to Item.Count - 1 do
  begin
    if Item[I].IsLine then
      Continue;
    P := Path + ' > ' + CleanCaption(Item[I].Caption);
    if Item[I].Count > 0 then
      CollectItems(Item[I], P, Items, Paths)
    else
    begin
      Paths.Add(P);
      Items.AddObject(P, Item[I]);
    end;
  end;
end;

procedure PrepareMenu(Item: TMenuItem);
// What opening the menu does before the entry can be clicked: a popup menu's OnPopup, or the OnClick of the
// entries above it in a main menu (the LCL calls it when a submenu opens).
var
  Menu: TMenu;
  Parents: TList;
  P: TMenuItem;
  I: Integer;
begin
  Menu := Item.GetParentMenu;
  if (Menu is TPopupMenu) and Assigned(TPopupMenu(Menu).OnPopup) then
    TPopupMenu(Menu).OnPopup(Menu);
  Parents := TList.Create;
  try
    P := Item.Parent;
    while (P <> nil) and (P.Parent <> nil) do
    begin
      Parents.Insert(0, P);
      P := P.Parent;
    end;
    for I := 0 to Parents.Count - 1 do
      if Assigned(TMenuItem(Parents[I]).OnClick) then
        TMenuItem(Parents[I]).OnClick(TMenuItem(Parents[I]));
  finally
    Parents.Free;
  end;
end;

procedure RunMenuSmoke(const Mode, ReportFile: String);
var
  Smoke: TSmoke;
  Menus: TList;
  Items, Paths: TStringList;
  I, FormCount, J: Integer;
  Item: TMenuItem;
  Menu: TMenu;
  OldHandler: TExceptionEvent;
begin
  Smoke := TSmoke.Create;
  Menus := TList.Create;
  Items := TStringList.Create;
  Paths := TStringList.Create;
  Smoke.Report := TStringList.Create;
  Smoke.Closed := TStringList.Create;
  Smoke.ReportFile := ReportFile;
  OldHandler := Application.OnException;
  try
    for I := 0 to Screen.FormCount - 1 do
      CollectMenus(Screen.Forms[I], Menus);
    for I := 0 to Menus.Count - 1 do
    begin
      Menu := TMenu(Menus[I]);
      CollectItems(Menu.Items, Menu.Owner.Name + '.' + Menu.Name, Items, Paths);
    end;

    if Mode = 'list' then
    begin
      for I := 0 to Items.Count - 1 do
      begin
        Item := TMenuItem(Items.Objects[I]);
        Smoke.Report.Add(Format('%s%s  [enabled=%s visible=%s handler=%s]', [IfThen(IsSkipped(Item.Caption),
          'SKIP ', ''), Items[I], BoolToStr(Item.Enabled, True), BoolToStr(Item.Visible, True),
          BoolToStr(Assigned(Item.OnClick) or Assigned(Item.Action), True)]));
      end;
      Smoke.Save;
      Exit;
    end;

    Application.OnException := Smoke.HandleException;
    Smoke.Timer := TTimer.Create(nil);
    Smoke.Timer.Interval := 700;
    Smoke.Timer.OnTimer := Smoke.CloseDialogs;
    for I := 0 to Items.Count - 1 do
    begin
      Item := TMenuItem(Items.Objects[I]);
      if IsSkipped(Item.Caption) then
        Continue;
      // Open the menu as a user would, so that it can enable and disable its entries first.
      try
        PrepareMenu(Item);
      except
        on E: Exception do
        begin
          Inc(Smoke.Errors);
          Smoke.Report.Add('opening the menu of ' + Items[I]);
          Smoke.Report.Add('    EXCEPTION ' + E.ClassName + ': ' + E.Message);
          AddBacktrace(Smoke.Report);
        end;
      end;
      if not (Item.Enabled and Item.Visible) then
      begin
        Smoke.Report.Add('disabled ' + Items[I]);
        Continue;
      end;
      Smoke.Report.Add('click ' + Items[I]);
      Smoke.Save;
      Smoke.Closed.Clear;
      FormCount := Screen.FormCount;
      try
        if Assigned(Application.MainForm) and Application.MainForm.CanFocus then
          Application.MainForm.SetFocus;
        Item.Click;
        Smoke.Settle(800);
      except
        on E: Exception do
        begin
          Inc(Smoke.Errors);
          Smoke.Report.Add('    EXCEPTION ' + E.ClassName + ': ' + E.Message);
          AddBacktrace(Smoke.Report);
        end;
      end;
      if Smoke.Closed.Count > 0 then
        Smoke.Report.Add('    closed modal ' + Smoke.Closed.CommaText);
      // windows that stayed open (non-modal) are closed again
      for J := Screen.FormCount - 1 downto FormCount do
        if (J < Screen.FormCount) and Screen.Forms[J].Visible and (Screen.Forms[J] <> Application.MainForm) then
        begin
          Smoke.Report.Add('    closed window ' + Screen.Forms[J].ClassName);
          Screen.Forms[J].Close;
        end;
      Smoke.Save;
    end;
    Smoke.Report.Add(Format('done: %d entries, %d exceptions', [Items.Count, Smoke.Errors]));
    Smoke.Save;
  finally
    Application.OnException := OldHandler;
    Smoke.Timer.Free;
    Smoke.Closed.Free;
    Smoke.Report.Free;
    Smoke.Free;
    Paths.Free;
    Items.Free;
    Menus.Free;
  end;
end;

end.
