{ SPDX-License-Identifier: GPL-2.0-or-later }
unit UpdateCheck;

{$mode delphi}

// Update check through Velopack (ADR-0018). The Velopack library is velopack-pas (third_party/velopack-pas),
// the releases are the GitHub releases of this project. Everything is optional at run time: without
// velopack_libc.dll next to the program, StartupVelopack returns and "Check for Updates ..." stays disabled.

interface

const
  UpdateRepositoryUrl = 'https://github.com/aurora/mysql-query-browser';

// First statement of the program, before the GUI is initialised: lets Velopack handle the install, update
// and uninstall launches (it may end the process) and applies a downloaded update on startup.
procedure StartupVelopack;

// True if the Velopack library was found; the menu item is enabled only then.
function UpdatesAvailable: Boolean;

// Menu command: asks whether there is a newer release and, if the user agrees, downloads it, restarts the
// program and lets Velopack replace the installation.
procedure CheckForUpdatesInteractive;

implementation

uses
  Classes, SysUtils, Controls, Forms, StdCtrls, ComCtrls, Dialogs, gnugettext,
  Velopack.Types, Velopack.App, Velopack.Updater;

type
  TUpdateDialogs = class
  private
    FUpdater: TVelopackUpdater;
    FProgress: TForm;
    FBar: TProgressBar;
    procedure HandleCheck(Sender: TObject; AResult: TUpdateCheckResult; const ATarget: TVelopackAsset);
    procedure HandleProgress(Sender: TObject; Percent: Integer);
    procedure HandleDownloaded(Sender: TObject);
    procedure HandleError(Sender: TObject; const AMessage: string);
    procedure ShowProgress;
    procedure CloseProgress;
  public
    destructor Destroy; override;
    procedure Run;
  end;

var
  GLibraryFound: Boolean = False;
  GDialogs: TUpdateDialogs = nil;

procedure StartupVelopack;
begin
  GLibraryFound := TVelopackApp.Run;
end;

function UpdatesAvailable: Boolean;
begin
  Result := GLibraryFound;
end;

procedure CheckForUpdatesInteractive;
begin
  if not GLibraryFound then
    Exit;
  if GDialogs = nil then
    GDialogs := TUpdateDialogs.Create;
  GDialogs.Run;
end;

{ TUpdateDialogs }

destructor TUpdateDialogs.Destroy;
begin
  CloseProgress;
  FUpdater.Free;
  inherited Destroy;
end;

procedure TUpdateDialogs.Run;
begin
  if FUpdater = nil then
  begin
    FUpdater := TVelopackUpdater.Create(nil);
    FUpdater.GitHubRepoUrl := UpdateRepositoryUrl;
    FUpdater.OnCheckCompleted := HandleCheck;
    FUpdater.OnDownloadProgress := HandleProgress;
    FUpdater.OnDownloadCompleted := HandleDownloaded;
    FUpdater.OnError := HandleError;
  end;
  if FUpdater.Busy then
    Exit;
  Screen.Cursor := crHourGlass;
  try
    FUpdater.CheckForUpdates;
  except
    Screen.Cursor := crDefault;
    raise;
  end;
end;

procedure TUpdateDialogs.HandleCheck(Sender: TObject; AResult: TUpdateCheckResult; const ATarget: TVelopackAsset);
begin
  Screen.Cursor := crDefault;
  if AResult <> ucUpdateAvailable then
    MessageDlg(_('You are running the latest version.'), mtInformation, [mbOK], 0)
  else
    if MessageDlg(Format(_('Version %s is available. Download and install it now?'), [ATarget.Version]),
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      ShowProgress;
      FUpdater.DownloadUpdates;
    end;
end;

procedure TUpdateDialogs.HandleProgress(Sender: TObject; Percent: Integer);
begin
  if FBar <> nil then
    FBar.Position := Percent;
end;

procedure TUpdateDialogs.HandleDownloaded(Sender: TObject);
begin
  CloseProgress;
  if MessageDlg(_('The update has been downloaded. The program has to restart to install it. Restart now?'),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    // The updater waits for this process to end, installs the update and starts the program again.
    FUpdater.ApplyUpdatesAndRestart;
    Application.Terminate;
  end;
  // Otherwise the downloaded update is applied the next time the program starts.
end;

procedure TUpdateDialogs.HandleError(Sender: TObject; const AMessage: string);
begin
  Screen.Cursor := crDefault;
  CloseProgress;
  MessageDlg(_('The update check failed.') + LineEnding + LineEnding + AMessage, mtError, [mbOK], 0);
end;

procedure TUpdateDialogs.ShowProgress;
var
  Caption: TLabel;
begin
  CloseProgress;
  FProgress := TForm.CreateNew(nil);
  FProgress.BorderStyle := bsDialog;
  FProgress.BorderIcons := [];
  FProgress.Position := poMainFormCenter;
  FProgress.Caption := _('Downloading update');
  FProgress.ClientWidth := 360;
  FProgress.ClientHeight := 64;
  Caption := TLabel.Create(FProgress);
  Caption.Parent := FProgress;
  Caption.SetBounds(12, 10, 336, 16);
  Caption.Caption := _('Downloading the update ...');
  FBar := TProgressBar.Create(FProgress);
  FBar.Parent := FProgress;
  FBar.SetBounds(12, 34, 336, 18);
  FBar.Max := 100;
  FProgress.Show;
end;

procedure TUpdateDialogs.CloseProgress;
begin
  FBar := nil;
  FreeAndNil(FProgress);
end;

initialization

finalization
  GDialogs.Free;

end.
