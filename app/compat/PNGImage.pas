{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces the third-party PNGImage unit (Delphi had no PNG support).
  The LCL reads PNG with alpha natively; TPNGObject only adds the two drawing
  methods the sources use. }
unit PNGImage;

{$mode delphi}

interface

uses
  Windows, Classes, SysUtils, Graphics, GraphType, IntfGraphics, FPImage;

type
  TPNGObject = class(TPortableNetworkGraphic)
  public
    { Draw stretched into Rect, honouring the alpha channel }
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); reintroduce;
    { The original library's alpha blending, as used for toolbar buttons and tabs: the image is
      drawn at its NATIVE size at Rect.Left/Rect.Top (Right/Bottom are ignored, which is why callers
      pass odd rectangles). Transparency is how transparent it is drawn: opacity (255-T)/256, 0 means
      opaque. OnlyGrayscale averages R, G, B; Highlight is added to and Darken subtracted from the
      colour channels. }
    procedure DrawPartialTrans(ACanvas: TCanvas; const Rect: TRect; Transparency: Integer = 0;
      OnlyGrayscale: Boolean = False; Darken: Integer = 0; Highlight: Integer = 0); overload;
    procedure DrawPartialTrans(DC: HDC; const Rect: TRect; Transparency: Integer = 0;
      OnlyGrayscale: Boolean = False; Darken: Integer = 0; Highlight: Integer = 0); overload;
    procedure DrawFaded(ACanvas: TCanvas; const Rect: TRect; Transparency: Integer = 127);
    procedure DrawGrayscale(ACanvas: TCanvas; const Rect: TRect; Transparency: Integer = 127);
  end;

implementation

procedure TPNGObject.Draw(ACanvas: TCanvas; const Rect: TRect);
begin
  ACanvas.StretchDraw(Rect, Self);
end;

procedure TPNGObject.DrawPartialTrans(ACanvas: TCanvas; const Rect: TRect; Transparency: Integer;
  OnlyGrayscale: Boolean; Darken: Integer; Highlight: Integer);
var
  Img: TLazIntfImage;
  Bmp: TBitmap;
  X, Y: Integer;
  C: TFPColor;
  Gray: Integer;

  function Adjust(V: Word): Word;
  var
    N: Integer;
  begin
    N := Integer(V) + Highlight * 257 - Darken * 257;       // channels are 16 bit here
    if N < 0 then
      N := 0
    else if N > 65535 then
      N := 65535;
    Result := N;
  end;

begin
  Img := TLazIntfImage.Create(0, 0, [riqfRGB, riqfAlpha]);
  Bmp := TBitmap.Create;
  try
    Bmp.Assign(Self);
    Img.LoadFromBitmap(Bmp.Handle, Bmp.MaskHandle);
    for Y := 0 to Img.Height - 1 do
      for X := 0 to Img.Width - 1 do
      begin
        C := Img.Colors[X, Y];
        if Transparency > 0 then
          C.Alpha := Word((Integer(C.Alpha) * (255 - Transparency)) div 256);
        if OnlyGrayscale then
        begin
          Gray := (Integer(C.Red) + Integer(C.Green) + Integer(C.Blue)) div 3;
          C.Red := Gray;
          C.Green := Gray;
          C.Blue := Gray;
        end
        else if (Highlight > 0) or (Darken > 0) then
        begin
          C.Red := Adjust(C.Red);
          C.Green := Adjust(C.Green);
          C.Blue := Adjust(C.Blue);
        end;
        Img.Colors[X, Y] := C;
      end;
    Bmp.LoadFromIntfImage(Img);
    ACanvas.Draw(Rect.Left, Rect.Top, Bmp);
  finally
    Bmp.Free;
    Img.Free;
  end;
end;

procedure TPNGObject.DrawPartialTrans(DC: HDC; const Rect: TRect; Transparency: Integer;
  OnlyGrayscale: Boolean; Darken: Integer; Highlight: Integer);
var
  Canvas: TCanvas;
begin
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := DC;
    DrawPartialTrans(Canvas, Rect, Transparency, OnlyGrayscale, Darken, Highlight);
  finally
    Canvas.Handle := 0;           // the caller owns the DC
    Canvas.Free;
  end;
end;

procedure TPNGObject.DrawFaded(ACanvas: TCanvas; const Rect: TRect; Transparency: Integer);
begin
  DrawPartialTrans(ACanvas, Rect, Transparency);
end;

procedure TPNGObject.DrawGrayscale(ACanvas: TCanvas; const Rect: TRect; Transparency: Integer);
begin
  DrawPartialTrans(ACanvas, Rect, Transparency, True);
end;

end.
