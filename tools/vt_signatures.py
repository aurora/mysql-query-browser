#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Adapt the signatures of overridden VirtualTreeView methods in ported units.

The original code uses VirtualTreeView 4.x, Lazarus ships a port of a newer version whose
protected virtual methods differ slightly (const parameters, String instead of WideString,
a longer DoBeforeCellPaint). Overrides in tree subclasses must match exactly.

  python tools/vt_signatures.py app/src/Unit1.pas [Unit2.pas ...]

Idempotent; changes both the declarations and the implementation headers. The remaining
differences (event handler signatures such as OnGetText) are fixed by hand.
"""
import re
import sys


def adapt(text):
    n = 0

    def sub(pat, rep):
        nonlocal text, n
        text, c = re.subn(pat, rep, text, flags=re.S)
        n += c

    # drag and drop
    sub(r"(?<!const )\bPt: TPoint(;\s*var Effect: )Integer", r"const Pt: TPoint\1LongWord")
    sub(r"(?<!const )\bPt: TPoint(;\s*Mode: TDropMode;\s*var Effect: )Integer", r"const Pt: TPoint\1LongWord")
    # text
    sub(r"(DoGetText\([^)]*?TextType: TVSTTextType;\s*var\s+(?:Cell)?Text:\s*)WideString", r"\1String")
    sub(r"(DoNewText\(Node: PVirtualNode; Column: TColumnIndex;\s*)Text: WideString", r"\1const Text: String")
    sub(r"(DoGetNodeTooltip\([^)]*?TVTTooltipLineBreakStyle\)\s*:\s*)WideString", r"\1String")
    # rectangles
    sub(r"(DoAfterCellPaint\([^)]*?Column:\s*TColumnIndex;\s*)(?<!const )CellRect:\s*TRect", r"\1const CellRect: TRect")
    sub(r"(DoBeforeItemErase\([^)]*?Node: PVirtualNode;\s*)(?<!const )ItemRect: TRect", r"\1const ItemRect: TRect")
    # DoBeforeCellPaint has two more parameters
    sub(r"DoBeforeCellPaint\(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;\s*CellRect: TRect\)",
        "DoBeforeCellPaint(Canvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;\n"
        "      CellPaintMode: TVTCellPaintMode; CellRect: TRect; var ContentRect: TRect)")
    # clean up doubled const from overlapping patterns
    text = text.replace("const const ", "const ")
    return text, n


def main():
    for path in sys.argv[1:]:
        s = open(path, encoding="utf-8").read()
        new, n = adapt(s)
        if new != s:
            open(path, "w", encoding="utf-8", newline="\n").write(new)
        print("%s: %d change(s)" % (path, n))


if __name__ == "__main__":
    main()
