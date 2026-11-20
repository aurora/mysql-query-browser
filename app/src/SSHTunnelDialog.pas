{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The SSH tunnel's UI (ADR-0048, mock-up in docs/mockups/ssh-tunnel): the dialog "SSH Tunnel" and the row
  "Use SSH tunnel [...] user@host" that the connect dialog and Options > Connections add at run time (their forms are
  converted from the original and stay as they are). Both work on the SSH_* entries of a connection's advanced
  options (SSHConnect.pas lists them). This form is the revival's own, so its .lfm lives next to this unit and not in
  app/forms, which tools/convert_forms.py generates. }
unit SSHTunnelDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, StdCtrls, Buttons, Dialogs, Graphics, TntForms;

type
  TSSHTunnelForm = class(TTntForm)
    SSHGBox: TGroupBox;
    SSHHostLbl: TLabel;
    SSHHostEd: TEdit;
    SSHPortLbl: TLabel;
    SSHPortEd: TEdit;
    SSHUserLbl: TLabel;
    SSHUserEd: TEdit;
    SSHAuthLbl: TLabel;
    SSHAgentRBtn: TRadioButton;
    SSHKeyRBtn: TRadioButton;
    SSHKeyEd: TEdit;
    SSHKeyBtn: TBitBtn;
    SSHPasswordRBtn: TRadioButton;
    SSHNoteLbl: TLabel;
    OKBtn: TButton;
    CancelBtn: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FieldChange(Sender: TObject);
    procedure SSHKeyBtnClick(Sender: TObject);
  public
    procedure LoadOptions(Options: TStrings);
    procedure SaveOptions(Options: TStrings);
  end;

  { The row: a check box, a "..." button and a grey summary, placed by the owner. It keeps the SSH_* entries itself;
    Load takes them from a connection's advanced options, Save writes them back (replacing the SSH_* entries there).
    Unchecked, the settings are kept with SSH_TUNNEL=No, so they are there when the box is checked again. }
  TSSHTunnelRow = class
  private
    FOptions: TStringList;
    FCheck: TCheckBox;
    FButton: TBitBtn;
    FSummary: TLabel;
    FOnChange: TNotifyEvent;
    FLoading: Boolean;
    procedure CheckClick(Sender: TObject);
    procedure ButtonClick(Sender: TObject);
    procedure CheckResize(Sender: TObject);
    procedure UpdateSummary;
    procedure Changed;
    function Edit: Boolean;
  public
    constructor Create(AParent: TWinControl; ALeft, ATop, AWidth: Integer);
    destructor Destroy; override;
    procedure Load(Options: TStrings);
    procedure Save(Options: TStrings);
    procedure Clear;
    procedure SetEnabled(Value: Boolean);
    // after the user changed something in the row
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property CheckBox: TCheckBox read FCheck;
    property Button: TBitBtn read FButton;
  end;

// the SSH_* entries of Options, without the others
procedure CopySSHOptions(Source, Dest: TStrings);
function IsSSHOption(const Entry: String): Boolean;

implementation

uses
  LCLIntf, LCLType, gnugettext, AuxFuncs;

{$R *.lfm}

function IsSSHOption(const Entry: String): Boolean;
begin
  Result := CompareText(Copy(Entry, 1, 4), 'SSH_') = 0;
end;

procedure CopySSHOptions(Source, Dest: TStrings);
var
  I: Integer;
begin
  Dest.Clear;
  for I := 0 to Source.Count - 1 do
    if IsSSHOption(Source[I]) then
      Dest.Add(Source[I]);
end;

procedure SetValue(Options: TStrings; const Name, Value: String);
var
  I: Integer;
begin
  I := Options.IndexOfName(Name);
  if Value = '' then
  begin
    if I >= 0 then
      Options.Delete(I);
  end
  else
    Options.Values[Name] := Value;
end;

{ TSSHTunnelForm }

procedure TSSHTunnelForm.FormCreate(Sender: TObject);
begin
  InitForm(Self);
end;

// the note can take more lines than the form file allows for; the frame and the buttons follow it
procedure TSSHTunnelForm.FormShow(Sender: TObject);
var
  R: TRect;
