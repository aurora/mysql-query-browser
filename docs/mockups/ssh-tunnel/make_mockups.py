#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Mock-ups of the SSH tunnel UI (ADR-0048): copies the generated connect and options forms, adds the proposed
controls and renders them with tools/lfmview, together with the new SSH dialog (SSHTunnel.lfm, next to this file).
Writes the PNG files into this folder; app/forms is not touched.

    python3 docs/mockups/ssh-tunnel/make_mockups.py

For the look of the Linux release, build lfmview with Qt6 first (lazbuild --ws=qt6 tools/lfmview/lfmview.lpi) or
point LFMVIEW at such a build; the forms are drawn with the Fusion style and the bundled fonts of app/bin/fonts
(python tools/prepare_runtime.py), under xvfb-run when it is available.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FORMS = os.path.join(ROOT, "app", "forms")
LFMVIEW = os.environ.get("LFMVIEW", os.path.join(ROOT, "tools", "lfmview", "bin", "lfmview"))

# connect dialog: the row "Use SSH tunnel" where the original keeps its hidden SSL check box (Top = 98)
CONNECT_ROW = """        object UseSSHTunnelCBox: TCheckBox
          Left = 0
          Top = 98
          Width = 106
          Height = 17
          Caption = 'Use SSH tunnel'
          Checked = True
          State = cbChecked
          TabOrder = 5
        end
        object SSHTunnelBtn: TBitBtn
          Left = 110
          Top = 95
          Width = 21
          Height = 23
          Caption = '...'
          TabOrder = 6
        end
        object SSHTunnelLbl: TLabel
          Left = 138
          Top = 99
          Width = 190
          Height = 13
          AutoSize = False
          Caption = 'admin@bastion.example.com:22'
          Font.Color = clGrayText
          ParentFont = False
        end
"""

# options dialog, stored connections: the same row on "Connection Parameters", between Schema and Notes (the notes
# field gives up one line); it opens the same SSH dialog as the connect dialog
OPTIONS_ROW = """          object ConnUseSSHCBox: TCheckBox
            Left = 4
            Top = 207
            Width = 118
            Height = 19
            Caption = 'Use SSH tunnel'
            Checked = True
            State = cbChecked
            TabOrder = 20
          end
          object ConnSSHBtn: TBitBtn
            Left = 124
            Top = 205
            Width = 21
            Height = 24
            Caption = '...'
            TabOrder = 21
          end
          object ConnSSHLbl: TLabel
            Left = 152
            Top = 209
            Width = 157
            Height = 16
            AutoSize = False
            Caption = 'admin@bastion:22'
            Font.Color = clGrayText
            ParentFont = False
          end
"""


def insert_after_object(text, name, addition):
    """Inserts addition after the end line of the object with the given name (same indentation)."""
    m = re.search(r"^( *)object " + re.escape(name) + r":", text, re.M)
    if not m:
        sys.exit("object not found: " + name)
    end = re.compile("^" + m.group(1) + "end$", re.M).search(text, m.end())
    return text[:end.end() + 1] + addition + text[end.end() + 1:]


def render(lfm, png, workdir, tabs=False):
    env = dict(os.environ, QT_QPA_PLATFORM="xcb", QT_STYLE_OVERRIDE="Fusion",
               FONTCONFIG_FILE=os.path.join(workdir, "fonts.conf"))
    env.pop("WAYLAND_DISPLAY", None)
    cmd = [LFMVIEW, lfm, "--png", png, "--quiet"] + (["--tabs"] if tabs else [])
    if shutil.which("xvfb-run"):
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1600x1200x24"] + cmd
    subprocess.run(cmd, env=env, check=True, timeout=120)


def main():
    work = tempfile.mkdtemp(prefix="ssh-mockup-")
    with open(os.path.join(work, "fonts.conf"), "w") as f:
        f.write('<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n'
                '  <dir>%s</dir>\n  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>\n'
                '</fontconfig>\n' % os.path.join(ROOT, "app", "bin", "fonts"))

    text = open(os.path.join(FORMS, "ConnectToInstance.lfm"), encoding="utf-8").read()
    text = insert_after_object(text, "UseSSLCBox", CONNECT_ROW)
    connect = os.path.join(work, "ConnectToInstance.lfm")
    open(connect, "w", encoding="utf-8").write(text)
    render(connect, os.path.join(HERE, "connect-dialog.png"), work)

    render(os.path.join(HERE, "SSHTunnel.lfm"), os.path.join(HERE, "ssh-dialog.png"), work)

    text = open(os.path.join(FORMS, "OptionsEditor.lfm"), encoding="utf-8").read()
    # move "Notes" down by one row and shorten its field, then add the row
    tab = re.search(r"object ConnGeneralTabSheet:(?:.*\n)*?        end\n", text)
    page = tab.group(0)
    page = re.sub(r"(object Label1: TLabel\n(?: .*\n)*? *Top = )205", r"\g<1>237", page, count=1)
    page = re.sub(r"(object ConnMemo: TMemo\n(?: .*\n)*? *Top = )204", r"\g<1>236", page, count=1)
    page = re.sub(r"(object ConnMemo: TMemo\n(?: .*\n)*? *Height = )101", r"\g<1>69", page, count=1)
    text = text[:tab.start()] + page + text[tab.end():]
    text = insert_after_object(text, "ConnMemo", OPTIONS_ROW)
    # show the connections page with its first tab
    text = text.replace("ActivePage = GeneralTabSheet", "ActivePage = ConnectionsTabSheet", 1)
    # the page header names the page ("General" in the form file; the program sets it)
    text = text.replace("Caption = 'General'", "Caption = 'Connections'", 1)
    # the program hides the outer tab row; under Qt6 its TabHeight would also hide the inner one (the program
    # scopes that style sheet, lfmview does not; AGENTS.md, Qt6 style sheets)
    text = re.sub(r"(object OptionPageControl: TPageControl\n(?:.*\n)*?) *TabHeight = 16\n", r"\1    ShowTabs = False\n",
                  text, count=1)
    options = os.path.join(work, "OptionsEditor.lfm")
    open(options, "w", encoding="utf-8").write(text)
    render(options, os.path.join(HERE, "options-connections.png"), work)
    shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
