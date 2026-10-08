#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Dependency closure of Delphi units in legacy/ (what has to be ported for a form).

  python tools/unit_deps.py ConnectToInstance [OtherUnit ...]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = [os.path.join(ROOT, "legacy", "mysql-query-browser", "source", "windows"),
        os.path.join(ROOT, "legacy", "mysql-gui-common", "source", "windows")]
# third-party / VCL units that are replaced rather than ported
KNOWN_REPLACED = {
    "windows", "messages", "sysutils", "variants", "classes", "graphics", "controls", "forms", "dialogs",
    "extctrls", "stdctrls", "comctrls", "buttons", "menus", "grids", "math", "contnrs", "strutils",
    "syncobjs", "clipbrd", "types", "imglist", "shellapi", "activex", "jpeg", "winsock", "registry",
    "inifiles", "printers", "commctrl", "richedit", "shlobj", "variants", "dateutils", "typinfo",
    "valedit", "checklst", "ole2", "olectrls", "mshtml", "shdocvw", "zlib", "xmldoc", "xmlintf", "db",
}


_DPR = None


def dpr_paths():
    """Unit name -> path as listed in the program file (`Unit in 'path'`): the files the
    original project really compiled. Needed because some unit names exist twice
    (e.g. About.pas in the Query Browser folder is an unused leftover)."""
    global _DPR
    if _DPR is None:
        _DPR = {}
        dpr = os.path.join(ROOT, "legacy", "mysql-query-browser", "source", "windows", "MySQLQueryBrowser.dpr")
        base = os.path.dirname(dpr)
        text = open(dpr, encoding="cp1252", errors="replace").read()
        for m in re.finditer(r"(\w+)\s+in\s+'([^']+)'", text):
            path = os.path.normpath(os.path.join(base, m.group(2).replace("\\", os.sep)))
            # the project tree had the shared library in "common"; here it is mysql-gui-common
            legacy = os.path.join(ROOT, "legacy") + os.sep
            if path.startswith(legacy + "common" + os.sep):
                path = legacy + "mysql-gui-common" + os.sep + path[len(legacy + "common" + os.sep):]
            _DPR[m.group(1).lower()] = path
    return _DPR


def find_unit(name):
    p = dpr_paths().get(name.lower())
    if p and os.path.exists(p):
        return p
    for d in DIRS:
        for root, _, files in os.walk(d):
            if "testing" in root or "GenericCanvas" in root:
                continue
            for f in files:
                if f.lower() == name.lower() + ".pas":
                    return os.path.join(root, f)
    return None


def uses_of(path):
    text = open(path, encoding="cp1252", errors="replace").read()
    text = re.sub(r"\{[^}]*\}|\(\*.*?\*\)|//[^\n]*", " ", text, flags=re.S)
    names = []
    for m in re.finditer(r"\buses\b(.*?);", text, flags=re.S | re.I):
        for n in m.group(1).split(","):
            n = re.sub(r"\s+in\s+'[^']*'", "", n.strip(), flags=re.I).strip()
            if re.match(r"^[A-Za-z_][\w.]*$", n):
                names.append(n)
    return names


def main():
    todo = sys.argv[1:]
    seen, order, missing, replaced = {}, [], set(), set()
    while todo:
        n = todo.pop(0)
        key = n.lower()
        if key in seen:
            continue
        if key in KNOWN_REPLACED:
            replaced.add(n)
            continue
        path = find_unit(n)
        if not path:
            missing.add(n)
            continue
        seen[key] = path
        order.append(n)
        todo.extend(uses_of(path))
    total = 0
    print("%-34s %7s  %s" % ("unit", "lines", "kind"))
    for n in order:
        path = seen[n.lower()]
        lines = sum(1 for _ in open(path, encoding="cp1252", errors="replace"))
        total += lines
        has_dfm = os.path.exists(path[:-4] + ".dfm")
        print("%-34s %7d  %s" % (n, lines, "form/frame" if has_dfm else ""))
    print("\n%d units, %d lines to port" % (len(order), total))
    print("replaced by LCL/FPC:", ", ".join(sorted(replaced, key=str.lower)))
    print("no source in repo (third party / generated):", ", ".join(sorted(missing, key=str.lower)))


if __name__ == "__main__":
    main()
