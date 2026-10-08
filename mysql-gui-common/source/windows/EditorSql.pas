unit EditorSql;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, TntExtCtrls, UniCodeEditor, UCEHighlighter,
  UCESQLHighlighter, StdCtrls, TntStdCtrls, MySQLConnection,
  AuxFuncs, TntForms, Options, myx_public_interface, AuxApplicationFuncs,
  gnugettext;

type
  TEditorSqlForm = class(TTntForm)
    BottomPnl: TTntPanel;
    ExecuteSQLBtn: TTntButton;
    CancelBtn: TTntButton;
    UCESQLHighlighter: TUCESQLHighlighter;
    SqlUCE: TUniCodeEdit;
    SepBevel: TTntBevel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ExecuteSQLBtnClick(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
  protected
    function GetSql: WideString;
    procedure SetSql(Sql: WideString);
    function GetPreSql: WideString;
    procedure SetPreSql(Sql: WideString);
    function GetSqlSchema: WideString;
    procedure SetSqlSchema(Sch: WideString);

  private
    { Private declarations }
    FMySQLConn: TMySQLConn;
    FRefreshSchemaObjects: TNotifyEvent;
    FPreSql: string;
    FSqlSchema: string;
    OrgObjectName: string;  // currently used oly for views

  public
    { Public declarations }
    property SqlSchema: WideString read GetSqlSchema write SetSqlSchema;
    property PreSql: WideString read GetPreSql write SetPreSql;
    property Sql: WideString read GetSql write SetSql;
    property MySQLConn: TMySQLConn read FMySQLConn write FMySQLConn;
    property RefreshSchemaObjects: TNotifyEvent read FRefreshSchemaObjects write FRefreshSchemaObjects;
    procedure Show;
  end;

implementation

{$R *.dfm}

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.FormCreate(Sender: TObject);

begin
  InitForm(self);

  FMySQLConn := nil;
  FRefreshSchemaObjects := nil;
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.FormDestroy(Sender: TObject);

begin
  //
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);

begin
  //
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.Show;

begin
  if(MYXCommonOptions.EditorKeepRoutineEditorOnTop)then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;

  inherited;
end;

// -----------------------------------------------------------------------------

function TEditorSqlForm.GetSql: WideString;
begin
  Result := SqlUCE.Content.Text;
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.SetSql(Sql: WideString);

begin
  SqlUCE.Content.Text := Sql;
  OrgObjectName := myx_dbm_get_view_name_from_query(Sql);

end;

// -----------------------------------------------------------------------------

function TEditorSqlForm.GetPreSql: WideString;
begin
  Result := FPreSql;
end;

function TEditorSqlForm.GetSqlSchema: WideString;
begin
  Result := FSqlSchema;
end;

procedure TEditorSqlForm.SetSqlSchema(Sch: WideString);
begin
  FSqlSchema:=Sch;
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.SetPreSql(Sql: WideString);
begin
  FPreSql := Sql;
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.ExecuteSQLBtnClick(Sender: TObject);

var NewObjectName: string;

begin
  if (FMySQLConn <> nil) then
  begin
    if(SqlSchema <> '') then
    begin
      MySQLConn.DefaultSchema:=SqlSchema;
    end;
{
    if(OrgObjectName <> '') and (PreSql <> '') then
    begin
      NewObjectName := myx_dbm_get_view_name_from_query(Sql);
      if(NewObjectName <> OrgObjectName)then
      begin
        if(ShowOptionalModalDialog(_('View name has changed'),
          _('Would you like to keep the original view object? '),
          myx_mtWarning, _('Yes')+#13#10+_('No'),
          True,
          '') = 2)then
          FMySQLConn.ExecuteDirect(PreSql);
      end;
    end;
}
    if (PreSql <> '') then
    begin
      NewObjectName := myx_dbm_get_view_name_from_query(Sql);
      if (OrgObjectName <> '') and (NewObjectName <> OrgObjectName) then
      begin
        if(ShowOptionalModalDialog(_('View name has changed'),
          _('Would you like to keep the original view object? '),
          myx_mtWarning, _('Yes')+#13#10+_('No'),
          True,
          '') = 2)then
        begin
          FMySQLConn.ExecuteDirect(PreSql);
          PreSQL := '';
        end
      end
      else
      begin
        FMySQLConn.ExecuteDirect(PreSql);
        PreSQL := '';
      end;
    end;

    if (FMySQLConn.ExecuteDirect(Sql) = True) then
    begin
      if (Assigned(FRefreshSchemaObjects)) then
        FRefreshSchemaObjects(self);
      Close;
    end;
  end;
end;

// -----------------------------------------------------------------------------

procedure TEditorSqlForm.CancelBtnClick(Sender: TObject);

begin
  Close;
end;

// -----------------------------------------------------------------------------

end.
