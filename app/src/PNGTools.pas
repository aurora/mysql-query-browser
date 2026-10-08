unit PNGTools;

// Copyright (C) 2003, 2004 MySQL AB
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

// Ported from the Delphi original (mysql-gui-common/source/windows/tools/PNGTools.pas).
// All images of the application go through this unit (they are named resources of
// type PNG), so the image format or size can later change in one place only.

{$mode delphi}

interface

uses
  Classes, SysUtils, Graphics, ExtCtrls, PNGImage, TntExtCtrls, TntClasses;

function LoadPNGImageFromResource(Resourcename: WideString; Image: TTntImage = nil;
  FreePNGImageAfterAssignToImage: Boolean = False): TPNGObject;
procedure DrawPNGImageFromResource(Resourcename: WideString; Image: TTntImage);
function LoadPNGImageFromFile(BasePath: WideString; Filename: WideString; Image: TTntImage = nil): TPNGObject;
function LoadStringFromResource(Resourcename: WideString; ResourceType: WideString): WideString;

function PaintEditButton(Canvas: TCanvas; Caption: WideString; PNGImg: TPNGObject; var xpos: Integer;
  Enabled: Boolean = True; Active: Boolean = True; DrawIconOnly: Boolean = False; DisabledPNGImg: TPNGObject = nil;
  ActivePNGImg: TPNGObject = nil): Integer;
function LoadPNGImageFromPChar(PImageData: PChar; DataLength: Integer; Image: TImage = nil;
  FreeAfterAssign: Boolean = False): TPNGObject;

//----------------------------------------------------------------------------------------------------------------------

implementation

uses
  TntSysUtils, Types;

//----------------------------------------------------------------------------------------------------------------------

function ResourceExists(const Name, ResType: String): Boolean;
var
  Stream: TResourceStream;
begin
  Result := False;
  try
    Stream := TResourceStream.Create(HInstance, Name, PChar(ResType));
    Stream.Free;
    Result := True;
  except
    on EResNotFound do
      ;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function LoadPNGImageFromResource(Resourcename: WideString; Image: TTntImage;
  FreePNGImageAfterAssignToImage: Boolean): TPNGObject;

var
  tmpStream: TTntResourceStream;
  PNGImage: TPNGObject;

begin
  Result := nil;

  if ResourceExists(UTF8Encode(Resourcename), 'PNG') then
  begin
    tmpStream := TTntResourceStream.Create(HInstance, UTF8Encode(Resourcename), PChar('PNG'));
    try
      PNGImage := TPNGObject.Create;
      try
        PNGImage.LoadFromStream(tmpStream);

        if Assigned(Image) then
        begin
          Image.Picture.Graphic := PNGImage;
          if Image.AutoSize then
          begin
            Image.Width := PNGImage.Width;
            Image.Height := PNGImage.Height;
          end;
        end;

        if FreePNGImageAfterAssignToImage then
          PNGImage.Free
        else
          Result := PNGImage;
      except
        PNGImage.Free;
      end;
    finally
      tmpStream.Free;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure DrawPNGImageFromResource(Resourcename: WideString; Image: TTntImage);

var
  tmpStream: TTntResourceStream;
  PNGImage: TPNGObject;

begin
  tmpStream := TTntResourceStream.Create(HInstance, UTF8Encode(Resourcename), PChar('PNG'));
  try
    PNGImage := TPNGObject.Create;
    try
      PNGImage.LoadFromStream(tmpStream);

      Image.Width := PNGImage.Width;
      Image.Height := PNGImage.Height;
      Image.Picture.Bitmap.Width := PNGImage.Width;
      Image.Picture.Bitmap.Height := PNGImage.Height;

      PNGImage.Draw(Image.Picture.Bitmap.Canvas, Rect(0, 0, PNGImage.Width, PNGImage.Height));
    finally
      PNGImage.Free;
    end;
  finally
    tmpStream.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function LoadPNGImageFromFile(BasePath: WideString; Filename: WideString; Image: TTntImage): TPNGObject;

var
  PNGImage: TPNGObject;
  FullFileName: String;

