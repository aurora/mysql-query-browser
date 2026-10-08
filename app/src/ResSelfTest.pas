{ SPDX-License-Identifier: GPL-2.0-or-later }
unit ResSelfTest;

{ Developer check: qbr --selftest-resources out.png
  Loads a few of the embedded PNG resources through PNGTools and writes them into one
  picture, so a change in resource handling or image drawing can be reviewed by eye. }

{$mode delphi}

interface

procedure RunResourceSelfTest(const OutFile: String);

implementation

uses
  Classes, SysUtils, Graphics, ExtCtrls, PNGImage, PNGTools, TntExtCtrls;

const
  ResourceNames: array[0..5] of String = ('connection_dialog_header', 'mysql_logo', 'connect_to_instance',
    'clear_search', 'magnify_glass', 'magnify_glass_with_popup');

procedure RunResourceSelfTest(const OutFile: String);
var
  Bmp: TBitmap;
  Png: TPNGObject;
  Out: TPortableNetworkGraphic;
  I, X, Y: Integer;
  Missing: String;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(640, 260);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, Bmp.Width, Bmp.Height);
    X := 8;
    Y := 8;
    Missing := '';
    for I := Low(ResourceNames) to High(ResourceNames) do
    begin
      Png := LoadPNGImageFromResource(ResourceNames[I]);
      if Png = nil then
        Missing := Missing + ' ' + ResourceNames[I]
      else
      try
        if X + Png.Width > Bmp.Width then
        begin
          X := 8;
          Y := Y + 70;
        end;
        Png.Draw(Bmp.Canvas, Rect(X, Y, X + Png.Width, Y + Png.Height));
        // faded variant below it: the same call the search edit buttons use for "disabled"
        Png.DrawFaded(Bmp.Canvas, Rect(X, Y + Png.Height + 4, X + Png.Width, Y + 4 + 2 * Png.Height), 50);
        X := X + Png.Width + 12;
      finally
        Png.Free;
      end;
    end;
    Out := TPortableNetworkGraphic.Create;
    try
      Out.Assign(Bmp);
      Out.SaveToFile(OutFile);
    finally
      Out.Free;
    end;
    // a GUI application has no console: report through a text file
    with TStringList.Create do
    try
      if Missing <> '' then
        Add('resources not found:' + Missing)
      else
        Add('ok: ' + IntToStr(Length(ResourceNames)) + ' resources drawn');
      SaveToFile(ChangeFileExt(OutFile, '.txt'));
    finally
      Free;
    end;
  finally
    Bmp.Free;
  end;
end;

end.
