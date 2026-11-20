{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The questions and messages of the SSH tunnel (ADR-0048) in the program: SSHConnect stays free of the LCL and calls
  these through procedure variables, always in the main thread. }
unit SSHConnectUI;

{$mode objfpc}{$H+}

interface

// shows why the last SSH tunnel could not be opened (main thread)
procedure ShowSSHError;

implementation

uses
  SysUtils, Forms, Controls, Dialogs, gnugettext, AuxFuncs, SSHTunnel, SSHConnect;

procedure ShowSSHError;
begin
  ShowModalDialog(Application.Title + ' - ' + _('SSH Tunnel'), SSHErrorMessage, myx_mtError, _('OK'));
end;

function VerifyHostKey(const Host, Fingerprint: String; State: TSSHHostKeyState): Boolean;
begin
  // changed keys are refused by the tunnel in any case; its message says why
  if State <> hksUnknown then
    Exit(False);
  Result := ShowModalDialog(Application.Title + ' - ' + _('SSH Tunnel'),
    Format(_('The authenticity of the SSH server %s cannot be established, it is not in your known_hosts file.' +
    #13#10#13#10 + 'Key fingerprint: %s' + #13#10#13#10 +
    'Do you trust this server and want to add its key to known_hosts?'), [Host, Fingerprint]),
    myx_mtConfirmation, _('Yes') + #13#10 + _('No')) = 1;
end;

function AskSecret(const Prompt: String; out Secret: String): Boolean;
var
  Value: String;
begin
  Value := '';
  Result := InputQuery(_('SSH Tunnel'), Prompt, True, Value);
  Secret := Value;
end;

initialization
  SSHVerifyHostKeyProc := @VerifyHostKey;
  SSHAskSecretProc := @AskSecret;

end.
