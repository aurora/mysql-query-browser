<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# Linux port: Windows API in the ported units

Inventory for ROADMAP step 5 (platform guards), sorted by the kind of work it needs, and the state
of that work. Regenerate the raw list inside the `freepascal` distrobox:

```
python tools/winapi_usage.py            # per unit: Windows units in `uses`, Windows-only identifiers
python tools/winapi_usage.py --where    # ... and the routines they are used in
python tools/winapi_usage.py --all      # ... and the identifiers the LCL/RTL covers as well
```

The script compares the identifiers of each unit with the declarations of FPC's Windows units
(`Windows`, `ShellAPI`, `ShlObj`, `ActiveX`, `CommCtrl`, `WinInet`, `WinSock`, the Windows part of
`SysUtils`) and the unit's own `external '*.dll'` imports, minus what the LCL, LazUtils,
VirtualTreeView, SynEdit and the portable RTL declare. Outside Windows the LCL ships its own
`Messages` unit (`lcl/nonwin32`) with the common `WM_*` constants and `TWM*` records, so those
count as portable. A trial build with the Windows units swapped for `LCLIntf`/`LCLType` confirmed the
list for `AuxFuncs` (the first unit the compiler reaches).

Conditional compilation is evaluated as for Linux, so guarded code no longer counts. Known false
positives: `password` (`with` fields in `ConnectToInstance`, `OptionsEditor`) and `IID` (a parameter
name in `CommonTypes`). The script does not see Windows *behaviour* behind portable names; see "Not
visible to the script" below.

## State (2026-10-30)

Sections 1 to 3 and the path separators of section 5 are done: `qbr` compiles and links on Linux
(GTK2), the script reports no Windows-only identifiers any more, and `tests/run-matrix.sh` passes on
all six servers including the application's `--selftest-connect` and `--selftest-dialog`. The main
window opens against a live server (schema tree, toolbar, SQL highlighting, help from the server).

How it is done:

- `uses Windows` became `{$IFDEF MSWINDOWS}Windows{$ELSE}LCLIntf, LCLType, WinAliases, Types{$ENDIF}`;
  the other Windows units are guarded the same way (`ActiveX` becomes VirtualTreeView's
  `laz.FakeActiveX`). `Messages` stays: the LCL has its own outside Windows.
- `app/compat/WinAliases.pas` (non-Windows only) holds Windows names that the LCL has under another
  name with the same meaning (`WM_TIMER`, `TWMTimer`, `CF_UNICODETEXT`, `GetTextExtentPoint32W`,
  `DrawTextW`, `MessageBoxW`, ...). Windows-only behaviour is never emulated there; it is guarded with
  `{$IFDEF MSWINDOWS}` where it is used, with a `// Port:` comment.
