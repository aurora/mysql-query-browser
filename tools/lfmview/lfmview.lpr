program lfmview;

{ Loads a .lfm file into a plain TForm without any form class, logs everything
  the LCL does not understand and writes screenshots. Used to review the forms
  converted from the original Delphi .dfm files.

    lfmview <file.lfm> [--png out.png] [--tabs] [--quiet]

  --png   save a screenshot (including title bar and border) and exit
  --tabs  with --png: additionally save one screenshot per tab page
}

{$mode objfpc}{$H+}

uses
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  Interfaces, Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  Buttons, Menus, Grids, ValEdit, ImgList, Dialogs, Spin, CheckLst, LResources, LCLType,
  laz.VirtualTrees, SynEdit, SynHighlighterSQL;

type
  TLoader = class
    Log: TStringList;
    procedure OnAppException(Sender: TObject; E: Exception);
    procedure OnError(Reader: TReader; const Message: string; var Handled: Boolean);
    procedure OnFindMethod(Reader: TReader; const AMethod: string; var Address: Pointer; var Error: Boolean);
    procedure OnFindClass(Reader: TReader; const AClass: string; var ComponentClass: TComponentClass);
  end;

procedure TLoader.OnAppException(Sender: TObject; E: Exception);
begin
  WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
end;

procedure TLoader.OnError(Reader: TReader; const Message: string; var Handled: Boolean);
begin
  Log.Add('property: ' + Message);
  Handled := True;
end;

procedure TLoader.OnFindMethod(Reader: TReader; const AMethod: string; var Address: Pointer; var Error: Boolean);
begin
  Address := nil;
  Error := False;                     // event handlers do not exist in the viewer
end;

procedure TLoader.OnFindClass(Reader: TReader; const AClass: string; var ComponentClass: TComponentClass);
begin
  if GetClass(AClass) <> nil then
    Exit;
  if (Copy(AClass, Length(AClass) - 3, 4) = 'Form') and (AClass <> 'TForm') then
    ComponentClass := TForm
  else
  begin
    Log.Add('class: ' + AClass + ' unknown, shown as TPanel');
    ComponentClass := TPanel;
  end;
end;

