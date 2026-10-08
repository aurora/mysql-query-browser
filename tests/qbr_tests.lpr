program qbr_tests;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, test_connect, test_catalog, test_schema_info, test_classes;

var
  App: TTestRunner;

begin
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Title := 'Query Browser Revival tests';
  App.Run;
  App.Free;
end.
