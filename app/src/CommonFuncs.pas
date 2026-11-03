unit CommonFuncs;

{$mode delphi}

interface

uses
  gnugettext, SysUtils, Options, AuxFuncs, {$IFDEF MSWINDOWS}Windows{$ELSE}LCLIntf, LCLType, WinAliases, Types{$ENDIF}, Forms, Controls, About,
  TntSystem;

{$include Consts.ini}
{$include RevivalInfo.inc}

// Version shown to the user: that of the revival, e.g. "0.1.0 beta.1" (VERSION file). product_version is the
// version of the original this program is based on.
function RevivalVersionText: WideString;

// Texts of the About dialog (version line and credits, ADR-0026).
function AboutVersionText: WideString;
function AboutCreditsText: WideString;

procedure CheckCommonCommandlineParameter;
function CreateAboutForm(Caption: WideString; Version: WideString; Credits: WideString): TAboutForm;
procedure ShowAboutDialog(Caption: WideString;
  Version: WideString; Credits: WideString);
function ShowSplashScreen(Caption: WideString): TAboutForm;

implementation

uses
  Classes;

// -----------------------------------------------------------------------------

function RevivalVersionText: WideString;

begin
  Result := revival_version_text;
end;

// -----------------------------------------------------------------------------

function AboutVersionText: WideString;

begin
  Result := RevivalVersionText + ' (' + _('based on') + ' ' + product_version + ' ' + product_build_level + ')';
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
    'Mike Hillyer, documentation | ' +
    'Revival (Free Pascal / Lazarus): Harald Lapp, with the help of Claude Code (Anthropic), an AI coding assistant';
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

begin
  Result := TAboutForm.Create(nil);
  Result.Caption := _('About ') + Caption;
  Result.VersionLbl.Caption := _('version') + ' ' + Version;
  Result.TextLbl.Caption := Credits;
  // The revival adds lines to the original's texts (ADR-0026): the credits get the space down to the button line
  // and the licence note names the source.
  Result.TextLbl.Top := 254;
  Result.TextLbl.Height := 85;
  {$IFNDEF MSWINDOWS}
  // Port: the substitute for Tahoma is wider; one pixel less keeps the texts above the button line
  Result.TextLbl.Font.Height := -10;
  Result.LicenceLbl.Font.Height := -10;
  Result.CopyrightLbl.Font.Height := -10;
  {$ENDIF}
  Result.LicenceLbl.Caption := _('This software is released under the GNU General Public License, version 2 or ' +
    '(at your option) any later version, and comes with NO WARRANTY. Source code and bug reports: ' +
    'https://github.com/aurora/mysql-query-browser');
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

