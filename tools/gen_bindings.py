#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Generate Free Pascal bindings from the myx_*_public_interface.h headers.

Replaces the Windows-only LibInterfaceMapper of the original sources.

  python tools/gen_bindings.py                 # write bindings/*.pas
  python tools/gen_bindings.py --layout DIR    # additionally write C and Pascal
                                               # programs that print struct sizes
                                               # and field offsets (see
                                               # tools/check_bindings.py)

Only the subset of C used by the public headers is understood: typedef'd structs
and enums, simple aliases, function pointer typedefs, numeric #defines and
MYX_PUBLIC_FUNC prototypes. Anything else is reported and aborts the run, so a
header change can never silently produce wrong bindings.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_classes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "backend", "src")

# (header, unit name, library basename), in dependency order.
HEADERS = [
    ("utilities/include/myx_util_public_interface.h", "myx_util_public_interface", "libmysqlutil"),
    ("base-library/include/myx_public_interface.h", "myx_public_interface", "libmysqlx"),
    ("sql-parser/include/myx_sql_parser_public_interface.h", "myx_sql_parser_public_interface", "libmysqlsqlparser"),
    ("qb/include/myx_qb_public_interface.h", "myx_qb_public_interface", "libmysqlqb"),
]

# Types that come from system or MySQL headers. Declared by hand in
# bindings/myx_types.pas; "opaque" types are only ever used behind a pointer.
EXTERNAL_OPAQUE = {"MYSQL", "MYSQL_RES", "FILE", "MYSQL_FIELD", "MYSQL_STMT"}
EXTERNAL_VALUE = {"MYSQL_ROW": "PPAnsiChar", "bigint": "Int64", "ubigint": "QWord",
                  "my_bool": "cchar", "size_t": "csize_t", "time_t": "clong",
                  "uint": "cuint", "uchar": "cuchar", "gulong": "culong",
                  "guint": "cuint", "gint": "cint"}

PASCAL_RESERVED = set("""and array as asm begin case class const constructor destructor div do downto else end
except exports file finalization finally for function goto if implementation in inherited initialization
inline interface is label library mod nil not object of on operator or out packed procedure program property
raise record repeat resourcestring set shl shr string then threadvar to try type unit until uses var while
with xor""".split())

TOKEN_RE = re.compile(r"""
    \.\.\. | [A-Za-z_][A-Za-z0-9_]* | 0[xX][0-9a-fA-F]+[uUlL]* | \d+[uUlL]*
  | '(?:\\.|[^'\\])' | "(?:\\.|[^"\\])*" | [{}()\[\];,*=<>|&+\-~!/%^]
""", re.X)


class GenError(Exception):
    pass


# --------------------------------------------------------------------------- reading

def read_header(path):
    text = open(path, encoding="latin-1").read().replace("\r", "")
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    lines, out = text.split("\n"), []
    skip_depth = 0   # inside "#ifdef __cplusplus"
    in_cpp = False
    cond_stack = []
    for line in lines:
        s = line.strip()
        if s.startswith("#"):
            d = s[1:].strip()
            if d.startswith(("if", "ifdef", "ifndef")):
                cond_stack.append(in_cpp and "cpp" or None)
                if re.match(r"ifdef\s+__cplusplus", d):
                    cond_stack[-1] = "cpp-start"
                    in_cpp = True
            elif d.startswith("else") and cond_stack and cond_stack[-1] == "cpp-start":
                in_cpp = False          # the #else branch of __cplusplus is plain C
            elif d.startswith("endif"):
                if cond_stack:
                    top = cond_stack.pop()
                    if top == "cpp-start":
                        in_cpp = False
            out.append(line if d.startswith("define") and not in_cpp else "")
            continue
        out.append("" if in_cpp else line)
    return "\n".join(out)


def tokenize(text):
    pos, toks = 0, []
    for m in TOKEN_RE.finditer(text):
        gap = text[pos:m.start()].strip()
        if gap:
            raise GenError("unparsed text %r" % gap[:60])
        toks.append(m.group(0))
        pos = m.end()
    if text[pos:].strip():
        raise GenError("unparsed text %r" % text[pos:].strip()[:60])
    return toks


