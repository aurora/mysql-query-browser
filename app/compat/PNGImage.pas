{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces the third-party PNGImage unit (Delphi had no PNG support).
  The LCL reads PNG with alpha natively; TPNGObject only adds the two drawing
  methods the sources use. }
unit PNGImage;

{$mode delphi}

interface

uses
  Classes, SysUtils, Graphics, GraphType, IntfGraphics, FPImage;

type
  TPNGObject = class(TPortableNetworkGraphic)
  public
    { Draw stretched into Rect, honouring the alpha channel }
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); reintroduce;
    { Draw with the whole image blended to Opacity (0..255) }
    procedure DrawFaded(ACanvas: TCanvas; const Rect: TRect; Opacity: Byte);
  end;

implementation

procedure TPNGObject.Draw(ACanvas: TCanvas; const Rect: TRect);
begin
  ACanvas.StretchDraw(Rect, Self);
end;

procedure TPNGObject.DrawFaded(ACanvas: TCanvas; const Rect: TRect; Opacity: Byte);
var
  Img: TLazIntfImage;
  Bmp: TBitmap;
  X, Y: Integer;
  C: TFPColor;
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
        C.Alpha := Word(C.Alpha * Opacity div 255);
        Img.Colors[X, Y] := C;
      end;
    Bmp.LoadFromIntfImage(Img);
    ACanvas.StretchDraw(Rect, Bmp);
  finally
    Bmp.Free;
    Img.Free;
  end;
end;

end.
