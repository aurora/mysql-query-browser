# SPDX-License-Identifier: GPL-2.0-or-later
"""Wrapper classes for structs marked `-generate_classes` in the public headers.

Replaces the class part of the original LibInterfaceMapper (templates in
legacy/mysql-gui-common/res/windows/LibInterfaceMapper). For a struct MYX_FOO it
generates

    TMYX_FOO       copies the C record into Pascal fields (Create(PMYX_FOO)),
                   builds a C record again for calls into the library
                   (get_record_pointer), owns the memory it allocates
    TMYX_FOO_List  typed TObjectList

so that the ported Delphi code can keep using the classes it always used.
Strings are String (UTF-8 in Lazarus), the original used WideString.
"""

# Class level type for scalar fields: the original mapped C int types to Integer.
CLASS_SCALAR = {"cint": "Integer", "cuint": "Integer", "clong": "Longint", "culong": "Longint",
                "cshort": "SmallInt", "cushort": "Word"}


class GenClassError(Exception):
    pass


def classify(em, name, fields, classes):
    """Split the fields of struct `name` into plain fields, objects, lists."""
    by_name = {f["name"]: f for f in fields}
    plain, objects, nested, strlists, intlists, hidden = [], [], [], [], [], set()
    for f in fields:
        n, base, stars = f["name"], f["base"], f["stars"]
        cname = em.lookup(base) if base[0] != "builtin" else None
        num = by_name.get(n + "_num")
        if f["fnptr"]:
            plain.append(f)
        elif num is not None and stars == 2 and base == ("builtin", "char"):
            strlists.append(f)
            hidden.add(n + "_num")
        elif num is not None and stars == 1 and cname in classes:
            nested.append(f)
            hidden.add(n + "_num")
        elif num is not None and stars == 1 and base == ("builtin", "cint"):
            intlists.append(f)
            hidden.add(n + "_num")
        elif stars == 1 and cname in classes and (n + "_num") not in by_name:
            objects.append(f)
        else:
            plain.append(f)
    plain = [f for f in plain if f["name"] not in hidden]
    return plain, objects, nested, strlists, intlists, by_name


def is_string(f):
    return f["base"] == ("builtin", "char") and f["stars"] == 1 and not f["fnptr"]


def plain_type(em, f, unit):
    if is_string(f):
        return "String"
    t = em.type_ref(f["base"], f["stars"], unit, f["fnptr"])
    return CLASS_SCALAR.get(t, t)


def emit_classes(em, unit):
    m = em.m
    mine = [n for n in m.classes if n in m.types and m.types[n]["unit"] == unit]
    if not mine:
        return [], []
    decl = ["type"]
    impl = []
    for n in mine:
        decl.append("  T%s = class;" % n)
        decl.append("  T%s_List = class;" % n)
    decl.append("")
    for n in mine:
        info = m.types[n]
        if info["kind"] != "struct":
            raise GenClassError("%s is not a struct" % n)
        d, i = emit_class(em, n, info["fields"], unit)
        decl.extend(d)
        impl.extend(i)
    return decl, impl


