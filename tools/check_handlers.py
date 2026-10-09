#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Lists event handlers that the .lfm files assign by name and whose declaration mentions a string
type, e.g. `var CellText: WideString`. The LCL checks nothing when it binds a handler at load time,
so a signature that differs from the event type (WideString where laz.VirtualTrees has String) is
not a compile error but corrupts memory at run time.

  python tools/check_handlers.py
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
forms = os.path.join(ROOT, "app", "forms")
src = os.path.join(ROOT, "app", "src")

decl = {}
for p in glob.glob(os.path.join(src, "*.pas")):
    text = open(p, encoding="utf-8").read()
    for m in re.finditer(r"(?im)^\s*procedure\s+(\w+)\.(\w+)\s*(\([^)]*\))?\s*;", text):
        decl[m.group(2).lower()] = (os.path.basename(p), (m.group(3) or "").replace("\n", " "))

seen = set()
for lfm in sorted(glob.glob(os.path.join(forms, "*.lfm"))):
    for m in re.finditer(r"(?m)^\s*(On\w+)\s*=\s*(\w+)\s*$", open(lfm, encoding="utf-8").read()):
        ev, h = m.group(1), m.group(2)
        d = decl.get(h.lower())
        if not d or (h, ev) in seen:
            continue
        seen.add((h, ev))
        if re.search(r"(?i)string", d[1]):
            print("%-28s %-22s %-28s %s" % (os.path.basename(lfm), ev, h, re.sub(r"\s+", " ", d[1])))
