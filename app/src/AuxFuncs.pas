unit AuxFuncs;

// Not ported (not used by the Query Browser, code from the MySQL Administrator):
//   AddListViewItem, AddToFile, BreakLine, ClearListView, ClearTreeView, ColorToHtmlColor, CreateShortcut, CreateVaList, DeleteComponentWithChildren, DisableEnablePages, ExecuteShellAppl, ExtractNumber, ExtractString, ExtractText, FetchHttpRequest, FormatFileSize, GetApplDir, GetCommonProgFilesDir, GetComputerNetName, GetDefaultBrowser, GetDriveInfo, GetDrives, GetExeByExtension, GetFileDate, GetFileSize, GetFileVersion, GetGlobalEnvironment, GetLocalHostName, GetNewGUID, GetShellLinkFileName, GetSubstringCount, GetTempDir, HtmlColorToColor, IsAcrobatInstalled, IsKeyDown, LoadRtfTextFromResource, LoadTextFromFile, LocalTimeToUTC, ParseCommandLine, PrintPDF, RemoveService, RescaleFontSize, SaveAnsiTextToFile, SendToEventLog, ServiceStart, ServiceStatus, ServiceStop, SetDataFont, SetGlobalEnvironment, ShortPathToLongPath, ShowPDF, StringAlignLeft, StringAlignRight, UTCtoLocalTime

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
  Classes, TntClasses, TntExtCtrls, Windows, Winsock, TntRegistry,
  TntComCtrls, ComCtrls, Forms, Messages,
  StdCtrls, Controls, Dialogs, ShlObj, Contnrs, Graphics,
  SysUtils, ShellAPI, ActiveX, WinInet,
  gnugettext, StrUtils, TntForms, TntStdCtrls,
  Clipbrd, ExtCtrls, TntSysUtils;

type
  MYX_MESSAGE_DLG_TYPE = (
    myx_mtError = 1,
    myx_mtInformation,
    myx_mtConfirmation,
    myx_mtEdit,
    myx_mtWarning
  );

  MYX_NODE_DATA_TYPE = (
    myx_ndt_pointer = 1,
    myx_ndt_tobject
  );


  TMyxModalDialog = class(TTntForm)
    MessageLbl: TTntLabel;
    ValueMemo: TTntMemo;
    DlgBtnList: TList;

    constructor Create(Titel: WideString; Messagetext: WideString;
      DlgType: MYX_MESSAGE_DLG_TYPE;
      buttons: WideString;
      doEdit: Boolean; editCaption: WideString; var editValue: WideString;
      editLinesNum: Integer = 1; editReadOnly: Boolean = False;
      ShowDisableMessageCheckbox: Boolean = False;
      PNGImgResName: WideString = ''); reintroduce;
    destructor Destroy; override;

    procedure doButtonClick(Sender: TObject);
    procedure HideEdit;
    procedure ShowEdit;
    procedure DoKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  protected
    EditLbl: TTntLabel;
    TypeImage, InfoImage: TTntImage;
  published
    DisableMessageCheckbox: TTntCheckBox;
  private
    doEdit: Boolean;
  end;


procedure InitForm(Form: TTntForm);
procedure InitGlobalVars;
procedure InitFrame(Frame: TTntFrame);

function getXPStyleEnabled: Boolean;

function AddTreeViewChildNode(theTreeView: TTntTreeView;
  ParentNode: TTntTreeNode; Caption: WideString; Icon: Integer;
  Data: Pointer = nil): TTntTreeNode;

function ShowModalDialog(Titel: WideString; Messagetext: WideString;
  DlgType: MYX_MESSAGE_DLG_TYPE = myx_mtInformation;
  buttons: WideString = 'OK'): Integer;
function ShowModalEditDialog(Titel: WideString; Messagetext: WideString;
  DlgType: MYX_MESSAGE_DLG_TYPE;
  buttons: WideString;
  doEdit: Boolean; editCaption: WideString; var editValue: WideString;
  editLinesNum: Integer = 1; editReadOnly: Boolean = False;
  ShowDisableMessageCheckbox: Boolean = False;
  PNGImgResName: WideString = ''): Integer;


//Create prozess
procedure CreateSubProcess(command: WideString; workingdir: WideString = ''; show: Boolean = True; wait4proz: Boolean =
  False);

procedure MessageToAllForms(Msg: UINT; wParam: WPARAM; lParam: LPARAM);


procedure DisableEnableControls(WinControl: TWinControl; Enable: Boolean);
procedure InitHandles(WinControl: TWinControl);

function LoadAnsiTextFromFile(filename: WideString): AnsiString;


procedure WriteToReg(theRoot: HKEY; Key, Name: WideString; Typ: Integer; Val: WideString);
function ReadFromReg(theRoot: HKEY; Key, Name: WideString; Typ: Integer;
  DefaultVal: WideString; CanCreate: Boolean = True): WideString;


const
  CSIDL_PROGRAM_FILES = $0026;
  CSIDL_PROGRAM_FILES_COMMON = $002B;
  CSIDL_COMMON_APPDATA = $0023;
  CSIDL_PERSONAL = $0005;
  CSIDL_STARTUP = $0007;


function GetSystemDir: WideString;
function GetWindowsDir: WideString;
function GetSpecialFolder(Folder: Integer): WideString;
function GetProgramFilesDir: WideString;
function GetApplicationDataDir: WideString;
function GetHomeDir: WideString;

procedure BrowseWebPage(URL: WideString);


procedure CopyDiskFile(sourcefile, destinationfile: WideString; PromtBeforeOverwrite: Boolean);

procedure ShowHelp;

function GetWideStringTextWidth(DC: THandle; Text: WideString): Integer; overload;
function GetWideStringTextWidth(Canvas: TCanvas; Text: WideString): Integer; overload;

procedure DrawWideStringText(DC: HDC; lpString: PWideChar; nCount: Integer;
  lpRect: TRect; uFormat: Cardinal = DT_LEFT; AdjustRight: Boolean = False);

function IsWinXP: Boolean;
function IsWin2k: Boolean;
function IsWinNT: Boolean;
function IsWin2kOrXP: Boolean;
function IsWinNTPlatform: Boolean;

function IsConnectedToInternet: Boolean;

// Port: the VCL sizes an auto-sizing label as soon as its caption is set, the LCL does it lazily. Code that
// positions controls from Label.Width right after setting the caption calls this first.
procedure SizeLabelToCaption(ALabel: TLabel);

function FormatLibraryVersion(LibVersion: Integer): WideString;

function GetCharFromVKey(vkey: Word): WideString;

function GetTransparentImgList(size: Integer): TImageList;

function ReplaceTags(s: WideString; tags: WideString): WideString;

procedure RegisterFileType(ExtName: WideString; AppName: WideString;
  IconNr: Integer; Params: WideString = '');

function GetHTMLReplaceStringList: TStringList;
function HTMLDecode(Source: string; NamedChars: TStringList = nil): string;
function HTMLEncode(Source: string; NamedChars: TStringList = nil;
  EncodeSpaces: Boolean = False): string;

