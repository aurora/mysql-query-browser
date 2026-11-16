{ SPDX-License-Identifier: GPL-2.0-or-later }
unit UpdateCheck;

{$mode delphi}

// Update check through Velopack (ADR-0018). The Velopack library is velopack-pas (third_party/velopack-pas),
// the releases are the GitHub releases of this project. Everything is optional at run time: without
// velopack_libc.dll next to the program, StartupVelopack returns and "Check for Updates ..." stays disabled.

interface

const
  UpdateRepositoryUrl = 'https://github.com/aurora/querymole';     // CommonFuncs.RevivalProjectUrl (ADR-0030)

  // Switched on again by ADR-0037 (ADR-0026 had hidden it for the first alpha). The item is disabled when the
  // Velopack library is missing (development builds, packages built without --velopack).
  UpdateMenuVisible = True;

  // Developer override of the feed (ADR-0037): a local folder or URL with a vpk release instead of the GitHub
  // releases, for testing an update cycle without publishing.
  UpdateUrlEnvironment = 'QBR_UPDATE_URL';

// First statement of the program, before the GUI is initialised: lets Velopack handle the install, update
// and uninstall launches (it may end the process) and applies a downloaded update on startup.
procedure StartupVelopack;

// True if the Velopack library was found; the menu item is enabled only then.
function UpdatesAvailable: Boolean;

// Menu command: asks whether there is a newer release and, if the user agrees, downloads it, restarts the
// program and lets Velopack replace the installation.
procedure CheckForUpdatesInteractive;

// Developer mode --selftest-update <report> (ADR-0037): the same steps without dialogs. Writes the installed
// version and the result of the check to the report; if there is an update, downloads it and starts the
// updater, which replaces the installation after this process has ended (no restart).
procedure RunUpdateSelftest(const ReportFile: String);

implementation

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  Classes, SysUtils, Controls, Forms, StdCtrls, ComCtrls, Dialogs, gnugettext, CommonFuncs,
  Velopack.Types, Velopack.App, Velopack.Updater, Velopack.Manager;

// An AppImage is updated by replacing its file, which needs write access to its folder. Velopack would then ask
// for pkexec, but its confirmation dialog cannot open on Linux (vpk 1.3.39, docs/linux-port.md), so the update
// fails after the download. Returns False and the folder if the running AppImage lies in a folder that is not
// writable; True everywhere else (Windows, macOS, a program started outside an AppImage).
function UpdateFolderWritable(out Folder: String): Boolean;
begin
  Folder := '';
  Result := True;
  {$IFDEF UNIX}
  if GetEnvironmentVariable('APPIMAGE') <> '' then
  begin
    Folder := ExtractFileDir(GetEnvironmentVariable('APPIMAGE'));
    Result := fpAccess(Folder, W_OK) = 0;
  end;
  {$ENDIF}
end;

function NotWritableMessage(const Version, Folder: String): String;
begin
  Result := Format(_('Version %s is available, but it cannot be installed automatically: the folder %s is not ' +
    'writable.'), [Version, Folder]) + LineEnding + LineEnding +
    Format(_('Move the AppImage to a folder you can write to and check again, or download the new version from %s.'),
    [UpdateRepositoryUrl + '/releases']);
end;

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

procedure RunUpdateSelftest(const ReportFile: String);
var
  Report: TStringList;
  Manager: TUpdateManager;
  Info: TUpdateInfo;
  Url, Folder: String;
begin
  Report := TStringList.Create;
  try
    try
      if not GLibraryFound then
        raise Exception.Create('Velopack library not found');
      Url := GetEnvironmentVariable(UpdateUrlEnvironment);
      if Url = '' then
        raise Exception.Create(UpdateUrlEnvironment + ' is not set');
      Manager := TUpdateManager.Create(Url);
      try
        Report.Add('installed ' + Manager.CurrentVersion);
        if Manager.CheckForUpdates(Info) <> ucUpdateAvailable then
          Report.Add('no update')
        else
          try
            Report.Add('available ' + Info.TargetFullRelease.Version);
            if not UpdateFolderWritable(Folder) then
              Report.Add('not writable ' + Folder)
            else
            begin
              Manager.DownloadUpdates(Info);
              Report.Add('downloaded');
              Manager.WaitExitThenApplyUpdates(Info.TargetFullRelease, True, False);
              Report.Add('updater started');
            end;
          finally
            Info.Free;
          end;
      finally
        Manager.Free;
      end;
    except
      on E: Exception do
        Report.Add('error ' + E.ClassName + ': ' + E.Message);
    end;
    Report.SaveToFile(ReportFile);
  finally
    Report.Free;
  end;
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
    if GetEnvironmentVariable(UpdateUrlEnvironment) <> '' then
      FUpdater.UpdateUrl := GetEnvironmentVariable(UpdateUrlEnvironment)
    else
    begin
      FUpdater.GitHubRepoUrl := UpdateRepositoryUrl;
      // A pre-release (alpha, beta) is updated to newer pre-releases as well; a release only to releases.
      FUpdater.GitHubPrerelease := Pos('-', revival_version) > 0;
    end;
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
var
  Folder: String;
begin
  Screen.Cursor := crDefault;
  if AResult <> ucUpdateAvailable then
    MessageDlg(_('You are running the latest version.'), mtInformation, [mbOK], 0)
  else
    if not UpdateFolderWritable(Folder) then
      MessageDlg(NotWritableMessage(ATarget.Version, Folder), mtWarning, [mbOK], 0)
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