def split_top(tokens, sep):
    """Split on `sep` at nesting depth 0 of (), {} and []."""
    parts, cur, depth = [], [], 0
    for t in tokens:
        if t in "({[":
            depth += 1
        elif t in ")}]":
            depth -= 1
        if t == sep and depth == 0:
            parts.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        parts.append(cur)
    return parts


# --------------------------------------------------------------------------- model

class Model:
    def __init__(self):
        self.types = {}      # c name -> dict(kind, unit, ...)
        self.tags = {}       # struct/enum tag -> c name
        self.consts = {}     # name -> (unit, value)
        self.funcs = []      # dict(name, unit, ret, params, varargs)
        self.classes = []    # struct names marked -generate_classes
        self.enum_values = {}
        self.order = []      # type names in declaration order

    def add_type(self, name, **kw):
        if name in self.types and self.types[name].get("kind") == kw.get("kind") and name in ("MYX_STRINGLIST",):
            return
        if name in self.types:
            raise GenError("type %s declared twice" % name)
        self.types[name] = kw
        self.order.append(name)

    def resolve(self, name):
        return self.tags.get(name, name)


BUILTIN_WORDS = {"void", "char", "short", "int", "long", "float", "double", "unsigned", "signed"}
QUALIFIERS = {"const", "volatile", "static", "extern", "register"}


def parse_base(toks):
    """Return (base, rest_tokens). base is ('builtin', key) or ('named', cname)."""
    i, words, named = 0, [], None
    while i < len(toks):
        t = toks[i]
        if t in QUALIFIERS:
            i += 1
        elif t in ("struct", "enum", "union"):
            if t == "union":
                raise GenError("unions are not supported")
            named = ("tag", toks[i + 1])
            i += 2
        elif t in BUILTIN_WORDS:
            words.append(t)
            i += 1
        elif re.match(r"[A-Za-z_]\w*$", t) and not words and named is None:
            named = ("name", t)
            i += 1
        else:
            break
    if named and words:
        raise GenError("ambiguous type %s" % " ".join(toks))
    if named:
        return named, toks[i:]
    if not words:
        raise GenError("no type in %s" % " ".join(toks))
    unsigned = "unsigned" in words
    longs = words.count("long")
    core = [w for w in words if w not in ("unsigned", "signed", "long", "int")]
    signed = "signed" in words
    if core == ["void"]:
        key = "void"
    elif core == ["char"]:
        key = "uchar" if unsigned else ("schar" if signed else "char")
    elif core == ["short"]:
        key = "cushort" if unsigned else "cshort"
    elif core == ["float"]:
        key = "cfloat"
    elif core == ["double"]:
        key = "cdouble"
    elif not core:
        key = ("culonglong" if unsigned else "clonglong") if longs >= 2 else \
              ("culong" if unsigned else "clong") if longs == 1 else \
              ("cuint" if unsigned else "cint")
    else:
        raise GenError("unsupported builtin %s" % " ".join(words))
    return ("builtin", key), toks[i:]


def parse_declarator(toks):
    """Parse '*** name [n]' or '(*name)(params)'. Returns dict."""
    stars = 0
    while toks and toks[0] in ("*",) + tuple(QUALIFIERS):
        if toks[0] == "*":
            stars += 1
        toks = toks[1:]
    if toks and toks[0] == "(":                       # function pointer
        close = toks.index(")")
        inner = [t for t in toks[1:close] if t not in QUALIFIERS]
        if not inner or inner[0] != "*":
            raise GenError("unsupported declarator %s" % " ".join(toks))
        name = inner[-1] if len(inner) > 1 else None
        return dict(stars=stars, name=name, fnptr=True, params=toks[close + 1:])
    name = toks[0] if toks else None
    rest = toks[1:] if toks else []
    if rest and rest[0] == "[":
        raise GenError("arrays are not supported: %s" % " ".join(toks))
    if rest:
        raise GenError("unexpected tokens after declarator: %s" % " ".join(toks))
    return dict(stars=stars, name=name, fnptr=False)


