#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Populate the runtime folder next to the executable (app/bin): XML data, docs, fonts,
translations. Replaces legacy/mysql-query-browser/PrepareApplicationFolder.cmd.

  python tools/prepare_runtime.py [target-dir]      (default: app/bin)

Layout produced (what the ported code expects, see Options.pas):
  XML/     mysqlx_dbm_*.xml, mysqlqb_*.xml
  doc/     help pages
  fonts/   Bitstream Vera Sans Mono
  locale/languages_list.txt, locale/<language>/LC_MESSAGES/<domain>.po
           (the .po files are read directly by app/compat/gnugettext.pas)
"""
import glob
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMMON = os.path.join(ROOT, "legacy", "mysql-gui-common")
QB = os.path.join(ROOT, "legacy", "mysql-query-browser")


def copy(src, dst_dir, name=None):
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copyfile(src, os.path.join(dst_dir, name or os.path.basename(src)))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "app", "bin")
    n = 0
    for f in ("mysqlx_dbm_charsets.xml", "mysqlx_dbm_datatypes.xml"):
        copy(os.path.join(COMMON, "res", f), os.path.join(out, "XML")); n += 1
    for f in ("mysqlqb_functions.xml", "mysqlqb_statements.xml"):
        copy(os.path.join(QB, "res", f), os.path.join(out, "XML")); n += 1
    for f in glob.glob(os.path.join(QB, "res", "doc", "*")):
        if os.path.isfile(f):
            copy(f, os.path.join(out, "doc")); n += 1
    for f in glob.glob(os.path.join(COMMON, "res", "fonts", "*.ttf")):
        copy(f, os.path.join(out, "fonts")); n += 1
    for f in ("languages_list.txt", "how_to_translate.txt"):
        copy(os.path.join(COMMON, "res", f), os.path.join(out, "locale")); n += 1
    for domain, podir in (("query-browser", os.path.join(QB, "po")), ("mysql-gui-common", os.path.join(COMMON, "po"))):
        for po in glob.glob(os.path.join(podir, "*.po")):
            lang = os.path.splitext(os.path.basename(po))[0]
            if lang.endswith("-template"):
                continue
            copy(po, os.path.join(out, "locale", lang, "LC_MESSAGES"), domain + ".po"); n += 1
    print("prepared %d files in %s" % (n, out))


if __name__ == "__main__":
    main()
