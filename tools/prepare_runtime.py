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
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMMON = os.path.join(ROOT, "legacy", "mysql-gui-common")
QB = os.path.join(ROOT, "legacy", "mysql-query-browser")


def copy(src, dst_dir, name=None):
    os.makedirs(dst_dir, exist_ok=True)
    shutil.copyfile(src, os.path.join(dst_dir, name or os.path.basename(src)))


def _checksum(data):
    data += b"\0" * (-len(data) % 4)
    return sum(struct.unpack(">%dI" % (len(data) // 4), data)) & 0xFFFFFFFF


def copy_without_bitmaps(src, dst_dir):
    """Copy a TrueType font without its embedded bitmap glyphs (EBDT/EBLC/EBSC).

    FreeType takes the line metrics of a bitmap strike when one exists for the requested size; for the Tahoma
    stand-in those are too small (10 pixels: ascent 8, descent 2, negative leading), so Qt, which uses FreeType's
    metrics, drew wrapped lines 9 pixels apart and they touched (About dialog). Without the bitmaps the outline
    metrics apply (12 pixels, as on Windows). GTK2 draws the same with and without them (checked by screenshot).
    """
    data = open(src, "rb").read()
    version, count = struct.unpack(">IH", data[:6])
    tables = []
    for i in range(count):
        tag, _, offset, length = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        if tag not in (b"EBDT", b"EBLC", b"EBSC"):
            tables.append((tag, data[offset:offset + length]))
    tables.sort()
    n = len(tables)
    power = 1 << (n.bit_length() - 1)
    header = struct.pack(">IHHHH", version, n, power * 16, power.bit_length() - 1, n * 16 - power * 16)
    offset = 12 + 16 * n
    directory, body = b"", b""
    for tag, table in tables:
        if tag == b"head":
            table = table[:8] + b"\0\0\0\0" + table[12:]    # checkSumAdjustment, set below
        directory += struct.pack(">4sIII", tag, _checksum(table), offset + len(body), len(table))
        body += table + b"\0" * (-len(table) % 4)
    font = bytearray(header + directory + body)
    head = next(i for i in range(n) if tables[i][0] == b"head")
    head_offset = struct.unpack(">I", directory[16 * head + 8:16 * head + 12])[0]
    font[head_offset + 8:head_offset + 12] = struct.pack(">I", (0xB1B0AFBA - _checksum(bytes(font))) & 0xFFFFFFFF)
    os.makedirs(dst_dir, exist_ok=True)
    with open(os.path.join(dst_dir, os.path.basename(src)), "wb") as f:
        f.write(font)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "app", "bin")
    n = 0
    copy(os.path.join(COMMON, "res", "mysqlx_dbm_charsets.xml"), os.path.join(out, "XML")); n += 1
    # the program's own data type list: the original's plus the types every supported server has (ADR-0034)
    copy(os.path.join(ROOT, "app", "xml", "mysqlx_dbm_datatypes.xml"), os.path.join(out, "XML")); n += 1
    for f in ("mysqlqb_functions.xml", "mysqlqb_statements.xml"):
        copy(os.path.join(QB, "res", f), os.path.join(out, "XML")); n += 1
    # Only the program's own quick start guide. The MySQL 5.0 manual extract (statements/functions pages) is not
    # shipped any more: the reference comes from the server's help tables (ADR-0016, docs/licenses.md section 4).
    copy(os.path.join(QB, "res", "doc", "mysqlqb_quickstart.html"), os.path.join(out, "doc")); n += 1
    for f in glob.glob(os.path.join(COMMON, "res", "fonts", "*.ttf")):
        copy(f, os.path.join(out, "fonts")); n += 1
    # Tahoma is part of Windows; elsewhere the forms get a free stand-in with similar metrics (ADR-0028), without its
    # embedded bitmaps (see copy_without_bitmaps)
    if sys.platform != "win32":
        for f in ("tahoma.ttf", "tahomabd.ttf"):
            copy_without_bitmaps(os.path.join(ROOT, "third_party", "fonts", "wine-tahoma", f), os.path.join(out, "fonts")); n += 1
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
