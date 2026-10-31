#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Which Windows API identifiers do the ported units still use? Helps planning the platform
guards of the Linux/macOS port (ROADMAP step 5).

  python tools/winapi_usage.py [--all] [--where] [Unit ...]

Collects the identifiers declared by the Windows-only units (FPC's Windows, Messages, ShellAPI,
...) and removes those that the LCL (LCLType, LCLIntf, LMessages) or the portable RTL also
declare: what is left cannot compile on Linux. Prints per unit the Windows units in its uses
clauses and these identifiers; --all also lists the ones the LCL covers (they still need the
uses clause changed), --where the routines each identifier is used in. Needs the FPC and Lazarus sources (Fedora: fpc-src, lazarus-lcl), i.e.
run it in the freepascal distrobox.
"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FPCSRC = os.environ.get("FPCSRC", "/usr/share/fpcsrc")
LAZDIR = os.environ.get("LAZARUSDIR", "/usr/lib64/lazarus")

# Windows-only unit -> declaring sources. On other platforms the LCL has its own Messages unit
# (lcl/nonwin32) with a part of the WM_* constants and TWM* records; that part counts as portable.
WIN_UNITS = {
    "windows": ["rtl/win/windows.pp", "rtl/win/wininc/*.inc"],
    "messages": ["rtl/win/messages.pp"],
    "shellapi": ["packages/winunits-base/src/shellapi.pp"],
    "shlobj": ["packages/winunits-base/src/shlobj.pp"],
    "activex": ["packages/winunits-base/src/activex.pp"],
    "commctrl": ["packages/winunits-base/src/commctrl.pp"],
    "wininet": ["packages/winunits-base/src/wininet.pp"],
    "winsock": ["rtl/win/winsock.pp"],
    # Windows-only part of SysUtils (Win32Platform, Win32MajorVersion, ...); the portable part is
    # subtracted below through rtl/unix/sysutils.pp
    "sysutils(win)": ["rtl/win/sysutils.pp"],
}
# Shims that are Windows-only in substance. FPC's Registry (and with it TntRegistry) compiles
# everywhere (an XML file outside Windows), so it is only listed, not counted.
SHIM_UNITS = {"tntregistry", "tntwindows", "registry"}

# Everything the LCL (not its widgetset interfaces), the components the project uses and the
# portable RTL declare counts as available on Linux.
PORTABLE = [os.path.join(LAZDIR, p) for p in (
    "lcl/*.pp", "lcl/*.pas", "lcl/include/*.inc", "lcl/nonwin32/*.pp", "components/lazutils/*.pas",
    "components/lazutils/*.pp", "components/lazutils/*.inc", "components/virtualtreeview/*.pas",
    "components/virtualtreeview/include/intf/*.inc", "components/virtualtreeview/units/gtk2/*.pas", "components/synedit/*.pp", "components/synedit/*.pas",
)] + [os.path.join(FPCSRC, p) for p in (
    "rtl/inc/systemh.inc", "rtl/inc/objpash.inc", "rtl/inc/threadh.inc", "rtl/inc/*h.inc",
    "packages/fcl-registry/src/registry.pp", "packages/fcl-registry/src/regdef.inc", "rtl/objpas/types.pp", "rtl/objpas/sysutils/*.inc",
    "rtl/objpas/classes/classesh.inc", "rtl/objpas/math.pp", "rtl/unix/sysutils.pp", "rtl/objpas/objpas.pp",
    "rtl/objpas/sysconst.pp", "rtl/inc/dynlibs.pas", "rtl/objpas/sysutils/sysutilh.inc",
)]

DECL = re.compile(r"^\s*(?:function|procedure)\s+([A-Za-z_]\w*)\s*[(:;]|^\s*([A-Za-z_]\w*)\s*(?:=|:\s*[A-Za-z_^])",
                  re.M | re.I)
IDENT = re.compile(r"[A-Za-z_]\w*")
# variable lists at the start of a line (`Win32MajorVersion, Win32MinorVersion: DWord;`)
DECL_LIST = re.compile(r"^\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)+)\s*:\s*[A-Za-z_^]", re.M)
# variables, parameters and fields, also in lists (`Low, High: Integer`); all-caps names are left
# out so that case labels such as `WM_CHAR:` are not taken for declarations
LOCAL = re.compile(r"\b([A-Za-z_]\w*)(?=\s*(?:,\s*[A-Za-z_]\w*\s*)*:(?!=))")
# strings and comments in one pass, so that a brace inside a string does not open a comment
NOISE = re.compile(r"'(?:[^'\n]|'')*'|\{[^$][^}]*\}|\(\*.*?\*\)|//[^\n]*", re.S)


# Conditional compilation is evaluated as for Linux (GTK2), so code guarded by {$IFDEF MSWINDOWS} is
# not counted and the LCL's Windows-only declarations are not taken for portable ones.
DEFINES = {"UNIX", "LINUX", "FPC", "LCL", "LCLGTK2", "CPU64", "CPUX86_64"}
COND = re.compile(r"\{\$(IFDEF|IFNDEF|ELSE|ENDIF)\b\s*(\w*)[^}]*\}", re.I)


