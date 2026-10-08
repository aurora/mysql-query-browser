#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""First, purely mechanical step of porting a Delphi unit from legacy/ to app/src/.

  python tools/port_unit.py MyxError [AuxApplicationFuncs ...]

Does only what never needs a decision: Windows-1252 -> UTF-8, CRLF -> LF, adds
`{$mode delphi}`, `{$R *.dfm}` -> `{$R ../forms/<Unit>.lfm}` (the generated forms live in app/forms),
`VirtualTrees` -> `laz.VirtualTrees, VTCompat`, drops the VCL-only `property OEMConvert;`.
Units that use TCreateParams or TLM* messages need `LCLType`/`LMessages` added by hand. Everything else (uses clauses,
Windows API calls, Delphi-only constructs) is fixed by hand while compiling, so the
result stays close to the original. The original licence header is kept.

An existing app/src/<Unit>.pas is never overwritten (it may contain edits).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from unit_deps import find_unit  # noqa: E402  (honours the program file's unit paths)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "src")


def port(name):
    src = find_unit(name)
    if not src:
        print("%s: not found" % name)
        return False
    dst = os.path.join(OUT, os.path.basename(src))
    if os.path.exists(dst):
        print("%s: %s exists, left alone" % (name, os.path.relpath(dst, ROOT)))
        return False
    text = open(src, encoding="cp1252", errors="replace").read().replace("\r\n", "\n").replace("\r", "\n")
    # {$mode delphi} right after the unit line
    text = re.sub(r"(?im)^(unit\s+[\w.]+\s*;[ \t]*\n)", r"\1\n{$mode delphi}\n", text, count=1)
    unit = os.path.splitext(os.path.basename(src))[0]
    text = re.sub(r"\{\$R\s+\*\.dfm\}", "{$R ../forms/%s.lfm}" % unit, text, flags=re.I)
    # VirtualTreeView: the Lazarus port has another unit name; VTCompat keeps the old class name
    text = re.sub(r"(?<![\w.])VirtualTrees(?![\w.])", "laz.VirtualTrees, VTCompat", text)
    # TCreateParams lives in LCLType, window message records (TWM*) are TLM* in LMessages
    if re.search(r"TCreateParams", text) and not re.search(r"LCLType", text):
        text = re.sub(r"(?im)^uses", "uses
  LCLType,", text, count=1)
    # VCL-only property of TEdit
    text = re.sub(r"(?m)^\s*property OEMConvert;\s*
", "", text)
    # the LCL has TJPEGImage in Graphics; there is no jpeg unit
    text = re.sub(r"(?i)(?<![\w.])jpeg\s*,\s*", "", text)
    text = re.sub(r"(?i),\s*jpeg(?=\s*;)", "", text)
    # TntMenus owner draw event -> LCL name (same parameter list)
    text = text.replace("OnAdvancedDrawItem", "OnDrawItem")
    os.makedirs(OUT, exist_ok=True)
    with open(dst, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("%s: -> %s (%d lines)" % (name, os.path.relpath(dst, ROOT), text.count("\n")))
    return True


if __name__ == "__main__":
    for n in sys.argv[1:]:
        port(n)
