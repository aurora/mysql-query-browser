{ SPDX-License-Identifier: GPL-2.0-or-later }
program qbr_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF} // threads on Unix (test_cancel); must come first
  {$IFDEF UNIX}cwstring,{$ENDIF} // UTF-8 aware WideString manager; LCL programs get it through LazUTF8
  Classes, consoletestrunner, test_connect, test_catalog, test_schema_info, test_classes, test_gettext,
  test_cancel;

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