def parse_params(toks):
    """Parameter list tokens (without the outer parentheses)."""
    params, varargs = [], False
    if not toks or toks == ["void"]:
        return params, varargs
    for i, part in enumerate(split_top(toks, ",")):
        if part == ["..."]:
            varargs = True
            continue
        before_star = part[:part.index("*")] if "*" in part else part
        base, rest = parse_base(part)
        d = parse_declarator(rest)
        params.append(dict(base=base, stars=d["stars"], name=d["name"] or "p%d" % (i + 1), fnptr=d["fnptr"],
                           const="const" in before_star))
    return params, varargs


# --------------------------------------------------------------------------- parsing

def eval_const(expr_tokens, known):
    parts = []
    for t in expr_tokens:
        if re.match(r"0[xX]", t):
            parts.append(str(int(re.sub(r"[uUlL]+$", "", t), 16)))
        elif re.match(r"\d", t):
            parts.append(str(int(re.sub(r"[uUlL]+$", "", t))))
        elif t in known:
            parts.append(str(known[t]))
        elif t in ("|", "&", "+", "-", "<", ">", "(", ")", "~", "*"):
            parts.append(t)
        else:
            raise GenError("cannot evaluate constant %s" % " ".join(expr_tokens))
    return int(eval("".join(parts), {"__builtins__": {}}))


def parse_enum_body(body, model, unit):
    nxt = 0
    names = []
    for item in split_top(body, ","):
        if not item:
            continue
        name = item[0]
        if len(item) > 1:
            if item[1] != "=":
                raise GenError("bad enum item %s" % " ".join(item))
            known = {k: v[1] for k, v in model.consts.items()}
            nxt = eval_const(item[2:], known)
        model.consts[name] = (unit, nxt)
        names.append(name)
        nxt += 1
    return names


def parse_struct_body(body):
    fields = []
    for decl in split_top(body, ";"):
        if not decl:
            continue
        base, rest = parse_base(decl)
        for d in split_top(rest, ","):
            dd = parse_declarator(d)
            if dd["fnptr"]:
                fields.append(dict(base=("builtin", "void"), stars=1, name=dd["name"], fnptr=True))
            else:
                fields.append(dict(base=base, stars=dd["stars"], name=dd["name"], fnptr=False))
    return fields


def parse_header(model, path, unit):
    text = read_header(path)
    raw = open(path, encoding="latin-1").read()
    for m in re.finditer(r"\[SCRIPT::LibInterfaceMapper\]\s+-generate_classes\s+(\w+)", raw):
        model.classes.append(m.group(1))
    # constants
    for m in re.finditer(r"^[ \t]*#define[ \t]+([A-Za-z_]\w*)[ \t]+(\S.*)$", text, flags=re.M):
        name, val = m.group(1), m.group(2).strip()
        if name == "MYX_PUBLIC_FUNC" or name.endswith("_h") or "(" in name:
            continue
        if re.fullmatch(r"(0[xX][0-9a-fA-F]+|\d+)[uUlL]*", val):
            model.consts[name] = (unit, int(re.sub(r"[uUlL]+$", "", val), 0))
        elif re.fullmatch(r"'(\\.|[^'\\])'", val):
            model.consts[name] = (unit, ("char", val[1:-1]))
    code = "\n".join(l for l in text.split("\n") if not l.strip().startswith("#"))
    toks = tokenize(code)
    stmts, cur, depth = [], [], 0
    for t in toks:
        cur.append(t)
        if t in "({":
            depth += 1
        elif t in ")}":
            depth -= 1
        if t == ";" and depth == 0:
            stmts.append(cur[:-1])
            cur = []
    if cur:
        raise GenError("trailing tokens: %s" % " ".join(cur[:10]))
    for st in stmts:
        if st:
            parse_statement(model, st, unit)


def parse_statement(model, st, unit):
    if st[0] == "MYX_PUBLIC_FUNC":
        parse_prototype(model, st[1:], unit)
    elif st[0] == "typedef":
        parse_typedef(model, st[1:], unit)
    elif st[0] in ("struct", "enum") and "{" in st:
        # struct tag { ... }  (no typedef)
        tag = st[1]
        body = st[st.index("{") + 1:len(st) - 1 - st[::-1].index("}")]
        add_aggregate(model, st[0], tag, tag, body, unit)
    elif st[0] == "extern":
        pass
    else:
        raise GenError("unsupported statement: %s" % " ".join(st[:12]))