function IsNumeric(S: WideString): Boolean;

//Global Variables

var
  ClearTypeOn: Boolean;
  TahomaFontAvailable: Boolean;
  DefaultFontName, DataFontName: string;
  DefaultFontHeight, DataFontHeight: Integer;

//----------------------------------------------------------------------------------------------------------------------

implementation

uses
  TntWindows, Types, PNGTools;


//----------------------------------------------------------------------------------------------------------------------

procedure InitGlobalVars;

// Whether ClearType is on and Tahoma exists decides which font InitForm gives the forms (the .lfm files say
// "MS Sans Serif", which the LCL does not map to the narrow bitmap font the original layouts were made for).

var
  Parameter: UINT;

begin
  Parameter := 0;
  SystemParametersInfo(SPI_GETFONTSMOOTHINGTYPE, 0, @Parameter, 0);
  ClearTypeOn := (Parameter and FE_FONTSMOOTHINGCLEARTYPE) <> 0;
  TahomaFontAvailable := Screen.Fonts.IndexOf('Tahoma') > -1;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure AdjustGroupBoxes(Form: TTntForm);

// The VCL's group box has no client area of its own: the children's coordinates count from the top left corner of
// the frame, so the original layouts put the first row 16 pixels down, below the caption. The LCL's client area
// starts below the caption already, which moved everything down by that much and pushed the last rows over the
// frame. The children are moved back by the difference.

var
  I, J: Integer;
  Box: TGroupBox;
  Client: TPoint;
  Child: TControl;

begin
  for I := 0 to Form.ComponentCount - 1 do
    if Form.Components[I] is TGroupBox then
    begin
      Box := TGroupBox(Form.Components[I]);
      if (Box.Parent = nil) or (Box.ControlCount = 0) then
        Continue;
      Box.HandleNeeded;
      Client := Box.ClientToParent(Point(0, 0), Box.Parent);
      Dec(Client.X, Box.Left);
      Dec(Client.Y, Box.Top);
      if (Client.X = 0) and (Client.Y = 0) then
        Continue;
      for J := 0 to Box.ControlCount - 1 do
      begin
        Child := Box.Controls[J];
        if Child.Align = alNone then
        begin
          Child.Left := Child.Left - Client.X;
          Child.Top := Child.Top - Client.Y;
        end;
      end;
    end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure KeepRightEdgeOfLabels(Form: TTntForm);

// The VCL keeps the right edge of an auto sizing, right aligned label when a (translated) caption changes its
// width; the LCL keeps the left edge and the label runs under the edit field next to it.

var
  I: Integer;
  ALabel: TLabel;
  Right, W: Integer;
  Bmp: TBitmap;

begin
  Bmp := TBitmap.Create;
  try
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TLabel then
      begin
        ALabel := TLabel(Form.Components[I]);
        if (ALabel.Alignment <> taRightJustify) or ALabel.WordWrap or (ALabel.Align <> alNone) then
          Continue;
        Bmp.Canvas.Font.Assign(ALabel.Font);
        W := Bmp.Canvas.TextWidth(ALabel.Caption);
        Right := ALabel.Left + ALabel.Width;
        if ALabel.AutoSize and (W <> ALabel.Width) then
        begin
          ALabel.Left := Right - W;
          ALabel.Width := W;
        end;
      end;
  finally
    Bmp.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure InitForm(Form: TTntForm);

var
  i: Integer;
  OriginalFontSize: Integer;

begin
  TranslateComponent(Form);

  Form.AutoScroll := False;
  Form.Scaled := False;
  Form.PixelsPerInch := 96;

  OriginalFontSize := Form.Font.Size;

  if (DefaultFontName <> '') then
  begin
    Form.Font.Name := DefaultFontName;
    Form.Font.Height := DefaultFontHeight;
  end;

  if (Screen.PixelsPerInch <> 96) or (ClearTypeOn) then
  begin
    //Change to Tahoma when MS Sans Serif is selected and
    //(ClearTypeOn) is activated
    if (ClearTypeOn) and
      (TahomaFontAvailable) and
      ((DefaultFontName = 'MS Sans Serif') or (DefaultFontName = '')) then
      Form.Font.Name := 'Tahoma';

    if (Screen.PixelsPerInch <> 96) then
    begin
      if (IsWin2k) and
        ((DefaultFontName = 'MS Sans Serif') or (DefaultFontName = '')) then
      begin
        Form.Font.Size := 7;
        Form.Font.Name := 'Tahoma';
      end
      else
      begin
        Form.Font.Height := -11;

        if (Form.Font.Name = 'MS Sans Serif') then
          Form.Font.Name:='Tahoma';
      end;
    end
    else
      Form.Font.Size := 8;

    Form.Font.Style := [];
  end;

  for i := 0 to Form.ComponentCount - 1 do
  begin
    if (Form.Components[i] is TTntLabel) then
      if (TLabel(Form.Components[i]).ParentFont = False) and
        (OriginalFontSize = TLabel(Form.Components[i]).Font.Size) then
      begin
        TLabel(Form.Components[i]).Font.Name := Form.Font.Name;
        TLabel(Form.Components[i]).Font.Size := Form.Font.Size;
      end;
  end;

  AdjustGroupBoxes(Form);
  KeepRightEdgeOfLabels(Form);
end;


//----------------------------------------------------------------------------------------------------------------------

procedure InitFrame(Frame: TTntFrame);

begin
  if (Screen.PixelsPerInch <> 96) or (ClearTypeOn) then
  begin
    if (TahomaFontAvailable) then
      Frame.Font.Name := 'Tahoma';

    if (Screen.PixelsPerInch <> 96) then
      Frame.Font.Size := 6
    else
      Frame.Font.Size := 8;

    Frame.Font.Style := [];
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function getXPStyleEnabled: Boolean;

var
  VersionInfo: TOSVersionInfo;
  Registry: TTntRegistry;

begin
  getXPStyleEnabled := False;

  VersionInfo.dwOSVersionInfoSize := Sizeof(TOSVersionInfo);
  GetVersionEx(VersionInfo);

  if (not (IsWinXP)) then
    Exit;

  Registry := TTntRegistry.Create;
  try
    Registry.RootKey := HKEY_CURRENT_USER; //HKEY_LOCAL_MACHINE;
    Registry.OpenKey('Control Panel\Appearance', False);
    if (Registry.ReadString('Current') <> 'Windows Standard') then
      Result := True;
    Registry.CloseKey;
  finally
    Registry.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function AddTreeViewChildNode(theTreeView: TTntTreeView; ParentNode: TTntTreeNode; Caption: WideString; Icon: Integer;
  Data: Pointer): TTntTreeNode;

var
  theTreeNode: TTntTreeNode;