begin
  // the height the wrapped note needs in its width, with the program's font and the translation
  SSHNoteLbl.Canvas.Font := SSHNoteLbl.Font;
  R := Rect(0, 0, SSHNoteLbl.Width, 0);
  DrawText(SSHNoteLbl.Canvas.Handle, PChar(SSHNoteLbl.Caption), Length(SSHNoteLbl.Caption), R,
    DT_CALCRECT or DT_WORDBREAK);
  SSHNoteLbl.Height := R.Bottom + 2;
  SSHGBox.Height := SSHNoteLbl.Top + SSHNoteLbl.Height + 16;
  OKBtn.Top := SSHGBox.Top + SSHGBox.Height + 10;
  CancelBtn.Top := OKBtn.Top;
  ClientHeight := OKBtn.Top + OKBtn.Height + 9;
end;

procedure TSSHTunnelForm.FieldChange(Sender: TObject);
begin
  SSHKeyEd.Enabled := SSHKeyRBtn.Checked;
  SSHKeyBtn.Enabled := SSHKeyRBtn.Checked;
  OKBtn.Enabled := (Trim(SSHHostEd.Text) <> '') and (not SSHKeyRBtn.Checked or (Trim(SSHKeyEd.Text) <> ''));
end;

procedure TSSHTunnelForm.SSHKeyBtnClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := _('Select the private key');
    Dlg.Filter := _('Private keys') + '|id_*;*.pem;*.key;*.ppk|' + _('All files') + '|*';
    if SSHKeyEd.Text <> '' then
      Dlg.InitialDir := ExtractFilePath(SSHKeyEd.Text)
    else
      Dlg.InitialDir := IncludeTrailingPathDelimiter(GetUserDir) + '.ssh';
    Dlg.Options := Dlg.Options + [ofFileMustExist];
    if Dlg.Execute then
      SSHKeyEd.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TSSHTunnelForm.LoadOptions(Options: TStrings);
var
  Auth: String;
begin
  SSHHostEd.Text := Options.Values['SSH_HOST'];
  SSHPortEd.Text := Options.Values['SSH_PORT'];
  SSHUserEd.Text := Options.Values['SSH_USER'];
  SSHKeyEd.Text := Options.Values['SSH_KEYFILE'];
  Auth := LowerCase(Options.Values['SSH_AUTH']);
  if Auth = 'key' then
    SSHKeyRBtn.Checked := True
  else if Auth = 'password' then
    SSHPasswordRBtn.Checked := True
  else
    SSHAgentRBtn.Checked := True;
  FieldChange(nil);
end;

procedure TSSHTunnelForm.SaveOptions(Options: TStrings);
begin
  SetValue(Options, 'SSH_HOST', Trim(SSHHostEd.Text));
  SetValue(Options, 'SSH_PORT', Trim(SSHPortEd.Text));
  SetValue(Options, 'SSH_USER', Trim(SSHUserEd.Text));
  if SSHKeyRBtn.Checked then
    SetValue(Options, 'SSH_AUTH', 'key')
  else if SSHPasswordRBtn.Checked then
    SetValue(Options, 'SSH_AUTH', 'password')
  else
    SetValue(Options, 'SSH_AUTH', 'agent');
  if SSHKeyRBtn.Checked then
    SetValue(Options, 'SSH_KEYFILE', Trim(SSHKeyEd.Text))
  else
    SetValue(Options, 'SSH_KEYFILE', '');
end;

{ TSSHTunnelRow }

constructor TSSHTunnelRow.Create(AParent: TWinControl; ALeft, ATop, AWidth: Integer);
begin
  inherited Create;
  FOptions := TStringList.Create;
  FCheck := TCheckBox.Create(AParent);
  FCheck.Parent := AParent;
  FCheck.Caption := _('Use SSH tunnel');
  FCheck.AutoSize := True;
  FCheck.SetBounds(ALeft, ATop, 0, FCheck.Height);
  FCheck.OnClick := @CheckClick;
  FCheck.OnResize := @CheckResize;
  FButton := TBitBtn.Create(AParent);
  FButton.Parent := AParent;
  FButton.Caption := '...';
  FButton.Width := 21;
  FButton.Height := 23;
  FButton.OnClick := @ButtonClick;
  FSummary := TLabel.Create(AParent);
  FSummary.Parent := AParent;
  FSummary.AutoSize := False;
  FSummary.Font.Color := clGrayText;
  FSummary.Tag := ALeft + AWidth;   // right edge of the row
  CheckResize(nil);
