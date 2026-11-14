unit CommonFuncs;

{$mode delphi}

interface

uses
  gnugettext, SysUtils, Options, AuxFuncs, {$IFDEF MSWINDOWS}Windows{$ELSE}LCLIntf, LCLType, WinAliases, Types{$ENDIF}, Forms, Controls, About,
  TntSystem;

{$include Consts.ini}
{$include RevivalInfo.inc}

const
  // Name of the product and its home (ADR-0030). The original's name appears only where the program
  // says what it is based on, and where it looks for an installed original.
  RevivalProductName = 'QueryMole';
  RevivalProjectUrl = 'https://github.com/aurora/querymole';

// Version shown to the user: that of the revival, e.g. "0.1.0 beta.1" (VERSION file). product_version is the
// version of the original this program is based on.
function RevivalVersionText: WideString;

// Texts of the About dialog (version line, the original it is based on, credits; ADR-0026, ADR-0030).
function AboutVersionText: WideString;
function AboutBasedOnText: WideString;
function AboutCreditsText: WideString;

procedure CheckCommonCommandlineParameter;
function CreateAboutForm(Caption: WideString; Version: WideString; Credits: WideString): TAboutForm;
procedure ShowAboutDialog(Caption: WideString;
  Version: WideString; Credits: WideString);
function ShowSplashScreen(Caption: WideString): TAboutForm;

implementation

uses
  Classes, Graphics, StdCtrls;

// -----------------------------------------------------------------------------

function RevivalVersionText: WideString;

begin
  Result := revival_version_text;
end;

// -----------------------------------------------------------------------------

function AboutVersionText: WideString;

begin
  Result := RevivalVersionText;
end;

// -----------------------------------------------------------------------------

function AboutBasedOnText: WideString;

begin
  Result := _('based on') + ' MySQL Query Browser ' + product_version + ' ' + product_build_level;
end;

// -----------------------------------------------------------------------------

function AboutCreditsText: WideString;

begin
  Result := 'Michael G. Zinner, graphical design, ' +
    'Windows development, library coding | ' +
    'Alfredo Kengi Kojima, Linux development, library coding | ' +
    'Mike Lischke, Windows development, library coding | ' +
    'Victor Vagin, library coding, QA | ' +
    'Ulrich Bayer, library coding, WIX | ' +
    'Brian Aker, main concept | ' +
    'Mike Hillyer, documentation';
end;

// -----------------------------------------------------------------------------

function AboutRevivalCreditsText: WideString;

begin
  Result := 'Harald Lapp, port to Free Pascal / Lazarus, maintenance, with the help of Claude Code (Anthropic), an ' +
    'AI coding assistant';
end;

// -----------------------------------------------------------------------------

type
  // The credits view of the About dialog has two sections (ADR-0032); the labels added for them are shown and
  // hidden together with the original's credits label.
  TAboutCreditsToggle = class(TComponent)
  public
    Form: TAboutForm;
    Labels: array of TLabel;
    procedure CreditsClick(Sender: TObject);
  end;

procedure TAboutCreditsToggle.CreditsClick(Sender: TObject);

var
  I: Integer;

begin
  Form.CreditsBtnClick(Sender);
  for I := 0 to High(Labels) do
    Labels[I].Visible := Form.TextLbl.Visible;
end;

// -----------------------------------------------------------------------------

// Height of Text wrapped into Width pixels in Font.
function WrappedTextHeight(Font: TFont; const Text: String; Width: Integer): Integer;

var
  Bitmap: TBitmap;
  R: TRect;

