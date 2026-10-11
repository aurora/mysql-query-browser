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


def make_app_rc():
    """Icon and version information of qbr.exe, from the VERSION file. No copyright holder is
    invented: that string is left out."""
    ver = open(os.path.join(ROOT, "VERSION"), encoding="utf-8").read().strip()
    nums = (re.findall(r"[0-9]+", ver) + ["0", "0", "0", "0"])[:4]
    icon = os.path.join(ROOT, "legacy", "mysql-query-browser", "images", "icons", "MySQLQueryBrowser.ico")
    rc = os.path.join(OUT, "qbr.rc")
    strings = (("FileDescription", "Query Browser (revival of the MySQL Query Browser)"),
               ("FileVersion", ver), ("InternalName", "qbr"), ("OriginalFilename", "qbr.exe"),
               ("ProductName", "MySQL Query Browser"), ("ProductVersion", ver))
    lines = ['MAINICON ICON "%s"' % icon.replace("\\", "/"),
             "1 VERSIONINFO",
             "FILEVERSION %s" % ",".join(nums),
             "PRODUCTVERSION %s" % ",".join(nums),
             "FILEOS 0x00040004L",
             "FILETYPE 0x00000001L",
             "{",
             ' BLOCK "StringFileInfo"',
             " {",
             '  BLOCK "040904E4"',
             "  {"]
    lines += ['   VALUE "%s", "%s\\000"' % kv for kv in strings]
    lines += ["  }", " }", ' BLOCK "VarFileInfo"', " {", '  VALUE "Translation", 1033, 1252', " }", "}"]
    with open(rc, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    return rc


def main():
    os.makedirs(OUT, exist_ok=True)
    rc = make_app_rc()
    env = dict(os.environ)
    env["PATH"] = os.path.dirname(WINDRES) + os.pathsep + env["PATH"]
    r = subprocess.run([WINDRES, "--input", rc, "--output", os.path.join(OUT, "qbr.res"),
                        "--output-format=res"], capture_output=True, text=True, env=env)
    if r.returncode != 0:
        sys.stderr.write("windres failed for qbr.rc:\n%s%s\n" % (r.stdout, r.stderr))
        return 1
    print("qbr: icon and version %s" % open(os.path.join(ROOT, "VERSION")).read().strip())
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
