{ SPDX-License-Identifier: GPL-2.0-or-later }
program qbr_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, test_connect, test_catalog, test_schema_info, test_classes, test_gettext;

var
  App: TTestRunner;

begin
  // like a Lazarus application: String is UTF-8, so String <-> WideString conversions keep non-ASCII text
  SetMultiByteConversionCodePage(CP_UTF8);
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Title := 'Query Browser Revival tests';
  App.Run;
  App.Free;
end.
