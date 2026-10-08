#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Which routines/types declared in the interface of a legacy unit are used by the rest of
the units a program needs? Lets a port skip dead code (e.g. MySQL Administrator functions
in the shared AuxFuncs unit).

  python tools/unit_usage.py AuxFuncs Main QueryBrowser
      unit to analyse, then the root units whose dependency closure counts as "the program"
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import unit_deps  # noqa: E402


def strip(text):
    return re.sub(r"\{[^}]*\}|\(\*.*?\*\)|//[^\n]*", " ", text, flags=re.S)


def interface_names(path):
    text = strip(open(path, encoding="cp1252", errors="replace").read())
    iface = re.split(r"\bimplementation\b", text, flags=re.I)[0]
    names = []
    for m in re.finditer(r"^\s*(?:function|procedure)\s+(\w+)", iface, flags=re.M | re.I):
        names.append(("routine", m.group(1)))
    for m in re.finditer(r"^\s*(\w+)\s*=\s*(?:class|record|interface|\()", iface, flags=re.M):
        names.append(("type", m.group(1)))
    for m in re.finditer(r"^\s*(\w+)\s*:\s*[\w\s]+;", iface.split("var", 1)[-1] if " var" in iface.lower() else "", flags=re.M):
        pass
    return names


def closure(roots):
    seen, todo = {}, list(roots)
    while todo:
        n = todo.pop(0)
        k = n.lower()
        if k in seen or k in unit_deps.KNOWN_REPLACED:
            continue
        p = unit_deps.find_unit(n)
        if not p:
            continue
        seen[k] = p
        todo.extend(unit_deps.uses_of(p))
    return seen


def main():
    target, roots = sys.argv[1], sys.argv[2:]
    units = closure(roots)
    tpath = units[target.lower()]
    others = {k: p for k, p in units.items() if k != target.lower()}
    blob = ""
    for p in others.values():
        blob += strip(open(p, encoding="cp1252", errors="replace").read()) + "\n"
        d = p[:-4] + ".dfm"
        if os.path.exists(d):
            blob += open(d, encoding="cp1252", errors="replace").read() + "\n"
    own = strip(open(tpath, encoding="cp1252", errors="replace").read())
    used, unused = [], []
    for kind, name in interface_names(tpath):
        outside = len(re.findall(r"\b%s\b" % re.escape(name), blob, flags=re.I))
        inside = len(re.findall(r"\b%s\b" % re.escape(name), own, flags=re.I)) - 2   # declaration + definition
        (used if outside else unused).append((kind, name, outside, inside))
    print("%s: %d declarations, %d used by other units of the program, %d not" % (target, len(used) + len(unused), len(used), len(unused)))
    print("\nUNUSED outside (name, uses inside the unit itself):")
    for kind, name, o, i in unused:
        print("  %-8s %-34s inside=%d" % (kind, name, max(i, 0)))


if __name__ == "__main__":
    main()
