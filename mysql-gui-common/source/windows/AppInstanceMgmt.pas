unit AppInstanceMgmt;

interface

uses Windows, SysUtils, Forms, TntMenus, Classes;

type
  PAppInstanceInfo = ^TAppInstanceInfo;
  TAppInstanceInfo = packed record
    AppHandle: THandle;
    ConnectionString: Array [0 .. 100] of Char;
    ApplicationCaption: Array [0 .. 100] of Char;
  end;

  PAppInstances = ^TAppInstances;
  TAppInstances = packed record
    InstanceCount: Integer;
    Instances: Array [0..100] of TAppInstanceInfo;
  end;

  TDataMenuItem = class(TTntMenuItem)
    constructor Create(AOwner: TComponent; AppHandle: THandle); reintroduce;
  private
    FAppHandle: THandle;
  public
    procedure Click; reintroduce; override;
    property AppHandle: THandle read FAppHandle;
  end;

function RegisterApplication(App: TApplication;
  ConnectionString: WideString; AllowOnlyOneInstance: Boolean = False): Boolean;

procedure UnregisterApplication(App: TApplication);

procedure BuildRegisterApplicationMenuItems(MenuItem: TTntMenuItem);

//----------------------------------------------------------------------------------------------------------------------

implementation

var
  MappingHandle: THandle; // Central handle for file mapping used for instance management.
  
//----------------------------------------------------------------------------------------------------------------------

constructor TDataMenuItem.Create(AOwner: TComponent; AppHandle: THandle);

begin
  inherited Create(AOwner);

  FAppHandle := AppHandle;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TDataMenuItem.Click;

begin
  inherited;

  if (IsIconic(FAppHandle)) then
     ShowWindow(FAppHandle, SW_RESTORE);

  SetForegroundWindow(FAppHandle);
end;

//----------------------------------------------------------------------------------------------------------------------

function RegisterApplication(App: TApplication; ConnectionString: WideString; AllowOnlyOneInstance: Boolean): Boolean;

var
  AppInstances: PAppInstances;
  S: string;
  I: Integer;
  LastError: Cardinal;

begin
  Result := True;

  if MappingHandle = 0 then
  begin
    MappingHandle := CreateFileMapping($FFFFFFFF, nil, PAGE_READWRITE, 0, SizeOf(TAppInstances), 'MySQLGuiInstanceManagement');
    if MappingHandle = 0 then
      RaiseLastOSError
  end;

  if MappingHandle <> 0 then
  begin
    LastError := GetLastError;
    AppInstances := MapViewOfFile(MappingHandle, FILE_MAP_ALL_ACCESS, 0, 0, SizeOf(TAppInstances));

    if Assigned(AppInstances) then
    begin
      if LastError <> ERROR_ALREADY_EXISTS then
        AppInstances^.InstanceCount := 1
      else //already runing
      begin
        if AllowOnlyOneInstance then
        begin
          for I := 0 to AppInstances^.InstanceCount - 1 do
            if (WideSameText(
              UTF8Decode(AppInstances^.Instances[I].ApplicationCaption),
              App.Title)) then
            begin
              if (IsIconic(AppInstances^.Instances[I].AppHandle)) then
                 ShowWindow(AppInstances^.Instances[I].AppHandle, SW_RESTORE);

              SetForegroundWindow(AppInstances^.Instances[I].AppHandle);

              Result := False;

              Exit;
            end;
        end;

        Inc(AppInstances^.InstanceCount);
      end;

      AppInstances^.Instances[AppInstances^.InstanceCount - 1].AppHandle := App.Handle;

      S := UTF8Encode(App.Title);
      StrMove(AppInstances^.Instances[AppInstances^.InstanceCount - 1].ApplicationCaption,
        PChar(S), Length(S));

      AppInstances^.Instances[AppInstances^.InstanceCount - 1].ConnectionString[0] := Char(0);
      S := UTF8Encode(ConnectionString);
      StrMove(AppInstances^.Instances[AppInstances^.InstanceCount - 1].ConnectionString,
        PChar(S), Length(S));

      UnmapViewOfFile(AppInstances);
    end;
  end
end;

//----------------------------------------------------------------------------------------------------------------------

procedure UnregisterApplication(App: TApplication);

var
  AppInstances: PAppInstances;
  I: Integer;
  J: Integer;

begin
  if MappingHandle <> 0 then
  begin
    AppInstances := MapViewOfFile(MappingHandle, FILE_MAP_ALL_ACCESS, 0, 0, SizeOf(TAppInstances));

    // find current application
    for I := 0 to AppInstances^.InstanceCount - 1 do
      if (AppInstances^.Instances[I].AppHandle = App.Handle) then
      begin
        // move down all other instances
        for J := AppInstances^.InstanceCount - 1 downto I + 1 do
          AppInstances^.Instances[J - 1] := AppInstances^.Instances[J];

        break;
      end;

    Dec(AppInstances^.InstanceCount);
    UnmapViewOfFile(AppInstances);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure BuildRegisterApplicationMenuItems(MenuItem: TTntMenuItem);

var
  I: Integer;
  CurrentCount: Integer;
  AppInstances: PAppInstances;
  AppMenuItem: TTntMenuItem;

begin
  CurrentCount := MenuItem.Count;

  if MappingHandle <> 0 then
  begin
    AppInstances := MapViewOfFile(MappingHandle, FILE_MAP_ALL_ACCESS, 0, 0, SizeOf(TAppInstances));

    // Find current application.
    for I := 0 to AppInstances^.InstanceCount - 1 do
    begin
      AppMenuItem := TDataMenuItem.Create(MenuItem.Owner,
        AppInstances^.Instances[I].AppHandle);
      AppMenuItem.Caption := UTF8Decode(AppInstances^.Instances[I].ApplicationCaption);

      if (AppInstances^.Instances[I].ConnectionString <> '') then
       AppMenuItem.Caption := AppMenuItem.Caption +
        ' - ' + UTF8Decode(AppInstances^.Instances[I].ConnectionString);
      AppMenuItem.OnAdvancedDrawItem := MenuItem.OnAdvancedDrawItem;
      AppMenuItem.OnMeasureItem := MenuItem.OnMeasureItem;
      MenuItem.Add(AppMenuItem);
    end;

    MenuItem.Enabled := True;

    UnmapViewOfFile(AppInstances);
  end;

  for I := 0 to CurrentCount - 1 do
    MenuItem.Delete(0);
end;

//----------------------------------------------------------------------------------------------------------------------

initialization
finalization
  if MappingHandle <> 0 then
    CloseHandle(MappingHandle);
end.
