program qbr;

{$mode delphi}

{$R res/mysqlcommon.res}
{$R res/mysqlqb.res}

uses
  Interfaces, Forms,
  TntClasses, TntStdCtrls, TntCheckLst, TntExtCtrls, TntForms, TntComCtrls, TntButtons, TntGrids,
  TntMenus, TntActnList, TntDialogs, TntRegistry, TntSysUtils, TntSystem, TntClipBrd,
  PNGImage, PNGTools, ResSelfTest;

begin
  Application.Initialize;
  if (ParamCount = 2) and (ParamStr(1) = '--selftest-resources') then
  begin
    RunResourceSelfTest(ParamStr(2));
    Exit;
  end;
end.