begin
  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(1, 1);
    Bitmap.Canvas.Font := Font;
    R := Rect(0, 0, Width, 0);
    DrawText(Bitmap.Canvas.Handle, PChar(Text), Length(Text), R, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    Result := R.Bottom - R.Top;
  finally
    Bitmap.Free;
  end;
end;

// -----------------------------------------------------------------------------

function AddAboutLabel(Form: TAboutForm; Template: TLabel; Bold: Boolean; Top: Integer; const Caption: String): TLabel;

begin
  Result := TLabel.Create(Form);
  Result.Parent := Form;
  Result.Transparent := True;
  Result.Font := Template.Font;
  if Bold then
    Result.Font.Style := [fsBold];
  Result.AutoSize := False;
  Result.WordWrap := True;
  Result.Left := Template.Left;
  Result.Width := Template.Width;
  Result.Top := Top;
  Result.Height := WrappedTextHeight(Result.Font, Caption, Result.Width);
  Result.Caption := Caption;
end;

// -----------------------------------------------------------------------------

procedure CheckCommonCommandlineParameter;

var
  i: integer;
  S: WideString;
  HexString: string;
  Utf8String: string;
  
begin
  for i := 1 to WideParamCount do
  begin
    //-------------------------------------------------------------
    //General cmdline parameters

    S := WideParamStr(I);

    //Connection
    if (S = '-c') and (I+1 <= WideParamCount) then
      MYXCommonOptions.ConnectionToUse := WideParamStr(I + 1)
    else
      if (Copy(S, 1, 2) = '-c') then
        MYXCommonOptions.ConnectionToUse := Copy(S, 3, MaxInt)
      else
        //Username
        if ((S = '-u')) and (I+1 <= WideParamCount) then
          MYXCommonOptions.ConnectionUsername := WideParamStr(I + 1)
        else
          if (Copy(S, 1, 2) = '-u') then
            MYXCommonOptions.ConnectionUsername := Copy(S, 3, MaxInt)
          else
            //Password
            if (S = '-p') and (I+1 <= WideParamCount) then
              MYXCommonOptions.ConnectionPassword := WideParamStr(I + 1)
            else
              if (Copy(S, 1, 2) = '-p') then
                MYXCommonOptions.ConnectionPassword := Copy(S, 3, MaxInt)
              else
                //Host
                if (S = '-h') and (I+1 <= WideParamCount) then
                  MYXCommonOptions.ConnectionHost := WideParamStr(I + 1)
                else
                  if (Copy(S, 1, 2) = '-h') then
                    MYXCommonOptions.ConnectionHost := Copy(S, 3, MaxInt)
                  else
                    //Port
                    if (S = '-P') and (I+1 <= WideParamCount) then
                    begin
                      S := WideParamStr(I + 1);
                      MYXCommonOptions.ConnectionPort := StrToIntDef(S, 3306);
                    end
                    else
                      if (Copy(S, 1, 2) = '-P') then
                      begin
                        S := Copy(S, 3, MaxInt);
                        MYXCommonOptions.ConnectionPort := StrToIntDef(S, 3306);
                      end
                      else
                        //Schema
                        if (S = '-D') and (I+1 <= WideParamCount) then
                          MYXCommonOptions.ConnectionSchema := WideParamStr(I + 1)
                        else
                          if (Copy(S, 1, 2) = '-D') then
                            MYXCommonOptions.ConnectionSchema := Copy(S, 3, MaxInt)
                          else
                            // Password hexadecimal
                            if Copy(S, 1, 2) = '-x' then      // Port: was StrLCompW from the Unicode unit
                            begin
                              if (Length(S) = 2) and (I < WideParamCount) then
                                HexString := WideParamStr(I + 1)
                              else
                                HexString := Copy(S, 3, MaxInt);
                              SetLength(Utf8String, Length(HexString) div 2);
                              HexToBin(PChar(HexString), PChar(Utf8String), Length(Utf8String));
                              MYXCommonOptions.ConnectionPassword := Utf8Decode(Utf8String);
                            end;
  end;

  //If only username was specified, automaticly set
  //other connection values
  if (MYXCommonOptions.ConnectionUsername <> '') then
  begin
    if (MYXCommonOptions.ConnectionHost = '') then
      MYXCommonOptions.ConnectionHost := 'localhost';

    if MYXCommonOptions.ConnectionPort = 0 then
      MYXCommonOptions.ConnectionPort := 3306;
  end;
end;

// -----------------------------------------------------------------------------

function CreateAboutForm(Caption: WideString; Version: WideString; Credits: WideString): TAboutForm;

var
  W, Grow, I: Integer;
  BasedOnLbl, Heading: TLabel;
  Toggle: TAboutCreditsToggle;

begin
  Result := TAboutForm.Create(nil);
  Result.Caption := _('About ') + Caption;
  Result.VersionLbl.Caption := _('version') + ' ' + Version;
  Result.TextLbl.Caption := Credits;
  // The QueryMole picture (ADR-0032) is wider than the original's and dark: the dialog takes its width, the texts
  // are light and stand in a column right of the mole, below the line under the slogan (the numbers belong to the
  // picture that tools/make_branding.sh writes). The lines are set by hand instead of wrapped where they can be.
  W := Result.AboutImg.Picture.Width;
  if W < Result.AboutImg.Width then
    W := Result.AboutImg.Width;
  Grow := W - Result.AboutImg.Width;
  Result.ClientWidth := Result.ClientWidth + Grow;
  Result.AboutImg.Width := W;
  Result.TntBevel1.Width := Result.TntBevel1.Width + Grow;
  Result.CloseBtn.Left := Result.CloseBtn.Left + Grow;
  Result.CreditsBtn.Left := Result.CreditsBtn.Left + Grow;
  Result.VersionLbl.Left := 468;
  Result.CopyrightLbl.Left := 468;
  Result.LicenceLbl.Left := 468;
  Result.TextLbl.Left := 468;
  Result.VersionLbl.Width := 240;
  Result.CopyrightLbl.Width := 240;
  Result.LicenceLbl.Width := 240;
  Result.TextLbl.Width := 240;
  Result.VersionLbl.Font.Color := RGBToColor(206, 218, 232);
  Result.CopyrightLbl.Font.Color := RGBToColor(160, 178, 200);
  Result.LicenceLbl.Font.Color := RGBToColor(160, 178, 200);
  Result.TextLbl.Font.Color := RGBToColor(160, 178, 200);
  {$IFNDEF MSWINDOWS}
  // Port: the substitute for Tahoma is wider; one pixel less keeps the texts above the button line
  Result.TextLbl.Font.Height := -10;
  Result.LicenceLbl.Font.Height := -10;
  Result.CopyrightLbl.Font.Height := -10;
  {$ENDIF}
  // Version of QueryMole (bold), below it the original it is based on (ADR-0030), in the plain font.
  Result.VersionLbl.Top := 106;
  BasedOnLbl := TLabel.Create(Result);
  BasedOnLbl.Parent := Result;
  BasedOnLbl.Transparent := True;
  BasedOnLbl.Font := Result.TextLbl.Font;
  BasedOnLbl.Left := 468;
  BasedOnLbl.Top := 122;
  BasedOnLbl.Caption := AboutBasedOnText;
  // Credits in two sections (ADR-0032): the original's authors, unchanged, under a heading that says what they
  // worked on, then the people of QueryMole. Heights are measured, so each section follows the previous one.
  Heading := AddAboutLabel(Result, Result.TextLbl, True, 146, _('Original: MySQL Query Browser (MySQL AB)'));
  Result.TextLbl.Top := Heading.Top + Heading.Height + 1;
  Result.TextLbl.Height := WrappedTextHeight(Result.TextLbl.Font, Result.TextLbl.Caption, Result.TextLbl.Width);
  Toggle := TAboutCreditsToggle.Create(Result);
  Toggle.Form := Result;
  SetLength(Toggle.Labels, 3);
  Toggle.Labels[0] := Heading;
  Toggle.Labels[1] := AddAboutLabel(Result, Result.TextLbl, True,
    Result.TextLbl.Top + Result.TextLbl.Height + 8, RevivalProductName);
  Toggle.Labels[2] := AddAboutLabel(Result, Result.TextLbl, False,
    Toggle.Labels[1].Top + Toggle.Labels[1].Height + 1, UTF8Encode(AboutRevivalCreditsText));
  for I := 0 to High(Toggle.Labels) do
    Toggle.Labels[I].Visible := Result.TextLbl.Visible;
  Result.CreditsBtn.OnClick := Toggle.CreditsClick;
  // The original's copyright line stays as it is (only broken after its first sentence); the project's own notice
  // goes below it (ADR-0031).
  Result.CopyrightLbl.Top := 146;
  Result.CopyrightLbl.Height := 56;
  Result.CopyrightLbl.WordWrap := True;
  Result.CopyrightLbl.Caption := StringReplace(Result.CopyrightLbl.Caption, '. All', '.' + LineEnding + 'All', []) +
    LineEnding + RevivalProductName + ' ' + #$C2#$A9 + ' 2026 Harald Lapp and contributors.';
  // GPLv2 2(c): copyright (above), no warranty, redistribution under the licence, where to find more.
  Result.LicenceLbl.Top := 202;
  Result.LicenceLbl.Height := 134;
  Result.LicenceLbl.Caption := _('Free software under the GNU GPL, version 2') + LineEnding +
    _('or later; you may redistribute it under its') + LineEnding +
    _('terms. It comes with NO WARRANTY.') + LineEnding +
    StringReplace(RevivalProjectUrl, 'https://', '', []) + LineEnding +
    _('Not affiliated with Oracle.');
end;

// -----------------------------------------------------------------------------

procedure ShowAboutDialog(Caption: WideString;
  Version: WideString; Credits: WideString);

var
  AboutForm: TAboutForm;

begin
  AboutForm := CreateAboutForm(Caption, Version, Credits);
  try
    AboutForm.ShowModal;
  finally
    AboutForm.Free;
  end;
end;

// -----------------------------------------------------------------------------

function ShowSplashScreen(Caption: WideString): TAboutForm;

var
  AboutForm: TAboutForm;

begin
  Result := nil;

  AboutForm := TAboutForm.Create(nil);
  try
    AboutForm.Caption := _('About ') + Caption;
    AboutForm.VersionLbl.Caption := _('version') + ' ' + RevivalVersionText;
    AboutForm.TextLbl.Caption := '';
    AboutForm.BorderStyle := bsNone;
    AboutForm.Width := AboutForm.AboutImg.Width;
    AboutForm.Height := AboutForm.AboutImg.Height;
    AboutForm.FormStyle := fsStayOnTop;
    AboutForm.Show;
    AboutForm.Refresh;

    Result := AboutForm;
  except
    AboutForm.Free;
  end;
end;

// -----------------------------------------------------------------------------

end.