begin
  if (ParentNode = nil) then
  begin
    theTreeNode := theTreeView.Items.Add(nil, Caption);
    theTreeNode.ImageIndex := Icon;
    theTreeNode.SelectedIndex := Icon;
  end
  else
  begin
    theTreeNode := theTreeView.Items.AddChild(ParentNode, Caption);
    theTreeNode.ImageIndex := Icon;
    theTreeNode.SelectedIndex := Icon;
  end;

  theTreeNode.Data := Data;

  AddTreeViewChildNode := theTreeNode;
end;


//----------------------------------------------------------------------------------------------------------------------

function ShowModalDialog(Titel: WideString; Messagetext: WideString; DlgType: MYX_MESSAGE_DLG_TYPE;
  buttons: WideString): Integer;

var
  NotUsed: WideString;

begin
  Result := ShowModalEditDialog(Titel, Messagetext, DlgType, buttons,
    False, '', NotUsed);
end;

//----------------------------------------------------------------------------------------------------------------------

function ShowModalEditDialog(Titel: WideString; Messagetext: WideString; DlgType: MYX_MESSAGE_DLG_TYPE;
  buttons: WideString; doEdit: Boolean; editCaption: WideString; var editValue: WideString; editLinesNum: Integer = 1;
  editReadOnly: Boolean = False; ShowDisableMessageCheckbox: Boolean = False; PNGImgResName: WideString = ''): Integer;

var
  ModalDialog: TMyxModalDialog;

begin
  ModalDialog := TMyxModalDialog.Create(Titel, Messagetext, DlgType, buttons,
    doEdit, editCaption, editValue, editLinesNum, editReadOnly,
    ShowDisableMessageCheckbox, PNGImgResName);
  try
    Result := ModalDialog.ShowModal;

    if Result = mrCancel then  // VCL result
      Result := 0
    else
      if Result > 100 then
        Dec(Result, 100);      // Our result

    if (doEdit) and (ModalDialog.ValueMemo.Text <> '') then
      editValue := ModalDialog.ValueMemo.Text;
  finally
    ModalDialog.Free;
  end;
end;


//----------------------------------------------------------------------------------------------------------------------

procedure CreateSubProcess(command: WideString; workingdir: WideString = ''; show: Boolean = True; wait4proz: Boolean =
  False);

var
{$IFDEF MSWINDOWS}
  StartupInfo: Windows.TStartupInfoW;
  wdir: PWideChar;
  ProcessInfo: TProcessInformation;
{$ENDIF}

{$IFDEF LINUX}
  FCmdThread: TCmdExecThread;
{$ENDIF}

