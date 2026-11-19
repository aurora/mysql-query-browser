{ SPDX-License-Identifier: GPL-2.0-or-later }
unit QtStyle;

{$mode delphi}

// Port: under the Qt6 widgetset the program draws with Qt's Fusion style and its standard (light) palette, whatever
// the desktop sets (ADR-0045). The forms are fixed pixel layouts made for one look; a bundled Qt cannot load the
// desktop's style plugins anyway, and a dark palette would not match the program's own colours (result grid,
// editor, gradients). Other widgetsets are left alone.
//
// The lists of combo boxes show their rows without any spacing in Fusion (as tight as the original's on Windows); next
// to the drop-down menus' 25 pixel items they looked squeezed. UseFusionStyle gives them a few pixels with an
// application style sheet that applies to those lists only.
//
// ScopeTabSizeStyleSheets: the Qt6 widgetset implements TabHeight/TabWidth of a page control with the style sheet
// "QTabBar::tab { height: Hpx; width: Wpx; }" on the page control, with width 0 when only the height is set. Style
// sheets apply to all child widgets, so every page control on its pages got tabs of width 0, i.e. no tabs (options
// dialog, Connections page: "Connection Parameters"/"Advanced Parameters" could not be reached). The rule is limited
// to the control's own tab bar here, and a size of 0 is left out.
//
// AdjustMenuBar: the Qt6 widgetset makes the menu bar a child widget of the main window, so it inherits the
// form's font (the small Tahoma of the layouts), and Fusion adds only a few pixels to the text height of menu bar
// entries: the bar was 16 pixels high above drop-down menus with 25 pixel items and looked squeezed. Menu bars in the
// original (Windows) and under GTK2 use the system's menu font, independent of the form, and are about 20 pixels
// high. The bar gets Qt's font for menu bars explicitly (ending the inheritance from the form) and more padding for
// its entries (about 22 pixels).

interface

uses
  Classes, Forms;

procedure UseFusionStyle;
procedure ScopeTabSizeStyleSheets(Form: TCustomForm);
procedure AdjustMenuBar(Form: TCustomForm);

implementation

uses
  SysUtils, ComCtrls{$IFDEF LCLQT6}, qt6, qtwidgets{$ENDIF};

procedure UseFusionStyle;

{$IFDEF LCLQT6}
const
  // the lists of combo boxes: some spacing around the rows, and the selection, which Fusion no longer draws once a
  // rule applies to the rows
  ComboListSheet = 'QComboBox QAbstractItemView::item { padding: 3px 2px; } ' +
    'QComboBox QAbstractItemView::item:selected { background: palette(highlight); color: palette(highlighted-text); }';

var
  Name, Sheet: WideString;
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
  Sheet := ComboListSheet;
  QApplication_setStyleSheet(QApplicationH(QCoreApplication_instance), @Sheet);
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

procedure AdjustMenuBar(Form: TCustomForm);

{$IFDEF LCLQT6}
const
  // more spacing than Fusion gives menu bar entries, and the selection, which Fusion no longer draws once a rule applies
  MenuBarSheet = 'QMenuBar::item { padding: 4px 8px; background: transparent; } ' +
    'QMenuBar::item:selected, QMenuBar::item:pressed { background: palette(highlight); color: palette(highlighted-text); }';

var
  Bar: TQtMenuBar;
  Font: QFontH;
{$ENDIF}

begin
  {$IFDEF LCLQT6}
  if (Form = nil) or (Form.Menu = nil) then
    Exit;
  Form.HandleNeeded;
  Bar := TQtMainWindow(Form.Handle).MenuBar;
  if Bar = nil then
    Exit;
  Font := QFont_Create;
  try
    QApplication_font(Font, PAnsiChar('QMenuBar'));
    QWidget_setFont(Bar.Widget, Font);
  finally
    QFont_Destroy(Font);
  end;
  Bar.StyleSheet := MenuBarSheet;
  {$ENDIF}
end;

end.
