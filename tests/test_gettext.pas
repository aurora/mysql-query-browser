unit test_gettext;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, gnugettext;

type
  TGettextTest = class(TTestCase)
  private
    FDir: String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestTranslatesFromPoFile;
    procedure TestFallsBackToEnglish;
    procedure TestRegionalFallback;
    procedure TestFuzzyAndMultiline;
  end;

implementation

procedure WritePo(const Dir, Lang, Text: String);
var
  L: TStringList;
begin
  ForceDirectories(Dir + PathDelim + Lang + PathDelim + 'LC_MESSAGES');
  L := TStringList.Create;
  try
    L.Text := Text;
    L.SaveToFile(Dir + PathDelim + Lang + PathDelim + 'LC_MESSAGES' + PathDelim + 'unit-test.po');
  finally
    L.Free;
  end;
end;

procedure TGettextTest.SetUp;
begin
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'qbr-gettext-test';
  WritePo(FDir, 'de',
    'msgid ""' + LineEnding + 'msgstr ""' + LineEnding + '"Content-Type: text/plain; charset=UTF-8\n"' + LineEnding + LineEnding +
    'msgid "Cancel"' + LineEnding + 'msgstr "Abbrechen"' + LineEnding + LineEnding +
    '#, fuzzy' + LineEnding + 'msgid "Maybe"' + LineEnding + 'msgstr "Vielleicht"' + LineEnding + LineEnding +
    'msgid "Line one\nLine two"' + LineEnding + 'msgstr ""' + LineEnding + '"Zeile eins\n"' + LineEnding + '"Zeile zwei"' + LineEnding + LineEnding +
    'msgid "Quote \"x\""' + LineEnding + 'msgstr "Anf' + #$C3#$BC + 'hrung \"x\""' + LineEnding);
  WritePo(FDir, 'pt', 'msgid "Close"' + LineEnding + 'msgstr "Fechar"' + LineEnding);
  bindtextdomain('unit-test', FDir);
end;

procedure TGettextTest.TearDown;
var
  Lang: String;
begin
  for Lang in ['de', 'pt'] do
  begin
    DeleteFile(FDir + PathDelim + Lang + PathDelim + 'LC_MESSAGES' + PathDelim + 'unit-test.po');
    RemoveDir(FDir + PathDelim + Lang + PathDelim + 'LC_MESSAGES');
    RemoveDir(FDir + PathDelim + Lang);
  end;
  RemoveDir(FDir);
end;

procedure TGettextTest.TestTranslatesFromPoFile;
begin
  UseLanguage('de');
  AssertEquals('Abbrechen', _('Cancel'));
end;

procedure TGettextTest.TestFallsBackToEnglish;
begin
  UseLanguage('de');
  AssertEquals('Not translated', _('Not translated'));
  UseLanguage('xx');
  AssertEquals('Cancel', _('Cancel'));
end;

procedure TGettextTest.TestRegionalFallback;
begin
  UseLanguage('pt_BR');
  AssertEquals('Fechar', _('Close'));
end;

procedure TGettextTest.TestFuzzyAndMultiline;
begin
  UseLanguage('de');
  AssertEquals('fuzzy entries are ignored', 'Maybe', _('Maybe'));
  AssertEquals('Zeile eins' + #10 + 'Zeile zwei', _('Line one' + #10 + 'Line two'));
  AssertEquals('Anf' + #$C3#$BC + 'hrung "x"', _('Quote "x"'));
end;

initialization
  RegisterTest(TGettextTest);

end.
