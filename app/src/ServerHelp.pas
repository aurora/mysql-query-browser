{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Help reference taken from the connected server (prototype, see ADR-0013 and the follow-up ADR).

  MySQL and MariaDB servers ship their own reference in the tables mysql.help_category and
  mysql.help_topic, matching the server's version. This unit reads them and builds the same
  group/entry structure that the original program loaded from mysqlqb_statements.xml and
  mysqlqb_functions.xml, so the "Syntax" and "Functions" trees and their double click keep working.
  An entry's id is the topic id; the page for it is made here (plain text: hard wrapped, with syntax and
  example blocks; the view lives in EmbeddedWB.pas). Nothing of this text is
  shipped with the program. }
unit ServerHelp;

{$mode delphi}

interface

uses
  Classes, SysUtils, Contnrs, MySQLConnection, myx_types, myx_util_public_interface, myx_public_interface, myx_qb_public_interface;

type
  TServerHelpCategory = class
  public
    Id, ParentId: Integer;
    Name: String;
  end;

  TServerHelpTopic = class
  public
    Id, CategoryId: Integer;
    Name, Description, Example, URL: String;
  end;

  TServerHelp = class
  private
    FCategories: TObjectList;
    FTopics: TObjectList;
    FServerVersion: String;
    FTopicCount: Integer;
    function FindCategory(const Name: String): TServerHelpCategory;
    function IsInCategory(CategoryId, AncestorId: Integer): Boolean;
    function GroupFor(Category: TServerHelpCategory): TMYX_SQL_FUNCTIONGROUP;
    function ReadTable(Conn: TMySQLConn; const SQL: String; Columns: Integer; Rows: TObjectList;
      Make: Integer): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { reads the help tables; False if the server has none (or no rights, or no content) }
    function Load(Conn: TMySQLConn): Boolean;
    { the two trees of the original: statements by category, and the functions }
    procedure BuildIndexes(out SyntaxIndex, FunctionsIndex: TMYX_SQL_FUNCTIONINDEX);
    function FindTopic(const Id: String): TServerHelpTopic;
    function FindTopicByName(const Name: String): Integer;
    property ServerVersion: String read FServerVersion;
    { where the vendor's documentation of this server is online }
    function DocsURL: String;
    property TopicCount: Integer read FTopicCount;
  end;

implementation


constructor TServerHelp.Create;
begin
  inherited Create;
  FCategories := TObjectList.Create(True);
  FTopics := TObjectList.Create(True);
end;

destructor TServerHelp.Destroy;
begin
  FTopics.Free;
  FCategories.Free;
  inherited Destroy;
end;

function TServerHelp.ReadTable(Conn: TMySQLConn; const SQL: String; Columns: Integer; Rows: TObjectList;
  Make: Integer): Boolean;
var
  RS: PMYX_RESULTSET;
  ErrorCode: MYX_LIB_ERROR;
  R, C: Integer;
  Row: PMYX_RS_ROW;
  Field: PMYX_RS_FIELD;
  Values: array of String;
  Cat: TServerHelpCategory;
  Topic: TServerHelpTopic;
begin
  Result := False;
  ErrorCode := MYX_NO_ERROR;
  RS := myx_query_execute(Conn.MySQL, SQL, 0, nil, @ErrorCode, nil, nil, nil, nil);
  if (RS = nil) or (ErrorCode <> MYX_NO_ERROR) then
  begin
    if RS <> nil then
      myx_query_free_resultset(RS);
    Exit;
  end;
  try
    if RS.columns_num < Cardinal(Columns) then
      Exit;
    SetLength(Values, Columns);
    for R := 0 to Integer(RS.rows_num) - 1 do
    begin
      Row := PMYX_RS_ROW(PByte(RS.rows) + R * SizeOf(MYX_RS_ROW));
      for C := 0 to Columns - 1 do
      begin
        Field := PMYX_RS_FIELD(PByte(Row.fields) + C * SizeOf(MYX_RS_FIELD));
        if Field.value = nil then
          Values[C] := ''
        else
          SetString(Values[C], Field.value, Field.value_length);
      end;
      if Make = 2 then
        FServerVersion := Values[0]
      else
      if Make = 0 then
      begin
        Cat := TServerHelpCategory.Create;
        Cat.Id := StrToIntDef(Values[0], 0);
        Cat.ParentId := StrToIntDef(Values[1], 0);
        Cat.Name := Values[2];
        Rows.Add(Cat);
      end
      else
      begin
        Topic := TServerHelpTopic.Create;
        Topic.Id := StrToIntDef(Values[0], 0);
        Topic.CategoryId := StrToIntDef(Values[1], 0);
        Topic.Name := Values[2];
        Topic.Description := Values[3];
        Topic.Example := Values[4];
        Topic.URL := Values[5];
        Rows.Add(Topic);
      end;
    end;
    Result := True;
  finally
    myx_query_free_resultset(RS);
  end;
end;

function TServerHelp.DocsURL: String;
begin
  if Pos('mariadb', LowerCase(FServerVersion)) > 0 then
    Result := 'https://mariadb.com/kb/en/documentation/'
  else
    Result := 'https://dev.mysql.com/doc/';
end;

function TServerHelp.Load(Conn: TMySQLConn): Boolean;
begin
  FServerVersion := '';
  FCategories.Clear;
  FTopics.Clear;
  FTopicCount := 0;
  ReadTable(Conn, 'SELECT VERSION()', 1, nil, 2);
  Result := ReadTable(Conn, 'SELECT help_category_id, parent_category_id, name FROM mysql.help_category', 3,
    FCategories, 0) and
    ReadTable(Conn, 'SELECT help_topic_id, help_category_id, name, description, example, url FROM mysql.help_topic',
      6, FTopics, 1);
  FTopicCount := FTopics.Count;
  Result := Result and (FTopicCount > 0);
end;

function TServerHelp.FindCategory(const Name: String): TServerHelpCategory;
var
  I: Integer;
begin
  for I := 0 to FCategories.Count - 1 do
    if SameText(TServerHelpCategory(FCategories[I]).Name, Name) then
      Exit(TServerHelpCategory(FCategories[I]));
  Result := nil;
end;

function TServerHelp.IsInCategory(CategoryId, AncestorId: Integer): Boolean;

// True if the category is the ancestor or lies below it (MariaDB nests e.g. the geographic features and operators).

var
  I, Depth: Integer;
  Cat: TServerHelpCategory;
begin
  Result := False;
  Depth := 0;
  while Depth < 10 do
  begin
    if CategoryId = AncestorId then
      Exit(True);
    Cat := nil;
    for I := 0 to FCategories.Count - 1 do
      if TServerHelpCategory(FCategories[I]).Id = CategoryId then
      begin
        Cat := TServerHelpCategory(FCategories[I]);
        Break;
      end;
    if (Cat = nil) or (Cat.ParentId = CategoryId) then
      Exit;
    CategoryId := Cat.ParentId;
    Inc(Depth);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TServerHelp.GroupFor(Category: TServerHelpCategory): TMYX_SQL_FUNCTIONGROUP;
var
  I: Integer;
  Names: TStringList;
  Topic: TServerHelpTopic;
begin
  Result := nil;
  Names := TStringList.Create;
  try
    Names.Sorted := True;
    Names.Duplicates := dupAccept;
    for I := 0 to FTopics.Count - 1 do
    begin
      Topic := TServerHelpTopic(FTopics[I]);
      if IsInCategory(Topic.CategoryId, Category.Id) then
        Names.AddObject(Topic.Name, Topic);
    end;
    if Names.Count = 0 then
      Exit;
    Result := TMYX_SQL_FUNCTIONGROUP.Create(Category.Name);
    for I := 0 to Names.Count - 1 do
    begin
      Topic := TServerHelpTopic(Names.Objects[I]);
      Result.functions.Add(TMYX_SQL_FUNCTION.Create(Topic.Name, IntToStr(Topic.Id)));
    end;
  finally
    Names.Free;
  end;
end;

procedure TServerHelp.BuildIndexes(out SyntaxIndex, FunctionsIndex: TMYX_SQL_FUNCTIONINDEX);
var
  I: Integer;
  Cat, FuncRoot, Root: TServerHelpCategory;
  RootId: Integer;
  Group: TMYX_SQL_FUNCTIONGROUP;
begin
  SyntaxIndex := TMYX_SQL_FUNCTIONINDEX.Create;
  FunctionsIndex := TMYX_SQL_FUNCTIONINDEX.Create;
  FuncRoot := FindCategory('Functions');
  // the root is "Contents": id 0 on MySQL, id 1 on MariaDB
  Root := FindCategory('Contents');
  if Root <> nil then
    RootId := Root.Id
  else
    RootId := 0;

  // statements: the top level categories (children of "Contents") other than the functions container;
  // functions: the children of "Functions"
  for I := 0 to FCategories.Count - 1 do
  begin
    Cat := TServerHelpCategory(FCategories[I]);
    if (Cat = Root) or ((Root = nil) and (Cat.Id = 0)) then
      Continue;
    if (FuncRoot <> nil) and (Cat.ParentId = FuncRoot.Id) then
    begin
      Group := GroupFor(Cat);
      if Group <> nil then
        FunctionsIndex.groups.Add(Group);
    end
    else
      if (Cat.ParentId = RootId) and (Cat <> FuncRoot) and not SameText(Cat.Name, 'Help Metadata') then
      begin
        Group := GroupFor(Cat);
        if Group <> nil then
          SyntaxIndex.groups.Add(Group);
      end;
  end;
end;

function TServerHelp.FindTopic(const Id: String): TServerHelpTopic;
var
  I, N: Integer;
begin
  N := StrToIntDef(Id, -1);
  for I := 0 to FTopics.Count - 1 do
    if TServerHelpTopic(FTopics[I]).Id = N then
      Exit(TServerHelpTopic(FTopics[I]));
  Result := nil;
end;

function TServerHelp.FindTopicByName(const Name: String): Integer;
var
  I: Integer;
begin
  for I := 0 to FTopics.Count - 1 do
    if SameText(TServerHelpTopic(FTopics[I]).Name, Name) then
      Exit(TServerHelpTopic(FTopics[I]).Id);
  Result := -1;
end;


end.
