{ SPDX-License-Identifier: GPL-2.0-or-later }
unit GtkDpi;

{$mode delphi}

// Port: the forms are laid out in pixels for 96 dpi (ADR-0023). GTK2 sizes its own text (menus, fonts the LCL maps
// to the system font, Screen.PixelsPerInch) from the desktop's dpi setting, which on a scaled desktop is not 96, so
// text and the rest of the window no longer match. The dpi setting is pinned to 96 for this program.

interface

procedure PinGtkDpiTo96;

implementation

uses
  {$IFDEF LCLGTK2}gtk2{$ELSE}SysUtils{$ENDIF};

procedure PinGtkDpiTo96;

begin
  {$IFDEF LCLGTK2}
  // the value is in 1/1024 dpi
  gtk_settings_set_long_property(gtk_settings_get_default, 'gtk-xft-dpi', 96 * 1024, 'qbr');
  {$ENDIF}
end;

end.
