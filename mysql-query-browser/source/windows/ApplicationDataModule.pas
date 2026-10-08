unit ApplicationDataModule;

interface

uses
  gnugettext, SysUtils, Classes, MyxError, Options, Forms, AuxFuncs, Dialogs,
  myx_public_interface, myx_util_public_interface, myx_qb_public_interface, StrUtils, TntSystem;

type
  TMYXAdminOptions = class;

  TApplicationDM = class(TDataModule)
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);

    procedure CheckCommandlineParameter;

    procedure OnApplicationException(Sender: TObject; E: Exception);

    procedure LoadOptions;
    function GetLastFileDialogPaths(DlgName: WideString): WideString;
    procedure SetLastFileDialogPaths(DlgName: WideString; Path: WideString);
  private
    FOptions: TMYXAdminOptions;
    FOptionProvider: IOptionProvider;
  public
    ApplicationIsTerminating: Boolean;
    property Options: TMYXAdminOptions read FOptions;
  end;

  TMYXAdminOptions = class(TMyxOptions)
    constructor Create(const ApplicationID: string); override;
    destructor Destroy; override;

    procedure LoadOptions; override;
    procedure StoreOptions; override;
  public
    ShowQuickStart: Boolean;

    StartSection: integer;
    StartTable: WideString;
    StartScriptFile: WideString;
    StartQueryFile: WideString;
    StartSQL1: WideString;
    StartSQL2: WideString;
    StartSQL3: WideString;

    OnlyTabsheets: Boolean;
    MaximizeSQLEdit: Boolean;

    ShowQueryToolbar: Boolean;
    UseToolbarGradient: Boolean;
    HideTabWhenOneOpen: Boolean;

    ShowFieldOverlayImages: Boolean;

    EnforceEditableQueries: Boolean;
    OpenExportedResultset: Boolean;

    AssociateFileExtensions: Boolean;

    ShowQueryBrowserSidebar: Boolean;

    ShowDragTargetWindowOnAltPressedOnly: Boolean;

    LastFileDialogPaths: TStringList;

    FriendlyLineBreaks: Boolean;
    FriendlyLineBreaksLF,
      FriendlyLineBreaksCR: WideChar;

    CreateWindowsStyleLineBreaks: Boolean;

    ShowMouseCursorToolbarGroup: Boolean;

    AlignNumericColsRight: Boolean;

    ShowTextSearchDetails: Boolean;

    SQLEditMaximizedRSTabSheetHeight: Integer;
    SQLEditMaximizedScriptTabSheetHeight: Integer;

    GlobalParametersAsStrings: WideString;

    Embedded: Boolean;

    ShowAdvancedToolbar: Boolean;
  end;

  EMyxQueryBrowserLibError = class(EMyxLibraryError);

var
  ApplicationDM: TApplicationDM;

implementation

{$R *.dfm}

procedure TApplicationDM.DataModuleCreate(Sender: TObject);
var
  s: WideString;
