{ SPDX-License-Identifier: GPL-2.0-or-later }
unit Animate;

{ Replaces the VCL's ComCtrls.TAnimate, which plays an AVI resource (the busy indicator top right in the main window,
  the progress bar of the connect dialog). The LCL has no such control and cannot play AVIs.

  This one plays a PNG resource (type PNG, like the program's other pictures) that holds the frames side by side:
  square frames as high as the picture, drawn centred in the control on the parent's colour (the VCL's TAnimate was
  transparent the same way). tools/make_branding.sh writes such a strip from the QueryMole animation (ADR-0030). If
  ResName names no PNG resource (the original's AVIs are not converted), the control stays empty, as before.

  The original's frame numbers in Play refer to its AVIs; a range beyond the strip plays all of its frames. The frame
  rate is that of the QueryMole animation. TntComCtrls re-exports the class, because the ported units find TAnimate
  there. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics;

type
  TAnimate = class(TCustomControl)
  private
    FResName: String;
    FFrames: array of TBitmap;
    FTimer: TTimer;
    FFrame: Integer;
    FFirst, FLast: Integer;
    FRepetitions: Integer;
    FOnStop: TNotifyEvent;
    procedure SetResName(const Value: String);
    function GetActive: Boolean;
    procedure SetActive(Value: Boolean);
    procedure LoadFrames;
    procedure FreeFrames;
    procedure TimerTick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Shows the frames FromFrame..ToFrame (1-based), Count times; Count <= 0 repeats until Stop. }
    procedure Play(FromFrame, ToFrame: Word; Count: Integer);
    procedure Stop;
    function FrameCount: Integer;
    property ResName: String read FResName write SetResName;
    property Active: Boolean read GetActive write SetActive;
  published
    property Align;
    property Anchors;
    property Visible;
    property OnStop: TNotifyEvent read FOnStop write FOnStop;
  end;

implementation

uses
  IntfGraphics, FPImage;

const
  FrameInterval = 150;   // ms, the delay of assets/querymole-icon-animated.gif

constructor TAnimate.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ParentColor := True;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := FrameInterval;
  FTimer.OnTimer := @TimerTick;
end;

destructor TAnimate.Destroy;
begin
  FTimer.Enabled := False;
  FreeFrames;
  inherited Destroy;
end;

procedure TAnimate.FreeFrames;
var
  I: Integer;
begin
  for I := 0 to High(FFrames) do
    FFrames[I].Free;
  FFrames := nil;
end;

procedure TAnimate.LoadFrames;
var
  Stream: TResourceStream;
  Png: TPortableNetworkGraphic;
  Strip, Part: TLazIntfImage;
  Size, Count, I, X, Y: Integer;
begin
  FreeFrames;
  if (FResName = '') or (FindResource(HInstance, PChar(FResName), PChar('PNG')) = 0) then
    Exit;
  Png := TPortableNetworkGraphic.Create;
  try
    Stream := TResourceStream.Create(HInstance, FResName, PChar('PNG'));
    try
      Png.LoadFromStream(Stream);
    finally
      Stream.Free;
    end;
    Size := Png.Height;
    if Size <= 0 then
      Exit;
    Count := Png.Width div Size;
    Strip := Png.CreateIntfImage;
    try
      SetLength(FFrames, Count);
      for I := 0 to Count - 1 do
      begin
        // Copy pixel by pixel through TLazIntfImage: Canvas.CopyRect would lose the alpha channel.
        Part := TLazIntfImage.Create(0, 0);
        try
          Part.DataDescription := Strip.DataDescription;
          Part.SetSize(Size, Size);
          for Y := 0 to Size - 1 do
            for X := 0 to Size - 1 do
              Part.Colors[X, Y] := Strip.Colors[I * Size + X, Y];
          FFrames[I] := TBitmap.Create;
          FFrames[I].LoadFromIntfImage(Part);
        finally
          Part.Free;
        end;
      end;
    finally
      Strip.Free;
    end;
  finally
    Png.Free;
  end;
end;

procedure TAnimate.SetResName(const Value: String);
begin
  Stop;
  FResName := Value;
  LoadFrames;
  FFrame := 0;
  Invalidate;
end;

function TAnimate.FrameCount: Integer;
begin
  Result := Length(FFrames);
end;

function TAnimate.GetActive: Boolean;
begin
  Result := FTimer.Enabled;
end;

procedure TAnimate.SetActive(Value: Boolean);
begin
  if Value then
    Play(1, High(Word), 0)
  else
    Stop;
end;

procedure TAnimate.Play(FromFrame, ToFrame: Word; Count: Integer);
begin
  if FrameCount = 0 then
    Exit;
  FFirst := FromFrame - 1;
  FLast := ToFrame - 1;
  if (FFirst < 0) or (FLast >= FrameCount) or (FFirst > FLast) then
  begin
    FFirst := 0;
    FLast := FrameCount - 1;
  end;
  FRepetitions := Count;
  FFrame := FFirst;
  FTimer.Enabled := True;
  Invalidate;
end;

procedure TAnimate.Stop;
var
  WasActive: Boolean;
begin
  WasActive := FTimer.Enabled;
  FTimer.Enabled := False;
  FFrame := 0;
  Invalidate;
  if WasActive and Assigned(FOnStop) then
    FOnStop(Self);
end;

procedure TAnimate.TimerTick(Sender: TObject);
begin
  if FFrame < FLast then
    Inc(FFrame)
  else
  begin
    if FRepetitions > 0 then
    begin
      Dec(FRepetitions);
      if FRepetitions = 0 then
      begin
        Stop;
        Exit;
      end;
    end;
    FFrame := FFirst;
  end;
  Invalidate;
end;

procedure TAnimate.Paint;
var
  Frame: TBitmap;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  if (FFrame >= 0) and (FFrame < FrameCount) then
  begin
    Frame := FFrames[FFrame];
    Canvas.Draw((ClientWidth - Frame.Width) div 2, (ClientHeight - Frame.Height) div 2, Frame);
  end;
end;

end.
