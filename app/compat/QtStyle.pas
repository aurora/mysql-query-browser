{ SPDX-License-Identifier: GPL-2.0-or-later }
unit QtStyle;

{$mode delphi}

// Port: under the Qt6 widgetset the program draws with Qt's Fusion style and its standard (light) palette, whatever
// the desktop sets (ADR-0045). The forms are fixed pixel layouts made for one look; a bundled Qt cannot load the
// desktop's style plugins anyway, and a dark palette would not match the program's own colours (result grid,
// editor, gradients). Other widgetsets are left alone.
//
// ScopeTabSizeStyleSheets: the Qt6 widgetset implements TabHeight/TabWidth of a page control with the style sheet
// "QTabBar::tab { height: Hpx; width: Wpx; }" on the page control, with width 0 when only the height is set. Style
// sheets apply to all child widgets, so every page control on its pages got tabs of width 0, i.e. no tabs (options
// dialog, Connections page: "Connection Parameters"/"Advanced Parameters" could not be reached). The rule is limited
// to the control's own tab bar here, and a size of 0 is left out.

interface

uses
  Classes, Forms;

procedure UseFusionStyle;
procedure ScopeTabSizeStyleSheets(Form: TCustomForm);

implementation

uses
  SysUtils, ComCtrls{$IFDEF LCLQT6}, qt6, qtwidgets{$ENDIF};

procedure UseFusionStyle;

{$IFDEF LCLQT6}
var
  Name: WideString;
  Style: QStyleH;
  Palette: QPaletteH;
{$ENDIF}

begin
  {$IFDEF LCLQT6}
  Name := 'Fusion';
  Style := QStyleFactory_create(@Name);
  if Style = nil then
    Exit;
  QApplication_setStyle(Style);   // the application takes ownership
  Palette := QPalette_Create;
  try
    QStyle_standardPalette(Style, Palette);
    QApplication_setPalette(Palette);
  finally
    QPalette_Destroy(Palette);
  end;
  {$ENDIF}
end;

procedure ScopeTabSizeStyleSheets(Form: TCustomForm);

{$IFDEF LCLQT6}
var
  I: Integer;
  PC: TPageControl;
  Rule, Sheet, ObjName: WideString;
{$ENDIF}

begin
  {$IFDEF LCLQT6}
  for I := 0 to Form.ComponentCount - 1 do
    if Form.Components[I] is TPageControl then
    begin
      PC := TPageControl(Form.Components[I]);
      if (PC.TabHeight <= 0) and (PC.TabWidth <= 0) then
        Continue;
      PC.HandleNeeded;
      Rule := '';
      if PC.TabHeight > 0 then
        Rule := Rule + WideFormat('height: %dpx; ', [PC.TabHeight]);
      if PC.TabWidth > 0 then
        Rule := Rule + WideFormat('width: %dpx; ', [PC.TabWidth]);
      ObjName := WideString('qbr_' + Form.Name + '_' + PC.Name);
      QObject_setObjectName(TQtTabWidget(PC.Handle).Widget, @ObjName);
      Sheet := 'QTabWidget#' + ObjName + ' > QTabBar::tab { ' + Rule + '}';
      TQtTabWidget(PC.Handle).StyleSheet := Sheet;
    end;
  {$ENDIF}
end;

end.
