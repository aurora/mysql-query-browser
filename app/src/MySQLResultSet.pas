unit MySQLResultSet;

{$mode delphi}

interface

uses
  Windows, Messages, SysUtils, Classes, Contnrs, Controls,
  TntExtCtrls, TntComCtrls, TntClasses, TntStdCtrls, SyncObjs,
  myx_types, myx_public_interface, myx_util_public_interface, gnugettext, auxfuncs, MyxError,
  MySQLConnection, laz.VirtualTrees, VTCompat, Graphics, StrUtils,
  TextSearch;

type
  TMySQLRS = class;
  TExecuteQueryThread = class;

  IMySQLRSControlInterface = interface(IUnknown)
    ['{B46142F1-743F-4BB2-9A00-20C7D485D7AA}']
    procedure ClearValues;

    function GetMySQLRS: TMySQLRS;
    procedure SetMySQLRS(MySQLRS: TMySQLRS);
    function GetControl: TObject;

    procedure DoCurrentRowChanged;
    procedure DoEditStateChanged;
    procedure DoStatusCaptionChanged;
    procedure DoMessagesChanged;

    property MySQLRS: TMySQLRS read GetMySQLRS write SetMySQLRS;
    property Control: TObject read GetControl;
  end;

  TConfirmEvent = function(Sender: TObject; Msg: WideString): Boolean of object;
  TResultsetEvent = function(Sender: TObject): TMySQLRS of object;

  PCommandEntry = ^TCommandEntry;
  TCommandEntry = record
    SQL: WideString;
    Caret: TPoint;
  end;

  // A list of commands with a scrollable pointer to a current command.
  TCommandList = class(TObject)
  private
    FCommands: TList;
    FCurrent: Integer;
    FPushPending: Boolean;       // Set when the current command is complete and might be pushed in case it is later changed.
    function GetCurrent: PCommandEntry;
    function GetCurrentCaret: TPoint;
    function GetCurrentSQL: WideString;
    procedure SetCurrentCaret(const Value: TPoint);
    procedure SetCurrentSQL(const Value: WideString);
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure Add(const SQL: WideString; Caret: TPoint);
    function Back: PCommandEntry;
    procedure Clear;
    function HasBack: Boolean;
    function HasNext: Boolean;
    function Next: PCommandEntry;
    procedure PrepareCurrent;

    property Current: PCommandEntry read GetCurrent;
    property CurrentSQL: WideString read GetCurrentSQL write SetCurrentSQL;
    property CurrentCaret: TPoint read GetCurrentCaret write SetCurrentCaret;
  end;

  TMySQLRS = class(TObject)
    constructor Create;
    destructor Destroy; override;

    procedure ConnectControl(Control: IMySQLRSControlInterface);
    procedure DisconnectControl(Control: IMySQLRSControlInterface);

    procedure ExecuteQuery(Sql: WideString = '');
    procedure Refresh;

    procedure FreeResultSet;

    procedure DoCurrentRowChanged(Sender: IMySQLRSControlInterface; CurrentRow: Integer);
    procedure DoDynamicParamsChanged;
    procedure DoEditStateChanged;
    procedure DoStatusCaptionChanged;

    procedure UpdateDynamicParams;

    procedure DoDisplaySearch(ShowReplacePage: Boolean = False);
    procedure GotoFirstRow;
    procedure GotoLastRow;
    procedure DoEdit;
    procedure DoApplyChanges;
    procedure DoDiscardChanges;

    procedure DoMessagesChanged;
    procedure AddRSMessage(Msg: WideString; MsgType: MYX_QUERY_ERROR_LEVEL;
      MsgNr: Integer);
    procedure ClearRSMessages;

    procedure ConnectRS(RS: TMySQLRS);
    procedure DisconnectRS(RS: TMySQLRS);
  private
    FConnectedControls: TInterfaceList;
    FConnectedResultsets: TList;

    FExecuteQueryThread: TExecuteQueryThread;

    FMySQLConn: TMySQLConn;
    FSQL: Widestring;

    FCommandList: TCommandList;

    FStatusCaption: WideString;

    FEdited: Boolean;
    FActive: Boolean;

    FParentRS: TMySQLRS;
    FCurrentRow: Integer;
    FOnParamChange: TNotifyEvent;

    FOnQueryExecute: TNotifyEvent;
    FOnQueryExecuted: TNotifyEvent;
    FOnQuerySuccess: TNotifyEvent;
    FOnQueryStopped: TNotifyEvent;
    FOnQueryError: TNotifyEvent;

    FOnConfirmDeletion: TConfirmEvent;

    FStopQuery: Boolean;
    FQueryExecuting: Boolean;

    FCreateNextRSForMultibleRSQuery: TResultsetEvent;

    FRemoveRSForMultibleRSQuery: TNotifyEvent;
    FShowRSForMultibleRSQuery: TNotifyEvent;

    FGlobalParams,
    FLocalParams,
    FDynamicParams: TTntStringList;
  protected
    QueryStateMultiReadSync: TMultiReadExclusiveWriteSynchronizer;

    function GetMySQLConn: TMySQLConn;
    procedure SetMySQLConn(MySQLConn: TMySQLConn);

    function GetActive: Boolean;
    procedure SetActive(Active: Boolean);

    procedure Open;
    procedure Close;

    function GetEdited: Boolean;
    procedure SetEdited(Edited: Boolean);

    function GetStatusCaption: WideString;
    procedure SetStatusCaption(StatusCaption: WideString);

    function GetParentRS: TMySQLRS;
    procedure SetParentRS(ParentRS: TMySQLRS);

    function GetRowCount: integer;

    procedure CheckAttributes;

    function GetStopQuery: Boolean;
    procedure SetStopQuery(StopQuery: Boolean);

    function GetQueryExecuting: Boolean;
    procedure SetQueryExecuting(QueryExecuting: Boolean);

    function GetConnectedDetailRSCount: Integer;
    function GetConnectedDetailRS(I: Integer): TMySQLRS;

    function GetConnectedControlsCount: Integer;
    function GetConnectedControls(I: Integer): IMySQLRSControlInterface;

    function DoSearch(Sender: TObject;
      SearchText: WideString; ReplaceText: WideString;
      SearchOptions: TTextSearchOptions): Integer;

  public
    WorkWithResultset: TCriticalSection;

    ResultSet: PMYX_RESULTSET;

    ErrorMessages: TObjectList;

    Editable,
    EditingAllowed,
    AtLeastOneRecord,
    FirstRowSelected,
    LastRowSelected: Boolean;
    ErrorOccured: Boolean;

    InsertedRows,
    DeletedRows: Integer;

    function AllowedToDiscard: Boolean;

    property CommandList: TCommandList read FCommandList;
    property MySQLConn: TMySQLConn read GetMySQLConn write SetMySQLConn default nil;
    property Active: Boolean read GetActive write SetActive default False;
    property SQL: Widestring read FSQL write FSQL;
    property Edited: Boolean read GetEdited write SetEdited default False;
    property StatusCaption: WideString read GetStatusCaption write SetStatusCaption;
    property ParentRS: TMySQLRS read GetParentRS write SetParentRS;
    property RowCount: Integer read GetRowCount;

    property OnParamChange: TNotifyEvent read FOnParamChange write FOnParamChange;
    property OnQueryExecute: TNotifyEvent read FOnQueryExecute write FOnQueryExecute;
    property OnQueryExecuted: TNotifyEvent read FOnQueryExecuted write FOnQueryExecuted;
    property OnQuerySuccess: TNotifyEvent read FOnQuerySuccess write FOnQuerySuccess;
    property OnQueryStopped: TNotifyEvent read FOnQueryStopped write FOnQueryStopped;
    property OnQueryError: TNotifyEvent read FOnQueryError write FOnQueryError;

    property OnConfirmDeletion: TConfirmEvent read FOnConfirmDeletion write FOnConfirmDeletion;

    property StopQuery: Boolean read GetStopQuery write SetStopQuery default False;
    property QueryExecuting: Boolean read GetQueryExecuting write SetQueryExecuting default False;

    property ConnectedDetailRSCount: integer read GetConnectedDetailRSCount;
    property ConnectedDetailRS[I: Integer]: TMySQLRS read GetConnectedDetailRS;

    property CreateNextRSForMultibleRSQuery: TResultsetEvent read FCreateNextRSForMultibleRSQuery write FCreateNextRSForMultibleRSQuery;
    property RemoveRSForMultibleRSQuery: TNotifyEvent read FRemoveRSForMultibleRSQuery write FRemoveRSForMultibleRSQuery;
    property ShowRSForMultibleRSQuery: TNotifyEvent read FShowRSForMultibleRSQuery write FShowRSForMultibleRSQuery;

    property ConnectedControlsCount: Integer read GetConnectedControlsCount;
    property ConnectedControls[I: Integer]: IMySQLRSControlInterface read GetConnectedControls;

    property GlobalParams: TTntStringList read FGlobalParams write FGlobalParams;
    property LocalParams: TTntStringList read FLocalParams write FLocalParams;
    property DynamicParams: TTntStringList read FDynamicParams write FDynamicParams;
  end;

  TExecuteQueryThread = class(TThread)
    constructor Create(MySQLRS: TMySQLRS);
    destructor Destroy; override;

    procedure BuildGrid;

    procedure QueryExecuted;

    procedure FetchMySQLMessages;

    procedure QuerySuccess;
    procedure QueryStopped;
    procedure QueryError;
  protected
    procedure Execute; override;
    procedure CreateNextRSForMultibleRSQuery;
    procedure RemoveRSForMultibleRSQuery;
    procedure ShowRSForMultibleRSQuery;
  private
    ThreadPMySQL: Pointer;
    ExceptionMsg: WideString;
    FNeedCleanup: Boolean;
  public
    MySQLRS: TMySQLRS;

    Query: WideString;

    current_row_count: Longint;
    previous_row_count: Longint;
    result_set: PMYX_RESULTSET;
  end;

  TRSError = class(TObject)
    constructor Create(Msg: WideString; MsgType: MYX_QUERY_ERROR_LEVEL;
      MsgNr: Integer);
  public
    Msg: WideString;
    MsgType: MYX_QUERY_ERROR_LEVEL;
    MsgNr: Integer;
  end;

  TRSFieldValue = record
    Value: PAnsiChar;
    Length: Integer;
    BinaryData: Boolean;
    IsNull: Boolean;
  end;

  function progress_row_fetch(current_row_count: Longint; previous_row_count: Longint; result_set: PMYX_RESULTSET; user_data: Pointer):Integer; cdecl;
  procedure resultset_realloc_before(user_data: Pointer); cdecl;
  procedure resultset_realloc_after(user_data: Pointer); cdecl;

