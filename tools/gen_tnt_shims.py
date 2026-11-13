#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Write the compatibility units that replace the TNT Unicode Controls (app/compat/Tnt*.pas).

The LCL is Unicode throughout, so every TTntFoo is simply an alias of the LCL
class TFoo. The units keep the original names, so `uses TntStdCtrls, ...` in the
ported code stays untouched. Extend the tables when the port needs more.

  python tools/gen_tnt_shims.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "compat")

# shim unit -> (LCL units to use, {TTntX: LCL class}, extra interface/implementation text)
UNITS = {
    "TntClasses": (["Classes"], {
        "TTntStringList": "TStringList", "TTntStrings": "TStrings",
        # Delphi's WideStrings unit; TNT re-exported it
        "TWideStringList": "TStringList", "TWideStrings": "TStrings", "TTntFileStream": "TFileStream",
        "TTntMemoryStream": "TMemoryStream", "TTntResourceStream": "TResourceStream"}),
    "TntStdCtrls": (["StdCtrls", "ComCtrls"], {
        "TTntLabel": "TLabel", "TTntEdit": "TEdit", "TTntMemo": "TMemo", "TTntComboBox": "TComboBox",
        "TTntCustomComboBox": "TCustomComboBox", "TTntButton": "TButton", "TTntCheckBox": "TCheckBox",
        "TTntRadioButton": "TRadioButton", "TTntGroupBox": "TGroupBox", "TTntListBox": "TListBox"}),
    "TntCheckLst": (["CheckLst"], {"TTntCheckListBox": "TCheckListBox"}),
    "TntExtCtrls": (["ExtCtrls"], {
        "TTntShape": "TShape", "TTntPaintBox": "TPaintBox", "TTntImage": "TImage", "TTntBevel": "TBevel",
        "TTntPanel": "TPanel", "TTntSplitter": "TSplitter"}),
    "TntForms": (["Types", "Forms"], {
        "TTntFrame": "TFrame", "TTntScrollBox": "TScrollBox"}),
    "TntComCtrls": (["Classes", "Controls", "ExtCtrls", "ComCtrls", "StdCtrls"], {
        "TTntPageControl": "TPageControl", "TTntTabSheet": "TTabSheet", "TTntTabControl": "TTabControl",
        "TTntTreeView": "TTreeView", "TTntTreeNode": "TTreeNode", "TTntListView": "TListView",
        "TTntListItem": "TListItem", "TTntStatusBar": "TStatusBar", "TTntProgressBar": "TProgressBar",
        "TTntUpDown": "TUpDown",
        # no TRichEdit in the LCL (the RichMemo package has one); a Memo is the closest built-in
        "TTntRichEdit": "TMemo"}),
    "TntButtons": (["Buttons"], {"TTntSpeedButton": "TSpeedButton", "TTntBitBtn": "TBitBtn"}),
    "TntGrids": (["Grids"], {"TTntStringGrid": "TStringGrid"}),
    "TntMenus": (["Menus"], {"TTntMenuItem": "TMenuItem", "TTntMainMenu": "TMainMenu", "TTntPopupMenu": "TPopupMenu"}),
    "TntActnList": (["ActnList"], {"TTntAction": "TAction", "TTntActionList": "TActionList"}),
    "TntDialogs": (["Dialogs"], {"TTntOpenDialog": "TOpenDialog", "TTntSaveDialog": "TSaveDialog"}),
    "TntRegistry": (["Registry"], {"TTntRegistry": "TRegistry"}),
}

# TTntForm is a class of its own (not an alias) for one difference between the VCL and the LCL.
FORM_DECL = """  { The VCL shows a form whose Position is poDesigned on the monitor that DefaultMonitor names (dmActiveForm by
    default); the LCL ignores DefaultMonitor for poDesigned. With several monitors such dialogs therefore opened at
    their designed coordinates, usually on the primary monitor, wherever the main window was. On its first show the
    form is now moved to that monitor, keeping its position relative to the monitor. A position restored from the
    options (PositionRestored, set by SetWinPos) is left alone. }
  TTntForm = class(TForm)
  private
    FMonitorPlaced: Boolean;
  protected
    procedure MoveToDefaultPosition; override;
  public
    PositionRestored: Boolean;
  end;
"""