def add_aggregate(model, kind, tag, name, body, unit):
    if kind == "enum":
        names = parse_enum_body(body, model, unit)
        model.add_type(name, kind="enum", unit=unit, names=names)
    else:
        model.add_type(name, kind="struct", unit=unit, fields=parse_struct_body(body))
    if tag:
        model.tags[tag] = name


def parse_typedef(model, toks, unit):
    if toks[0] in ("struct", "enum") and "{" in toks:
        kind = toks[0]
        tag = toks[1] if toks[1] != "{" else None
        lb = toks.index("{")
        rb = len(toks) - 1 - toks[::-1].index("}")
        names = toks[rb + 1:]
        if len(names) != 1:
            raise GenError("unsupported typedef: %s" % " ".join(toks[:10]))
        add_aggregate(model, kind, tag, names[0], toks[lb + 1:rb], unit)
        return
    base, rest = parse_base(toks)
    d = parse_declarator(rest)
    if d["fnptr"]:
        ret_stars = d["stars"]
        params, varargs = parse_params(d["params"][1:-1])
        model.add_type(d["name"], kind="fnptr", unit=unit, ret=(base, ret_stars), params=params)
    else:
        if base[0] == "tag":                       # typedef struct foo foo_t;
            model.tags.setdefault(base[1], d["name"])
        model.add_type(d["name"], kind="alias", unit=unit, target=base, stars=d["stars"])


def parse_prototype(model, toks, unit):
    base, rest = parse_base(toks)
    ret_const = "const" in toks[:toks.index("(")]
    stars = 0
    while rest and rest[0] == "*":
        stars += 1
        rest = rest[1:]
    name = rest[0]
    if rest[1] != "(" or rest[-1] != ")":
        raise GenError("bad prototype %s" % " ".join(toks[:12]))
    params, varargs = parse_params(rest[2:-1])
    model.funcs.append(dict(name=name, unit=unit, ret=(base, stars), params=params, varargs=varargs,
                            ret_const=ret_const))


# --------------------------------------------------------------------------- emitting

CTYPE_PTR = {"cint": "pcint", "cuint": "pcuint", "clong": "pclong", "culong": "pculong",
             "cshort": "pcshort", "cushort": "pcushort", "cdouble": "pcdouble", "cfloat": "pcfloat",
             "clonglong": "pclonglong", "culonglong": "pculonglong", "schar": "PShortInt",
             "uchar": "PByte"}
CTYPE_VAL = {"char": "AnsiChar", "schar": "cschar", "uchar": "cuchar"}


