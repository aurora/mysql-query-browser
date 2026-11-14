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
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "res")
if sys.platform == "win32":
    WINDRES = r"C:\msys64\mingw64\bin\windres.exe"
else:
    # the .res files are platform neutral; FPC links them on Linux too (Fedora: mingw64-binutils)
    WINDRES = shutil.which("x86_64-w64-mingw32-windres") or shutil.which("windres") or "windres"

SCRIPTS = {
    "mysqlcommon": os.path.join(ROOT, "legacy", "mysql-gui-common", "res", "windows", "mysqlcommon.rc"),
    "mysqlqb": os.path.join(ROOT, "legacy", "mysql-query-browser", "res", "windows", "mysqlqb.rc"),
}


# ADR-0030: resources that carry the MySQL logo or the old product name. OVERRIDES replaces the file
# of a resource (pictures made by tools/make_branding.sh), DROPPED leaves it out of the .res.
IMAGES = os.path.join(ROOT, "app", "images")
OVERRIDES = {
    "about": os.path.join(IMAGES, "about.png"),                                   # About dialog, splash
    "connection_dialog_header": os.path.join(IMAGES, "connect_header_qb.png"),    # connect dialog
}
DROPPED = {
    "dolphin_loop",     # the MySQL dolphin as busy animation (AVI; TAnimate does not play it yet)
    "mysql_logo",       # the MySQL logo; the Query Browser does not show it
}


def rebrand_rc(text):
    """Applies OVERRIDES and DROPPED to the text of a .rc script (lines `name TYPE "file"`)."""
    out = []
    for line in text.split("\n"):
        m = re.match(r'(\s*)(\w+)(\s+\w+\s+)"([^"]*)"(.*)$', line)
        if m and m.group(2) in DROPPED:
            continue
        if m and m.group(2) in OVERRIDES:
            line = '%s%s%s"%s"%s' % (m.group(1), m.group(2), m.group(3),
                                     OVERRIDES[m.group(2)].replace("\\", "/"), m.group(5))
        out.append(line)
    return "\n".join(out)


def make_app_rc():
    """Icon and version information of qbr.exe, from the VERSION file. No copyright holder is
    invented: that string is left out."""
    ver = open(os.path.join(ROOT, "VERSION"), encoding="utf-8").read().strip()
    nums = (re.findall(r"[0-9]+", ver.split("-")[0]) + ["0", "0", "0", "0"])[:4]
    icon = os.path.join(ROOT, "legacy", "mysql-query-browser", "images", "icons", "MySQLQueryBrowser.ico")
    rc = os.path.join(OUT, "qbr.rc")
    strings = (("FileDescription", "QueryMole SQL client"),
               ("FileVersion", ver), ("InternalName", "qbr"), ("OriginalFilename", "qbr.exe"),
               ("ProductName", "QueryMole"), ("ProductVersion", ver))
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
        text = rebrand_rc(text)
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