begin
  FullFileName := UTF8Encode(WideIncludeTrailingBackslash(BasePath)) + 'images' + PathDelim + UTF8Encode(Filename);

  PNGImage := nil;

  if FileExists(FullFileName) then
  begin
    PNGImage := TPNGObject.Create;
    PNGImage.LoadFromFile(FullFileName);

    if Assigned(Image) then
      Image.Picture.Graphic := PNGImage;
  end;

  Result := PNGImage;
end;

//----------------------------------------------------------------------------------------------------------------------

function LoadStringFromResource(Resourcename: WideString; ResourceType: WideString): WideString;

var
  tmpStream: TTntResourceStream;
  StringList: TTntStringList;

begin
  Result := '';

  tmpStream := TTntResourceStream.Create(HInstance, UTF8Encode(Resourcename), PChar(UTF8Encode(ResourceType)));
  try
    StringList := TTntStringList.Create;
    try
      StringList.LoadFromStream(tmpStream);

      Result := UTF8Decode(StringList.Text);
    finally
      StringList.Free;       // the original leaked the list on success
    end;
  finally
    tmpStream.Free;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function PaintEditButton(Canvas: TCanvas; Caption: WideString; PNGImg: TPNGObject; var xpos: Integer; Enabled: Boolean;
  Active: Boolean; DrawIconOnly: Boolean; DisabledPNGImg: TPNGObject; ActivePNGImg: TPNGObject): Integer;

var
  S: String;
  Size: TSize;
  R: TRect;

begin
  with Canvas do
  begin
    Dec(xpos, 7);

    if not DrawIconOnly then
    begin
      S := UTF8Encode(Caption);

      Size := TextExtent(S);
      Dec(xpos, Size.cx);

      if Active then
        Font.Color := $0023AC23
      else
        if Enabled then
          Font.Color := clBlack
        else
          Font.Color := $00CCCCCC;

      R := Rect(xpos, 4, xpos + Size.cx, 4 + 18);
      Brush.Style := bsClear;
      TextRect(R, R.Left, R.Top, S);

      if Assigned(PNGImg) then
        xpos := xpos - 21
      else
        xpos := xpos - 4;
    end
    else
      xpos := xpos - 16;

    if (Active) and (ActivePNGImg <> nil) then
      ActivePNGImg.Draw(Canvas,
        Rect(xpos + 1, 2, xpos + 1 + PNGImg.Width, 2 + PNGImg.Height))
    else if (Enabled) and (PNGImg <> nil) then
      PNGImg.Draw(Canvas,
        Rect(xpos + 1, 2, xpos + 1 + PNGImg.Width, 2 + PNGImg.Height))
    else
    begin
      if (DisabledPNGImg = nil) and Assigned(PNGImg) then
        PNGImg.DrawFaded(Canvas, Rect(xpos + 1, 2, xpos + 1 + PNGImg.Width, 2 + PNGImg.Height), 50)
      else
        if Assigned(DisabledPNGImg) then
          DisabledPNGImg.Draw(Canvas, Rect(xpos + 1, 2, xpos + 1 + PNGImg.Width, 2 + PNGImg.Height));
    end;

    xpos := xpos - 5;
    MoveTo(xpos, 0);
    LineTo(xpos, 20);
  end;

  Result := xpos;
end;

//----------------------------------------------------------------------------------------------------------------------

function LoadPNGImageFromPChar(PImageData: PChar; DataLength: Integer; Image: TImage;
  FreeAfterAssign: Boolean): TPNGObject;

var
  MemStream: TMemoryStream;

begin
  Result := nil;

  if (DataLength > 0) then
  begin
    MemStream := TMemoryStream.Create;
    try
      MemStream.WriteBuffer(PImageData^, DataLength);
      MemStream.Position := 0;

      Result := TPNGObject.Create;
      try
        Result.LoadFromStream(MemStream);

        if (Assigned(Image)) then
        begin
          Image.Picture.Assign(Result);
          Image.Invalidate
        end;
      finally
        if (FreeAfterAssign) then
        begin
          Result.Free;
          Result := nil;
        end;
      end;
    finally
      MemStream.Free;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

end.