implementation

uses
  MySQLResultSetControls, ApplicationDataModule,
  Forms;
                                                   
constructor TMySQLRS.Create;
begin
  inherited;

  ResultSet:=nil;
  FMySQLConn:=nil;

  FParentRS:=nil;

  FConnectedControls := TInterfaceList.Create;
  FConnectedResultsets := TList.Create;

  FCommandList := TCommandList.Create;

  FCurrentRow := -1;

  InsertedRows := 0;
  DeletedRows := 0;

  FGlobalParams := nil;
  FLocalParams := TTntStringList.Create;
  FDynamicParams := TTntStringList.Create;

  ErrorMessages := TObjectList.Create;

  ErrorOccured := False;

  Editable := False;
  EditingAllowed := False;
  FEdited := False;

  QueryStateMultiReadSync := TMultiReadExclusiveWriteSynchronizer.Create;
  FActive := False;
  StopQuery := False;

  FQueryExecuting := False;

  WorkWithResultset := TCriticalSection.Create;
end;

destructor TMySQLRS.Destroy;

var
  I: integer;
  
begin
  // Disconnect from ParentRS
  ParentRS := nil;
  FreeResultSet;

  // Disconnect controls.
  for I := 0 to FConnectedControls.Count - 1 do
    IMySQLRSControlInterface(FConnectedControls[0]).MySQLRS := nil;

  ErrorMessages.Free;
  FCommandList.Free;

  FConnectedControls.Free;
  FConnectedResultsets.Free;

  FLocalParams.Free;
  FDynamicParams.Free;

  QueryStateMultiReadSync.Free;

  WorkWithResultset.Free;

  inherited;