def preprocess(text):
    out, pos, stack = [], 0, []          # stack: (active before, branch taken)
    active = True
    for m in COND.finditer(text):
        if active:
            out.append(text[pos:m.start()])
        kind, name = m.group(1).upper(), m.group(2).upper()
        if kind in ("IFDEF", "IFNDEF"):
            cond = (name in DEFINES) == (kind == "IFDEF")
            stack.append((active, cond))
            active = active and cond
        elif kind == "ELSE" and stack:
            outer, cond = stack[-1]
            active = outer and not cond
        elif kind == "ENDIF" and stack:
            active = stack.pop()[0]
        pos = m.end()
    if active:
        out.append(text[pos:])
    return "".join(out)


def strip(text):
    text = NOISE.sub(lambda m: "''" if m.group(0).startswith("'") else " ", text)
    return preprocess(text)


def declared(patterns, base=""):
    names = set()
    for pat in patterns:
        for path in glob.glob(os.path.join(base, pat)):
            text = strip(open(path, encoding="utf-8", errors="replace").read())
            for m in DECL.finditer(text):
                names.add((m.group(1) or m.group(2)).lower())
            for m in DECL_LIST.finditer(text):
                names.update(n.strip().lower() for n in m.group(1).split(","))
    return names


def uses_units(text):
    found = []
    for m in re.finditer(r"\buses\b(.*?);", text, re.S | re.I):
        found += [u for u in re.split(r"[\s,]+", re.sub(r"\{\$[^}]*\}", " ", m.group(1))) if u]
    return found


DLL_IMPORT = re.compile(r"(?:function|procedure)\s+(\w+)\s*(?:\([^)]*\))?[^;(]*;(?:\s*\w+\s*;)*\s*external\s+'(\w+)\.dll'",
                        re.I)
ROUTINE = re.compile(r"^(?:class\s+)?(?:function|procedure|constructor|destructor)\s+([\w.]+)", re.I)


def routines_using(text, ident):
    """Names of the implementation routines whose body mentions ident (top-level headers only)."""
    names, current = [], "(declarations)"
    word = re.compile(r"(?<![\w.])%s\b" % re.escape(ident), re.I)
    for line in text.splitlines():
        m = ROUTINE.match(line)
        if m:
            current = m.group(1)
        elif word.search(line) and current not in names:
            names.append(current)
    return names


def main():
    if "-h" in sys.argv or "--help" in sys.argv:
        print(__doc__.strip())
        return
    show_all = "--all" in sys.argv
    where = "--where" in sys.argv
    wanted = {a.lower() for a in sys.argv[1:] if not a.startswith("--")}
    if not os.path.isdir(FPCSRC):
        sys.exit("FPC sources not found in %s (set FPCSRC)" % FPCSRC)
    win = {u: declared(p, FPCSRC) for u, p in WIN_UNITS.items()}
    portable = declared(PORTABLE)

    files = sorted(glob.glob(os.path.join(ROOT, "app", "src", "*.pas")) +
                   glob.glob(os.path.join(ROOT, "app", "compat", "*.pas")) + [os.path.join(ROOT, "app", "qbr.lpr")])
    own = set()
    texts = {}
    dll_imports = {}
    for f in files:
        raw = open(f, encoding="utf-8", errors="replace").read()
        texts[f] = strip(raw)
        # routines the unit imports from a Windows DLL itself (user32.dll, gdi32.dll, ...)
        dll_imports[f] = {m.group(1).lower(): "%s.dll" % m.group(2) for m in DLL_IMPORT.finditer(preprocess(raw))}
        own |= {(m.group(1) or m.group(2)).lower() for m in DECL.finditer(texts[f])}
        own |= {m.group(1).lower() for m in LOCAL.finditer(texts[f]) if not m.group(1).isupper()}

    total = collections.Counter()
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        if wanted and name.lower() not in wanted:
            continue
        # Messages exists outside Windows too (lcl/nonwin32); its Windows-only names are still counted
        used_units = [u for u in uses_units(texts[f])
                      if (u.lower() in win and u.lower() != "messages") or u.lower() in SHIM_UNITS]
        if not used_units and not dll_imports[f]:
            continue
        # members (after a dot) are not looked up in the Windows units
        free = [m.group(0) for m in IDENT.finditer(texts[f])
                if not re.search(r"\.\s*$", texts[f][max(0, m.start() - 3):m.start()])]
        idents = collections.Counter(i.lower() for i in free)
        orig = {}
        for i in free:
            orig.setdefault(i.lower(), i)
        only, covered = [], []
        for ident, n in idents.items():
            if ident in dll_imports[f]:
                only.append((orig[ident], n - 1, dll_imports[f][ident]))     # minus the declaration
                total[orig[ident]] += n - 1
                continue
            units = [u for u in win if ident in win[u]]
            if not units:
                continue
            if ident in portable or ident in own:
                covered.append(orig[ident])
            else:
                only.append((orig[ident], n, units[0]))
                total[orig[ident]] += n
        print("== %s  uses %s" % (os.path.relpath(f, ROOT), ", ".join(used_units) or "-"))
        for ident, n, unit in sorted(only, key=lambda x: (x[2], x[0].lower())):
            print("   %-38s %3dx  (%s)" % (ident, n, unit))
            if where:
                print("      in " + ", ".join(routines_using(texts[f], ident)))
        if show_all and covered:
            print("   LCL/RTL: " + ", ".join(sorted(covered, key=str.lower)))
    print("\nWindows-only identifiers in the listed units: %d distinct, %d uses" % (len(total), sum(total.values())))


if __name__ == "__main__":
    main()