FORM_IMPL = """procedure TTntForm.MoveToDefaultPosition;
var
  Target, Current: TMonitor;
  Work: TRect;
  X, Y: Integer;
begin
  inherited MoveToDefaultPosition;

  if FMonitorPlaced or not Visible then
    Exit;
  FMonitorPlaced := True;
  if (Position <> poDesigned) or (DefaultMonitor = dmDesktop) or PositionRestored or (Screen.MonitorCount < 2) or
    (Parent <> nil) or (ParentWindow <> 0) or (WindowState <> wsNormal) or (Application.MainForm = nil) or
    (Application.MainForm = Self) then
    Exit;

  case DefaultMonitor of
    dmPrimary:
      Target := Screen.PrimaryMonitor;
    dmMainForm:
      Target := Application.MainForm.Monitor;
  else
    if (Screen.ActiveCustomForm <> nil) and (Screen.ActiveCustomForm <> Self) then
      Target := Screen.ActiveCustomForm.Monitor
    else
      Target := Application.MainForm.Monitor;
  end;
  Current := Screen.MonitorFromRect(BoundsRect);
  if (Target = nil) or (Target = Current) then
    Exit;

  X := Left;
  Y := Top;
  if Current <> nil then
  begin
    X := X - Current.Left + Target.Left;
    Y := Y - Current.Top + Target.Top;
  end;
  Work := Target.WorkareaRect;
  if X + Width > Work.Right then
    X := Work.Right - Width;
  if X < Work.Left then
    X := Work.Left;
  if Y + Height > Work.Bottom then
    Y := Work.Bottom - Height;
  if Y < Work.Top then
    Y := Work.Top;
  SetBounds(X, Y, Width, Height);
end;
"""

HEADER = "{ GENERATED by tools/gen_tnt_shims.py -- do not edit. Replaces the TNT Unicode Controls unit of the same name:\n  the LCL is Unicode, so the TNT classes are plain aliases of the LCL classes. }\n"


def write_unit(name, uses, aliases, extra_decl="", extra_impl=""):
    lines = [HEADER.rstrip("\n"), "{ SPDX-License-Identifier: GPL-2.0-or-later }", "unit %s;" % name, "",
             "{$mode delphi}", "", "interface", "",
             "uses", "  " + ", ".join(uses) + ";", "", "type"]
    for k in sorted(aliases):
        lines.append("  %s = %s;" % (k, aliases[k]))
    if extra_decl:
        lines += ["", extra_decl.rstrip("\n")]
    lines += ["", "implementation", ""]
    if extra_impl:
        lines += [extra_impl.rstrip("\n"), ""]
    lines += ["end.", ""]
    with open(os.path.join(OUT, name + ".pas"), "w", newline="\n") as fh:
        fh.write("\n".join(lines))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (uses, aliases) in UNITS.items():
        decl = impl = ""
        if name == "TntForms":
            decl = FORM_DECL + ("\n{ TNT's TntApplication gave access to Unicode versions of the Application methods }\n"
                                "function TntApplication: TApplication;")
            impl = FORM_IMPL + "\nfunction TntApplication: TApplication;\nbegin\n  Result := Application;\nend;\n"
        if name == "TntComCtrls":
            decl = ("{ The VCL's ComCtrls.TAnimate plays an AVI resource (the busy indicator). The LCL has no\n"
                    "  equivalent; this placeholder keeps the properties the ported code uses and shows nothing\n"
                    "  yet. ROADMAP: rebuild the animation. Declared here because every ported unit that uses\n"
                    "  TAnimate also uses TntComCtrls. }\n"
                    "type\n"
                    "  TAnimate = class(TPanel)\n"
                    "  private\n"
                    "    FResName: String;\n"
                    "    FActive: Boolean;\n"
                    "  public\n"
                    "    constructor Create(AOwner: TComponent); override;\n"
                    "    procedure Play(FromFrame, ToFrame: Word; Count: Integer);\n"
                    "    procedure Stop;\n"
                    "    property ResName: String read FResName write FResName;\n"
                    "    property Active: Boolean read FActive write FActive;\n"
                    "  end;")
            impl = ("constructor TAnimate.Create(AOwner: TComponent);\n"
                    "begin\n"
                    "  inherited Create(AOwner);\n"
                    "  BevelOuter := bvNone;\n"
                    "  Caption := '';\n"
                    "end;\n"
                    "\n"
                    "procedure TAnimate.Play(FromFrame, ToFrame: Word; Count: Integer);\n"
                    "begin\n"
                    "  FActive := True;\n"
                    "end;\n"
                    "\n"
                    "procedure TAnimate.Stop;\n"
                    "begin\n"
                    "  FActive := False;\n"
                    "end;\n")
        write_unit(name, uses, aliases, decl, impl)
    print("wrote %d units to %s" % (len(UNITS), OUT))


if __name__ == "__main__":
    main()