class Emitter:
    def __init__(self, model):
        self.m = model
        self.extra_ptr2 = set()
        self.used_units = {}

    def pas_name(self, ident):
        return "&" + ident if ident.lower() in PASCAL_RESERVED else ident

    def lookup(self, base):
        kind, name = base
        if kind == "tag":
            name = self.m.resolve(name)
        return name

    def type_ref(self, base, stars, unit, fnptr=False):
        """Pascal type for a C type. Tracks the units the type comes from."""
        if fnptr:
            return "Pointer"
        kind, name = base
        if kind == "builtin":
            if name == "void":
                return {0: "Pointer", 1: "Pointer", 2: "PPointer"}.get(stars, "Pointer") if stars else "void"
            if name == "char":
                return {0: "AnsiChar", 1: "PAnsiChar", 2: "PPAnsiChar"}.get(stars, "Pointer")
            if stars == 0:
                return CTYPE_VAL.get(name, name)
            if stars == 1:
                return CTYPE_PTR[name]
            return "Pointer"
        cname = self.lookup(base)
        if cname in EXTERNAL_OPAQUE:
            return "P" + cname if stars >= 1 else "Pointer"
        if cname in EXTERNAL_VALUE:
            v = EXTERNAL_VALUE[cname]
            if stars == 0:
                return v
            return {"Int64": "PInt64", "QWord": "PQWord", "PPAnsiChar": "Pointer"}.get(v, "p" + v if v.startswith("c") else "Pointer")
        info = self.m.types.get(cname)
        if info is None:
            if kind == "tag":              # struct never defined: opaque
                return "Pointer"
            raise GenError("unknown type %s" % cname)
        if info["unit"] != unit:
            self.used_units.setdefault(unit, set()).add(info["unit"])
        if stars == 0:
            return cname
        if info["kind"] == "fnptr":
            return "Pointer"
        if stars == 1:
            return "P" + cname
        if stars == 2:
            self.extra_ptr2.add(cname)
            return "PP" + cname
        return "Pointer"

    def emit_unit(self, unit, libname, header):
        m = self.m
        types = [n for n in m.order if m.types[n]["unit"] == unit]
        out = []
        w = out.append
        w("{ GENERATED by tools/gen_bindings.py from %s -- do not edit. }" % header.replace("\\", "/"))
        w("{ SPDX-License-Identifier: GPL-2.0-or-later }")
        w("unit %s;" % unit)
        w("")
        w("{$mode objfpc}{$H+}")
        w("{$PACKRECORDS C}")
        w("{$POINTERMATH ON}")
        w("")
        w("interface")
        w("")
        body = []
        b = body.append

        b("const")
        b("{$IFDEF WINDOWS}")
        b("  LIB_%s = '%s.dll';" % (libname.upper().replace("LIB", ""), libname))
        b("{$ELSE}{$IFDEF DARWIN}")
        b("  LIB_%s = '%s.dylib';" % (libname.upper().replace("LIB", ""), libname))
        b("{$ELSE}")
        b("  LIB_%s = '%s.so';" % (libname.upper().replace("LIB", ""), libname))
        b("{$ENDIF}{$ENDIF}")
        b("")
        for name, (u, v) in m.consts.items():
            if u != unit:
                continue
            if isinstance(v, tuple):
                ch = v[1]
                esc = {"\\n": "#10", "\\r": "#13", "\\t": "#9", "\\0": "#0", "\\\\": "\\", "\\'": "'"}.get(ch, ch)
                b("  %s = %s;" % (name, esc if esc.startswith("#") else "'%s'" % esc.replace("'", "''")))
            else:
                b("  %s = %d;" % (name, v))
        b("")
        b("type")
        # pointer types first (forward references are legal inside one type block)
        for n in types:
            if m.types[n]["kind"] in ("struct", "enum", "alias"):
                b("  P%s = ^%s;" % (n, n))
        ptr2_at = len(body)
        b("")
        for n in types:
            if m.types[n]["kind"] == "enum":
                b("  %s = cint;" % n)
        # aliases and records ordered by by-value dependencies
        pending = [n for n in types if m.types[n]["kind"] in ("struct", "alias")]
        done = {n for n in m.types if m.types[n]["unit"] != unit}
        done |= {n for n in types if m.types[n]["kind"] in ("enum", "fnptr")}
        ordered = []
        while pending:
            progress = False
            for n in list(pending):
                info = m.types[n]
                deps = self.value_deps(info)
                if all(d in done or d == n for d in deps):
                    ordered.append(n)
                    done.add(n)
                    pending.remove(n)
                    progress = True
            if not progress:
                raise GenError("cyclic by-value dependency among %s" % ", ".join(pending))
        for n in types:
            if m.types[n]["kind"] == "fnptr":
                info = m.types[n]
                b("  %s = %s;" % (n, self.proc_type(info["ret"], info["params"], unit)))
        b("")
        for n in ordered:
            info = m.types[n]
            if info["kind"] == "alias":
                target = info["target"]
                if target[0] == "tag" and info["stars"] == 0 and self.m.resolve(target[1]) == n:
                    b("  %s = record end;   { opaque: struct defined in a private header }" % n)
                else:
                    b("  %s = %s;" % (n, self.type_ref(target, info["stars"], unit)))
            else:
                b("  %s = record" % n)
                for f in info["fields"]:
                    b("    %s: %s;" % (self.pas_name(f["name"]), self.type_ref(f["base"], f["stars"], unit, f["fnptr"])))
                b("  end;")
                b("")
        b("")
        for f in [f for f in m.funcs if f["unit"] == unit]:
            b(self.func_decl(f, unit, libname))
        # double-pointer types, now that we know which are used
        extra = ["  PP%s = ^P%s;" % (n, n) for n in sorted(self.extra_ptr2) if m.types[n]["unit"] == unit]
        body[ptr2_at:ptr2_at] = extra

        class_decl, class_impl = gen_classes.emit_classes(self, unit)
        wrappers = [f for f in m.funcs if f["unit"] == unit and self.wraps_string(f)]
        uses = ["ctypes", "Classes", "SysUtils", "Contnrs", "AuxLists", "myx_types"] + sorted(self.used_units.get(unit, []))
        w("uses %s;" % ", ".join(uses))
        w("")
        out.extend(body)
        w("")
        out.extend(class_decl)
        w("")
        w("implementation")
        w("")
        for f in wrappers:
            w(self.func_wrapper_impl(f))
        out.extend(class_impl)
        w("end.")
        return "\n".join(out) + "\n"

    def value_deps(self, info):
        deps = []
        if info["kind"] == "alias":
            if info["stars"] == 0:
                deps.append(self.lookup(info["target"]) if info["target"][0] != "builtin" else None)
        else:
            for f in info["fields"]:
                if f["stars"] == 0 and not f["fnptr"] and f["base"][0] != "builtin":
                    deps.append(self.lookup(f["base"]))
        return [d for d in deps if d and d in self.m.types]

    def proc_type(self, ret, params, unit):
        plist = "; ".join("%s: %s" % (self.pas_name(p["name"]), self.param_type(p, unit)) for p in params)
        rtype = self.type_ref(ret[0], ret[1], unit)
        if rtype == "void":
            return "procedure(%s); cdecl" % plist if plist else "procedure; cdecl"
        return "function(%s): %s; cdecl" % (plist, rtype) if plist else "function: %s; cdecl" % rtype

    def param_type(self, p, unit):
        return self.type_ref(p["base"], p["stars"], unit, p["fnptr"])

    # Non-const `char *` parameters that are NOT input text: output buffers and pointers that
    # are handed back to the library to be freed. They stay PAnsiChar.
    RAW_CHAR_PARAMS = {("myx_intl_fgets", "string"), ("myx_free_lib_str", "str"), ("myx_get_ip_as_string", "ip")}

    def is_string_param(self, f, p):
        """`char *` input parameter: the wrapper takes a WideString for it (the original mapper
        treated every `char *` parameter as text; the exceptions are listed above)."""
        if p["base"] != ("builtin", "char") or p["stars"] != 1 or p["fnptr"]:
            return False
        return p.get("const") or (f["name"], p["name"]) not in self.RAW_CHAR_PARAMS

    def returns_string(self, f):
        base, stars = f["ret"]
        return base == ("builtin", "char") and stars == 1

    def wraps_string(self, f):
        """Functions with text parameters or a text result get a wrapper like the original
        LibInterfaceMapper generated: `const char *` parameters become WideString, `char *`
        results become String (non-const ones are freed with g_free). The raw function keeps
        the name `_name`. Varargs functions cannot be wrapped."""
        if f["varargs"]:
            return False
        return self.returns_string(f) or any(self.is_string_param(f, p) for p in f["params"])

    def func_decl(self, f, unit, libname):
        plist = "; ".join("%s: %s" % (self.pas_name(p["name"]), self.param_type(p, unit)) for p in f["params"])
        rtype = self.type_ref(f["ret"][0], f["ret"][1], unit)
        tail = " cdecl;" + (" varargs;" if f["varargs"] else "")
        lib = "LIB_" + libname.upper().replace("LIB", "")
        wrap = self.wraps_string(f)
        name = "_" + f["name"] if wrap else f["name"]
        head = "procedure %s" % name if rtype == "void" else "function %s" % name
        sig = ("(%s)" % plist) if plist else ""
        res = "" if rtype == "void" else ": %s" % rtype
        ext = "external %s name '%s'" % (lib, f["name"]) if wrap else "external %s" % lib
        decl = "%s%s%s;%s %s;" % (head, sig, res, tail, ext)
        if wrap:
            wsig = self.wrapper_signature(f)
            if self.returns_string(f):
                decl += "\nfunction %s%s: String;" % (f["name"], wsig)
            elif rtype == "void":
                decl += "\nprocedure %s%s;" % (f["name"], wsig)
            else:
                decl += "\nfunction %s%s: %s;" % (f["name"], wsig, rtype)
        return decl

    def wrapper_signature(self, f):
        plist = "; ".join(
            ("const %s: WideString" % self.pas_name(p["name"])) if self.is_string_param(f, p)
            else "%s: %s" % (self.pas_name(p["name"]), self.param_type(p, ""))
            for p in f["params"])
        return ("(%s)" % plist) if plist else ""

    def func_wrapper_impl(self, f):
        sig = self.wrapper_signature(f)
        args = ", ".join(("PAnsiChar(UTF8Encode(%s))" % self.pas_name(p["name"])) if self.is_string_param(f, p)
                         else self.pas_name(p["name"]) for p in f["params"])
        call = "_%s(%s)" % (f["name"], args)
        rtype = self.type_ref(f["ret"][0], f["ret"][1], "")
        if self.returns_string(f):
            free = "" if f.get("ret_const") else "  g_free(P);\n"
            return ("function %s%s: String;\nvar\n  P: PAnsiChar;\nbegin\n  P := %s;\n"
                    "  if P = nil then\n    Result := ''\n  else\n    Result := String(P);\n%send;\n"
                    % (f["name"], sig, call, free))
        if rtype == "void":
            return "procedure %s%s;\nbegin\n  %s;\nend;\n" % (f["name"], sig, call)
        return "function %s%s: %s;\nbegin\n  Result := %s;\nend;\n" % (f["name"], sig, rtype, call)

    # ------------------------------------------------------------------ layout check
    def layout_programs(self, c_includes):
        structs = [n for n in self.m.order if self.m.types[n]["kind"] == "struct"]
        c = ["#include <stdio.h>", "#include <stddef.h>"]
        c += ["#include <%s>" % i for i in c_includes]
        c += ["int main(void) {"]
        for n in structs:
            c.append('  printf("%s size %%u\\n", (unsigned)sizeof(%s));' % (n, n))
            for f in self.m.types[n]["fields"]:
                c.append('  printf("%s.%s %%u\\n", (unsigned)offsetof(%s, %s));' % (n, f["name"], n, f["name"]))
        c += ["  return 0;", "}", ""]
        units = [u for _, u, _ in HEADERS]
        p = ["program layout;", "{$mode objfpc}{$H+}", "uses " + ", ".join(units) + ";", "begin"]
        for n in structs:
            p.append("  writeln('%s size ', SizeOf(%s));" % (n, n))
            for f in self.m.types[n]["fields"]:
                p.append("  writeln('%s.%s ', PtrUInt(@P%s(nil)^.%s));" % (n, f["name"], n, self.pas_name(f["name"])))
        p += ["end.", ""]
        return "\n".join(c), "\n".join(p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layout", metavar="DIR")
    ap.add_argument("--out", default=os.path.join(ROOT, "bindings"))
    args = ap.parse_args()

    model = Model()
    try:
        for header, unit, lib in HEADERS:
            parse_header(model, os.path.join(SRC, header), unit)
        em = Emitter(model)
        os.makedirs(args.out, exist_ok=True)
        for header, unit, lib in HEADERS:
            text = em.emit_unit(unit, lib, header)
            with open(os.path.join(args.out, unit + ".pas"), "w", newline="\n") as fh:
                fh.write(text)
        if args.layout:
            os.makedirs(args.layout, exist_ok=True)
            c, p = em.layout_programs(["mysql.h", "myx_public_interface.h", "myx_sql_parser_public_interface.h",
                                       "myx_qb_public_interface.h"])
            open(os.path.join(args.layout, "layout.c"), "w", newline="\n").write(c)
            open(os.path.join(args.layout, "layout.pas"), "w", newline="\n").write(p)
    except GenError as e:
        print("gen_bindings: error: %s" % e, file=sys.stderr)
        return 1
    n_types = len(model.types)
    print("generated %d units: %d types, %d functions, %d constants" %
          (len(HEADERS), n_types, len(model.funcs), len(model.consts)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