begin
  //Exception Handling
  Application.OnException := OnApplicationException;

  ApplicationIsTerminating := False;

  //DLL Version check
  if (libmysqlx_PUBLIC_INTERFACE_VERSION <> myx_get_public_interface_version) then
    s := Format(_('There is a incompatible version of the ' +
      'library %s installed (Version %s). Please update the library to version %s.'),
      ['libmysqlx.dll', FormatLibraryVersion(myx_get_public_interface_version),
      FormatLibraryVersion(libmysqlx_PUBLIC_INTERFACE_VERSION)]) + #13#10#13#10;

  if (libmysqlqb_PUBLIC_INTERFACE_VERSION <> myx_get_qb_public_interface_version) then
    s := Format(_('There is a incompatible version of the ' +
      'library %s installed (Version %s). Please update the library to version %s.'),
      ['libmysqlqb.dll', FormatLibraryVersion(myx_get_qb_public_interface_version),
      FormatLibraryVersion(libmysqlqb_PUBLIC_INTERFACE_VERSION)]) + #13#10#13#10;

  if (s <> '') then
    if (ShowModalDialog('Library version mismatch',
      trim(s), myx_mtError, 'Quit' + #13#10 + 'Ignore') = 1) then
    begin
      ApplicationIsTerminating := True;
      Application.Terminate;
    end;
end;

procedure TApplicationDM.DataModuleDestroy(Sender: TObject);

begin
  FOptions := nil;
  FOptionProvider := nil;
end;

procedure TApplicationDM.CheckCommandlineParameter;

var
  I: integer;

begin
  I := 0;
  while (I <= WideParamCount) do
  begin
    inc(I);

    //Select the start section
    if (WideSameText(Copy(WideParamStr(i), 1, 14), '-startsection=')) then
      FOptions.StartSection := StrToIntDef(Copy(WideParamStr(i), 15, MaxInt), 1);

    if (WideSameText(Copy(WideParamStr(i), 1, 13), '-selecttable=')) then
      FOptions.StartTable := Copy(WideParamStr(i), 14, MaxInt);

    if (WideSameText(WideParamStr(I), '-qs')) and (I+1 <= WideParamCount) then
    begin
      inc(I);
      FOptions.StartScriptFile := WideParamStr(I);
      continue;
    end;

    if (WideSameText(WideParamStr(I), '-qb')) and (I+1 <= WideParamCount) then
    begin
      inc(I);
      FOptions.StartQueryFile := WideParamStr(I);
      continue;
    end;


    if (WideSameText(WideParamStr(I), '-sql')) and (I+1 <= WideParamCount) then
    begin
      inc(I);
      FOptions.StartSQL1 := WideParamStr(I);
      continue;
    end;

    if (WideSameText(WideParamStr(I), '-sql2')) and (I+1 <= WideParamCount) then
    begin
      inc(I);
      FOptions.StartSQL2 := WideParamStr(I);
      continue;
    end;

    if (WideSameText(WideParamStr(I), '-sql3')) and (I+1 <= WideParamCount) then
    begin
      inc(I);
      FOptions.StartSQL3 := WideParamStr(I);
      continue;
    end;

    if (WideSameText(WideParamStr(I), '-embedded')) then
      FOptions.Embedded := True;
  end;
end;

procedure TApplicationDM.OnApplicationException(Sender: TObject; E: Exception);
begin
  if (not (Application.Terminated)) then
    ShowError(E);
end;

procedure TApplicationDM.LoadOptions;
begin
  //Load Options
  FOptions := TMYXAdminOptions.Create('query-browser');
  FOptionProvider := FOptions; // Increment reference counter.
end;

function TApplicationDM.GetLastFileDialogPaths(DlgName: WideString): WideString;
begin
  Result := FOptions.LastFileDialogPaths.Values['DlgName'];
end;

procedure TApplicationDM.SetLastFileDialogPaths(DlgName: WideString; Path: WideString);
begin
  FOptions.LastFileDialogPaths.Values['DlgName'] := Path;
end;

// -------------------------------------------------
// MYXOptions

constructor TMYXAdminOptions.Create(const ApplicationID: string);
begin
  LastFileDialogPaths := TStringList.Create;

  Embedded := False;

  inherited Create(ApplicationID);
end;

destructor TMYXAdminOptions.Destroy;
begin
  inherited Destroy;

  LastFileDialogPaths.Free;
end;

procedure TMYXAdminOptions.LoadOptions;
var
  POptions: PMYX_APPLICATION_OPTIONS;
  Options: TMYX_APPLICATION_OPTIONS;
  i, j: integer;
  error: MYX_LIB_ERROR;
  OptionGroupName, OptionName, OptionValue: WideString;
  ExePath: WideString;
begin
  ExePath := ExtractFilePath(Application.ExeName);

  StartSection := 1;

  //------------------------------------------------------------
  //Initialize Values

  LastFileDialogPaths.Text := '';

  UseToolbarGradient := True;

  OnlyTabsheets := False;

  ShowQueryToolbar := True;

  ShowFieldOverlayImages := True;

  AlignNumericColsRight := True;

  HideTabWhenOneOpen := False;
  ShowQueryBrowserSidebar := True;
  MaximizeSQLEdit := False;
  ShowMouseCursorToolbarGroup := True;

  EnforceEditableQueries := True;
  OpenExportedResultset := False;

  AssociateFileExtensions := False;

  ShowDragTargetWindowOnAltPressedOnly := False;

  ShowQuickStart := False;

  FriendlyLineBreaks := True;
  FriendlyLineBreaksLF := #183;
  FriendlyLineBreaksCR := #182;
  CreateWindowsStyleLineBreaks := True;

  ShowTextSearchDetails := False;

  SQLEditMaximizedRSTabSheetHeight := 240;
  SQLEditMaximizedScriptTabSheetHeight := 65;

  GlobalParametersAsStrings := '';

  ShowAdvancedToolbar := False;


  //------------------------------------------------------------
  //Read Options file
  if (FileExists(MYXCommonOptions.UserDataDir + 'mysqlqb_options.xml')) then
  begin
    POptions := myx_get_application_options(
      MYXCommonOptions.UserDataDir + 'mysqlqb_options.xml',
      @error);
    try
      if (error <> MYX_NO_ERROR) then
      begin
        ShowModalDialog('XML Error',
          'Error while loading Options file ''' +
          MYXCommonOptions.UserDataDir + 'mysqlqb_options.xml' + ''''#13#10 +
          'Error Number ' + IntToStr(Ord(error)),
          myx_mtError);
      end
      else
      begin
        Options := TMYX_APPLICATION_OPTIONS.Create(POptions);
        try
          for i := 0 to Options.option_groups.Count - 1 do
            for j := 0 to Options.option_groups[i].name_value_pairs.Count - 1 do
            begin
              OptionGroupName := Options.option_groups[i].name;
              OptionName := Options.option_groups[i].name_value_pairs[j].name;
              OptionValue := Options.option_groups[i].name_value_pairs[j].value;

              // TODO: Once only the interface is used this cast will be unncessary.
              (Self as IOptionProvider).OptionAsString[OptionName] := OptionValue;
              if (CompareText(OptionGroupName, 'General') = 0) then
              begin
                if (CompareText(OptionName, 'LastFileDialogPaths') = 0) then
                  LastFileDialogPaths.Text := AnsiReplaceText(OptionValue,
                    '´', #13#10)
                else
                  ;
              end
              else
                if (CompareText(OptionGroupName, 'Display') = 0) then
                begin
                  if (CompareText(OptionName, 'ShowQueryToolbar') = 0) then
                    ShowQueryToolbar := (OptionValue = '1')
                  else
                    if (CompareText(OptionName, 'UseToolbarGradient') = 0) then
                      UseToolbarGradient := (OptionValue = '1')
                    else
                      if (CompareText(OptionName, 'HideTabWhenOneOpen') = 0) then
                        HideTabWhenOneOpen := (OptionValue = '1')
                      else
                        if (CompareText(OptionName, 'ShowQueryBrowserSidebar') = 0) then
                          ShowQueryBrowserSidebar := (OptionValue = '1')
                        else
                          if (CompareText(OptionName, 'ShowQuickStart') = 0) then
                            ShowQuickStart := (OptionValue = '1')
                          else
                            if (CompareText(OptionName, 'ShowDragTargetWindowOnAltPressedOnly') = 0) then
                              ShowDragTargetWindowOnAltPressedOnly := (OptionValue = '1')
                            else
                              if (CompareText(OptionName, 'ShowFieldOverlayImages') = 0) then
                                ShowFieldOverlayImages := (OptionValue = '1')
                              else
                                if (CompareText(OptionName, 'MaximizeSQLEdit') = 0) then
                                  MaximizeSQLEdit := (OptionValue = '1')
                                else
                                  if (CompareText(OptionName, 'ShowMouseCursorToolbarGroup') = 0) then
                                    ShowMouseCursorToolbarGroup := (OptionValue = '1')
                                  else
                                    if (CompareText(OptionName, 'ShowTextSearchDetails') = 0) then
                                      ShowTextSearchDetails := (OptionValue = '1')
                                    else
                                      if (CompareText(OptionName, 'SQLEditMaximizedRSTabSheetHeight') = 0) then
                                        SQLEditMaximizedRSTabSheetHeight := StrToIntDef(OptionValue, 240)
                                      else
                                        if (CompareText(OptionName, 'SQLEditMaximizedScriptTabSheetHeight') = 0) then
                                          SQLEditMaximizedScriptTabSheetHeight := StrToIntDef(OptionValue, 60)
                                        else
                                          if (CompareText(OptionName, 'ShowAdvancedToolbar') = 0) then
                                            ShowAdvancedToolbar := (OptionValue = '1')


                end
                else
                  if (CompareText(OptionGroupName, 'Query') = 0) then
                  begin
                    if (CompareText(OptionName, 'EnforceEditableQueries') = 0) then
                      EnforceEditableQueries := (OptionValue = '1')
                    else
                      if (CompareText(OptionName, 'OpenExportedResultset') = 0) then
                        OpenExportedResultset := (OptionValue = '1')
                      else
                        if (CompareText(OptionName, 'FriendlyLineBreaks') = 0) then
                          FriendlyLineBreaks := (OptionValue = '1')
                        else
                          if (CompareText(OptionName, 'FriendlyLineBreaksLF') = 0) then
                            FriendlyLineBreaksLF := OptionValue[1]
                          else
                            if (CompareText(OptionName, 'FriendlyLineBreaksCR') = 0) then
                              FriendlyLineBreaksCR := OptionValue[1]
                            else
                              if (CompareText(OptionName, 'CreateWindowsStyleLineBreaks') = 0) then
                                CreateWindowsStyleLineBreaks := (OptionValue = '1')
                            else
                              if (CompareText(OptionName, 'AlignNumericColsRight') = 0) then
                                AlignNumericColsRight := (OptionValue = '1')

                  end
                  else
                    if (CompareText(OptionGroupName, 'Various') = 0) then
                    begin
                      if (CompareText(OptionName, 'AssociateFileExtensions') = 0) then
                        AssociateFileExtensions := (OptionValue = '1')
                        else if (CompareText(OptionName, 'GlobalParametersAsStrings') = 0) then
                          GlobalParametersAsStrings := OptionValue
                      else
                        ;
                    end
                    else
                      if (CompareText(OptionGroupName, 'WindowPos') = 0) then
                      begin
                        WindowPosList.AddObject(OptionName, TMyxWindowPos.Create(OptionValue));
                      end;

            end;
        finally
          Options.Free;
        end;
      end;
    finally
      //Free Application Options
      myx_free_application_options(POptions);
    end;
  end;
end;

procedure TMYXAdminOptions.StoreOptions;
var
  Options: TMYX_APPLICATION_OPTIONS;
  OptionGroup: TMYX_OPTION_GROUP;
  ExePath: WideString;
  i: integer;
begin
  if (MYXCommonOptions.UserDataDir='') then
    Exit;

  ExePath := ExtractFilePath(Application.ExeName);

  //Create Application Options
  Options := TMYX_APPLICATION_OPTIONS.create;
  try
    //-----------------------------------------------
    //Create Option Group
    OptionGroup := TMYX_OPTION_GROUP.create('General');
    Options.option_groups.Add(OptionGroup);

    AddParam(OptionGroup, 'LastFileDialogPaths',
      AnsiReplaceText(LastFileDialogPaths.Text, #13#10, '´'));

    //-----------------------------------------------
    //Create Option Group
    OptionGroup := TMYX_OPTION_GROUP.create('Display');
    Options.option_groups.Add(OptionGroup);

    AddParam(OptionGroup, 'ShowQueryToolbar',
      IntToStr(Ord(ShowQueryToolbar)));

    AddParam(OptionGroup, 'UseToolbarGradient',
      IntToStr(Ord(UseToolbarGradient)));

    AddParam(OptionGroup, 'HideTabWhenOneOpen',
      IntToStr(Ord(HideTabWhenOneOpen)));

    AddParam(OptionGroup, 'ShowQueryBrowserSidebar',
      IntToStr(Ord(ShowQueryBrowserSidebar)));

    AddParam(OptionGroup, 'MaximizeSQLEdit',
      IntToStr(Ord(MaximizeSQLEdit)));

    AddParam(OptionGroup, 'ShowMouseCursorToolbarGroup',
      IntToStr(Ord(ShowMouseCursorToolbarGroup)));

    AddParam(OptionGroup, 'ShowTextSearchDetails',
      IntToStr(Ord(ShowTextSearchDetails)));

    AddParam(OptionGroup, 'SQLEditMaximizedRSTabSheetHeight',
      IntToStr(SQLEditMaximizedRSTabSheetHeight));

    AddParam(OptionGroup, 'SQLEditMaximizedScriptTabSheetHeight',
      IntToStr(SQLEditMaximizedScriptTabSheetHeight));

    AddParam(OptionGroup, 'ShowAdvancedToolbar',
      IntToStr(Ord(ShowAdvancedToolbar)));




    //Show Quickstart only once
    if (ShowQuickStart) then
      ShowQuickStart := False;
    AddParam(OptionGroup, 'ShowQuickStart',
      IntToStr(Ord(ShowQuickStart)));

    AddParam(OptionGroup, 'ShowDragTargetWindowOnAltPressedOnly',
      IntToStr(Ord(ShowDragTargetWindowOnAltPressedOnly)));

    AddParam(OptionGroup, 'ShowFieldOverlayImages',
      IntToStr(Ord(ShowFieldOverlayImages)));

    //-----------------------------------------------
    //Create Option Group
    OptionGroup := TMYX_OPTION_GROUP.create('Query');
    Options.option_groups.Add(OptionGroup);

    AddParam(OptionGroup, 'EnforceEditableQueries',
      IntToStr(Ord(EnforceEditableQueries)));

    AddParam(OptionGroup, 'OpenExportedResultset',
      IntToStr(Ord(OpenExportedResultset)));

    AddParam(OptionGroup, 'FriendlyLineBreaks',
      IntToStr(Ord(FriendlyLineBreaks)));

    AddParam(OptionGroup, 'FriendlyLineBreaksLF', FriendlyLineBreaksLF);

    AddParam(OptionGroup, 'FriendlyLineBreaksCR', FriendlyLineBreaksCR);

    AddParam(OptionGroup, 'CreateWindowsStyleLineBreaks',
      IntToStr(Ord(CreateWindowsStyleLineBreaks)));

    AddParam(OptionGroup, 'AlignNumericColsRight',
      IntToStr(Ord(AlignNumericColsRight)));

    //-----------------------------------------------
    //Create Option Group
    OptionGroup := TMYX_OPTION_GROUP.create('Various');
    Options.option_groups.Add(OptionGroup);

    AddParam(OptionGroup, 'AssociateFileExtensions',
      IntToStr(Ord(AssociateFileExtensions)));

    AddParam(OptionGroup, 'GlobalParametersAsStrings',
      GlobalParametersAsStrings);

    //-----------------------------------------------
    //Create Option Group
    OptionGroup := TMYX_OPTION_GROUP.create('WindowPos');
    Options.option_groups.Add(OptionGroup);

    //Store all window positions
    for i := 0 to WindowPosList.Count - 1 do
      AddParam(OptionGroup, WindowPosList[i],
        TMyxWindowPos(WindowPosList.Objects[i]).AsWideString);

    // Convert all options (stored only in the list) to the needed name-value-pairs.
    // TODO: Once everything works via the list this will be the main save method.
    StoreListOptions(Options.option_groups);

    //-----------------------------------------------
    //Store Options to file
    myx_store_application_options(Options.get_record_pointer,
      MYXCommonOptions.UserDataDir + 'mysqlqb_options.xml');
  finally
    Options.Free;
  end;
end;

end.

