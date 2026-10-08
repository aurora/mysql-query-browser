#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Remove unused stand-alone routines from a ported Delphi unit (interface declaration and
implementation) and note them in a comment at the top of the unit.

  python tools/drop_routines.py app/src/AuxFuncs.pas Name1 Name2 ...

Works on the Borland layout of the sources: a routine implementation starts with
`function|procedure Name` in column 0 and ends with the first `end;` in column 0.
Methods (`TClass.Name`) are never touched.
"""
import re
import sys


def drop(path, names):
    text = open(path, encoding="utf-8").read()
    lines = text.split("\n")
    low = {n.lower() for n in names}
    removed, out, i = [], [], 0
    # split interface/implementation
    impl_at = next(k for k, l in enumerate(lines) if re.match(r"^implementation\b", l, re.I))
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^(function|procedure)\s+(\w+)\b", line, re.I)
        if m and m.group(2).lower() in low:
            # declaration (interface) or implementation (after 'implementation')
            if i < impl_at:
                # skip until the line that ends the declaration with ';' (may span lines;
                # an `overload;` / calling convention may follow on the same line)
                j, depth = i, 0
                while True:
                    depth += lines[j].count("(") - lines[j].count(")")
                    if depth <= 0 and re.search(r";\s*(//.*)?$", lines[j]):
                        break
                    j += 1
                # declaration directives that continue on the next line, e.g. "overload;"
                i = j + 1
                removed.append(m.group(2))
                continue
            j = i
            while not re.match(r"^end;", lines[j]):
                j += 1
            i = j + 1
            # swallow the separator comment and blank lines that preceded the routine
            while out and (out[-1].strip() == "" or re.match(r"^//-{20,}", out[-1].strip())):
                out.pop()
            out.append("")
            if m.group(2) not in removed:
                removed.append(m.group(2))
            continue
        out.append(line)
        i += 1
    note = ("// Not ported (not used by the Query Browser, code from the MySQL Administrator):\n//   " +
            ", ".join(sorted(set(removed), key=str.lower)) + "\n")
    new = "\n".join(out)
    new = re.sub(r"(?im)^(unit\s+[\w.]+\s*;[ \t]*\n)", lambda m: m.group(1) + "\n" + note, new, count=1)
    open(path, "w", encoding="utf-8", newline="\n").write(new)
    print("removed %d routines from %s" % (len(set(removed)), path))
    missing = low - {r.lower() for r in removed}
    if missing:
        print("not found as stand-alone routines:", ", ".join(sorted(missing)))


if __name__ == "__main__":
    drop(sys.argv[1], sys.argv[2:])
