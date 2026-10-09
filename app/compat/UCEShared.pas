{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Interfaces of UniCodeEditor's UCEShared unit (ADR-0012). Declarations only. }
unit UCEShared;

{$mode delphi}

interface

uses
  Types, Graphics;

type
  // Defines the interface for a line marker, an entry in the gutter of the edit.
  IUCELineMarker = interface
    ['{6F0D4A2E-3B51-4C7A-9E18-52D1C7A94B01}']
    procedure Draw(Index: Integer; Canvas: TCanvas; X, Y: Integer);
    function GetSize(Index: Integer): TSize;
  end;

  // Defines the interface for a custom line style.
  IUCELineStyle = interface
    ['{6F0D4A2E-3B51-4C7A-9E18-52D1C7A94B02}']
    function GetBackground: TColor;
    function GetFontStyles: TFontStyles;
    function GetForceFontStyles: Boolean;
    function GetForeground: TColor;
    property Background: TColor read GetBackground;
    property Foreground: TColor read GetForeground;
    property FontStyles: TFontStyles read GetFontStyles;
    property ForceFontStyles: Boolean read GetForceFontStyles;
  end;

implementation

end.
