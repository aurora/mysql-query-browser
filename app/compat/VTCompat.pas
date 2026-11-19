{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The original code uses VirtualTreeView 4.x: `uses VirtualTrees`, class TVirtualStringTree.
  Lazarus ships a port (unit laz.VirtualTrees, class TLazVirtualStringTree). Ported units use
  `laz.VirtualTrees, VTCompat`; this unit supplies the original class name, also for loading
  .lfm files. Event and property signatures of the newer VirtualTreeView differ in places and
  are fixed in the ported units. }
unit VTCompat;

{$mode delphi}

interface

uses
  Classes, Types, LMessages, LCLType, laz.VirtualTrees{$IFDEF LCLQT6}, Graphics, Math{$ENDIF};

type
  { Two GTK2 workarounds; Windows keeps the original behaviour.

    Scrolling: on GTK2 the LCL's ScrollWindowEx moves a GDK region and has aborted the program with
    "gdkregion-generic.c: miUnionNonO: assertion failed (y1 < y2)" while scrolling the schemata tree (core dump,
    2026-11-12). The tree repaints completely instead of scrolling the pixels, as VirtualTreeView itself does for
    GTK1 ("scrollwindow implementation under gtk is broken").

    Scroll bars: WMSize updates the scroll bars, and showing or hiding one changes the client size again. Windows
    sends that WM_SIZE at once, inside ShowScrollBar, where the tree ignores it (tsSizing). GTK2 delivers it later
    from the main loop, so the tree reacts to it, and it can do so forever: the horizontal range depends on the nodes
    that are visible (GetMaxRightExtend), and these change with the client height. The schemata tree did that while
    scrolling or expanding nodes (main loop busy in WMSize/UpdateScrollBars/ShowScrollBar, 2026-11-13). While handling
    a size change the tree may now only show scroll bars, not hide them, so a chain of size changes ends after at
    most two steps; hiding happens again with the next change of content or position.

    Grid and tree lines (Qt6 only): the tree draws them with a monochrome pattern brush whose colours come from the
    canvas (Font.Color for the line, Brush.Color between the dots), as on Windows. The Qt6 widgetset takes the
    pattern as a black and white image instead, so every grid line came out black. The two line routines draw the
    same pattern with the canvas colours here (solid and dotted; a custom style keeps the original code). }
  TVirtualStringTree = class(TLazVirtualStringTree)
  {$IFNDEF MSWINDOWS}
  private
    FInSize: Boolean;
    FBarShown: array[SB_HORZ..SB_VERT] of Boolean;
    procedure WMSize(var Message: TLMSize); message LM_SIZE;
  protected
    function DoSetOffsetXY(Value: TPoint; Options: TScrollUpdateOptions; ClipRect: PRect = nil): Boolean; override;
    procedure DoShowScrollBar(Bar: Integer; Show: Boolean); override;
  {$ENDIF}
  {$IFDEF LCLQT6}
  protected
    procedure DrawDottedHLine(const PaintInfo: TVTPaintInfo; Left, Right, Top: Integer); override;
    procedure DrawDottedVLine(const PaintInfo: TVTPaintInfo; Top, Bottom, Left: Integer;
      UseSelectedBkColor: Boolean = False); override;
  {$ENDIF}
  end;

implementation

{$IFNDEF MSWINDOWS}
function TVirtualStringTree.DoSetOffsetXY(Value: TPoint; Options: TScrollUpdateOptions; ClipRect: PRect): Boolean;

begin
  Result := inherited DoSetOffsetXY(Value, Options - [suoScrollClientArea], ClipRect);
  if Result and (suoScrollClientArea in Options) and HandleAllocated then
    Invalidate;
end;

procedure TVirtualStringTree.WMSize(var Message: TLMSize);

begin
  FInSize := True;
  try
    inherited;
  finally
    FInSize := False;
  end;
end;

procedure TVirtualStringTree.DoShowScrollBar(Bar: Integer; Show: Boolean);

begin
  if Bar = SB_BOTH then
  begin
    DoShowScrollBar(SB_HORZ, Show);
    DoShowScrollBar(SB_VERT, Show);
    Exit;
  end;
  if not (Bar in [SB_HORZ, SB_VERT]) then
  begin
    inherited;
    Exit;
  end;

  // Keep a bar during a size change (see above); the range set afterwards makes it empty.
  if FInSize and not Show and FBarShown[Bar] then
    Exit;
  FBarShown[Bar] := Show;
  inherited;
end;
{$ENDIF}

{$IFDEF LCLQT6}
// The pattern brush of the original is aligned to the canvas origin: a dotted line has the line colour where
// X + Y is even and the background colour elsewhere; a solid line has the line colour everywhere.
procedure DrawPatternLine(Canvas: TCanvas; X1, Y1, X2, Y2: Integer; Dotted: Boolean; Back: TColor);

var
  X, Y: Integer;
  LineColor: TColor;

begin
  LineColor := Canvas.Font.Color;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Back;
  if Dotted then
    Canvas.FillRect(Rect(X1, Y1, X2 + 1, Y2 + 1));
  Canvas.Brush.Color := LineColor;
  if not Dotted then
    Canvas.FillRect(Rect(X1, Y1, X2 + 1, Y2 + 1))
  else
    for Y := Y1 to Y2 do
      for X := X1 to X2 do
        if not Odd(X + Y) then
          Canvas.FillRect(Rect(X, Y, X + 1, Y + 1));
  Canvas.Brush.Color := Back;
end;

procedure TVirtualStringTree.DrawDottedHLine(const PaintInfo: TVTPaintInfo; Left, Right, Top: Integer);

begin
  if LineStyle = lsCustomStyle then
    inherited
  else
    DrawPatternLine(PaintInfo.Canvas, Min(Left, Right), Top, Max(Left, Right), Top, LineStyle = lsDotted,
      Colors.BackGroundColor);
end;

procedure TVirtualStringTree.DrawDottedVLine(const PaintInfo: TVTPaintInfo; Top, Bottom, Left: Integer;
  UseSelectedBkColor: Boolean);

var
  Back: TColor;

begin
  if LineStyle = lsCustomStyle then
  begin
    inherited;
    Exit;
  end;
  if not UseSelectedBkColor then
    Back := Colors.BackGroundColor
  else if Focused or (toPopupMode in TreeOptions.PaintOptions) then
    Back := Colors.FocusedSelectionColor
  else
    Back := Colors.UnfocusedSelectionColor;
  DrawPatternLine(PaintInfo.Canvas, Left, Min(Top, Bottom), Left, Max(Top, Bottom), LineStyle = lsDotted, Back);
end;
{$ENDIF}

initialization
  RegisterClassAlias(TVirtualStringTree, 'TVirtualStringTree');

end.
