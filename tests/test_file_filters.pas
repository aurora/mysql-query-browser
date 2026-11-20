{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The file dialog filters under Qt6 (app/compat/FileFilters.pas, QBFileDialogs.pas): Qt appends the patterns to the
  descriptions itself, so the "(*.ext)" the original writes into them is dropped. }
unit test_file_filters;

{$mode objfpc}{$H+}

interface

uses
  fpcunit, testregistry, FileFilters;

type
  TFileFilterTest = class(TTestCase)
  published
    procedure TestPatternsInDescriptionsDropped;
    procedure TestDescriptionsWithoutPatternsKept;
  end;

implementation

procedure TFileFilterTest.TestPatternsInDescriptionsDropped;
begin
  AssertEquals('JSON Lines File|*.jsonl|Any File|*.*',
    FilterWithoutPatternsInDescriptions('JSON Lines File (*.jsonl)|*.jsonl|Any File (*.*)|*.*'));
  AssertEquals('SQL Script Files|*.sql;*.txt',
    FilterWithoutPatternsInDescriptions('SQL Script Files (*.sql, *.txt)|*.sql;*.txt'));
  AssertEquals('one filter', 'CSV File|*.csv', FilterWithoutPatternsInDescriptions('CSV File (*.csv) |*.csv'));
end;

procedure TFileFilterTest.TestDescriptionsWithoutPatternsKept;
begin
  AssertEquals('Private keys|id_*;*.pem;*.ppk|All files|*',
    FilterWithoutPatternsInDescriptions('Private keys|id_*;*.pem;*.ppk|All files|*'));
  // parentheses in the middle of a description stay; patterns are never touched
  AssertEquals('Excel (2003 XML) File|*.xml',
    FilterWithoutPatternsInDescriptions('Excel (2003 XML) File|*.xml'));
  AssertEquals('', FilterWithoutPatternsInDescriptions(''));
end;

initialization
  RegisterTest(TFileFilterTest);

end.
