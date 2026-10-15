#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Convert Delphi text .dfm files (Delphi 2006 + TNT Unicode controls) into
Lazarus .lfm files.

  python tools/dfm2lfm.py in.dfm out.lfm [--search DIR ...]

What it does
  * parses the DFM into a tree and writes it back as LFM (same syntax),
  * maps classes (TTntButton -> TButton, TUniCodeEdit stays (compat class on SynEdit), ...),
  * drops properties the LCL does not have (see DROP_*),
  * converts strings to UTF-8 (the DFMs are Windows-1252 with #nnn escapes),
  * inlines frames (`inline X: TFooFrame`) as panels holding the frame's
    controls, using the frame's own .dfm found in the --search directories.

Geometry (Left/Top/Width/Height/ClientWidth/Anchors/Align...) is never touched:
that is what makes the converted forms look like the originals.
"""
import argparse
import os
import re
import sys

# --------------------------------------------------------------------------- model


class Node:
    def __init__(self, kind, name, cls):
        self.kind, self.name, self.cls = kind, name, cls
        self.props = []        # list of [name, Value]
        self.children = []


class Value:
    def __init__(self, kind, data):
        self.kind, self.data = kind, data     # str | raw | set | bin | list | coll


# --------------------------------------------------------------------------- parsing

TOKEN = re.compile(r"""
    (?P<ws>\s+)
  | (?P<str>'(?:[^']|'')*')
  | (?P<chr>\#\$[0-9A-Fa-f]+|\#\d+)
  | (?P<num>-?\$[0-9A-Fa-f]+|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)
  | (?P<id>[A-Za-z_À-￿][A-Za-z0-9_À-￿]*)
  | (?P<punct>[=:.\[\](),<>+-])
  | (?P<bin>\{[0-9A-Fa-f\s]*\})
""", re.X)


class DfmError(Exception):
    pass


def tokenize(text):
    pos, out = 0, []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise DfmError("cannot tokenize at %r" % text[pos:pos + 40])
        pos = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        out.append((kind, m.group()))
    return out


def decode_piece(kind, s):
    if kind == "str":
        return s[1:-1].replace("''", "'")
    n = int(s[2:], 16) if s.startswith("#$") else int(s[1:])
    if n < 256:
        try:
            return bytes([n]).decode("cp1252")
        except UnicodeDecodeError:
            return chr(n)
    return chr(n)


class Parser:
    def __init__(self, tokens):
        self.t, self.i = tokens, 0

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None)

    def next(self):
        tok = self.t[self.i]
        self.i += 1
        return tok

    def expect(self, text):
        kind, val = self.next()
        if val != text:
            raise DfmError("expected %r, got %r near token %d" % (text, val, self.i))

    def parse_object(self):
        kind, val = self.next()
        if val not in ("object", "inherited", "inline"):
            raise DfmError("expected object, got %r" % val)
        name = self.next()[1]
        self.expect(":")
        cls = self.next()[1]
        if self.peek()[1] == "[":              # "[0]" ordering index of inherited
            while self.next()[1] != "]":
                pass
        node = Node(val, name, cls)
        while True:
            kind, v = self.peek()
            if v == "end":
                self.next()
                return node
            if v in ("object", "inherited", "inline"):
                node.children.append(self.parse_object())
            else:
                node.props.append(self.parse_property())

    def parse_property(self):
        parts = [self.next()[1]]
        while self.peek()[1] == ".":
            self.next()
            parts.append(self.next()[1])
        self.expect("=")
        return ["".join(p if i == 0 else "." + p for i, p in enumerate(parts)), self.parse_value()]

    def parse_value(self):
        kind, val = self.peek()
        if kind in ("str", "chr"):
            return Value("str", self.parse_string())
        if kind == "bin":
            self.next()
            return Value("bin", re.sub(r"\s+", "", val[1:-1]))
        if val == "[":
            self.next()
            items = []
            while self.peek()[1] != "]":
                tok = self.next()[1]
                if tok != ",":
                    items.append(tok)
            self.next()
            return Value("set", items)
        if val == "(":
            self.next()
            if self.peek()[0] in ("num", "id"):          # e.g. DesignSize = (418, 510)
                items = []
                while self.peek()[1] != ")":
                    tok = self.next()[1]
                    if tok != ",":
                        items.append(tok)
                self.next()
                return Value("rawlist", items)
            items = []
            while self.peek()[1] != ")":
                items.append(self.parse_string())
            self.next()
            return Value("list", items)
        if val == "<":
            self.next()
            items = []
            while self.peek()[1] != ">":
                self.expect("item")
                props = []
                while self.peek()[1] != "end":
                    props.append(self.parse_property())
                self.next()
                items.append(props)
            self.next()
            return Value("coll", items)
        # number / identifier / qualified identifier / signed number
        self.next()
        text = val
        if val == "-" and self.peek()[0] == "num":
            text += self.next()[1]
        while self.peek()[1] == "." and self.peek(1)[0] == "id":
            self.next()
            text += "." + self.next()[1]
        return Value("raw", text)

    def parse_string(self):
        s = ""
        while True:
            kind, val = self.peek()
            if kind in ("str", "chr"):
                self.next()
                s += decode_piece(kind, val)
            elif val == "+" and self.peek(1)[0] in ("str", "chr"):
                self.next()
            else:
                return s


# --------------------------------------------------------------------------- serialising

def q(s):
    """UTF-8 string literal in Pascal/LFM syntax."""
    out, run = [], ""
    for ch in s:
        if ord(ch) < 32:
            if run:
                out.append("'" + run.replace("'", "''") + "'")
                run = ""
            out.append("#%d" % ord(ch))
        else:
            run += ch
    if run or not out:
        out.append("'" + run.replace("'", "''") + "'")
    return "".join(out)


def wrap_hex(h, indent):
    return ["%s%s" % (indent, h[i:i + 64]) for i in range(0, len(h), 64)]


def write_value(lines, indent, name, v):
    pre = "%s%s = " % (indent, name)
    if v.kind == "str":
        # split very long strings at line breaks to keep lines readable
        lines.append(pre + q(v.data))
    elif v.kind == "raw":
        lines.append(pre + v.data)
    elif v.kind == "set":
        lines.append(pre + "[" + ", ".join(v.data) + "]")
    elif v.kind == "rawlist":
        lines.append(pre + "(" + " ".join(v.data) + ")")     # no commas: lists are whitespace separated
    elif v.kind == "bin":
        lines.append(pre + "{")
        lines.extend(wrap_hex(v.data, indent + "  "))
        lines.append(indent + "  }")
    elif v.kind == "list":
        lines.append(pre + "(")
        for s in v.data[:-1]:
            lines.append(indent + "  " + q(s))
        if v.data:
            lines.append(indent + "  " + q(v.data[-1]) + ")")
        else:
            lines[-1] = pre + "()"
    elif v.kind == "coll":
        lines.append(pre + "<")
        for item in v.data:
            lines.append(indent + "  item")
            for n, val in item:
                write_value(lines, indent + "    ", n, val)
            lines.append(indent + "  end")
        lines[-1] += ">"


def write_node(lines, node, level=0):
    ind = "  " * level
    lines.append("%s%s %s: %s" % (ind, node.kind, node.name, node.cls))
    for n, v in node.props:
        write_value(lines, ind + "  ", n, v)
    for c in node.children:
        write_node(lines, c, level + 1)
    lines.append(ind + "end")


# --------------------------------------------------------------------------- transformation

# Classes that are 1:1 the LCL class after removing the "Tnt" prefix are handled
# generically; these need something else.
CLASS_MAP = {
    # TUniCodeEdit / TUniCodeConsole / TUCESQLHighlighter keep their names: app/compat provides
    # compatible classes on top of SynEdit (ADR-0012).
    # TAnimate stays TAnimate: the LCL has none, app/compat/TntComCtrls declares a placeholder
}

# For these target classes only the listed properties survive; everything the
# original control had beyond that has no LCL equivalent and is re-done in code.
_EDITOR_PROPS = {"Left", "Top", "Width", "Height", "Align", "Anchors", "Visible", "TabOrder", "TabStop",
                 "Color", "Font.Charset", "Font.Color", "Font.Height", "Font.Name", "Font.Style",
                 "PopupMenu", "Constraints.MinHeight", "Constraints.MinWidth", "Cursor", "Hint", "ShowHint",
                 "Name", "HighLighter", "Enabled", "ParentColor", "ParentFont", "TabOrder",
                 # events the ported code handles
                 "OnScroll", "OnKeyDown", "OnKeyUp", "OnKeyPress", "OnEnter", "OnExit", "OnClick",
                 "OnDblClick", "OnDragDrop", "OnDragOver", "OnMouseDown", "OnMouseUp", "OnCaretChange",
                 "OnExecuteCommand", "OnIsMultilineCommand", "OnProcessCommand", "OnProcessUserCommand"}
KEEP_ONLY = {
    # The remaining UniCodeEditor settings (Options, GutterWidth, Keystrokes, colours, ...) are applied
    # by the compatibility classes and by the ported code at run time.
    "TUniCodeEdit": _EDITOR_PROPS,
    "TUniCodeConsole": _EDITOR_PROPS,
    "TUCESQLHighlighter": set(),
    "TAnimate": {"Left", "Top", "Width", "Height", "Align", "Anchors", "Visible", "TabOrder",
                 "Constraints.MinHeight", "Constraints.MinWidth"},
}

# Properties that exist in the VCL only (or are pure designer state).
DROP_ALWAYS = {
    "ExplicitLeft", "ExplicitTop", "ExplicitWidth", "ExplicitHeight", "OldCreateOrder", "DesignSize",
    "TextHeight", "AutoHotkeys", "AlignWithMargins",
    "Ctl3D", "ParentCtl3D", "Icon.Data", "BevelKind", "BevelInner", "BevelOuter_", "Locked",
    "ParentBackground", "UseDockManager", "DockSite", "DragKind", "Flat_", "ShowAccelChar_",
}

# Properties that only exist on some classes in the LCL.
DROP_BY_CLASS = {
    "TPanel": {"AutoScroll"},
    "TVirtualStringTree": {"HintAnimation"},
}

# Tnt (WideString) property names -> LCL names; the LCL is Unicode throughout.
RENAME_PROP = {
    "WideDefaultText": "DefaultText",
    # TntMenus owner draw; same parameter list as the LCL's TMenuItem.OnDrawItem
    "OnAdvancedDrawItem": "OnDrawItem",
}
RENAME_ITEM_PROP = {"WideText": "Text", "WideHint": "Hint"}
DROP_SUFFIXES = ("_UTF7",)
DROP_EVENTS = set()

# Components removed from the converted forms for the first release (ADR-0017): the menu entries
# that start other MySQL GUI tools or open online documentation. The separators next to them go too.
DROP_OBJECTS = {
    "MySQLAdministratorMI", "MySQLCommandLineClientMI", "N11",
    "OnlineDocsMI", "OnlineReferenceCAPIMI", "OnlineDocsPHPAPIMI", "N6", "VisitMySQLcomMI", "N13",
}


def lcl_class(cls):
    if cls in CLASS_MAP:
        return CLASS_MAP[cls]
    if cls.startswith("TTnt"):
        return "T" + cls[4:]
    return cls


def is_event(name):
    return re.match(r"On[A-Z]", name) is not None


# Captions changed for the first release (ADR-0017): component name -> new Caption.
CAPTION_OVERRIDES = {"ReportBugMI": "Report a new bug"}


class Converter:
    def __init__(self, search, flatten=False):
        self.search = search
        self.flatten = flatten            # expand frames into panels (for the viewer)
        self.frame_cache = {}
        self.notes = []

    def find_frame(self, cls):
        if cls in self.frame_cache:
            return self.frame_cache[cls]
        hit = None
        for d in self.search:
            for root, _, files in os.walk(d):
                for f in files:
                    if f.lower().endswith(".dfm"):
                        p = os.path.join(root, f)
                        try:
                            head = open(p, encoding="cp1252").read(300)
                        except OSError:
                            continue
                        m = re.match(r"\s*object\s+\w+\s*:\s*(\w+)", head)
                        if m and m.group(1) == cls:
                            hit = p
                            break
                if hit:
                    break
            if hit:
                break
        self.frame_cache[cls] = hit
        return hit

    def convert(self, node):
        if node.kind == "inline" and self.flatten:
            node = self.inline_frame(node)
        orig_cls = node.cls
        node.cls = lcl_class(node.cls)
        keep = KEEP_ONLY.get(node.cls)
        dropped = DROP_BY_CLASS.get(node.cls, set())
        new_props = []
        for name, v in node.props:
            if name in DROP_ALWAYS or name in dropped or name in DROP_EVENTS or name.endswith(DROP_SUFFIXES):
                continue
            if keep is not None and name not in keep:
                continue
            name = RENAME_PROP.get(name, name)
            if name == "Columns" and v.kind == "coll":     # VirtualTrees keep columns in the header
                name = "Header.Columns"
            if name.endswith(".WideStrings"):
                name = name[:-len(".WideStrings")] + ".Strings"
            if v.kind == "coll":
                v = Value("coll", [[[RENAME_ITEM_PROP.get(n, n), x] for n, x in item] for item in v.data])
            new_props.append([name, v])
        if node.name in CAPTION_OVERRIDES:
            for prop in new_props:
                if prop[0] == "Caption":
                    prop[1] = Value("str", CAPTION_OVERRIDES[node.name])
        node.props = new_props
        node.children = [self.convert(c) for c in node.children if c.name not in DROP_OBJECTS]
        return node

    def inline_frame(self, node):
        path = self.find_frame(node.cls)
        if not path:
            self.notes.append("frame %s (%s): no .dfm found, kept as panel" % (node.name, node.cls))
            node.cls = "TPanel"
            return node
        text = open(path, encoding="cp1252").read().replace("\r", "")
        root = Parser(tokenize(text)).parse_object()
        merged = Node("object", node.name, "TPanel")
        have = {n for n, _ in node.props}
        # geometry of the instance wins; defaults come from the frame
        for n, v in root.props:
            if n in have or n in ("Left", "Top", "Name", "Caption", "OldCreateOrder"):
                continue
            merged.props.append([n, v])
        merged.props.extend(node.props)
        names = {n for n, _ in merged.props}
        if "BevelOuter" not in names:
            merged.props.append(["BevelOuter", Value("raw", "bvNone")])
        if "Caption" not in names:
            merged.props.append(["Caption", Value("str", "")])
        merged.children = list(root.children)
        for c in node.children:
            if c.kind == "inherited" and merge_override(merged.children, c):
                continue
            merged.children.append(c)
        # components of different frame instances must not clash in one flat form
        local = set()
        collect_names(merged.children, local)
        rename_subtree(merged.children, node.name + "_", local)
        self.notes.append("frame %s (%s) inlined from %s" % (node.name, node.cls, os.path.basename(path)))
        return merged


def collect_names(nodes, out):
    for n in nodes:
        if n.kind != "inherited":          # inherited nodes name components of a nested frame
            out.add(n.name)
        collect_names(n.children, out)


def rename_subtree(nodes, prefix, local):
    for n in nodes:
        if n.kind != "inherited":
            n.name = prefix + n.name
        for p in n.props:
            v = p[1]
            if v.kind == "raw" and v.data in local:
                v.data = prefix + v.data
            elif v.kind == "raw" and "." in v.data and v.data.split(".")[0] in local:
                head, _, rest = v.data.partition(".")
                v.data = prefix + head + "." + rest
        rename_subtree(n.children, prefix, local)


def merge_override(nodes, over):
    """Apply an `inherited X` block of a frame instance to the frame's own child X."""
    for n in nodes:
        if n.name == over.name:
            names = {p[0] for p in over.props}
            n.props = [p for p in n.props if p[0] not in names] + over.props
            for c in over.children:
                if not (c.kind == "inherited" and merge_override(n.children, c)):
                    n.children.append(c)
            return True
        if merge_override(n.children, over):
            return True
    return False


def convert_file(src, dst, search, flatten=False):
    text = open(src, encoding="cp1252").read().replace("\r", "")
    root = Parser(tokenize(text)).parse_object()
    conv = Converter(search, flatten)
    root = conv.convert(root)
    lines = []
    write_node(lines, root)
    with open(dst, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    return conv.notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--search", action="append", default=[])
    ap.add_argument("--flatten-frames", action="store_true", help="expand frames into panels (viewer only)")
    a = ap.parse_args()
    for n in convert_file(a.src, a.dst, a.search, a.flatten_frames):
        print(n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
