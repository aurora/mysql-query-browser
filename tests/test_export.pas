{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_export;

{ Result set export (myx_exporter.c through myx_export_resultset, as the File > Export menu calls it): every format
  with the values that broke exporters before (NULL vs empty string, quotes, separators, newlines, markup characters,
  non-ASCII text, bytes that are not UTF-8, decimals, column names with special characters, very long values), plus
  a timing check for a large result (ADR-0049); the CSV/TSV settings and the TSV format (ADR-0050). Needs a server (QBR_TEST_*).

  QBR_EXPORT_ROWS sets the row count of the timing test (default 200000); the times are written to stdout. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpcunit, testregistry, fpjson, jsonparser, DOM, XMLRead,
  myx_types, myx_util_public_interface, myx_public_interface, test_support;

type
  TExportTest = class(TTestCase)
  private
    FMy: PMYSQL;
    FDir: string;
    function Query(const SQL: AnsiString): PMYX_RESULTSET;
    function ExportRs(const Format: AnsiString; Rs: PMYX_RESULTSET; const Ext: string = 'out'): AnsiString;
    function ExportSQL(const Format: AnsiString; const SQL: AnsiString): AnsiString;
    // Options: name/value pairs set with myx_set_table_exporter_option, as SaveResultsetAs does (ADR-0050)
    function ExportWith(const Format, SQL: AnsiString; const Options: array of AnsiString): AnsiString;
    function Tricky(const Format: AnsiString): AnsiString;
    procedure AssertXml(const What, Text: AnsiString);
    procedure AssertNotContains(const What, Needle, Hay: AnsiString);
    procedure AssertContains(const What, Needle, Hay: AnsiString);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFormatsListed;
    procedure TestCsv;
    procedure TestCsvSeparator;
    procedure TestHtml;
    procedure TestXml;
    procedure TestExcel;
    procedure TestPlist;
    procedure TestJson;
    procedure TestJsonLines;
    procedure TestJsonEmptyResult;
    procedure TestLongValue;
    procedure TestWideRow;
    procedure TestLargeExportTime;
    procedure TestCsvDefaultOptionsUnchanged;
    procedure TestCsvSemicolonWhenNeeded;
    procedure TestCsvQuoteAll;
    procedure TestCsvTabNoHeader;
    procedure TestCsvLineBreaksAndBom;
    procedure TestTsv;
    procedure TestTsvOptions;
    procedure TestTsvLoadDataRoundTrip;
  end;

implementation

const
  // column 7 is named  we"ird <col>&  (backticks in the CREATE)
  WeirdName = 'we"ird <col>&';
  TrickySQL = 'SELECT * FROM qbr_export.t ORDER BY id';
  NL = #10;

procedure TExportTest.SetUp;
begin
  FMy := ConnectTestServer;
  FDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'qbr_export_' + IntToStr(GetProcessID);
  ForceDirectories(FDir);
  ExecSQL(FMy, 'DROP DATABASE IF EXISTS qbr_export');
  ExecSQL(FMy, 'CREATE DATABASE qbr_export CHARACTER SET utf8');
  ExecSQL(FMy, 'CREATE TABLE qbr_export.t (id INT PRIMARY KEY, s VARCHAR(100), n DECIMAL(10,2), f DOUBLE, ' +
    'd DATETIME, b VARBINARY(20), `we"ird <col>&` VARCHAR(10))');
  // row 1: separator, quote, newline, semicolon; bytes that are no UTF-8 (C3 28 FF)
  // row 2: empty string next to NULLs, markup characters
  // row 3: non-ASCII text, tab and a control character, negative decimal, huge double
  // row 4: NULL string, zeros, empty binary
  ExecSQL(FMy, 'INSERT INTO qbr_export.t VALUES ' +
    '(1, CONCAT(''a,b"c'', CHAR(10), ''d;e''), 1.50, 2.5, ''2026-01-02 03:04:05'', X''C328FF'', ''x''), ' +
    '(2, '''', NULL, NULL, NULL, NULL, ''<&>''), ' +
    '(3, CONCAT(''Gr' + #$C3#$BC#$C3#$9F + 'e ' + #$E6#$97#$A5#$E6#$9C#$AC + ''', CHAR(9), ''t'', CHAR(1), ''c''), ' +
    '-0.25, 1e300, ''1999-12-31 23:59:59'', X''4142'', ''''), ' +
    '(4, NULL, 0, 0, NULL, X'''', NULL)');
  // digits for generated row counts (no sequence tables on MySQL, no CTEs on 5.7)
  ExecSQL(FMy, 'CREATE TABLE qbr_export.dig (n INT)');
  ExecSQL(FMy, 'INSERT INTO qbr_export.dig VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)');
end;

procedure TExportTest.TearDown;
var
  Info: TSearchRec;
begin
  if FindFirst(FDir + PathDelim + '*', faAnyFile, Info) = 0 then
  begin
    repeat
      if (Info.Attr and faDirectory) = 0 then
        DeleteFile(FDir + PathDelim + Info.Name);
    until FindNext(Info) <> 0;
    FindClose(Info);
  end;
  RemoveDir(FDir);
  if FMy <> nil then
  begin
    ExecSQL(FMy, 'DROP DATABASE IF EXISTS qbr_export');
    DisconnectTestServer(FMy);
  end;
end;

function TExportTest.Query(const SQL: AnsiString): PMYX_RESULTSET;
var
  Err: MYX_LIB_ERROR;
begin
  Err := MYX_NO_ERROR;
  Result := _myx_query_execute(FMy, PAnsiChar(SQL), 0, nil, @Err, nil, nil, nil, nil);
  AssertNotNull(SQL + ' -> error ' + IntToStr(Ord(Err)) + ': ' + myx_mysql_error(FMy), Result);
end;

function ReadFileText(const FileName: string): AnsiString;
var
  F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then
      F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

function TExportTest.ExportRs(const Format: AnsiString; Rs: PMYX_RESULTSET; const Ext: string): AnsiString;
var
  Info: PMYX_TABLE_EXPORTER_INFO;
  FileName: AnsiString;
begin
  Info := _myx_get_table_exporter_info(PAnsiChar(Format));
  AssertNotNull('exporter ' + Format, Info);
  FileName := FDir + PathDelim + 'export.' + Ext;
  try
    AssertEquals('export ' + Format, 0, _myx_export_resultset(FMy, Info, PAnsiChar(FileName),
      'Query $QUERY$, $DATE$', Rs, ''));
  finally
    myx_free_table_exporter_info(Info);
  end;
  Result := ReadFileText(FileName);
end;

function TExportTest.ExportSQL(const Format: AnsiString; const SQL: AnsiString): AnsiString;
var
  Rs: PMYX_RESULTSET;
begin
  Rs := Query(SQL);
  try
    Result := ExportRs(Format, Rs);
  finally
    myx_query_free_resultset(Rs);
  end;
end;

function TExportTest.ExportWith(const Format, SQL: AnsiString; const Options: array of AnsiString): AnsiString;
var
  Rs: PMYX_RESULTSET;
  Info: PMYX_TABLE_EXPORTER_INFO;
  FileName: AnsiString;
  I: Integer;
begin
  Rs := Query(SQL);
  Info := _myx_get_table_exporter_info(PAnsiChar(Format));
  AssertNotNull('exporter ' + Format, Info);
  FileName := FDir + PathDelim + 'opts.out';
  try
    I := 0;
    while I < High(Options) do
    begin
      _myx_set_table_exporter_option(Info, PAnsiChar(Options[I]), PAnsiChar(Options[I + 1]));
      Inc(I, 2);
    end;
    AssertEquals('export ' + Format, 0, _myx_export_resultset(FMy, Info, PAnsiChar(FileName), '', Rs, ''));
  finally
    myx_free_table_exporter_info(Info);
    myx_query_free_resultset(Rs);
  end;
  Result := ReadFileText(FileName);
end;

function TExportTest.Tricky(const Format: AnsiString): AnsiString;
begin
  Result := ExportSQL(Format, TrickySQL);
end;

procedure TExportTest.AssertXml(const What, Text: AnsiString);
var
  Doc: TXMLDocument;
  S: TStringStream;
begin
  Doc := nil;
  S := TStringStream.Create(Text);
  try
    try
      ReadXMLFile(Doc, S);
    except
      on E: Exception do
        Fail(What + ' is not well-formed XML: ' + E.Message);
    end;
  finally
    Doc.Free;
    S.Free;
  end;
end;

procedure TExportTest.AssertContains(const What, Needle, Hay: AnsiString);
begin
  AssertTrue(What + ': expected ' + Needle, Pos(Needle, Hay) > 0);
end;

procedure TExportTest.AssertNotContains(const What, Needle, Hay: AnsiString);
begin
  AssertTrue(What + ': unexpected ' + Needle, Pos(Needle, Hay) = 0);
end;

procedure TExportTest.TestFormatsListed;
var
  P: PMYX_STRINGLIST;
  Names: string;
  I: Integer;
begin
  P := myx_get_table_export_formats;
  try
    Names := '';
    for I := 0 to Integer(P^.strings_num) - 1 do
      Names := Names + PPAnsiChar(PtrUInt(P^.strings) + PtrUInt(I * SizeOf(PAnsiChar)))^ + ',';
  finally
    myx_free_lib_stringlist(P);
  end;
  // the original's formats keep their order (the menu shows them in this order); the new ones follow
  AssertEquals('CSV,HTML,XML,Excel,PLIST,JSON,JSON Lines,TSV,', Names);
end;

procedure TExportTest.TestCsv;
var
  S: AnsiString;
begin
  S := Tricky('CSV');
  AssertContains('header', '"id","s","n","f","d","b","we""ird <col>&"' + NL, S);
  AssertContains('quotes, separator, newline', NL + '1,"a,b""c' + NL + 'd;e",1.50,2.5,"2026-01-02 03:04:05",', S);
  // NULL is empty and unquoted, the empty string is quoted
  AssertContains('NULL vs empty', NL + '2,"",,,,,"<&>"' + NL, S);
  AssertContains('non-ASCII', NL + '3,"Gr' + #$C3#$BC#$C3#$9F + 'e ' + #$E6#$97#$A5#$E6#$9C#$AC + #9't'#1'c",-0.25,', S);
  AssertContains('NULL string, empty binary', NL + '4,,0.00,0,,"",' + NL, S);
end;

procedure TExportTest.TestCsvSeparator;
var
  Rs: PMYX_RESULTSET;
  Info: PMYX_TABLE_EXPORTER_INFO;
  FileName, S: AnsiString;
begin
  Rs := Query(TrickySQL);
  Info := _myx_get_table_exporter_info('CSV');
  try
    AssertEquals(0, _myx_set_table_exporter_option(Info, 'Separator', ';'));
    FileName := FDir + PathDelim + 'sep.csv';
    AssertEquals(0, _myx_export_resultset(FMy, Info, PAnsiChar(FileName), '', Rs, ''));
  finally
    myx_free_table_exporter_info(Info);
    myx_query_free_resultset(Rs);
  end;
  S := ReadFileText(FileName);
  AssertContains('header', '"id";"s";"n"', S);
  AssertContains('separator inside quotes', NL + '1;"a,b""c' + NL + 'd;e";1.50;2.5;', S);
end;

procedure TExportTest.TestHtml;
var
  S: AnsiString;
begin
  S := ExportSQL('HTML', 'SELECT * FROM qbr_export.t WHERE id < 3 ORDER BY id');
  AssertNotContains('empty string', '(null)', S);
  AssertContains('column name escaped', '<th>we&quot;ird &lt;col&gt;&amp;</th>', S);
  AssertContains('value escaped', '<td>&lt;&amp;&gt;</td>', S);
  AssertContains('empty cell', '<td>2</td><td></td><td></td>', S);
  AssertContains('quote', 'a,b&quot;c', S);
  AssertContains('title escaped', '<title>Query SELECT * FROM qbr_export.t WHERE id &lt; 3 ORDER BY id, ', S);
end;

procedure TExportTest.TestXml;
var
  S: AnsiString;
begin
  S := Tricky('XML');
  AssertXml('XML', S);
  AssertContains('name escaped', '<field name="we&quot;ird &lt;col&gt;&amp;">x</field>', S);
  AssertContains('empty string', '<field name="s"></field>', S);
  AssertContains('NULL', '<field name="n" xsi:nil="true" />', S);
  AssertContains('value escaped', '>&lt;&amp;&gt;</field>', S);
  AssertContains('decimal', '<field name="n">1.50</field>', S);
end;

procedure TExportTest.TestExcel;
var
  S: AnsiString;
begin
  S := Tricky('Excel');
  AssertXml('Excel XML', S);
  AssertContains('header escaped', '<Data ss:Type="String">we&quot;ird &lt;col&gt;&amp;</Data>', S);
  AssertContains('integer', '<Data ss:Type="Number">1</Data>', S);
  AssertContains('decimal', '<Data ss:Type="Number">1.50</Data>', S);
  AssertContains('empty string', '<Data ss:Type="String"></Data>', S);
  AssertContains('NULL', '<Data ss:Type="String"/>', S);
end;

procedure TExportTest.TestPlist;
var
  S: AnsiString;
begin
  S := Tricky('PLIST');
  AssertXml('PLIST', S);
  AssertNotContains('empty string', '(null)', S);
  AssertContains('key escaped', '<key>we&quot;ird &lt;col&gt;&amp;</key>', S);
  AssertContains('empty string', '<string></string>', S);
  AssertContains('integer', '<integer>1</integer>', S);
  AssertContains('decimal', '<real>1.50</real>', S);
end;

procedure TExportTest.TestJson;
var
  S: AnsiString;
  J: TJSONData;
  A: TJSONArray;
  O: TJSONObject;
begin
  S := Tricky('JSON');
  J := GetJSON(S);
  try
    AssertTrue('array', J.JSONType = jtArray);
    A := TJSONArray(J);
    AssertEquals('rows', 4, A.Count);
    O := A.Objects[0];
    AssertTrue('id is a number', O.Elements['id'].JSONType = jtNumber);
    AssertEquals(1, O.Integers['id']);
    AssertEquals('a,b"c' + NL + 'd;e', O.Strings['s']);
    AssertTrue('decimal is a number', O.Elements['n'].JSONType = jtNumber);
    AssertEquals(1.5, O.Floats['n'], 0);
    AssertEquals('2026-01-02 03:04:05', O.Strings['d']);
    AssertTrue('bytes as a string', O.Elements['b'].JSONType = jtString);
    AssertEquals('x', O.Strings[WeirdName]);
    O := A.Objects[1];
    AssertEquals('empty string', '', O.Strings['s']);
    AssertTrue('NULL decimal', O.Elements['n'].JSONType = jtNull);
    AssertTrue('NULL date', O.Elements['d'].JSONType = jtNull);
    AssertEquals('<&>', O.Strings[WeirdName]);
    O := A.Objects[2];
    AssertEquals(UTF8Decode('Gr' + #$C3#$BC#$C3#$9F + 'e ' + #$E6#$97#$A5#$E6#$9C#$AC + #9't'#1'c'),
      UTF8Decode(O.Strings['s']));
    AssertEquals(-0.25, O.Floats['n'], 0);
    AssertEquals(1e300, O.Floats['f'], 1e285);
    AssertEquals('AB', O.Strings['b']);
    O := A.Objects[3];
    AssertTrue('NULL string', O.Elements['s'].JSONType = jtNull);
    AssertEquals('empty binary', '', O.Strings['b']);
    AssertTrue('NULL', O.Elements[WeirdName].JSONType = jtNull);
  finally
    J.Free;
  end;
  // control characters are escaped, non-ASCII stays UTF-8
  AssertContains('tab and U+0001', '\tt\u0001c', S);
  AssertContains('UTF-8 kept', 'Gr' + #$C3#$BC#$C3#$9F + 'e', S);
end;

procedure TExportTest.TestJsonLines;
var
  S: AnsiString;
  Lines: TStringList;
  I: Integer;
  J: TJSONData;
begin
  S := Tricky('JSON Lines');
  AssertEquals('ends with a newline', #10, S[Length(S)]);
  Lines := TStringList.Create;
  try
    Lines.LineBreak := #10;
    Lines.Text := S;
    AssertEquals('one line per row', 4, Lines.Count);
    for I := 0 to Lines.Count - 1 do
    begin
      J := GetJSON(Lines[I]);
      try
        AssertTrue('object', J.JSONType = jtObject);
        AssertEquals('id', I + 1, TJSONObject(J).Integers['id']);
      finally
        J.Free;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TExportTest.TestJsonEmptyResult;
var
  J: TJSONData;
begin
  J := GetJSON(ExportSQL('JSON', 'SELECT * FROM qbr_export.t WHERE id < 0'));
  try
    AssertTrue('array', J.JSONType = jtArray);
    AssertEquals(0, J.Count);
  finally
    J.Free;
  end;
  AssertEquals('JSON Lines: nothing', '', ExportSQL('JSON Lines', 'SELECT * FROM qbr_export.t WHERE id < 0'));
end;

// a value of 2 MB that is all markup: escaping must not grow its buffer in small steps (quadratic)
procedure TExportTest.TestLongValue;
const
  Formats: array[0..7] of AnsiString = ('CSV', 'HTML', 'XML', 'Excel', 'PLIST', 'JSON', 'JSON Lines', 'TSV');
var
  Rs: PMYX_RESULTSET;
  F: AnsiString;
  T: TDateTime;
  S: AnsiString;
begin
  Rs := Query('SELECT REPEAT(''<&"'', 700000) AS v');
  try
    for F in Formats do
    begin
      if _myx_get_table_exporter(PAnsiChar(F)) = nil then
        Continue;
      T := Now;
      S := ExportRs(F, Rs);
      WriteLn(Format('  long value %-10s %6d ms, %d bytes', [F, MilliSecondsBetween(Now, T), Length(S)]));
      AssertTrue(F + ' took too long', MilliSecondsBetween(Now, T) < 10000);
      AssertTrue(F + ' output too short', Length(S) > 2100000);
    end;
  finally
    myx_query_free_resultset(Rs);
  end;
end;

procedure TExportTest.TestWideRow;
var
  SQL, S: AnsiString;
  I: Integer;
  J: TJSONData;
begin
  SQL := 'SELECT 0 AS c0';
  for I := 1 to 299 do
    SQL := SQL + Format(', REPEAT(''v'', 1000) AS c%d', [I]);
  S := ExportSQL('CSV', SQL);
  AssertEquals('CSV row length', 1 + 299 * 1003 + 1, Length(S) - Pos(NL, S));
  AssertXml('XML', ExportSQL('XML', SQL));
  J := GetJSON(ExportSQL('JSON', SQL));
  try
    AssertEquals('JSON columns', 300, TJSONArray(J).Objects[0].Count);
  finally
    J.Free;
  end;
end;

procedure TExportTest.TestLargeExportTime;
const
  Formats: array[0..7] of AnsiString = ('CSV', 'HTML', 'XML', 'Excel', 'PLIST', 'JSON', 'JSON Lines', 'TSV');
var
  Rows: Integer;
  Rs: PMYX_RESULTSET;
  F, SQL: AnsiString;
  T: TDateTime;
  Ms: Int64;
  Info: PMYX_TABLE_EXPORTER_INFO;
  FileName: AnsiString;
begin
  Rows := StrToIntDef(GetEnvironmentVariable('QBR_EXPORT_ROWS'), 200000);
  // MD5() and SHA1() are gone from MySQL 9.7 ("FUNCTION <db>.MD5 does not exist"); 32 hex digits like MD5
  SQL := 'SELECT seq, LEFT(SHA2(seq, 256), 32) AS h, NOW() AS t FROM (SELECT d0.n + 10*d1.n + 100*d2.n + 1000*d3.n + ' +
    '10000*d4.n + 100000*d5.n + 1000000*d6.n AS seq FROM qbr_export.dig d0, qbr_export.dig d1, qbr_export.dig d2, ' +
    'qbr_export.dig d3, qbr_export.dig d4, qbr_export.dig d5, qbr_export.dig d6 LIMIT ' + IntToStr(Rows) + ') x';
  T := Now;
  Rs := Query(SQL);
  WriteLn(Format('  %d rows fetched in %d ms', [Rows, MilliSecondsBetween(Now, T)]));
  try
    AssertEquals('rows', Rows, Integer(Rs^.rows_num));
    for F in Formats do
    begin
      if _myx_get_table_exporter(PAnsiChar(F)) = nil then
        Continue;
      Info := _myx_get_table_exporter_info(PAnsiChar(F));
      FileName := FDir + PathDelim + 'large.out';
      T := Now;
      try
        AssertEquals(0, _myx_export_resultset(FMy, Info, PAnsiChar(FileName), 'Query', Rs, ''));
      finally
        myx_free_table_exporter_info(Info);
      end;
      Ms := MilliSecondsBetween(Now, T);
      WriteLn(Format('  export %-10s %6d ms, %d bytes', [F, Ms, Length(ReadFileText(FileName))]));
      DeleteFile(FileName);
      // a few seconds per million rows on the CI runner; quadratic work would take minutes
      AssertTrue(F + ' export took ' + IntToStr(Ms) + ' ms', Ms < 15000 + Int64(Rows) div 20);
    end;
  finally
    myx_query_free_resultset(Rs);
  end;
end;

// the values the program passes when the options were never changed give the original's output, byte for byte
procedure TExportTest.TestCsvDefaultOptionsUnchanged;
begin
  AssertEquals(Tricky('CSV'), ExportWith('CSV', TrickySQL,
    ['Separator', ',', 'Quoting', 'text', 'Line Breaks', 'system', 'Header', '1', 'BOM', '0']));
  AssertEquals('TSV', ExportSQL('TSV', TrickySQL), ExportWith('TSV', TrickySQL,
    ['Separator', ',', 'Quoting', 'text', 'Line Breaks', 'system', 'Header', '1', 'BOM', '0']));
end;

procedure TExportTest.TestCsvSemicolonWhenNeeded;
var
  S: AnsiString;
begin
  S := ExportWith('CSV', TrickySQL, ['Separator', ';', 'Quoting', 'needed']);
  AssertContains('header', 'id;s;n;f;d;b;"we""ird <col>&"' + NL, S);
  AssertContains('quote and newline need quotes', NL + '1;"a,b""c' + NL + 'd;e";1.50;2.5;2026-01-02 03:04:05;', S);
  // the empty string keeps its quotes so that it differs from NULL
  AssertContains('NULL vs empty', NL + '2;"";;;;;<&>' + NL, S);
  AssertContains('NULL string', NL + '4;;0.00;0;;"";' + NL, S);
end;

procedure TExportTest.TestCsvQuoteAll;
var
  S: AnsiString;
begin
  S := ExportWith('CSV', TrickySQL, ['Quoting', 'all']);
  AssertContains('header', '"id","s","n"', S);
  AssertContains('numbers too', NL + '"1","a,b""c' + NL + 'd;e","1.50","2.5",', S);
  AssertContains('NULL stays empty', NL + '"2","",,,,,"<&>"' + NL, S);
end;

procedure TExportTest.TestCsvTabNoHeader;
var
  S: AnsiString;
begin
  S := ExportWith('CSV', TrickySQL, ['Separator', #9, 'Header', '0']);
  AssertEquals('no header', '1'#9'"a,b', Copy(S, 1, 6));
  AssertContains('tab', NL + '2'#9'""'#9#9#9#9#9'"<&>"' + NL, S);
end;

procedure TExportTest.TestCsvLineBreaksAndBom;
var
  S: AnsiString;
begin
  S := ExportWith('CSV', TrickySQL, ['Line Breaks', 'crlf', 'BOM', '1']);
  AssertEquals('BOM', #$EF#$BB#$BF'"id"', Copy(S, 1, 7));
  AssertContains('CR LF after the header', '"we""ird <col>&"'#13#10'1,', S);
  AssertContains('CR LF after a row', '"<&>"'#13#10'3,', S);
  // the line break inside a value is the value's own
  AssertContains('value unchanged', '"a,b""c'#10'd;e"', S);
  S := ExportWith('CSV', TrickySQL, ['Line Breaks', 'lf']);
  AssertEquals('LF only', 0, Pos(#13, S));
  AssertEquals('no BOM by default', '"id"', Copy(S, 1, 4));
end;

procedure TExportTest.TestTsv;
var
  S: AnsiString;
begin
  S := ExportSQL('TSV', TrickySQL);
  AssertContains('header, names unquoted', 'id'#9's'#9'n'#9'f'#9'd'#9'b'#9'we"ird <col>&' + NL, S);
  AssertContains('newline escaped, no quotes', NL + '1'#9'a,b"c\nd;e'#9'1.50'#9'2.5'#9'2026-01-02 03:04:05'#9, S);
  AssertContains('NULL as \N, empty string empty', NL + '2'#9#9'\N'#9'\N'#9'\N'#9'\N'#9'<&>' + NL, S);
  AssertContains('tab escaped', 'Gr' + #$C3#$BC#$C3#$9F + 'e ' + #$E6#$97#$A5#$E6#$9C#$AC + '\tt'#1'c'#9'-0.25', S);
  AssertContains('NULL string, empty binary', NL + '4'#9'\N'#9'0.00'#9'0'#9'\N'#9#9'\N' + NL, S);
  AssertEquals('backslash', 'v' + NL + 'a\\b\r' + NL, ExportSQL('TSV', 'SELECT CONCAT(''a\\b'', CHAR(13)) AS v'));
end;

procedure TExportTest.TestTsvOptions;
var
  S: AnsiString;
begin
  S := ExportWith('TSV', TrickySQL, ['Header', '0', 'Line Breaks', 'crlf', 'BOM', '1']);
  AssertEquals('BOM, no header', #$EF#$BB#$BF'1'#9, Copy(S, 1, 5));
  AssertContains('CR LF', '<&>'#13#10'3'#9, S);
end;

// the format of LOAD DATA's defaults: a TSV file goes back into a table unchanged, NULLs included
procedure TExportTest.TestTsvLoadDataRoundTrip;
const
  Cols = 'id, s, n, f, d, `we"ird <col>&`';
var
  Data, FileName, OldValue: AnsiString;
  F: TFileStream;
  Rs: PMYX_RESULTSET;
begin
  Data := ExportWith('TSV', 'SELECT ' + Cols + ' FROM qbr_export.t ORDER BY id', ['Header', '0', 'Line Breaks', 'lf']);
  FileName := FDir + PathDelim + 'roundtrip.tsv';
  F := TFileStream.Create(FileName, fmCreate);
  try
    F.WriteBuffer(Data[1], Length(Data));
  finally
    F.Free;
  end;
  Rs := Query('SELECT @@GLOBAL.local_infile');
  SetString(OldValue, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
  myx_query_free_resultset(Rs);
  ExecSQL(FMy, 'SET GLOBAL local_infile = 1');
  try
    ExecSQL(FMy, 'CREATE TABLE qbr_export.t2 LIKE qbr_export.t');
    ExecSQL(FMy, 'LOAD DATA LOCAL INFILE ''' + StringReplace(FileName, '\', '\\', [rfReplaceAll]) +
      ''' INTO TABLE qbr_export.t2 CHARACTER SET utf8mb4 (' + Cols + ')');
  finally
    ExecSQL(FMy, 'SET GLOBAL local_infile = ' + OldValue);
  end;
  AssertEquals(ExportSQL('CSV', 'SELECT ' + Cols + ' FROM qbr_export.t ORDER BY id'),
    ExportSQL('CSV', 'SELECT ' + Cols + ' FROM qbr_export.t2 ORDER BY id'));
end;

initialization
  RegisterTest(TExportTest);
end.