{$IFDEF WINDOWS}
function PrintWindow(hwnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall; external 'user32.dll';
{$ENDIF}

function BlackColumn(B: TBitmap; X: Integer): Boolean;
var
  Y: Integer;
begin
  for Y := B.Height div 3 to B.Height - 1 do      // the title bar spans the black border
    if B.Canvas.Pixels[X, Y] <> clBlack then
      Exit(False);
  Result := True;
end;

function BlackRow(B: TBitmap; Y: Integer): Boolean;
var
  X: Integer;
begin
  for X := B.Width div 3 to B.Width - 1 do
    if B.Canvas.Pixels[X, Y] <> clBlack then
      Exit(False);
  Result := True;
end;

procedure CaptureForm(Form: TForm; const FileName: string);
var
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
  {$IFDEF WINDOWS}
  R: TRect;
  ScreenDC, MemDC: HDC;
  Crop: TBitmap;
  L, T, Rr, Bt: Integer;
  HBmp: HBITMAP;
  OldBmp: HGDIOBJ;
  {$ENDIF}
begin
  Form.Invalidate;
  Application.ProcessMessages;
  Sleep(100);
  Application.ProcessMessages;
  Bmp := TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    {$IFDEF WINDOWS}
    GetWindowRect(Form.Handle, R);
    ScreenDC := GetDC(0);
    MemDC := CreateCompatibleDC(ScreenDC);
    HBmp := CreateCompatibleBitmap(ScreenDC, R.Right - R.Left, R.Bottom - R.Top);
    OldBmp := SelectObject(MemDC, HBmp);
    PrintWindow(Form.Handle, MemDC, 2);        // PW_RENDERFULLCONTENT
    SelectObject(MemDC, OldBmp);
    DeleteDC(MemDC);
    ReleaseDC(0, ScreenDC);
    Bmp.Handle := HBmp;
    // Windows 10/11 windows have an invisible resize border that PrintWindow leaves
    // black: trim completely black columns/rows at the edges.
    L := 0;
    T := 0;
    Rr := Bmp.Width;
    Bt := Bmp.Height;
    while (L < Rr - 1) and BlackColumn(Bmp, L) do Inc(L);
    while (Rr > L + 1) and BlackColumn(Bmp, Rr - 1) do Dec(Rr);
    while (Bt > T + 1) and BlackRow(Bmp, Bt - 1) do Dec(Bt);
    if (L > 0) or (T > 0) or (Rr < Bmp.Width) or (Bt < Bmp.Height) then
    begin
      Crop := TBitmap.Create;
      try
        Crop.SetSize(Rr - L, Bt - T);
        Crop.Canvas.CopyRect(Rect(0, 0, Crop.Width, Crop.Height), Bmp.Canvas, Rect(L, T, Rr, Bt));
        Bmp.Assign(Crop);
      finally
        Crop.Free;
      end;
    end;
    {$ELSE}
    Bmp.Assign(Form.GetFormImage);
    {$ENDIF}
    Png.Assign(Bmp);
    Png.SaveToFile(FileName);
  finally
    Png.Free;
    Bmp.Free;
  end;
end;

procedure CollectPageControls(C: TComponent; List: TList);
var
  I: Integer;
begin
  if C is TPageControl then
    List.Add(C);
  for I := 0 to C.ComponentCount - 1 do
    CollectPageControls(C.Components[I], List);
end;

var
  FileName, PngName: string;
  WithTabs, Quiet: Boolean;
  I, P, T: Integer;
  Src, Bin: TMemoryStream;
  Reader: TReader;
  Loader: TLoader;
  Form: TForm;
  Pages: TList;
  PC: TPageControl;
  Base: string;
begin
  FileName := '';
  PngName := '';
  WithTabs := False;
  Quiet := False;
  I := 1;
  while I <= ParamCount do
  begin
    if ParamStr(I) = '--png' then
    begin
      Inc(I);
      PngName := ParamStr(I);
    end
    else if ParamStr(I) = '--tabs' then
      WithTabs := True
    else if ParamStr(I) = '--quiet' then
      Quiet := True
    else
      FileName := ParamStr(I);
    Inc(I);
  end;
  if FileName = '' then
  begin
    WriteLn('usage: lfmview <file.lfm> [--png out.png] [--tabs] [--quiet]');
    Halt(2);
  end;

  RegisterClasses([TForm, TPanel, TLabel, TButton, TBitBtn, TSpeedButton, TCheckBox, TRadioButton,
    TEdit, TMemo, TComboBox, TListBox, TGroupBox, TScrollBox, TBevel, TShape, TImage, TPaintBox,
    TSplitter, TPageControl, TTabSheet, TTreeView, TListView, TStatusBar, TProgressBar, TTimer,
    TMainMenu, TPopupMenu, TMenuItem, TImageList, TStringGrid, TValueListEditor, TCheckListBox,
    TLazVirtualStringTree, TSynEdit, TSynSQLSyn, TStaticText, TTrackBar, TToolBar, TToolButton]);

  RegisterClassAlias(TLazVirtualStringTree, 'TVirtualStringTree');
  Application.Initialize;
  Loader := TLoader.Create;
  Loader.Log := TStringList.Create;
  Application.OnException := @Loader.OnAppException;
  Src := TMemoryStream.Create;
  Bin := TMemoryStream.Create;
  Form := TForm.CreateNew(Application);
  try
    Src.LoadFromFile(FileName);
    Src.Position := 0;
    LRSObjectTextToBinary(Src, Bin);
    Bin.Position := 0;
    Reader := TReader.Create(Bin, 4096);
    try
      Reader.OnError := @Loader.OnError;
      Reader.OnFindMethod := @Loader.OnFindMethod;
      Reader.OnFindComponentClass := @Loader.OnFindClass;
      Reader.ReadRootComponent(Form);
    finally
      Reader.Free;
    end;

    if not Quiet then
      for I := 0 to Loader.Log.Count - 1 do
        WriteLn(Loader.Log[I]);

    Form.Position := poDesigned;
    Form.Left := 40;
    Form.Top := 40;
    Form.Visible := True;
    Form.Show;
    Application.ProcessMessages;

    if PngName <> '' then
    begin
      CaptureForm(Form, PngName);
      WriteLn('wrote ', PngName, ' (', Form.Width, 'x', Form.Height, ', ', Loader.Log.Count, ' issues)');
      if WithTabs then
      begin
        Pages := TList.Create;
        try
          CollectPageControls(Form, Pages);
          Base := ChangeFileExt(PngName, '');
          for P := 0 to Pages.Count - 1 do
          begin
            PC := TPageControl(Pages[P]);
            for T := 0 to PC.PageCount - 1 do
            begin
              PC.ActivePageIndex := T;
              CaptureForm(Form, Format('%s_%s_%d_%s.png', [Base, PC.Name, T, PC.Pages[T].Name]));
            end;
            PC.ActivePageIndex := 0;
          end;
        finally
          Pages.Free;
        end;
      end;
    end
    else
      Application.Run;
  finally
    Form.Free;
    Src.Free;
    Bin.Free;
    Loader.Log.Free;
    Loader.Free;
  end;
end.
