#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Compile the original resource scripts (PNG images, cursors, icons, animations)
into app/res/*.res, which qbr.lpr links in with {$R}.

The scripts are used in place (their image paths are relative to the .rc file), so
the images stay where they are in legacy/ until the new UI no longer needs them.

  python tools/build_resources.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "res")
WINDRES = r"C:\msys64\mingw64\bin\windres.exe"

SCRIPTS = {
    "mysqlcommon": os.path.join(ROOT, "legacy", "mysql-gui-common", "res", "windows", "mysqlcommon.rc"),
    "mysqlqb": os.path.join(ROOT, "legacy", "mysql-query-browser", "res", "windows", "mysqlqb.rc"),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, rc in SCRIPTS.items():
        res = os.path.join(OUT, name + ".res")
        env = dict(os.environ)
        env["PATH"] = os.path.dirname(WINDRES) + os.pathsep + env["PATH"]      # windres runs gcc -E
        # brcc32 accepted backslashes in paths; the C preprocessor of windres reads them as escapes
        text = open(rc, encoding="cp1252").read()
        text = re.sub(r'"([^"\n]*)"', lambda m: '"' + m.group(1).replace("\\", "/") + '"', text)
        tmp_rc = os.path.join(os.path.dirname(rc), "_" + os.path.basename(rc))
        with open(tmp_rc, "w", encoding="cp1252", newline="\n") as fh:
            fh.write(text)
        try:
            r = subprocess.run([WINDRES, "--input", tmp_rc, "--output", res, "--output-format=res"],
                               cwd=os.path.dirname(rc), capture_output=True, text=True, env=env)
        finally:
            os.remove(tmp_rc)
        if r.returncode != 0:
            sys.stderr.write("windres failed for %s:\n%s%s\n" % (rc, r.stdout, r.stderr))
            return 1
        print("%s: %.1f MB" % (name, os.path.getsize(res) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())