end;

destructor TSSHTunnelRow.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

// the button and the summary follow the check box, whose width depends on the font and the translation
procedure TSSHTunnelRow.CheckResize(Sender: TObject);
begin
  FButton.SetBounds(FCheck.Left + FCheck.Width + 4, FCheck.Top + (FCheck.Height - FButton.Height) div 2,
    FButton.Width, FButton.Height);
  FSummary.SetBounds(FButton.Left + FButton.Width + 7, FCheck.Top + (FCheck.Height - FSummary.Height) div 2,
    Max(0, FSummary.Tag - (FButton.Left + FButton.Width + 7)), FSummary.Height);
end;

procedure TSSHTunnelRow.UpdateSummary;
var
  S: String;
begin
  S := FOptions.Values['SSH_HOST'];
  if S <> '' then
  begin
    if FOptions.Values['SSH_USER'] <> '' then
      S := FOptions.Values['SSH_USER'] + '@' + S;
    if FOptions.Values['SSH_PORT'] <> '' then
      S := S + ':' + FOptions.Values['SSH_PORT'];
  end;
  FSummary.Caption := S;
  FSummary.Enabled := FCheck.Checked;
end;

procedure TSSHTunnelRow.Changed;
begin
  UpdateSummary;
  if not FLoading and Assigned(FOnChange) then
    FOnChange(Self);
end;

function TSSHTunnelRow.Edit: Boolean;
var
  Dlg: TSSHTunnelForm;
begin
  Dlg := TSSHTunnelForm.Create(nil);
  try
    Dlg.LoadOptions(FOptions);
    Result := Dlg.ShowModal = mrOK;
    if Result then
      Dlg.SaveOptions(FOptions);
  finally
    Dlg.Free;
  end;
end;

procedure TSSHTunnelRow.CheckClick(Sender: TObject);
begin
  if FLoading then
    Exit;
  // checking the box without settings opens the dialog; cancelling it leaves the box unchecked
  if FCheck.Checked and (FOptions.Values['SSH_HOST'] = '') and not Edit then
  begin
    FLoading := True;
    try
      FCheck.Checked := False;
    finally
      FLoading := False;
    end;
    Exit;
  end;
  if FCheck.Checked then
    FOptions.Values['SSH_TUNNEL'] := 'Yes'
  else
    FOptions.Values['SSH_TUNNEL'] := 'No';
  Changed;
end;

procedure TSSHTunnelRow.ButtonClick(Sender: TObject);
begin
  if not Edit then
    Exit;
  FLoading := True;
  try
    FCheck.Checked := FOptions.Values['SSH_HOST'] <> '';
  finally
    FLoading := False;
  end;
  if FCheck.Checked then
    FOptions.Values['SSH_TUNNEL'] := 'Yes';
  Changed;
end;

procedure TSSHTunnelRow.Load(Options: TStrings);
begin
  CopySSHOptions(Options, FOptions);
  FLoading := True;
  try
    FCheck.Checked := SameText(FOptions.Values['SSH_TUNNEL'], 'Yes') and (FOptions.Values['SSH_HOST'] <> '');
  finally
    FLoading := False;
  end;
  UpdateSummary;
end;

procedure TSSHTunnelRow.Save(Options: TStrings);
var
  I: Integer;
begin
  for I := Options.Count - 1 downto 0 do
    if IsSSHOption(Options[I]) then
      Options.Delete(I);
  if FOptions.Values['SSH_HOST'] = '' then
    Exit;
  Options.AddStrings(FOptions);
end;

procedure TSSHTunnelRow.Clear;
begin
  FOptions.Clear;
  FLoading := True;
  try
    FCheck.Checked := False;
  finally
    FLoading := False;
  end;
  UpdateSummary;
end;

procedure TSSHTunnelRow.SetEnabled(Value: Boolean);
begin
  FCheck.Enabled := Value;
  FButton.Enabled := Value;
  FSummary.Enabled := Value and FCheck.Checked;
end;

end.