end;

procedure TMySQLRS.ConnectControl(Control: IMySQLRSControlInterface);
begin
  if FConnectedControls.IndexOf(Control) = -1 then
    FConnectedControls.Add(Control);
end;

procedure TMySQLRS.DisconnectControl(Control: IMySQLRSControlInterface);
begin
  FConnectedControls.Remove(Control);
end;

procedure TMySQLRS.FreeResultSet;
var i: integer;
begin
  for i:=0 to FConnectedControls.Count-1 do
    IMySQLRSControlInterface(FConnectedControls[i]).ClearValues;

  if(ResultSet<>nil)then
    myx_query_free_resultset(ResultSet);

  InsertedRows:=0;
  DeletedRows:=0;

  ResultSet:=nil;
end;

function TMySQLRS.GetMySQLConn: TMySQLConn;
begin
  Result:=FMySQLConn;
end;

procedure TMySQLRS.SetMySQLConn(MySQLConn: TMySQLConn);
begin
  FMySQLConn:=MySQLConn;
end;

//----------------------------------------------------------------------------------------------------------------------

function TMySQLRS.AllowedToDiscard: Boolean;

begin
  Result := Not(FEdited) or (ShowModalDialog(_('Unapplied Changes'),
    _('You have made changes to the resultset that have not been '+
      'applied yet. Do you want to discard the changes?'),
    myx_mtConfirmation, _('Discard')+#13#10+_('Abort')) = 1);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMySQLRS.ExecuteQuery(Sql: WideString);

begin
  FSQL := Trim(Sql);
  Refresh;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMySQLRS.Refresh;

begin
  if FSQL = '' then
  begin
    ShowModalDialog(_('No SQL Command'),
      _('You tried to execute an empty string. Please type an SQL command into the SQL edit field and execute again.'),
      myx_mtError, _('Ok'));
    Exit;
  end;

  if not AllowedToDiscard  then
    Exit;

  if FMySQLConn.Ping <> 0 then
    FMySQLConn.Reconnect;

  Edited := False;

  FreeResultSet;

  ClearRSMessages;

  EditingAllowed:=False;
  StopQuery:=False;
  QueryExecuting:=True;

  if(Assigned(FOnQueryExecute))then
    FOnQueryExecute(self);

  try
    FExecuteQueryThread := TExecuteQueryThread.Create(self);
    try
      // Thread will be freed after execution.
      FExecuteQueryThread.FreeOnTerminate:=True;

      FExecuteQueryThread.Resume;
    except
      FreeAndNil(FExecuteQueryThread);
    end;
  except
    on x: Exception do
    begin
      QueryExecuting := False;

      if Assigned(FOnQueryError) then
        FOnQueryError(self);
      if Assigned(FOnQueryExecuted) then
        FOnQueryExecuted(self);

      raise;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMySQLRS.SetActive(Active: Boolean);

begin
  if(Active)then
    Open
  else
    Close;
end;

function TMySQLRS.GetActive: Boolean;
begin
  Result:=FActive;
end;

procedure TMySQLRS.Open;
begin
  FActive:=True;

  ExecuteQuery;
end;

procedure TMySQLRS.Close;
begin
  FreeResultSet;

  FActive:=False;
end;

function TMySQLRS.GetEdited: Boolean;
begin
  Result:=FEdited;
end;

procedure TMySQLRS.SetEdited(Edited: Boolean);
begin
  if(FEdited<>Edited)then
  begin
    FEdited:=Edited;

    DoEditStateChanged;
  end;
end;

procedure TMySQLRS.ConnectRS(RS: TMySQLRS);
begin
  if(FConnectedResultsets.IndexOf(RS)=-1)then
    FConnectedResultsets.Add(RS);
end;

procedure TMySQLRS.DisconnectRS(RS: TMySQLRS);
begin
  if(FConnectedResultsets.IndexOf(RS)<>-1)then
    FConnectedResultsets.Delete(FConnectedResultsets.IndexOf(RS));
end;

function TMySQLRS.GetParentRS: TMySQLRS;
begin
  Result:=FParentRS;
end;

procedure TMySQLRS.SetParentRS(ParentRS: TMySQLRS);
begin
  if(FParentRS<>nil)and(FParentRS<>ParentRS)then
    FParentRS.DisconnectRS(self);

  FParentRS:=ParentRS;

  if(FParentRS<>nil)then
    FParentRS.ConnectRS(self);
end;

function TMySQLRS.GetRowCount: integer;
begin
  if(ResultSet<>nil)then
    Result:=ResultSet.rows_num+InsertedRows-DeletedRows
  else
    Result:=0;
end;


procedure TMySQLRS.DoCurrentRowChanged(Sender: IMySQLRSControlInterface;
  CurrentRow: Integer);

var
  i: integer;

begin
  CheckAttributes;

  FirstRowSelected:=False;
  if(ResultSet<>nil)then
    if(CurrentRow=0)or((ResultSet.rows_num+InsertedRows=0)and(CurrentRow=1))then
      FirstRowSelected:=True;

  LastRowSelected:=False;
  if(ResultSet<>nil)then
    if((CurrentRow>=ResultSet.rows_num-1+InsertedRows)or
      (ResultSet.rows_num+InsertedRows=0))then
      LastRowSelected:=True;


  {if(FCurrentRow=int(CurrentRow))then
    Exit;}

  FCurrentRow:=CurrentRow;

  UpdateDynamicParams;

  for i:=0 to FConnectedControls.Count-1 do
    if(FConnectedControls[i]<>Sender)then
      IMySQLRSControlInterface(FConnectedControls[i]).DoCurrentRowChanged;

  for i:=0 to FConnectedResultsets.Count-1 do
    TMySQLRS(FConnectedResultsets[i]).DoDynamicParamsChanged;

  {if(Assigned(FOnParamChange))then
    FOnParamChange(self);}
end;

procedure TMySQLRS.UpdateDynamicParams;

var
  I: integer;
  Row: PMYX_RS_ROW;
  col: PMYX_RS_COLUMN;
  Field: MYX_RS_FIELD;
  Column: WideString;
  Value: WideString;

begin
  //Set Dynamic Parameters
  FDynamicParams.Clear;
  if (FCurrentRow>-1) and
     (ResultSet<>nil) and
     (FCurrentRow<Integer(ResultSet.rows_num))then
  begin
    Row := PMYX_RS_ROW(integer(ResultSet.rows)+sizeof(MYX_RS_ROW)*FCurrentRow);

    for I := 0 to ResultSet.columns_num-1 do
    begin
      col := PMYX_RS_COLUMN(integer(ResultSet.columns)+(sizeof(MYX_RS_COLUMN)*I));
      Column := Copy(Utf8Decode(col.name), 1, 28);
      if Assigned(Row.fields) then
      begin
        Field := (PMYX_RS_FIELD(integer(Row.fields) + (sizeof(MYX_RS_FIELD) * I)))^;

        // Only take first 128 chars.
        Value := Utf8Decode(Field.value);
        FDynamicParams.Add(Column + '=' + Value);
      end
      else
        FDynamicParams.Add(Column + '=');
    end;
  end;
end;

procedure TMySQLRS.DoDynamicParamsChanged;
begin
  if (ResultSet <> nil) then
    if (Not(Assigned(ResultSet.query)) or
      ((Assigned(ResultSet.query)) and (ResultSet.query.params_num = 0))) then
      Exit;

  if (FSQL <> '') and (FParentRS.FDynamicParams.Count > 0) then
  begin
    ExecuteQuery(FSQL);

    if(Assigned(FOnParamChange))then
      FOnParamChange(self);
  end;
end;

procedure TMySQLRS.DoEditStateChanged;
var i: integer;
begin
  for i:=0 to FConnectedControls.Count-1 do
    IMySQLRSControlInterface(FConnectedControls[i]).DoEditStateChanged;
end;

procedure TMySQLRS.DoStatusCaptionChanged;
var i: integer;
begin
  for i:=0 to FConnectedControls.Count-1 do
    IMySQLRSControlInterface(FConnectedControls[i]).DoStatusCaptionChanged;
end;


function TMySQLRS.GetStatusCaption: WideString;
begin
  Result:=FStatusCaption;
end;

procedure TMySQLRS.SetStatusCaption(StatusCaption: WideString);
begin
  FStatusCaption:=StatusCaption;

  DoStatusCaptionChanged;
end;


procedure TMySQLRS.CheckAttributes;
begin
  if(ResultSet<>nil)then
    Editable:=(ResultSet.editable=1);

  AtLeastOneRecord:=False;
  if(ResultSet<>nil)then
    if(ResultSet.rows_num+InsertedRows>0)then
      AtLeastOneRecord:=True;
end;


procedure TMySQLRS.DoDisplaySearch(ShowReplacePage: Boolean);
begin
  if TextSearchForm=nil then
    TextSearchForm := TTextSearchForm.Create(nil,
      ApplicationDM.Options);

  if ShowReplacePage then
    TextSearchForm.PageControl.ActivePage:=
      TextSearchForm.ReplaceTabSheet;

  TextSearchForm.Show;
  TextSearchForm.OnSearch := DoSearch;
end;

function TMySQLRS.DoSearch(Sender: TObject;
  SearchText: WideString; ReplaceText: WideString;
  SearchOptions: TTextSearchOptions): Integer;

var
  i: Integer;

begin
  Result := 0;

  for i:=0 to FConnectedControls.Count-1 do
    if IMySQLRSControlInterface(FConnectedControls[i]).Control is TMySQLRSGrid then
    begin
      Result := TMySQLRSGrid(IMySQLRSControlInterface(
        FConnectedControls[i]).Control).DoSearch(Sender,
          SearchText, ReplaceText, SearchOptions);
    end;
end;

procedure TMySQLRS.GotoFirstRow;
var i: integer;
  RSGrid: TMySQLRSGrid;
begin
  for i:=0 to FConnectedControls.Count-1 do
  begin
    if((TObject(IMySQLRSControlInterface(FConnectedControls[i]).GetControl) is TMySQLRSGrid))then
    begin
      RSGrid:=TMySQLRSGrid(IMySQLRSControlInterface(FConnectedControls[i]).GetControl);

      if(RSGrid.CanFocus)then
        RSGrid.SetFocus;

      RSGrid.FocusedNode:=RSGrid.GetFirstNoInit;
      RSGrid.ClearSelection;
      RSGrid.Selected[RSGrid.FocusedNode]:=True;
    end;
  end;
end;

procedure TMySQLRS.GotoLastRow;
var i: integer;
  RSGrid: TMySQLRSGrid;
  LastNode: PVirtualNode;
begin
  for i:=0 to FConnectedControls.Count-1 do
  begin
    if((TObject(IMySQLRSControlInterface(FConnectedControls[i]).GetControl) is TMySQLRSGrid))then
    begin
      RSGrid:=TMySQLRSGrid(IMySQLRSControlInterface(FConnectedControls[i]).GetControl);

      if(RSGrid.CanFocus)then
        RSGrid.SetFocus;

      LastNode:=RSGrid.GetLastNoInit;
      if(LastNode<>nil)then
        if(LastNode.PrevSibling<>nil)then
          RSGrid.FocusedNode:=LastNode.PrevSibling
        else
          RSGrid.FocusedNode:=LastNode;
          
      RSGrid.ClearSelection;
      RSGrid.Selected[RSGrid.FocusedNode]:=True;
    end;
  end;
end;

procedure TMySQLRS.DoEdit;
begin
  if Editable then
  begin
    DoEditStateChanged;
    if not EditingAllowed then
    begin
      EditingAllowed := True;
    end
    else
    begin
      DoDiscardChanges;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TMySQLRS.DoApplyChanges;

var
  errors: PMYX_RS_ACTION_ERRORS;
  error: PMYX_RS_ACTION_ERROR;
  I: integer;
  RSGrid: TMySQLRSGrid;
  RSAction: PMYX_RS_ACTION;

begin
  ClearRSMessages;
  SetStatusCaption('');

  if FMySQLConn.Ping <> 0 then
    FMysQLConn.Reconnect(True);

  WorkWithResultset.Acquire;
  try
    //convert all failed actions to normal actions
    if Assigned(ResultSet.actions) then
    begin
      for I := 0 to ResultSet.actions.actions_num-1 do
      begin
        RSAction := PMYX_RS_ACTION(Integer(ResultSet.actions.actions) + sizeof(MYX_RS_ACTION) * I);
        if RSAction.status <> MYX_RSAS_NEW then
          RSAction.status:=MYX_RSAS_NEW;
      end;

      // Apply actions.
      errors := myx_query_apply_actions(ResultSet);
      if errors <> nil then
      begin
        SetStatusCaption(_('Error while applying actions.'));

        for I:=0 to errors.errors_num-1 do
        begin
          error := PMYX_RS_ACTION_ERROR(Integer(errors.errors) + sizeof(MYX_RS_ACTION_ERROR) * I);
          AddRSMessage(UTF8Decode(error.error_text), error.level, error.error);

          if error.error = 2006 then
            FMySQLConn.Connected := False;
        end;

        g_free(errors);
      end;

      // Delete Rows from Grids.
      for I:=0 to FConnectedControls.Count-1 do
        if((TObject(IMySQLRSControlInterface(FConnectedControls[I]).GetControl) is TMySQLRSGrid))then
        begin
          RSGrid:=TMySQLRSGrid(IMySQLRSControlInterface(FConnectedControls[I]).GetControl);

          RSGrid.ApplyDeleteActionsToGrid;
        end;

      // Update resultset which will clear or re-generate a action list.
      if(myx_query_update_resultset(ResultSet)<>0)then
        SetStatusCaption(_('Error while applying changes to the result set.'));

      // Update rows that had actions.
      for I:=0 to FConnectedControls.Count-1 do
        if((TObject(IMySQLRSControlInterface(FConnectedControls[I]).GetControl) is TMySQLRSGrid))then
        begin
          RSGrid:=TMySQLRSGrid(IMySQLRSControlInterface(FConnectedControls[I]).GetControl);
          RSGrid.SynchronizeActions;
        end;
    end;
  finally
    WorkWithResultset.Release;
  end;

  Edited:=False;
  DoEditStateChanged;
end;

procedure TMySQLRS.DoDiscardChanges;
var DoIt: Boolean;
begin
  DoIt:=True;

  if(Assigned(FOnConfirmDeletion))and(Edited)then
    DoIt := FOnConfirmDeletion(Self, _('Do you really want to discard all changes?'));

  if DoIt then
  begin
    myx_query_discard_actions(ResultSet);

    Edited:=False;
    EditingAllowed:=False;

    DoEditStateChanged;
  end;
end;

procedure TMySQLRS.DoMessagesChanged;
var i: integer;
begin
  for i:=0 to FConnectedControls.Count-1 do
    IMySQLRSControlInterface(FConnectedControls[i]).DoMessagesChanged;
end;

procedure TMySQLRS.AddRSMessage(Msg: WideString; MsgType: MYX_QUERY_ERROR_LEVEL;
  MsgNr: Integer);
begin
  if(MsgType=MYX_QEL_ERROR)then
    ErrorOccured:=True;

  ErrorMessages.Add(TRSError.Create(Msg, MsgType, MsgNr));

  DoMessagesChanged;
end;

procedure TMySQLRS.ClearRSMessages;
begin
  ErrorMessages.Clear;

  DoMessagesChanged;
end;

function TMySQLRS.GetStopQuery: Boolean;
begin
  QueryStateMultiReadSync.BeginRead;
  try
    Result:=FStopQuery;
  finally
    QueryStateMultiReadSync.EndRead;
  end;
end;

procedure TMySQLRS.SetStopQuery(StopQuery: Boolean);
begin
  QueryStateMultiReadSync.BeginWrite;
  try
    FStopQuery:=StopQuery;
  finally
    QueryStateMultiReadSync.EndWrite;
  end;
end;

function TMySQLRS.GetQueryExecuting: Boolean;
begin
  QueryStateMultiReadSync.BeginRead;
  try
    Result:=FQueryExecuting;
  finally
    QueryStateMultiReadSync.EndRead;
  end;
end;

procedure TMySQLRS.SetQueryExecuting(QueryExecuting: Boolean);
begin
  QueryStateMultiReadSync.BeginWrite;
  try
    FQueryExecuting:=QueryExecuting;
  finally
    QueryStateMultiReadSync.EndWrite;
  end;
end;

function TMySQLRS.GetConnectedDetailRSCount: Integer;

begin
  Result:=FConnectedResultsets.Count;
end;

function TMySQLRS.GetConnectedDetailRS(I: Integer): TMySQLRS;

begin
  if (I<FConnectedResultsets.Count) then
    Result := FConnectedResultsets[I]
  else
    Result := nil;
end;

function TMySQLRS.GetConnectedControlsCount: Integer;

begin
  Result:=FConnectedControls.Count;
end;

function TMySQLRS.GetConnectedControls(I: Integer): IMySQLRSControlInterface;

begin
  if (I<FConnectedControls.Count) then
    Result := IMySQLRSControlInterface(FConnectedControls[I])
  else
    Result := nil;
end;

// -----------------------------------------------------------------------------

constructor TExecuteQueryThread.Create(MySQLRS: TMySQLRS);
begin
  inherited Create(True);

  self.MySQLRS:=MySQLRS;

  current_row_count:=0;
  previous_row_count:=0;
  result_set:=nil;
  ExceptionMsg:='';

  // When the user is in the middle of a transaction, don't create a new connection.
  FNeedCleanup := not MySQLRS.MySQLConn.InTransaction;
  if FNeedCleanup then
  begin
    if (MySQLRS.MySQLConn.EmbeddedConnection) then
      ThreadPMySQL := myx_mysql_embedded_init()
    else
      ThreadPMySQL := myx_mysql_init();

    if(ThreadPMySQL=nil)then
      raise EMyxError.Create(_('Error while allocating memory for MySQL Struct in Query Execute Thread.'));


    if(myx_connect_to_instance(
      MySQLRS.MySQLConn.UserConnection.get_record_pointer,
      ThreadPMySQL)<>0)then
      raise EMyxError.Create(_('Query Execute Thread cannot connect to MySQL'));

    if(MySQLRS.MySQLConn.DefaultSchema<>'')and
      (MySQLRS.MySQLConn.DefaultSchema<>MySQLRS.MySQLConn.UserConnection.schema)then
        myx_use_schema(ThreadPMySQL, MySQLRS.MySQLConn.DefaultSchema);
  end
  else
    ThreadPMySQL:=MySQLRS.MySQLConn.MySQL;
end;

destructor TExecuteQueryThread.Destroy;

begin
  if FNeedCleanUp and Assigned(MySQLRS) and Assigned(MySQLRS.MySQLConn) then
    myx_mysql_close(ThreadPMySQL);

  inherited Destroy;
end;

procedure TExecuteQueryThread.Execute;

var
  ErrorCode: MYX_LIB_ERROR;
  Parameters: TMYX_STRINGLIST;
  MySQLConn: TMySQLConn;
  InTransaction: Boolean;
  DoRemoveLastRS: Boolean;

begin
  DoRemoveLastRS := False;

  MySQLConn := MySQLRS.MySQLConn;
  try
    try
      InTransaction := MySQLConn.InTransaction;

      //If the user is in a transaction, wait till connection is free
      if (InTransaction) then
        MySQLConn.Lock.Acquire;
      try
        Query:=MySQLRS.SQL;

        Parameters:=TMYX_STRINGLIST.create;
        try
          Parameters.strings.Text := '';
          //Global Params
          if (MySQLRS.GlobalParams<>nil) then
            Parameters.strings.Text := Parameters.strings.Text+
              MySQLRS.GlobalParams.Text;
          //Local Params
          if (MySQLRS.LocalParams<>nil) then
            Parameters.strings.Text := Parameters.strings.Text+
              MySQLRS.LocalParams.Text;
          //Add dynamic parameters from parent
          if (MySQLRS.FParentRS<>nil) and
            (MySQLRS.FParentRS.DynamicParams<>nil) then
            Parameters.strings.Text:=Parameters.strings.Text+#13#10+
              MySQLRS.FParentRS.DynamicParams.Text;

          result_set := myx_query_execute(ThreadPMySQL,
            Query, Ord(ApplicationDM.Options.EnforceEditableQueries),
            Parameters.get_record_pointer,
            @ErrorCode, Addr(self), @progress_row_fetch,
            @resultset_realloc_before,
            @resultset_realloc_after);

          //Handle multible resultsets
          while (1=1) do
          begin
            //If this was executed using a cloned MySQL Connection,
            //reassign the original one
            if (Not(MySQLRS.MySQLConn.InTransaction)) and
              (MySQLRS.ResultSet<>nil) then
              MySQLRS.ResultSet.mysql:=MySQLRS.MySQLConn.MySQL;

            //Display error/summary
            if (ErrorCode=MYX_NO_ERROR) then
              Synchronize(QuerySuccess)
            else
              if ErrorCode=MYX_STOP_EXECUTION then
                Synchronize(QueryStopped)
              else
                Synchronize(QueryError);

            //Check if there is a resultset left
            if Not( (result_set<>nil) and (result_set.has_more=1) ) then
              break;

            //Get new MySQLRS
            if Assigned(MySQLRS.CreateNextRSForMultibleRSQuery) then
            begin
              Synchronize(CreateNextRSForMultibleRSQuery);

              if MySQLRS<>nil then
              begin
                //Reset thread values
                current_row_count := 0;
                previous_row_count := 0;
                result_set:=nil;
                ExceptionMsg:='';

                //Fetch next resultset (use _ function so nil can be passed as query)
                result_set := _myx_query_execute(ThreadPMySQL,
                  nil, 0,
                  nil,
                  @ErrorCode, Addr(self), @progress_row_fetch,
                  @resultset_realloc_before,
                  @resultset_realloc_after);

                //Handle last result in a multi resultset query
                if (ErrorCode=MYX_SQL_ERROR) and
                  (myx_mysql_errno(ThreadPMySQL)=0) then
                begin
                  DoRemoveLastRS := True;
                  //Synchronize(RemoveRSForMultibleRSQuery);
                  break;
                end
                else
                  Synchronize(ShowRSForMultibleRSQuery);
              end
              else
                break;
            end
            else
              break;
          end;
        finally
          Parameters.Free;
        end;
      finally
        if(InTransaction)then
          MySQLConn.Lock.Release;
      end;
    except
      Synchronize(QueryError);
      raise;
    end;
  finally
    Synchronize(QueryExecuted);

    if (DoRemoveLastRS) then
      Synchronize(RemoveRSForMultibleRSQuery);
  end;
end;

procedure TExecuteQueryThread.CreateNextRSForMultibleRSQuery;
begin
  if Assigned(MySQLRS.CreateNextRSForMultibleRSQuery) then
    MySQLRS := MySQLRS.CreateNextRSForMultibleRSQuery(MySQLRS)
  else
    MySQLRS := nil;
end;

procedure TExecuteQueryThread.RemoveRSForMultibleRSQuery;
begin
  if Assigned(MySQLRS.RemoveRSForMultibleRSQuery) then
    MySQLRS.RemoveRSForMultibleRSQuery(MySQLRS);
end;

procedure TExecuteQueryThread.ShowRSForMultibleRSQuery;
begin
  if Assigned(MySQLRS.ShowRSForMultibleRSQuery) then
    MySQLRS.ShowRSForMultibleRSQuery(MySQLRS);
end;

function progress_row_fetch(current_row_count: Longint; previous_row_count: Longint; result_set: PMYX_RESULTSET; user_data: Pointer):Integer;
var PSender: ^TExecuteQueryThread;
begin
  PSender:=user_data;
  try
    PSender.current_row_count:=current_row_count;
    PSender.previous_row_count:=previous_row_count;
    PSender.result_set:=result_set;

    PSender.Synchronize(PSender.BuildGrid);

    Result:=Ord(PSender.MySQLRS.StopQuery);
  except
    on x: Exception do
    begin
      PSender.ExceptionMsg:=x.Message;
      PSender.Synchronize(PSender.QueryError);
      Result:=Ord(True);
    end;
  end;
end;

procedure resultset_realloc_before(user_data: Pointer);
var PSender: ^TExecuteQueryThread;
begin
  PSender:=user_data;
  try
    PSender.MySQLRS.WorkWithResultset.Acquire;
  except
    on x: Exception do
    begin
      PSender.MySQLRS.WorkWithResultset.Release;

      PSender.ExceptionMsg:=x.Message;
      PSender.Synchronize(PSender.QueryError);
    end;
  end;
end;

procedure resultset_realloc_after(user_data: Pointer);
var PSender: ^TExecuteQueryThread;
begin
  PSender:=user_data;
  try
    PSender.MySQLRS.WorkWithResultset.Release;
  except
    on x: Exception do
    begin
      PSender.ExceptionMsg:=x.Message;
      PSender.Synchronize(PSender.QueryError);
    end;
  end;
end;

procedure TExecuteQueryThread.BuildGrid;
var j: integer;
  RSGrid: TMySQLRSGrid;
begin
  if(MySQLRS=nil)then
    Exit;

  if(previous_row_count=0)then
    MySQLRS.ResultSet:=result_set;

  for j:=0 to MySQLRS.FConnectedControls.Count-1 do
  begin
    if(TObject(IMySQLRSControlInterface(MySQLRS.FConnectedControls[j]).GetControl).InheritsFrom(TMySQLRSGrid))then
    begin
      RSGrid:=TMySQLRSGrid(IMySQLRSControlInterface(MySQLRS.FConnectedControls[j]).GetControl);

      //If this is the first block of rows, add columns
      if(previous_row_count=0)then
      begin
        RSGrid.MySQLRS.ResultSet:=result_set;

        RSGrid.BuildColumns;
        RSGrid.FocusedColumn:=1;
      end;

      //Add rows
      RSGrid.BuildRows(previous_row_count, current_row_count-1,
        (previous_row_count=0));

      MySQLRS.CheckAttributes;

      MySQLRS.StatusCaption:=
        Format(_('%d rows fetched so far.'), [current_row_count]);
    end;
  end;
end;

// -----------------------------------------------------------------------------

procedure TExecuteQueryThread.QueryExecuted;

begin
  if(Assigned(MySQLRS)) then
    if(Assigned(MySQLRS.OnQueryExecuted))then
      MySQLRS.OnQueryExecuted(MySQLRS);
end;

// -----------------------------------------------------------------------------

procedure TExecuteQueryThread.FetchMySQLMessages;

var
  PMsgs: PMYX_MYSQL_ERROR_MSGS;
  PMsg: PMYX_MYSQL_ERROR_MSG;
  I: Integer;

begin
  PMsgs := myx_mysql_error_msgs_fetch(ThreadPMySQL);

  if (PMsgs <> nil) then
  begin
    for I := 0 to PMsgs.errors_num - 1 do
    begin
      PMsg := PMYX_MYSQL_ERROR_MSG(Integer(PMsgs.errors) +
        sizeof(MYX_MYSQL_ERROR_MSG) * I);

      MySQLRS.AddRSMessage(UTF8Decode(PMsg.text), PMsg.level,
        PMsg.error);
    end;

    myx_mysql_error_msgs_free(PMsgs);
  end;
end;

// -----------------------------------------------------------------------------

procedure TExecuteQueryThread.QuerySuccess;

var
  j: integer;
  RSGrid: TMySQLRSGrid;
  S: WideString;
  AffectedRows: Int64;

begin
  if(MySQLRS.ResultSet<>nil)then
    for j:=0 to MySQLRS.FConnectedControls.Count-1 do
    begin
      if(TObject(IMySQLRSControlInterface(MySQLRS.FConnectedControls[j]).GetControl).InheritsFrom(TMySQLRSGrid))then
      begin
        RSGrid:=TMySQLRSGrid(IMySQLRSControlInterface(MySQLRS.FConnectedControls[j]).GetControl);

        RSGrid.BuildRowForAppending;
      end;
    end;

  MySQLRS.CheckAttributes;

  //Check if this command has commited the open Trx (if there is any)
  MySQLRS.MySQLConn.CheckConnectionStatusChange(Query);

  if current_row_count <> 1 then
    S := 's'
  else
    S := '';

  if (MySQLRS.ResultSet<>nil)then
    MySQLRS.SetStatusCaption(
      Format(_('%d row%s fetched in %.4fs (%.4fs)'),
        [current_row_count, S,
        MySQLRS.ResultSet.fetch_time,
        MySQLRS.ResultSet.query_time]))
  else
  begin
    AffectedRows := myx_mysql_affected_rows(ThreadPMySQL);

    if (AffectedRows > 0) then
    begin
      if (AffectedRows = 1) then
        MySQLRS.SetStatusCaption(_('1 row affected by the last command, no resultset returned.'))
      else
        MySQLRS.SetStatusCaption(Format(_('%s rows affected by the last command, no resultset returned.'),
          [IntToStr(AffectedRows)]))
    end
    else
      MySQLRS.SetStatusCaption(_('Query returned no resultset.'));
  end;

  MySQLRS.StopQuery:=False;
  MySQLRS.QueryExecuting:=False;

  //Check for errors and warnings
  FetchMySQLMessages;

  if(Assigned(MySQLRS.OnQuerySuccess))then
    MySQLRS.OnQuerySuccess(MySQLRS);
end;

procedure TExecuteQueryThread.QueryStopped;
begin
  MySQLRS.CheckAttributes;

  //Check if this command has commited the open Trx (if there is any)
  MySQLRS.MySQLConn.CheckConnectionStatusChange(Query);

  if MySQLRS.ResultSet<>nil then
    MySQLRS.SetStatusCaption(
      Format(_('Query aborted. %d rows fetched so far in %.4fs (%.4fs)'),
        [current_row_count,
        MySQLRS.ResultSet.fetch_time,
        MySQLRS.ResultSet.query_time]))
  else
    MySQLRS.SetStatusCaption(
      _('Query aborted.'));

  MySQLRS.StopQuery:=False;
  MySQLRS.QueryExecuting:=False;

  //Check for errors and warnings
  FetchMySQLMessages;

  if(Assigned(MySQLRS.OnQueryStopped))then
    MySQLRS.OnQueryStopped(MySQLRS);
end;

procedure TExecuteQueryThread.QueryError;
begin
  MySQLRS.FreeResultSet;

  //Check if there actually was a MySQL Error
  if myx_mysql_errno(ThreadPMySQL)>0 then
  begin
    //Check if ExceptionMsg is set
    if(ExceptionMsg<>'')then
      MySQLRS.SetStatusCaption(ExceptionMsg)
    else
      MySQLRS.SetStatusCaption(
        _('The query could not be executed.'));

    {MySQLRS.AddRSMessage(myx_mysql_error(ThreadPMySQL), MYX_QEL_ERROR,
      myx_mysql_errno(ThreadPMySQL));}
  end
  else
    MySQLRS.SetStatusCaption(_('No resultset returned.'));

  MySQLRS.StopQuery:=False;
  MySQLRS.QueryExecuting:=False;

  //Check for errors and warnings
  FetchMySQLMessages;

  if(Assigned(MySQLRS.OnQueryError))then
    MySQLRS.OnQueryError(MySQLRS);
end;

//----------------- TRSError -------------------------------------------------------------------------------------------

constructor TRSError.Create(Msg: WideString; MsgType: MYX_QUERY_ERROR_LEVEL; MsgNr: Integer);

begin
  Self.Msg := Msg;
  Self.MsgType := MsgType;
  Self.MsgNr := MsgNr;
end;

//----------------- TCommandList ---------------------------------------------------------------------------------------

constructor TCommandList.Create;

begin
  FCommands := TList.Create;
  FCurrent := -1;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TCommandList.Destroy;

begin
  Clear;
  FCommands.Free;

  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.GetCurrent: PCommandEntry;

// Returns the current command entry or nil if there is none.

begin
  Result := nil;
  if (FCurrent >= 0) and (FCurrent < FCommands.Count) then
    Result := FCommands[FCurrent];
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.GetCurrentCaret: TPoint;

// Returns the caret position of the current entry. If there is no entry then (0, 0) is returned.

begin
  if FCurrent = -1 then
    Add('', Point(0, 0));

  Result := Current.Caret;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.GetCurrentSQL: WideString;

// Returns the command text of the current entry. If there is no entry then an empty string is returned.

begin
  if FCurrent = -1 then
    Add('', Point(0, 0));

  Result := Current.SQL;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCommandList.SetCurrentCaret(const Value: TPoint);

begin
  if FCurrent = -1 then
    Add('', Value)
  else
    Current.Caret := Value;

  // Keep a flag telling us that we have set the current command.
  // By calling PrepareCurrent this flag is used to determine if we should duplicate the current entry
  // to allow for future recovery when it is changed.
  FPushPending := True;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCommandList.SetCurrentSQL(const Value: WideString);

begin
  if FCurrent = -1 then
    Add(Value, Point(0, 0))
  else
    Current.SQL := Value;

  // Keep a flag telling us that we have set the current command.
  // By calling PrepareCurrent this flag is used to determine if we should duplicate the current entry
  // to allow for future recovery when it is changed.
  FPushPending := True;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCommandList.Add(const SQL: WideString; Caret: TPoint);

var
  Entry: PCommandEntry;
  I: Integer;
  
begin
  New(Entry);
  Entry.SQL := SQL;
  Entry.Caret := Caret;

  // If the current entry is not at the end of the list then delete everything after it
  // making it so the end.
  for I := FCommands.Count - 1 downto FCurrent + 1 do
    Dispose(PCommandEntry(FCommands[I]));

  if FCurrent > -1 then
  begin
    FCommands.Count := FCurrent + 1;
    FCommands.Capacity := FCurrent + 1;
  end;
  FCurrent := FCommands.Add(Entry);
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.Back: PCommandEntry;

// Returns the previous entry in the list relative to the current position or nil
// we reached the start.

begin
  Result := nil;
  if FCurrent > 0 then
  begin
    Dec(FCurrent);
    Result := FCommands[FCurrent];
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCommandList.Clear;

var
  I: Integer;

begin
  for I := 0 to FCommands.Count - 1 do
    Dispose(PCommandEntry(FCommands[I]));
  FCurrent := -1;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.HasBack: Boolean;

// Determines if there is still a previous entry in the command list (relative to the current position).

begin
  Result := FCurrent > 0;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.HasNext: Boolean;

// Determines if there is still a next entry in the command list (relative to the current position).

begin
  Result := FCurrent < FCommands.Count - 1;
end;

//----------------------------------------------------------------------------------------------------------------------

function TCommandList.Next: PCommandEntry;

// Returns the next entry in the list relative to the current position or nil if we reach the end.

begin
  Result := nil;
  if FCurrent < FCommands.Count - 1 then
  begin
    Inc(FCurrent);
    Result := FCommands[FCurrent];
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCommandList.PrepareCurrent;

// Used to tell the list that the current command is about to be changed. If the current command was set just
// before that call then a flag was set to indicate that we must duplicate the current entry to keep its content
// also after the comming changes.

var
  Entry: PCommandEntry;

begin
  if FPushPending then
  begin
    FPushPending := False;
    Entry := Current;
    if Assigned(Entry) then
      Add(Entry.SQL, Entry.Caret);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

end.