- **The Windows build is unchanged:** a Win64 cross-build of the changed tree has the same `.text`,
  `.data`, `.rdata`, `.idata` and `.rsrc` as one of the previous commit (stripped executables); the only
  difference in the object files is the removed, never called `AuxFuncs.GetTimeBias`. Path literals
  are written as `('fonts' + PathDelim)` for that reason: FPC folds the parenthesised constant, not
  `X + 'fonts' + PathDelim`. Check it the same way after changes to shared code (section "Checking the
  Windows build").

Interim behaviour until the decisions in section 4:

- Data directory: `~/.mysqlgui/`, the folder of the original Linux version (ADR-0019, decision 4.1).
- Long statements are cancelled on the server with `KILL QUERY` over a second connection, guarded so
  that no other statement can be hit (ADR-0020, decision 4.2), on Linux and Windows. The connect and
  ping threads of the connect dialog are still not killed outside Windows; freeing them waits.
- No global hot keys outside Windows (4.3).

**64-bit pointer arithmetic (fixed).** Query results stayed empty on Linux: the ported code walked
the C arrays with `Integer(Pointer) + n`, which keeps only the low 32 bits of an address (sign
extended, `movslq` in the Win64 code). On Linux the C heap lies above 4 GB, so it failed at once; on
Win64 it worked only while the heap stayed below 4 GB. Now `PtrUInt(Pointer) + n` in
`MySQLResultSetControls`, `MySQLResultSet`, `EditorTable`, `QueryBrowser`, `EditorTableVTEdit`,
`OptionsEditor`; the hash tries in `LexicalTools`/`StringContainers` keep their `PChar` keys as
`PtrUInt` instead of `Cardinal`; `LexicalTools` seeks by a `PByte` difference; `EM_SETRECTNP` gets
`LPARAM(@R)`. This deliberately changes the Windows build in exactly these units. FPC's warnings 4056
and 4082 (`-vw`) find such places; the one left (`LexicalTools`, an ID stored in `Objects[]`) is
harmless. Results, non-ASCII text, NULL and schema expansion checked by screenshot under GTK2.

**Main window checked under GTK2 (2026-10-30)**, by screenshot with the developer modes (`--sql`,
`--cmd edit,setcell,apply`, `--script`, `--cmd explain`, `--dialog ...`, `--help-page`, `--upper-tab`,
`--expand`, `--dblclick-table`, `--modal-shot`) against MySQL 8.4 with a small test schema:

| Area | Result |
|---|---|
| Result grid, navigation bar (Edit/Apply/Discard/First/Last/Search), status text | works |
| Edit mode; apply with server error (error list), apply that succeeds (row changed in the database) | works |
| EXPLAIN panel, export to CSV/HTML/XML (UTF-8 content correct), modal error dialog | works |
| Script tab: breakpoint stop, script with error (error list), progress bar | works after fix 1 |
| Tab headers (faded icons of inactive tabs) | works after fix 2 |
| Options dialog: page "Browser" (from `QueryBrowserOptionPages`) | works after fix 3; General, Connections, Editors were fine |
| Text search, RegEx importer, schema selection, inline help, history, table double click | works |
| Compare without a second result set | shows the original's message |

Fixes:

1. `THandle` is a 32-bit `Longint` on Linux (64-bit on Win64), so `GetWideStringTextWidth(DC: THandle)`
   cut the device context pointer and the measuring failed; the script panel's progress bar got
   `Left=32769` and raised `ELayoutException`. Now `HDC` (also `LastFont: HGDIOBJ` in the inline editors).
   Same type on Windows.
2. `TPNGObject.DrawPartialTrans` read the pixels through `TLazIntfImage.LoadFromBitmap`, which
   misreads the GTK2 device bitmap (smeared icons); outside Windows it reads them from the PNG.
   `TPNGObject.Draw` now follows the original library: images with alpha are drawn at native size at
   `Rect.Left/Top` (callers pass `Rect(X, Y, Width, Height)`), others stretched. **This changes the
   Windows build** (the only difference in the Win64 objects: `PNGImage`); before, those icons were
   stretched into the odd rectangles there too.
3. A tab sheet that moves into another notebook loses `TabVisible` in the LCL, so GTK2 never added it
   (Win32 shows it as a child window anyway), and the page that takes over index 0 is not switched to.
   `OptionsEditor.BuildOptionSideBar` sets `TabVisible` again and selects another page first (non-Windows).

Still open, cosmetic: in the options dialog a few pixels of the hidden notebook tabs show above
`HeaderPnl` (GTK2 tabs are taller than the 16 pixels the original hides). Not checked yet: real
keyboard/mouse interaction, drag and drop, bookmarks, the field viewer, the Qt5 widgetset.

## Summary before the port (2026-10-30)

- 40 files have Windows units in their `uses` clauses.
- **22 files need only the `uses` clause changed** (plus the three with false positives).
- About **95 Windows-only identifiers** in 16 units remain, ~200 uses. `AuxFuncs` (46) and
  `QueryBrowser` (23) hold most of them.
- Four topics need a decision before code is written (section 4).

## 1. `uses` clause only

`ColorTools`, `CommonFuncs`, `AdvancedEdit`, `InstanceSections`, `MySQLResultSet`,
`MySQLResultSetFieldViewer`, `QueryBrowserOptionPages`, `RegExTextImporter`, `SQLErrorGrid`,
`SchemaSelection`, `ScriptPanel`, `Sections`, `SqlCmdPanel`, `StringContainers`, `TabHeader`,
`TableDrag`, `TextSearch`, `Toolbar`, `UniCodeConsole`, `qbr.lpr`, `compat/PNGImage`,
`compat/TntRegistry`; also `CommonTypes`, `OptionsEditor` (false positives only).

`Windows` becomes `LCLIntf, LCLType` (on all platforms, or `{$IFDEF MSWINDOWS}Windows,{$ENDIF}` where
Windows-only code stays); `Messages` can stay. FPC's `Registry` (and with it the `TntRegistry` shim)
compiles on Linux, where it stores into an XML file; units that use `HKEY_*` constants need `Registry`
in their own `uses`.

## 2. Direct replacements (same behaviour)

| Windows | Replacement | Where |
|---|---|---|
| `WM_DESTROY`/`TWMDestroy`, `WM_TIMER`/`TWMTimer` | `LM_DESTROY`/`TLMDestroy`, `LM_TIMER`/`TLMTimer` | grid edit links, `QueryBrowser`, `SchemataTreeView` |
| `CF_UNICODETEXT` | `CF_TEXT` (LCL clipboard text is UTF-8) | `Main`, `QueryBrowser` |
| `IDC_APPSTARTING`, `IDC_ARROW` + `SetCursor` | `Screen.Cursor := crAppStart / crDefault` | `QueryBrowser.DoQueryExecute(d)` |
| `MessageBoxW` | `Application.MessageBox` | `LexicalTools.TDelphiLexer.LexerError` |
| `IsEqualIID` | `IsEqualGUID` (SysUtils) | `QueryBrowser` |
| `IDataObject` (ActiveX) in VirtualTreeView handlers | the type from `laz.FakeActiveX`, e.g. an alias in `compat/VTCompat` | `EditorTable`, `MySQLResultSetControls`, `QueryBrowser`; check with `tools/check_handlers.py` |
| `ExtTextOutW`, `DrawTextW`, `GetTextExtentPoint32W`, `Get/SetTextAlign` | LCL `ExtTextOut`/`DrawText`/`GetTextExtentPoint` with UTF-8 strings | `AuxFuncs.DrawWideStringText`, `GetWideStringTextWidth`, `TMyxModalDialog.Create`, `MenuMeasureItem` (2x), `AutoAdjustSize` (3x) |
| `ShellExecuteW` | `LCLIntf.OpenURL` | `AuxFuncs.BrowseWebPage` |
| `SHGetSpecialFolderLocation(CSIDL_PERSONAL)` | `GetUserDir` | `AuxFuncs.GetHomeDir` |
| `WideCompareText(.., LOCALE_USER_DEFAULT)` | without the locale argument | `SchemataTreeView.CatalogVSTCompareNodes` |
| `GetLocaleFormatSettings(LANG_ENGLISH)` | explicit English `TFormatSettings` (must equal the Windows values) | `Options.TMyxOptions.Create` |
| `CreateProcessW` + `WaitForSingleObject` | `TProcess` (FCL); the old `{$IFDEF LINUX}` branch refers to Kylix's `TCmdExecThread` and has to go | `AuxFuncs.CreateSubProcess` (restart after error, new instance) |
| `PrintWindow` (user32.dll) | `TWinControl.PaintTo` / `GetFormImage` | `DevTools.CaptureWindowToPng` (developer modes only) |

## 3. Windows-only features: guard, no-op elsewhere

None of these changes what a Linux user sees compared to a feature that does not exist there; they
are listed so that each guard is a deliberate choice.

| Feature | Where | On Linux |
|---|---|---|
| Version checks `IsWinXP`, `IsWin2k`, `IsWinNT`, `IsWin2kOrXP`, `getXPStyleEnabled` (`Win32Platform`, `GetVersion(Ex)`) | `AuxFuncs`; callers in `About`, `AdvancedEdit`, `Options`, `Sections`, `QueryBrowser` | return False (`getXPStyleEnabled`: check what the themed drawing paths look like under GTK2 first) |
| Drop shadow `CS_DROPSHADOW` | `About.CreateParams` | skip |
| ClearType check `FE_FONTSMOOTHINGCLEARTYPE` | `AuxFuncs.InitGlobalVars` | skip |
| `GetSystemDirectory`, `GetWindowsDirectory` | `AuxFuncs`; `Main` checks for `cmd.exe` | return ''; the "Windows command line" menu item already disables itself when `cmd.exe` is missing |
| Online check `InternetGetConnectedState` (WinInet) | `AuxFuncs.IsConnectedToInternet` → `Main` (Report bug, Check for updates) | return True |
| File associations `RegisterFileType` (registry + `SHChangeNotify`) | `Main` | packaging (`.desktop`, MIME types) instead |
| MySQL installations from the registry (`RegOpenKeyExW`, ...; `mysql.exe`, Administrator path, `RegisterMySQLApplication`) | `MySQLCommonFuncs` | `RegisterMySQLApplication` no-op; command line client from `PATH` (`mysql`/`mariadb`) |
| Running-instance list in shared memory (`CreateFileMapping`, `MapViewOfFile`) | `AppInstanceMgmt`; `Main.WMInitMenuPopup` fills the Window menu | no-op. `RegisterApplication` is never called in the port, so the list is empty on Windows too |
| `EM_SETRECTNP`, `EM_SCROLLCARET`, `WM_SETREDRAW` on the inline editors | `EditorTableVTEdit`, `EditorTableVTFKEdit`, `MySQLResultSetControls` | skip; check the editors' margins and flicker visually |
| `GetCharFromVKey` (`ToAscii`, `MapVirtualKey`) to detect `(` while typing | `AuxFuncs`, used in `EditorTableVTEdit` | use the character from `KeyPress`/`UTF8KeyPress` instead of the virtual key |
| Private fonts `AddFontResourceExW` (gdi32.dll) | `Main.CheckFonts` | fontconfig: `FcConfigAppFontAddFile`, or ship the Vera fonts with the package |
| `GetTimeBias` | `AuxFuncs` | unused; remove (porting convention) |

## 4. Needs a decision (ADR candidates)

1. **User data directory (decided: ADR-0019, the original's folder).** Windows: `%APPDATA%\MySQL\` (`Options.TMyxOptions.Create`). The original
   Linux Query Browser used `~/.mysqlgui` (`legacy/mysql-gui-common/source/linux/MGPreferences.cc`), the
   desktop convention is `$XDG_CONFIG_HOME/<name>`. Reading an existing `~/.mysqlgui` would carry
   over connections from the old Linux version.
2. **Stopping hanging threads (decided: ADR-0020, cancel on the server).** `TerminateThread` kills
   query, connect and ping threads after a timeout (`MySQLConnection.ClearWorkList`, `FetchData`,
   `StopCurrentThread`; `ConnectToInstance` 3x). POSIX has no safe equivalent. Options: cancel on
   the server (`KILL QUERY` over a second connection), close the socket (`mariadb_cancel`) and then
   wait, or abandon the thread. The same change would make Windows safer (killing a thread inside
   libmysql can leave locks held). Implemented for the `MySQLConnection` threads and the query Stop
   button (`app/src/QueryCancel.pas`, tests in `tests/test_cancel.pas`); the `ConnectToInstance`
   threads run no statement and are unchanged.
3. **Global copy/paste hotkeys.** `QueryBrowser.FormCreate`/`WMHotKey` registers Ctrl+Alt+Shift+C/V
   system-wide and sends keystrokes to the foreground application (`RegisterHotKey`, `keybd_event`,
   `AttachThreadInput`). X11 can do something similar, Wayland cannot. Probably Windows-only; the
   related option ("copy SQL mode") would then do nothing on Linux.
4. **"OS specific" password storage (decided: ADR-0021, not offered outside Windows).** Windows uses DPAPI in the
   backend (`myx_xml_user_connections.c`); elsewhere the backend calls `os_password_store_function` /
   `os_password_retrieve_function` hooks, which the original Linux UI filled with GNOME Keyring and which the
   port never sets (a Linux build would have stored clear text). `Options` now lists the choice on Windows
   only; libsecret / Keychain are deferred.

## 5. Not visible to the script

- **Path separators.** Hard-coded `\` in paths: `Options` (`'MySQL\'`, `'XML\'`,
  `'locale\...\LC_MESSAGES\'`, the `-datadir` handling), `OptionsEditor` (`'fonts\VeraMono.ttf'`),
  `Main` (`'fonts\'`). Use `PathDelim` / `IncludeTrailingPathDelimiter`. `MySQLCommonFuncs` and the
  registry keys in `AuxFuncs` are Windows-only anyway.
- **Case-sensitive file names** for the runtime folder (`XML/`, `locale/`, `fonts/`) and resources.
- **Window messages through portable calls.** `SendMessage`/`PostMessage` with Windows messages
  compile but may do nothing under GTK2 (e.g. `WM_SETREDRAW`, `WM_COPY`/`WM_PASTE` to foreign
  windows); about 70 lines in `CommonTypes`, the grid edit links, `MySQLConnection`, `QueryBrowser`,
  `Main`. Messages the program posts to its own forms (`WM_USER + n`) work with the LCL.
- **`LoadCursor(HInstance, ...)`** for the drag cursors in `QueryBrowser.FormCreate`: declared by
  the LCL, but whether GTK2 loads cursors from the `.res` needs a test.
- **`CreateParams`** overrides (window class styles) have no effect outside Windows.

## Checking the Windows build

Inside the `freepascal` distrobox (`fpc-units-x86_64-win64` installed by `tools/distrobox-setup.sh`;
the first run compiles the LCL for Win64):

```
# reference: the previous commit, in a scratch copy with the same app/res and third_party
lazbuild -B --os=win64 --cpu=x86_64 --ws=win32 --opt=-FU<lib-a> --opt=-o<a.exe> app/qbr.lpi
# the working tree
lazbuild -B --os=win64 --cpu=x86_64 --ws=win32 --opt=-FU<lib-b> --opt=-o<b.exe> app/qbr.lpi
# compare the stripped executables section by section
x86_64-w64-mingw32-strip -o a-s.exe a.exe   # same for b
x86_64-w64-mingw32-objcopy -O binary -j .text a-s.exe a.text   # .data .rdata .idata .rsrc likewise; cmp
# per unit, when they differ:
x86_64-w64-mingw32-objdump -d --no-addresses <lib-a>/Unit.o > a.dis   # same for b; diff
```

## Suggested order

1. ~~Sections 1 and 2 plus the `AuxFuncs` guards from section 3: the program compiles and the
   connect dialog runs.~~ Done, together with the rest of section 3 and the path separators.
2. ~~The 64-bit pointer arithmetic, so that results show.~~ ~~Check the main window's features by
   screenshot under GTK2.~~ Done (see "State"); interactive use on a real desktop is next.
3. ~~Decide 4.1 (data directory).~~ Done, ADR-0019.
4. ~~Decide and implement 4.2~~ (ADR-0020); ~~decide and implement 4.4~~ (ADR-0021); decide 4.3.
