#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Convert all Query Browser forms from legacy/ to app/forms/*.lfm and render each
one (and each tab page) to docs/reconstructed/ with tools/lfmview.

  python tools/convert_forms.py [FormName ...]

Prints the problems the LCL reported per form (unknown properties/classes); those
drive the property tables in dfm2lfm.py.
"""
import collections
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import dfm2lfm  # noqa: E402

COMMON = os.path.join(ROOT, "legacy", "mysql-gui-common", "source", "windows")
QB = os.path.join(ROOT, "legacy", "mysql-query-browser", "source", "windows")
OUT = os.path.join(ROOT, "app", "forms")
SHOTS = os.path.join(ROOT, "docs", "reconstructed")
FLAT = os.path.join(ROOT, "docs", "reconstructed", "_flat")
VIEWER = os.path.join(ROOT, "tools", "lfmview", "bin", "lfmview.exe")

# name -> source .dfm. The Query Browser's own files win over common/ ones.
FORMS = {
    "Main": os.path.join(QB, "Main.dfm"),
    "QueryBrowser": os.path.join(QB, "QueryBrowser.dfm"),
    "QueryBrowserOptionPages": os.path.join(QB, "QueryBrowserOptionPages.dfm"),
    "RegExTextImporter": os.path.join(QB, "RegExTextImporter.dfm"),
    "TableDrag": os.path.join(QB, "TableDrag.dfm"),
    # the program file compiles the shared About.pas/.dfm; QB/About.pas is an unused leftover
    "About": os.path.join(COMMON, "About.dfm"),
    "ConnectToInstance": os.path.join(COMMON, "ConnectToInstance.dfm"),
    "OptionsEditor": os.path.join(COMMON, "OptionsEditor.dfm"),
    "TextSearch": os.path.join(COMMON, "TextSearch.dfm"),
    "SchemaSelection": os.path.join(COMMON, "SchemaSelection.dfm"),
    "MySQLResultSetFieldViewer": os.path.join(COMMON, "MySQLResultSetFieldViewer.dfm"),
    "Progress": os.path.join(COMMON, "Progress.dfm"),
}

# Frames and the data module: converted for the app only (the viewer sees the
# frames expanded inside the forms).
FRAMES = {
    "AdvancedEdit": os.path.join(COMMON, "AdvancedEdit.dfm"),
    "TabHeader": os.path.join(COMMON, "TabHeader.dfm"),
    "SchemataTreeView": os.path.join(COMMON, "SchemataTreeView.dfm"),
    "EditorTable": os.path.join(COMMON, "EditorTable.dfm"),
    "ApplicationDataModule": os.path.join(QB, "ApplicationDataModule.dfm"),
}


def main():
    names = sys.argv[1:] or list(FORMS)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SHOTS, exist_ok=True)
    os.makedirs(FLAT, exist_ok=True)
    if not sys.argv[1:]:
        for fname, fsrc in FRAMES.items():
            dfm2lfm.convert_file(fsrc, os.path.join(OUT, fname + ".lfm"), [QB, COMMON])
    summary = collections.OrderedDict()
    for name in names:
        src = FORMS[name]
        dst = os.path.join(OUT, name + ".lfm")
        dfm2lfm.convert_file(src, dst, [QB, COMMON])                 # faithful: frames stay frames
        flat = os.path.join(FLAT, name + ".lfm")
        notes = dfm2lfm.convert_file(src, flat, [QB, COMMON], flatten=True)
        png = os.path.join(SHOTS, name + ".png")
        try:
            r = subprocess.run([VIEWER, flat, "--png", png, "--tabs"], capture_output=True, text=True, timeout=90)
            out = (r.stdout + r.stderr).strip().splitlines()
        except subprocess.TimeoutExpired:
            out = ["TIMEOUT"]
        issues = [l for l in out if not l.startswith("wrote ")]
        summary[name] = (notes, issues, [l for l in out if l.startswith("wrote ")])
    counts = collections.Counter()
    for name, (notes, issues, wrote) in summary.items():
        print("== %s  %s" % (name, wrote[0].split(" (")[1].rstrip(")") if wrote else "NO IMAGE"))
        for n in notes:
            print("   note:", n)
        for i in issues:
            print("   " + i)
            counts[i.split("Error reading ")[-1].split(": ", 1)[-1] if "Error reading" in i else i] += 1
    print("\nmost common problems:")
    for k, v in counts.most_common(25):
        print("  %3d  %s" % (v, k))


if __name__ == "__main__":
    main()