def emit_class(em, n, fields, unit):
    m = em.m
    plain, objects, nested, strlists, intlists, by_name = classify(em, n, fields, set(m.classes))
    pn = em.pas_name
    T = "T" + n
    rec = n
    rp = "record_pointer"

    # ------------------------------------------------------------------ declaration
    d = []
    d.append("  %s = class(TPersistent)" % T)
    d.append("  private")
    d.append("    record_pointer: P%s;" % rec)
    for f in plain:
        d.append("    F%s: %s;" % (f["name"], plain_type(em, f, unit)))
    d.append("  public")
    for f in objects:
        d.append("    %s: T%s;" % (pn(f["name"]), em.lookup(f["base"])))
    for f in nested:
        d.append("    %s: T%s_List;" % (pn(f["name"]), em.lookup(f["base"])))
    for f in strlists:
        d.append("    %s: TStringList;" % pn(f["name"]))
    for f in intlists:
        d.append("    %s: TIntegerList;" % pn(f["name"]))
    params = "; ".join("%s: %s" % (pn(f["name"]), plain_type(em, f, unit)) for f in plain)
    d.append("    constructor Create(%s); overload;" % params if params else "    constructor Create; overload;")
    d.append("    constructor Create(ARecord: P%s); overload;" % rec)
    d.append("    destructor Destroy; override;")
    d.append("    function get_record_pointer: P%s;" % rec)
    d.append("    procedure Assign(Source: TPersistent); override;")
    for f in plain:
        d.append("    property %s: %s read F%s write F%s;" % (pn(f["name"]), plain_type(em, f, unit), f["name"], f["name"]))
    d.append("  end;")
    d.append("")
    d.append("  %s_List = class(TObjectList)" % T)
    d.append("  protected")
    d.append("    function GetItem(Index: Integer): %s;" % T)
    d.append("    procedure SetItem(Index: Integer; AObject: %s);" % T)
    d.append("  public")
    d.append("    function Add(AObject: %s): Integer;" % T)
    d.append("    function Extract(Item: %s): %s;" % (T, T))
    d.append("    function Remove(AObject: %s): Integer;" % T)
    d.append("    function IndexOf(AObject: %s): Integer;" % T)
    d.append("    procedure Insert(Index: Integer; AObject: %s);" % T)
    d.append("    function First: %s;" % T)
    d.append("    function Last: %s;" % T)
    d.append("    property Items[Index: Integer]: %s read GetItem write SetItem; default;" % T)
    d.append("  end;")
    d.append("")

    # ------------------------------------------------------------------ implementation
    i = []
    w = i.append
    needs_i = bool(nested or strlists or intlists)
    var_i = "var\n  I: Integer;\n" if needs_i else ""

    # constructor from values
    w("constructor %s.Create(%s);" % (T, params) if params else "constructor %s.Create;" % T)
    w("begin")
    w("  inherited Create;")
    for f in plain:
        w("  Self.F%s := %s;" % (f["name"], pn(f["name"])))
    for f in objects:
        w("  Self.%s := nil;" % pn(f["name"]))
    for f in nested:
        w("  Self.%s := T%s_List.Create;" % (pn(f["name"]), em.lookup(f["base"])))
    for f in strlists:
        w("  Self.%s := TStringList.Create;" % pn(f["name"]))
    for f in intlists:
        w("  Self.%s := TIntegerList.Create;" % pn(f["name"]))
    w("end;")
    w("")

    # constructor from record
    args = []
    for f in plain:
        if is_string(f):
            args.append("''" if (f["name"] + "_length") in by_name else "ConvertString(ARecord^.%s)" % pn(f["name"]))
        else:
            t = plain_type(em, f, unit)
            args.append("ARecord^.%s" % pn(f["name"]))
    w("constructor %s.Create(ARecord: P%s);" % (T, rec))
    if needs_i:
        w("var\n  I: Integer;")
    w("begin")
    if args:
        defaults = []
        for f in plain:
            defaults.append("''" if is_string(f) else "Default(%s)" % plain_type(em, f, unit))
        w("  if ARecord <> nil then")
        w("    Create(%s)" % ", ".join(args))
        w("  else")
        w("    Create(%s);" % ", ".join(defaults))
    else:
        w("  Create;")
    w("  Self.record_pointer := nil;")
    w("  if ARecord <> nil then")
    w("  begin")
    for f in plain:
        if is_string(f) and (f["name"] + "_length") in by_name:
            n_ = f["name"]
            w("    SetString(Self.F%s, ARecord^.%s, ARecord^.%s_length);" % (n_, pn(n_), n_))
    for f in objects:
        w("    if ARecord^.%s <> nil then" % pn(f["name"]))
        w("      Self.%s := T%s.Create(ARecord^.%s);" % (pn(f["name"]), em.lookup(f["base"]), pn(f["name"])))
    for f in nested:
        n_ = f["name"]
        w("    for I := 0 to Integer(ARecord^.%s_num) - 1 do" % n_)
        w("      Self.%s.Add(T%s.Create(@ARecord^.%s[I]));" % (pn(n_), em.lookup(f["base"]), pn(n_)))
    for f in strlists:
        n_ = f["name"]
        w("    for I := 0 to Integer(ARecord^.%s_num) - 1 do" % n_)
        w("      Self.%s.Add(ConvertString(ARecord^.%s[I]));" % (pn(n_), pn(n_)))
    for f in intlists:
        n_ = f["name"]
        w("    for I := 0 to Integer(ARecord^.%s_num) - 1 do" % n_)
        w("      Self.%s.Add(ARecord^.%s[I]);" % (pn(n_), pn(n_)))
    w("  end;")
    w("end;")
    w("")

    # destructor
    w("destructor %s.Destroy;" % T)
    if needs_i:
        w("var\n  I: Integer;")
    w("begin")
    for f in objects:
        w("  Self.%s.Free;" % pn(f["name"]))
    for f in nested:
        n_ = f["name"]
        w("  if record_pointer <> nil then")
        w("    if record_pointer^.%s <> nil then" % pn(n_))
        w("      FreeMem(record_pointer^.%s);" % pn(n_))
        w("  Self.%s.Free;" % pn(n_))
    for f in strlists:
        n_ = f["name"]
        w("  if record_pointer <> nil then")
        w("    FreeCStringArray(record_pointer^.%s, record_pointer^.%s_num);" % (pn(n_), n_))
        w("  Self.%s.Free;" % pn(n_))
    for f in intlists:
        n_ = f["name"]
        w("  if record_pointer <> nil then")
        w("    if record_pointer^.%s <> nil then" % pn(n_))
        w("      FreeMem(record_pointer^.%s);" % pn(n_))
        w("  Self.%s.Free;" % pn(n_))
    w("  if record_pointer <> nil then")
    w("  begin")
    for f in plain:
        if is_string(f):
            w("    FreeCString(record_pointer^.%s);" % pn(f["name"]))
    w("    FreeMem(record_pointer);")
    w("  end;")
    w("  inherited Destroy;")
    w("end;")
    w("")

    # get_record_pointer
    w("function %s.get_record_pointer: P%s;" % (T, rec))
    w("var")
    w("  P: Pointer;")
    if needs_i:
        w("  I: Integer;")
    w("begin")
    w("  P := nil;")
    w("  if record_pointer = nil then")
    w("  begin")
    w("    GetMem(record_pointer, SizeOf(%s));" % rec)
    w("    FillChar(record_pointer^, SizeOf(%s), 0);" % rec)
    w("  end;")
    for f in plain:
        n_ = f["name"]
        if is_string(f):
            if (n_ + "_length") in by_name:
                w("  SetCBinary(record_pointer^.%s, Self.F%s, Self.F%s_length);" % (pn(n_), n_, n_))
            else:
                w("  SetCString(record_pointer^.%s, Self.F%s);" % (pn(n_), n_))
        else:
            ctype = em.type_ref(f["base"], f["stars"], unit, f["fnptr"])
            w("  record_pointer^.%s := %s(Self.F%s);" % (pn(n_), ctype, n_))
    for f in objects:
        n_ = f["name"]
        w("  if Self.%s <> nil then" % pn(n_))
        w("    record_pointer^.%s := Self.%s.get_record_pointer" % (pn(n_), pn(n_)))
        w("  else")
        w("    record_pointer^.%s := nil;" % pn(n_))
    for f in nested:
        n_ = f["name"]
        et = em.lookup(f["base"])
        w("  record_pointer^.%s_num := Self.%s.Count;" % (n_, pn(n_)))
        w("  if Self.%s.Count = 0 then" % pn(n_))
        w("  begin")
        w("    if record_pointer^.%s <> nil then" % pn(n_))
        w("    begin")
        w("      FreeMem(record_pointer^.%s);" % pn(n_))
        w("      record_pointer^.%s := nil;" % pn(n_))
        w("    end;")
        w("  end")
        w("  else")
        w("  begin")
        w("    P := record_pointer^.%s;" % pn(n_))
        w("    ReallocMem(P, Self.%s.Count * SizeOf(%s));" % (pn(n_), et))
        w("    record_pointer^.%s := P;" % pn(n_))
        w("  end;")
        w("  for I := 0 to Self.%s.Count - 1 do" % pn(n_))
        w("    record_pointer^.%s[I] := T%s(Self.%s[I]).get_record_pointer^;" % (pn(n_), et, pn(n_)))
    for f in strlists:
        n_ = f["name"]
        w("  SetCStringArray(record_pointer^.%s, record_pointer^.%s_num, Self.%s);" % (pn(n_), n_, pn(n_)))
    for f in intlists:
        n_ = f["name"]
        w("  SetCIntArray(record_pointer^.%s, record_pointer^.%s_num, Self.%s);" % (pn(n_), n_, pn(n_)))
    w("  Result := record_pointer;")
    w("end;")
    w("")

    # Assign
    w("procedure %s.Assign(Source: TPersistent);" % T)
    avars = []
    if nested:
        avars.append("I: Integer")
    for k, f in enumerate(nested):
        avars.append("Item%d: T%s" % (k, em.lookup(f["base"])))
    if avars:
        w("var")
        for v in avars:
            w("  %s;" % v)
    w("begin")
    w("  if Source is %s then" % T)
    w("    with %s(Source) do" % T)
    w("    begin")
    for f in plain:
        w("      Self.F%s := F%s;" % (f["name"], f["name"]))
    for f in objects:
        n_ = pn(f["name"])
        w("      if (Self.%s <> nil) and (%s <> nil) then" % (n_, n_))
        w("        Self.%s.Assign(%s);" % (n_, n_))
    for k, f in enumerate(nested):
        n_ = pn(f["name"])
        et = em.lookup(f["base"])
        w("      Self.%s.Clear;" % n_)
        w("      for I := 0 to %s.Count - 1 do" % n_)
        w("      begin")
        w("        Item%d := T%s.Create(P%s(nil));" % (k, et, et))
        w("        Item%d.Assign(%s[I]);" % (k, n_))
        w("        Self.%s.Add(Item%d);" % (n_, k))
        w("      end;")
    for f in strlists + intlists:
        w("      Self.%s.Assign(%s);" % (pn(f["name"]), pn(f["name"])))
    w("    end")
    w("  else")
    w("    inherited Assign(Source);")
    w("end;")
    w("")

    # list class
    w("function %s_List.GetItem(Index: Integer): %s;" % (T, T))
    w("begin\n  Result := %s(inherited Items[Index]);\nend;\n" % T)
    w("procedure %s_List.SetItem(Index: Integer; AObject: %s);" % (T, T))
    w("begin\n  inherited Items[Index] := AObject;\nend;\n")
    w("function %s_List.Add(AObject: %s): Integer;" % (T, T))
    w("begin\n  Result := inherited Add(AObject);\nend;\n")
    w("function %s_List.Extract(Item: %s): %s;" % (T, T, T))
    w("begin\n  Result := %s(inherited Extract(Item));\nend;\n" % T)
    w("function %s_List.Remove(AObject: %s): Integer;" % (T, T))
    w("begin\n  Result := inherited Remove(AObject);\nend;\n")
    w("function %s_List.IndexOf(AObject: %s): Integer;" % (T, T))
    w("begin\n  Result := inherited IndexOf(AObject);\nend;\n")
    w("procedure %s_List.Insert(Index: Integer; AObject: %s);" % (T, T))
    w("begin\n  inherited Insert(Index, AObject);\nend;\n")
    w("function %s_List.First: %s;" % (T, T))
    w("begin\n  Result := %s(inherited First);\nend;\n" % T)
    w("function %s_List.Last: %s;" % (T, T))
    w("begin\n  Result := %s(inherited Last);\nend;\n" % T)
    return d, i