begin
{$IFDEF MSWINDOWS}
  if (workingdir <> '') then
    wdir := PWideChar(workingdir)
  else
    wdir := nil;

  FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
  StartupInfo.cb := Sizeof(TStartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  if (show) then
    StartupInfo.wShowWindow := SW_Show
  else
    StartupInfo.wShowWindow := SW_Hide;

  if (not (CreateProcessW(nil, PWideChar(command), nil, nil, False, Normal_PRIORITY_CLASS and CREATE_DEFAULT_ERROR_MODE,
    nil, wdir, StartupInfo, ProcessInfo))) then
    raise Exception.Create(command + ': '#13#10 + 'The Program could not be launched.'#13#10 +
      'Error Number ' + IntToStr(GetLastError) + #13#10 + SysErrorMessage(GetLastError));

  //If requested, wait for the programm to end
  if (wait4proz) then
  begin
    while (WaitForSingleObject(ProcessInfo.hProcess, 0) = WAIT_TIMEOUT) do
      Application.ProcessMessages;

    ProcessInfo.hProcess := 0;
  end;
{$ENDIF}

{$IFDEF LINUX}
  {if FCmdThread <> nil then
  begin
    if not FCmdThread.Done
      then raise Exception.Create('A command is already running')
    else FCmdThread.Free;
  end;}
  FCmdThread := TCmdExecThread.Create;
  //FCmdThread.OnComplete := InternalComplete;
  FCmdThread.Command := command;
  FCmdThread.Resume;

  //Wenn erwünscht, warten bis Programm beendet wird.
  if (wait4proz = 1) then
  begin
    while (not (FCmdThread.Done)) do
    begin
      Sleep(500);
      //Do drawing and stuff
      Application.ProcessMessages;
    end;
  end;
{$ENDIF}
end;


//----------------------------------------------------------------------------------------------------------------------

procedure MessageToAllForms(Msg: UINT; wParam: WPARAM; lParam: LPARAM);

var
  i: Integer;

begin
  for i := 0 to Screen.FormCount - 1 do
    Screen.Forms[i].Perform(Msg, wParam, lParam);
end;

//----------------------------------------------------------------------------------------------------------------------

// sMachine .. \\SERVER or empty for local machine
// sService ... service name, ie: mysqld
// return TRUE if successful


//----------------------------------------------------------------------------------------------------------------------

// sMachine .. \\SERVER or empty for local machine
// sService ... service name, ie: mysqld
// return TRUE if successful


//----------------------------------------------------------------------------------------------------------------------

// sMachine .. \\SERVER or empty for local machine
// sService ... service name, ie: mysqld
// return codes:
//   -1 if not successful
//   SERVICE_STOPPED
//   SERVICE_RUNNING
//   SERVICE_PAUSED
//   SERVICE_START_PENDING
//   SERVICE_STOP_PENDING
//   SERVICE_CONTINUE_PENDING
//   SERVICE_PAUSE_PENDING


//----------------------------------------------------------------------------------------------------------------------

//Returns 0 on success


//----------------------------------------------------------------------------------------------------------------------

procedure DisableEnableControls(WinControl: TWinControl; Enable: Boolean);

var
  i: Integer;

begin
  for i := 0 to WinControl.ControlCount - 1 do
  begin
    if WinControl.Controls[i].Tag <> -1 then
    begin
      WinControl.Controls[i].Enabled := Enable;

      if (WinControl.Controls[i].InheritsFrom(TWinControl)) then
        DisableEnableControls(TWinControl(WinControl.Controls[i]), Enable);
    end;
  end;

  WinControl.Enabled := Enable;
end;


//----------------------------------------------------------------------------------------------------------------------

procedure InitHandles(WinControl: TWinControl);

var
  i: Integer;

begin
  WinControl.HandleNeeded;

  for i := 0 to WinControl.ControlCount - 1 do
  begin
    if (WinControl.Controls[i].InheritsFrom(TWinControl)) then
      InitHandles(TWinControl(WinControl.Controls[i]));
  end;
end;


//----------------------------------------------------------------------------------------------------------------------

function LoadAnsiTextFromFile(filename: WideString): AnsiString;

var
  Stream: TStream;
  Size: Integer;
  S: string;

begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Size := Stream.Size - Stream.Position;
    SetString(S, nil, Size);
    Stream.Read(Pointer(S)^, Size);
  finally
    Stream.Free;
  end;

  Result := S;
end;


//----------------------------------------------------------------------------------------------------------------------

procedure WriteToReg(theRoot: HKEY; Key, Name: WideString; Typ: Integer; Val: WideString);

var
  MyReg: TTntRegistry;

begin
  try
    MyReg := TTntRegistry.Create(KEY_WRITE);
    MyReg.RootKey := theRoot;
    try
      MyReg.OpenKey(Key, True);
      case Typ of
        0: MyReg.WriteString(Name, Val);
        1: MyReg.WriteInteger(Name, StrToIntDef(Val, 0));
      end;
      MyReg.CloseKey;
    finally
      MyReg.Free;
    end;
  except
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function ReadFromReg(theRoot: HKEY; Key, Name: WideString; Typ: Integer; DefaultVal: WideString;
  CanCreate: Boolean): WideString;

var
  MyReg: TTntRegistry;

begin
  try
    MyReg := TTntRegistry.Create(KEY_READ);
    MyReg.RootKey := theRoot;
    try
      MyReg.OpenKey(Key, CanCreate);
      case Typ of
        0: ReadFromReg := MyReg.ReadString(Name);
        1: ReadFromReg := IntToStr(MyReg.ReadInteger(Name));
      end;
      MyReg.CloseKey;
    finally
      MyReg.Free;
    end;
  except
    ReadFromReg := DefaultVal;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function GetSystemDir: WideString;

var
  SysDir: array[0..MAX_PATH] of Char;

begin
  GetSystemDirectory(SysDir, MAX_PATH);

  GetSystemDir := IncludeTrailingPathDelimiter(SysDir);
end;

//----------------------------------------------------------------------------------------------------------------------

function GetWindowsDir: WideString;

var
  WinDir: array[0..MAX_PATH] of Char;

begin
  GetWindowsDirectory(WinDir, MAX_PATH);

  GetWindowsDir := IncludeTrailingPathDelimiter(WinDir);
end;


//----------------------------------------------------------------------------------------------------------------------

function GetSpecialFolder(Folder: Integer): WideString;

// Reads the file name of the special (system) folder given by the id in Folder.

var
  pMalloc: IMalloc;
  pidl: PItemIDList;
  Buffer: array[0..MAX_PATH] of WideChar;

begin
  // We need the IMalloc interface pointer to free memory allocated by the shell.
  if (SHGetMalloc(pMalloc) <> S_OK) then
    raise EInOutError.Create('Couldn''t get pointer to IMalloc interface.')
  else
  begin
    SHGetSpecialFolderLocation(0, Folder, pidl);
    SHGetPathFromIDListW(pidl, Buffer);
    Result := Buffer;

    // Free memory allocated by SHGetSpecialFolderLocation.
    pMalloc.Free(pidl);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function GetProgramFilesDir: WideString;

var
  folder: WideString;

begin
  folder := GetSpecialFolder(CSIDL_PROGRAM_FILES);

  if (folder = '') then
    folder := ReadFromReg(HKEY_LOCAL_MACHINE,
      '\Software\Microsoft\Windows\CurrentVersion',
      'ProgramFilesDir', 0, '');

  Result := IncludeTrailingPathDelimiter(folder);
end;


//----------------------------------------------------------------------------------------------------------------------

function GetApplicationDataDir: WideString;

var
  folder: WideString;

begin
  folder := GetSpecialFolder(CSIDL_APPDATA);

  if (folder = '') then
    folder := ReadFromReg(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',
      'AppData', 0, '');

  Result := IncludeTrailingPathDelimiter(folder);
end;

//----------------------------------------------------------------------------------------------------------------------

function GetHomeDir: WideString;

var
  folder: WideString;

begin
  folder := GetSpecialFolder(CSIDL_PERSONAL);

  if (folder = '') then
    folder := ReadFromReg(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',
      'Personal', 0, '');

  Result := IncludeTrailingPathDelimiter(folder);
end;


//----------------------------------------------------------------------------------------------------------------------

// Not defined in Windows.pas
function GetLongPathNameW(lpszLongPath: PWideChar; lpszShortPath: PWideChar; cchBuffer: DWORD): DWORD; stdcall; external 'Kernel32.dll';


//----------------------------------------------------------------------------------------------------------------------

procedure CopyDiskFile(sourcefile, destinationfile: WideString; PromtBeforeOverwrite: Boolean);

var
  NewFile: TTntFileStream;
  OldFile: TTntFileStream;

begin
  if (FileExists(sourcefile)) then
  begin
    if (FileExists(destinationfile)) and (PromtBeforeOverwrite) then
    begin
      if (MessageDlg(Format('The destination file %s does already exist. ' +
        'Do you want to overwrite this file?', [destinationfile]), mtCustom, [mbYes, mbNo], 0) = 3) then
        DeleteFile(destinationfile)
      else
        Exit;
    end;

    OldFile := TTntFileStream.Create(sourcefile, fmOpenRead or fmShareDenyWrite);
    try
      NewFile := TTntFileStream.Create(destinationfile, fmCreate {or fmShareDenyRead});

      try
        NewFile.CopyFrom(OldFile, OldFile.Size);
      finally
        FreeAndNil(NewFile);
      end;
    finally
      FreeAndNil(OldFile);
    end;
  end
  else
    MessageDlg(Format('The source file %s does not exist.', [sourcefile]), mtError, [mbOK], 0);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure ShowHelp;

begin
  CreateSubProcess('hh ' + ChangeFileExt(Application.ExeName, '.chm'));
end;


//----------------------------------------------------------------------------------------------------------------------

function GetWideStringTextWidth(Canvas: TCanvas; Text: WideString): Integer;

begin
  Result := GetWideStringTextWidth(Canvas.Handle, Text);
end;

//----------------------------------------------------------------------------------------------------------------------

function GetWideStringTextWidth(DC: THandle; Text: WideString): Integer;

var
  Size: TSize;

begin
  GetTextExtentPoint32W(DC, PWideChar(Text), Length(Text), Size);

  Result := Size.cx;
end;

//----------------------------------------------------------------------------------------------------------------------

// This function is taken from laz.VirtualTrees, VTCompat, (C) Mike Lischke and was modified

procedure DrawWideStringText(DC: HDC; lpString: PWideChar; nCount: Integer; lpRect: TRect; uFormat: Cardinal;
  AdjustRight: Boolean);

// This procedure implements a subset of Window's DrawText API for Unicode which is not available for
// Windows 9x. For a description of the parameters see DrawText in the online help.
// Supported flags are currently:
//   - DT_LEFT
//   - DT_TOP
//   - DT_CALCRECT
//   - DT_NOCLIP
//   - DT_RTLREADING
//   - DT_SINGLELINE
//   - DT_VCENTER
// Differences to the DrawTextW Windows API:
//   - The additional parameter AdjustRight determines whether to adjust the right border of the given rectangle to
//     accomodate the largest line in the text. It has only a meaning if also DT_CALCRECT is specified.

var
  Head, Tail: PWideChar;
  Size: TSize;
  MaxWidth: Integer;
  TextOutFlags: Integer;
  TextAlign,
  OldTextAlign: Cardinal;
  TM: TTextMetric;
  TextHeight: Integer;
  LineRect: TRect;
  TextPosY,
  TextPosX: Integer;

  CalculateRect: Boolean;

begin
  // Prepare some work variables.
  MaxWidth := 0;
  Head := lpString;
  GetTextMetrics(DC, TM);
  TextHeight := TM.tmHeight;
  if uFormat and DT_SINGLELINE <> 0 then
    LineRect := lpRect
  else
    LineRect := Rect(lpRect.Left, lpRect.Top, lpRect.Right, lpRect.Top + TextHeight);

  CalculateRect := uFormat and DT_CALCRECT <> 0;

  // Prepare text output.
  TextOutFlags := 0;
  if uFormat and DT_NOCLIP = 0 then
    TextOutFlags := TextOutFlags or ETO_CLIPPED;
  if uFormat and DT_RTLREADING <> 0 then
    TextOutFlags := TextOutFlags or ETO_RTLREADING;

  // Determine horizontal and vertical text alignment.
  OldTextAlign := GetTextAlign(DC);
  TextAlign := TA_LEFT or TA_TOP;
  TextPosX := lpRect.Left;
  if uFormat and DT_RIGHT <> 0 then
  begin
    TextAlign := TextAlign or TA_RIGHT and not TA_LEFT;
    TextPosX := lpRect.Right;
  end
  else
    if uFormat and DT_CENTER <> 0 then
    begin
      TextAlign := TextAlign or TA_CENTER and not TA_LEFT;
      TextPosX := (lpRect.Left + lpRect.Right) div 2;
    end;

  TextPosY := lpRect.Top;
  if uFormat and DT_VCENTER <> 0 then
  begin
    // Note: vertical alignment does only work with single line text ouput!
    TextPosY := (lpRect.Top + lpRect.Bottom - TextHeight) div 2;
  end;
  SetTextAlign(DC, TextAlign);

  if uFormat and DT_SINGLELINE <> 0 then
  begin
    if CalculateRect then
    begin
      GetTextExtentPoint32W(DC, Head, nCount, Size);
      if Size.cx > MaxWidth then
        MaxWidth := Size.cx;
    end
    else
      ExtTextOutW(DC, TextPosX, TextPosY, TextOutFlags, @LineRect, Head, nCount, nil);
    OffsetRect(LineRect, 0, TextHeight);
  end
  else
  begin
    while (nCount > 0) and (Head^ <> WideChar(#0)) do
    begin
      Tail := Head;
      // Look for the end of the current line. A line is finished either by the WideString end or a line break.
      while (nCount > 0) and not (Tail^ in [WideChar(#0), WideChar(#13), WideChar(#10)]) and (Tail^ <> WideChar(#2028))
        do
      begin
        Inc(Tail);
        Dec(nCount);
      end;

      if CalculateRect then
      begin
        GetTextExtentPoint32W(DC, Head, Tail - Head, Size);
        if Size.cx > MaxWidth then
          MaxWidth := Size.cx;
      end
      else
        ExtTextOutW(DC, TextPosX, LineRect.Top, TextOutFlags, @LineRect, Head, Tail - Head, nil);
      OffsetRect(LineRect, 0, TextHeight);

      // Get out of the loop if the rectangle is filled up.
      if (nCount = 0) or (not CalculateRect and (LineRect.Top >= lpRect.Bottom)) then
        Break;

      if (nCount > 0) and (Tail^ = WideChar(#13)) or (Tail^ = WideChar(#2028)) then
      begin
        Inc(Tail);
        Dec(nCount);
      end;

      if (nCount > 0) and (Tail^ = WideChar(#10)) then
      begin
        Inc(Tail);
        Dec(nCount);
      end;
      Head := Tail;
    end;
  end;

  SetTextAlign(DC, OldTextAlign);
  if CalculateRect then
  begin
    if AdjustRight then
      lpRect.Right := lpRect.Left + MaxWidth;
    lpRect.Bottom := LineRect.Top;
  end;
end;


//----------------------------------------------------------------------------------------------------------------------

function IsWinXP: Boolean;

begin
  Result := (Win32Platform = VER_PLATFORM_WIN32_NT) and
    (Win32MajorVersion >= 5) and (Win32MinorVersion >= 1);
end;

//----------------------------------------------------------------------------------------------------------------------

function IsWin2k: Boolean;

begin
  Result := (Win32Platform = VER_PLATFORM_WIN32_NT) and (Win32MajorVersion >= 5) and (Win32MinorVersion = 0);
end;

//----------------------------------------------------------------------------------------------------------------------

function IsWinNT: Boolean;

begin
  Result := (Win32Platform = VER_PLATFORM_WIN32_NT) and (Win32MajorVersion = 4);
end;

//----------------------------------------------------------------------------------------------------------------------

function IsWin2kOrXP: Boolean;

var
  Version: DWORD;
  MajorVersion: BYTE;

begin
  Version := GetVersion();

  // Get major and minor version numbers of Windows.
  MajorVersion := LOBYTE(LOWORD(Version));

  Result := MajorVersion >= 5;
end;

//----------------------------------------------------------------------------------------------------------------------

function IsWinNTPlatform: Boolean;

begin
  Result := (Win32Platform = VER_PLATFORM_WIN32_NT);
end;


//----------------------------------------------------------------------------------------------------------------------

procedure SizeLabelToCaption(ALabel: TLabel);

var
  Bmp: TBitmap;

begin
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Assign(ALabel.Font);
    ALabel.Width := Bmp.Canvas.TextWidth(UTF8Encode(ALabel.Caption));
    ALabel.Height := Bmp.Canvas.TextHeight('Wg');
  finally
    Bmp.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function IsConnectedToInternet: Boolean;

var
  dwConnectionTypes: DWORD;

begin
  dwConnectionTypes := INTERNET_CONNECTION_MODEM +
    INTERNET_CONNECTION_LAN + INTERNET_CONNECTION_PROXY;

  Result := InternetGetConnectedState(@dwConnectionTypes, 0);
end;

//----------------------------------------------------------------------------------------------------------------------

function FormatLibraryVersion(LibVersion: Integer): WideString;

var
  MajorVersion,
  MinorVersion,
  SubVersion: WideString;

begin
  MajorVersion := IntToStr(LibVersion div 10000);
  MinorVersion := IntToStr(LibVersion div 100 - (LibVersion div 10000) * 100);
  SubVersion := IntToStr(LibVersion - (LibVersion div 100) * 100);

  Result := MajorVersion + '.' + MinorVersion + '.' + SubVersion;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure BrowseWebPage(URL: WideString);

begin
  if (CompareText(Copy(URL, 1, 4), 'http') <> 0) then
    URL := URL + 'http:\\' + URL;

  ShellExecuteW(Application.Handle, 'open', PWideChar(URL),
    nil, nil, SW_NORMAL);
end;

//----------------------------------------------------------------------------------------------------------------------

constructor TMyxModalDialog.Create(Titel: WideString; Messagetext: WideString;
  DlgType: MYX_MESSAGE_DLG_TYPE;
  buttons: WideString;
  doEdit: Boolean; editCaption: WideString; var editValue: WideString;
  editLinesNum: Integer = 1; editReadOnly: Boolean = False;
  ShowDisableMessageCheckbox: Boolean = False;
  PNGImgResName: WideString = '');

var
  DlgBtn: TTntButton;
  DlgButtonCaptions: TTntStringList;
  MessageLines: TTntStringList;
  I, W,
    PNGImgHeight: Integer;
  TotalBtnWidth,
    CurrentBtnWidth: Integer;
  Size: TSize;
  R: TRect;
  MaxMessageWidth: Integer;

begin
  CreateNew(nil);

  DisableMessageCheckbox := nil;

  InitForm(self);

  OnKeyDown := DoKeyDown;
  KeyPreview := True;

  self.doEdit := doEdit;

  DlgButtonCaptions := TTntStringList.Create;
  MessageLines := TTntStringList.Create;
  DlgBtnList := TList.Create;
  try
    MessageLines.Text := Messagetext;
    DlgButtonCaptions.Text := buttons;

    BorderStyle := bsDialog;
    Caption := Titel;
    Tag := 0;

    // Get number of text-Lines
    MaxMessageWidth := 0;
    for I := 0 to MessageLines.Count - 1 do
    begin
      GetTextExtentPoint32W(Canvas.Handle, PWideChar(MessageLines[I]), Length(MessageLines[I]), Size);
      if Size.cx > MaxMessageWidth then
        MaxMessageWidth := Size.cx;
    end;

    if MaxMessageWidth > 400 then
      MaxMessageWidth := 400;

    // Display message text.
    MessageLbl := TTntLabel.Create(self);
    MessageLbl.Parent := self;
    MessageLbl.Left := 80;
    MessageLbl.Top := 30;
    MessageLbl.Width := MaxMessageWidth;
    R := Rect(0, 0, MaxMessageWidth, 0);
    DrawTextW(Canvas.Handle, PWideChar(Messagetext), Length(Messagetext), R, DT_CALCRECT or DT_WORDBREAK);
    MessageLbl.Height := R.Bottom;
    MessageLbl.AutoSize := False;
    MessageLbl.WordWrap := True;
    // Set message text after all settings are in place.
    MessageLbl.Caption := Messagetext;

    //Size the form according to the size of the label/buttons
    if (MessageLbl.Width + 80 + 32 > DlgButtonCaptions.Count * (80 + 10) + 42) then
      Width := MessageLbl.Width + 80 + 32
    else
      Width := DlgButtonCaptions.Count * (80 + 10) + 42;

    // Minimum height. Might be adjusted if editing is active.
    Height := 130 + MessageLbl.Height;

    //Add PNGImg
    if (PNGImgResName <> '') then
    begin
      InfoImage := TTntImage.Create(self);
      InfoImage.Parent := self;
      InfoImage.Top := MessageLbl.Top + MessageLbl.Height + 15;
      InfoImage.AutoSize := True;
      LoadPNGImageFromResource(PNGImgResName, InfoImage, True);

      InfoImage.Left := (Width - InfoImage.Width) div 2;

      PNGImgHeight := InfoImage.Height;

      Height := Height + PNGImgHeight + 20;
    end
    else
      PNGImgHeight := 0;

    //Create Edit
    if (doEdit) then
    begin
      if (editCaption <> '') then
      begin
        EditLbl := TTntLabel.Create(self);
        EditLbl.Parent := self;
        EditLbl.Left := 80;
        EditLbl.Top := MessageLbl.Top + MessageLbl.Height + 10 + PNGImgHeight + 10;
        GetTextExtentPoint32W(Canvas.Handle, PWideChar(editCaption), Length(editCaption), Size);
        EditLbl.Width := Size.cx;
        EditLbl.Caption := editCaption;
      end;

      ValueMemo := TTntMemo.Create(self);
      ValueMemo.Parent := self;
      ValueMemo.Font := Self.Font;
      if (editCaption <> '') then
        ValueMemo.Left := EditLbl.Left + EditLbl.Width + 14
      else
        ValueMemo.Left := 80;
      ValueMemo.Top := MessageLbl.Top + MessageLbl.Height + 10 - 4 + PNGImgHeight + 10;

      ValueMemo.Width := Width - ValueMemo.Left - 30;
      ValueMemo.Height := editLinesNum * Abs(ValueMemo.Font.Height) + 10;
      ValueMemo.Text := editValue;
      Self.Height := Self.Height + ValueMemo.Height + 10;

      ActiveControl := ValueMemo;

      // Disable multiline functionality if editLinesNum is 1.
      if editLinesNum = 1 then
      begin
        ValueMemo.WordWrap := False;
        ValueMemo.WantReturns := False;
      end;

      if (editReadOnly) then
      begin
        ValueMemo.ReadOnly := True;
        ValueMemo.Color := Color;
      end;

      if (ValueMemo.Text <> '') then
        ValueMemo.SelStart := Length(ValueMemo.Text);
    end
    else
      ValueMemo := nil;

    //Create DisableMessage Checkbox
    if (ShowDisableMessageCheckbox) then
    begin
      DisableMessageCheckbox := TTntCheckBox.Create(self);
      DisableMessageCheckbox.Parent := self;

      DisableMessageCheckbox.Left := 20;
      DisableMessageCheckbox.Top := Height - 70;
      DisableMessageCheckbox.Width := Width - 40;
      DisableMessageCheckbox.Caption := _('Do not show this message anymore.');

      Height := Height + 30;
    end;

    //Get total buttons width
    TotalBtnWidth := (DlgButtonCaptions.Count - 1) * 10;
    for I := 0 to DlgButtonCaptions.Count - 1 do
    begin
      W := Canvas.TextWidth(DlgButtonCaptions[I]) + 16;

      if W < 80 then
        W := 80;

      inc(TotalBtnWidth, W);
    end;

    //Create buttons
    CurrentBtnWidth := 0;
    for I := 0 to DlgButtonCaptions.Count - 1 do
    begin
      DlgBtn := TTntButton.Create(self);
      DlgBtn.Parent := self;
      DlgBtn.Caption := DlgButtonCaptions[I];

      W := Canvas.TextWidth(DlgButtonCaptions[I]) + 16;
      if W < 80 then
        W := 80;

      DlgBtn.Width := W;
      DlgBtn.Left := (Width - TotalBtnWidth) div 2 +
        CurrentBtnWidth;

      CurrentBtnWidth := CurrentBtnWidth + W + 10;

      {DlgBtn.Width:=80;
      DlgBtn.Left:=(Width-DlgButtonCaptions.Count*80+19) div 2+
        (80+10)*I;}

      DlgBtn.Top := Height - 70;
      DlgBtn.Height := 25;

      DlgBtn.ModalResult := I + 101;

      DlgBtn.Default := (I = 0);

      DlgBtnList.Add(DlgBtn);
    end;

    //Create image
    TypeImage := TTntImage.Create(self);
    TypeImage.Parent := self;
    TypeImage.Left := 20;
    TypeImage.Top := MessageLbl.Top - 5; // Just to have it nicely places move it up 5 pixels.
    case DlgType of
      myx_mtError:
        LoadPNGImageFromResource('messagedlg_error', TypeImage, True);
      myx_mtEdit:
        LoadPNGImageFromResource('messagedlg_edit', TypeImage, True);
      myx_mtConfirmation:
        LoadPNGImageFromResource('messagedlg_confirmation', TypeImage, True);
      myx_mtWarning:
        LoadPNGImageFromResource('messagedlg_warning', TypeImage, True);
    else
      // myx_mtInformation
      LoadPNGImageFromResource('messagedlg_information', TypeImage, True);
    end;

    if (DlgBtnList.Count > 0) and ((not (doEdit)) or (editReadOnly)) then
      ActiveControl := DlgBtnList[0];

    Position := poScreenCenter;
  finally
    MessageLines.Free;
    DlgButtonCaptions.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TMyxModalDialog.Destroy;

begin
  DlgBtnList.Free;

  inherited Destroy;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMyxModalDialog.doButtonClick(Sender: TObject);

begin
  TTntForm(Parent).Tag := ModalResult;
  TTntForm(Parent).Close;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMyxModalDialog.HideEdit;

var
  i: Integer;

begin
  ValueMemo.Visible := False;

  Height := MessageLbl.Top + MessageLbl.Height + 100;

  for i := 0 to DlgBtnList.Count - 1 do
    TTntButton(DlgBtnList[i]).Top := Height - 70;

  if (DlgBtnList.Count > 0) then
    ActiveControl := DlgBtnList[0];
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMyxModalDialog.ShowEdit;

var
  i: Integer;

begin
  Height := ValueMemo.Top + ValueMemo.Height + 80;

  for i := 0 to DlgBtnList.Count - 1 do
    TTntButton(DlgBtnList[i]).Top := Height - 70;

  ValueMemo.Visible := True;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMyxModalDialog.DoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

begin
  if (Key = Ord('C')) and (ssCtrl in Shift) and (not (doEdit)) then
  begin
    Clipboard.AsText := MessageLbl.Caption;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function GetCharFromVKey(vkey: Word): WideString;

var
  keystate: TKeyboardState;
  retcode: Integer;

begin
  GetKeyboardState(keystate);
  SetLength(Result, 2);
  retcode := ToAscii(vkey, MapVirtualKey(vkey, 0), keystate, @Result[1], 0);
  case retcode of
    0: Result := ''; // no character
    1: SetLength(Result, 1);
    2: ;
  else
    Result := ''; // retcode < 0 indicates a dead key
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function GetTransparentImgList(size: Integer): TImageList;

var
  ImgList: TImageList;
  Bitmap: TBitmap;

begin
  ImgList := TImageList.Create(nil);
  ImgList.Width := size;
  ImgList.Height := size;
  Bitmap := TBitmap.Create;
  Bitmap.Width := size;
  Bitmap.Height := size;
  Bitmap.TransparentMode := tmFixed;
  Bitmap.TransparentColor := clBlack;
  ImgList.AddMasked(Bitmap, clBlack);
  Bitmap.Free;

  Result := ImgList;
end;

//----------------------------------------------------------------------------------------------------------------------

function ReplaceTags(s: WideString; tags: WideString): WideString;

var
  TagList: TTntStringList;
  i: Integer;

begin
  TagList := TTntStringList.Create;
  try
    TagList.Text := tags;
    for i := 0 to TagList.Count - 1 do
      s := AnsiReplaceText(s, TagList.Names[i], TagList.ValueFromIndex[i]);
  finally
    TagList.Free;
  end;

  Result := s;
end;


//----------------------------------------------------------------------------------------------------------------------

{function CreateVaList(const Args: array of const): Pointer;
var VaList: array of Pointer;
  i: Integer;
begin
  SetLength(VaList, Length(Args));

  for i:=0 to High(Args) do
    case Args[i].VType of
      vtInteger:
        VaList[i]:=PInteger(Args[i].VInteger);
      vtBoolean:
        VaList[i]:=PBoolean(Args[i].VBoolean);
      vtInt64:
        VaList[i]:=PInt64(Args[i].VInt64);
      vtPointer:
        VaList[i]:=Args[i].VPointer;
      vtAnsiString:
        VaList[i]:=PChar(Args[i].VAnsiString);
      vtExtended:
        VaList[i]:=PExtended(Args[i].VExtended);
      vtPChar:
        VaList[i]:=Args[i].VPChar;
    else
      raise EInOutError.Create('This variant argument is not supported.');
    end;

  Result:=VaList;
end;}


//----------------------------------------------------------------------------------------------------------------------

procedure RegisterFileType(ExtName: WideString; AppName: WideString; IconNr: Integer; Params: WideString);

// Registers the given application with a particular extension on a per-user-basis.
// No admin rights required to set the association.

var
  Reg: TTntRegistry;

begin
  Reg := TTntRegistry.Create;
  try
    with Reg do
    begin
      RootKey := HKEY_CURRENT_USER;
      OpenKey('\Software\Classes\.' + ExtName, True);
      WriteString('', ExtName + 'file');
      CloseKey;

      OpenKey('\Software\Classes\' + ExtName + 'file\DefaultIcon', True);
      WriteString('', AppName + ',' + IntToStr(IconNr));
      CloseKey;

      OpenKey('\Software\Classes\' + ExtName + 'file\shell\open\command', True);
      if (Params = '') then
        WriteString('', AppName + ' "%1"')
      else
        WriteString('', AppName + ' ' + Params);
      CloseKey;
    end;
  finally
    Reg.Free;
  end;

  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
end;


//----------------------------------------------------------------------------------------------------------------------

function GetHTMLReplaceStringList: TStringList;

var
  NamedChars: TStringList;

begin
  NamedChars := TStringList.Create;
  NamedChars.Add('&amp;=&');
  NamedChars.Add('&quot;="');
  NamedChars.Add('&lt;=<');
  NamedChars.Add('&gt;=>');
  NamedChars.Add('&nbsp;= ');
  NamedChars.Add('&iexcl;=¡');
  NamedChars.Add('&cent;=¢');
  NamedChars.Add('&pound;=£');
  NamedChars.Add('&curren;=¤');
  NamedChars.Add('&yen;=¥');
  NamedChars.Add('&brvbar;=¦');
  NamedChars.Add('&sect;=§');
  NamedChars.Add('&uml;=¨');
  NamedChars.Add('&copy;=©');
  NamedChars.Add('&ordf;=ª');
  NamedChars.Add('&laquo;=«');
  NamedChars.Add('&not;=¬');
  NamedChars.Add('&shy;=-');
  NamedChars.Add('&reg;=®');
  NamedChars.Add('&macr;=¯');
  NamedChars.Add('&deg;=°');
  NamedChars.Add('&plusmn;=±');
  NamedChars.Add('&sup2;=²');
  NamedChars.Add('&sup3;=³');
  NamedChars.Add('&acute;=´');
  NamedChars.Add('&micro;=µ');
  NamedChars.Add('&para;=¶');
  NamedChars.Add('&middot;=·');
  NamedChars.Add('&cedil;=¸');
  NamedChars.Add('&sup1;=¹');
  NamedChars.Add('&ordm;=º');
  NamedChars.Add('&raquo;=»');
  NamedChars.Add('&frac14;=¼');
  NamedChars.Add('&frac12;=½');
  NamedChars.Add('&frac34;=¾');
  NamedChars.Add('&iquest;=¿');
  NamedChars.Add('&Agrave;=À');
  NamedChars.Add('&Aacute;=Á');
  NamedChars.Add('&Acirc;=Â');
  NamedChars.Add('&Atilde;=Ã');
  NamedChars.Add('&Auml;=Ä');
  NamedChars.Add('&Aring;=Å');
  NamedChars.Add('&AElig;=Æ');
  NamedChars.Add('&Ccedil;=Ç');
  NamedChars.Add('&Egrave;=È');
  NamedChars.Add('&Eacute;=É');
  NamedChars.Add('&Ecirc;=Ê');
  NamedChars.Add('&Euml;=Ë');
  NamedChars.Add('&Igrave;=Ì');
  NamedChars.Add('&Iacute;=Í');
  NamedChars.Add('&Icirc;=Î');
  NamedChars.Add('&Iuml;=Ï');
  NamedChars.Add('&ETH;=Ð');
  NamedChars.Add('&Ntilde;=Ñ');
  NamedChars.Add('&Ograve;=Ò');
  NamedChars.Add('&Oacute;=Ó');
  NamedChars.Add('&Ocirc;=Ô');
  NamedChars.Add('&Otilde;=Õ');
  NamedChars.Add('&Ouml;=Ö');
  NamedChars.Add('&times;=×');
  NamedChars.Add('&Oslash;=Ø');
  NamedChars.Add('&Ugrave;=Ù');
  NamedChars.Add('&Uacute;=Ú');
  NamedChars.Add('&Ucirc;=Û');
  NamedChars.Add('&Uuml;=Ü');
  NamedChars.Add('&Yacute;=Ý');
  NamedChars.Add('&THORN;=Þ');
  NamedChars.Add('&szlig;=ß');
  NamedChars.Add('&agrave;=à');
  NamedChars.Add('&aacute;=á');
  NamedChars.Add('&acirc;=â');
  NamedChars.Add('&atilde;=ã');
  NamedChars.Add('&auml;=ä');
  NamedChars.Add('&aring;=å');
  NamedChars.Add('&aelig;=æ');
  NamedChars.Add('&ccedil;=ç');
  NamedChars.Add('&egrave;=è');
  NamedChars.Add('&eacute;=é');
  NamedChars.Add('&ecirc;=ê');
  NamedChars.Add('&euml;=ë');
  NamedChars.Add('&igrave;=ì');
  NamedChars.Add('&iacute;=í');
  NamedChars.Add('&icirc;=î');
  NamedChars.Add('&iuml;=ï');
  NamedChars.Add('&eth;=ð');
  NamedChars.Add('&ntilde;=ñ');
  NamedChars.Add('&ograve;=ò');
  NamedChars.Add('&oacute;=ó');
  NamedChars.Add('&ocirc;=ô');
  NamedChars.Add('&otilde;=õ');
  NamedChars.Add('&ouml;=ö');
  NamedChars.Add('&divide;=÷');
  NamedChars.Add('&oslash;=ø');
  NamedChars.Add('&ugrave;=ù');
  NamedChars.Add('&uacute;=ú');
  NamedChars.Add('&ucirc;=û');
  NamedChars.Add('&uuml;=ü');
  NamedChars.Add('&yacute;=ý');
  NamedChars.Add('&thorn;=þ');
  NamedChars.Add('&yuml;=ÿ');

  Result := NamedChars;
end;

//----------------------------------------------------------------------------------------------------------------------

function HTMLDecode(Source: string; NamedChars: TStringList): string;

var
  i: Integer;

begin
  Result := Source;

  if (NamedChars = nil) then
  begin
    NamedChars := GetHTMLReplaceStringList;
    try
      for i := 0 to NamedChars.Count - 1 do
        Result := AnsiReplaceStr(Result,
          NamedChars.Names[i], NamedChars.ValueFromIndex[i]);
    finally
      NamedChars.Free;
    end;
  end
  else
    for i := 0 to NamedChars.Count - 1 do
      Result := AnsiReplaceStr(Result,
        NamedChars.Names[i], NamedChars.ValueFromIndex[i]);

end;

//----------------------------------------------------------------------------------------------------------------------

function HTMLEncode(Source: string; NamedChars: TStringList; EncodeSpaces: Boolean): string;

var
  i: Integer;
  
begin
  Result := Source;

  if (NamedChars = nil) then
  begin
    NamedChars := GetHTMLReplaceStringList;
    try
      for i := NamedChars.Count - 1 downto 0 do
      begin
        if (NamedChars.Names[i] = '&nbsp;') and (not (EncodeSpaces)) then
          Continue;

        Result := AnsiReplaceStr(Result,
          NamedChars.ValueFromIndex[i], NamedChars.Names[i]);
      end;
    finally
      NamedChars.Free;
    end;
  end
  else
    for i := NamedChars.Count - 1 downto 0 do
    begin
      if (NamedChars.Names[i] = '&nbsp;') and (not (EncodeSpaces)) then
        Continue;

      Result := AnsiReplaceStr(Result,
        NamedChars.ValueFromIndex[i], NamedChars.Names[i]);
    end;

end;

//----------------------------------------------------------------------------------------------------------------------

function IsNumeric(S: WideString): Boolean;

var
  I, L: Integer;

begin
  Result := True;

  L := Length(S);

  for I := 1 to L do
    if ((Ord(S[I]) < Ord('0')) or (Ord(S[I]) > Ord('9'))) and
      (S[I] <> '.') and (S[I] <> ',') then
    begin
      Result := False;
      break;
    end;
end;


//----------------------------------------------------------------------------------------------------------------------

function GetTimeBias: integer;

var
  TZInfo : TTimeZoneInformation;
  TZID   : LongInt;

begin
  TZID := GetTimeZoneInformation (TZInfo);
  Result := TZInfo.Bias;   // bias is in minutes
  if TZID = TIME_ZONE_ID_DAYLIGHT then
    Result := Result + TZInfo.DaylightBias;
end;


//----------------------------------------------------------------------------------------------------------------------

end.

