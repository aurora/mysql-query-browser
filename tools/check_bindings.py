#!/usr/bin/env python3
"""Verify that the generated Pascal records have exactly the memory layout of the
C structs: compiles a C and a Pascal program that print sizeof and offsetof of
every struct field and compares the output.

Needs gcc and pkg-config (MSYS2 mingw64) and fpc on PATH, or at the default
Windows locations below.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND = os.path.join(ROOT, "backend")
MSYS_BIN = r"C:\msys64\mingw64\bin"
FPC = shutil.which("fpc") or r"C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe"


def run(cmd, **kw):
    # On Windows the executable is looked up in the caller's PATH, not in env=.
    exe = shutil.which(cmd[0], path=kw.get("env", os.environ)["PATH"]) or cmd[0]
    r = subprocess.run([exe] + cmd[1:], capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.stderr.write("command failed: %s\n%s%s\n" % (" ".join(cmd), r.stdout, r.stderr))
        sys.exit(1)
    return r.stdout


def main():
    env = dict(os.environ)
    env["PATH"] = MSYS_BIN + os.pathsep + env["PATH"]
    tmp = tempfile.mkdtemp(prefix="qbr-layout-")
    try:
        run([sys.executable, os.path.join(ROOT, "tools", "gen_bindings.py"), "--out", tmp, "--layout", tmp])
        for hand_written in ("myx_types.pas", "AuxLists.pas"):
            shutil.copy(os.path.join(ROOT, "bindings", hand_written), tmp)

        src = os.path.join(BACKEND, "src")
        incs = [os.path.join(BACKEND, "compat")] + [
            os.path.join(src, d) for d in
            ("utilities/include", "utilities/shared_include", "base-library/include",
             "sql-parser/include", "qb/include", "generic-runtime/include")]
        flags = run(["pkg-config", "--cflags", "glib-2.0", "libmariadb", "libxml-2.0", "libpcre"], env=env).split()
        run(["gcc", "-w", os.path.join(tmp, "layout.c"), "-o", os.path.join(tmp, "layout_c.exe")]
            + ["-I" + i for i in incs] + flags, env=env)
        run([FPC, "-Fu" + tmp, "-FU" + tmp, "-FE" + tmp, os.path.join(tmp, "layout.pas")])

        c_out = run([os.path.join(tmp, "layout_c.exe")], env=env).split("\n")
        p_out = run([os.path.join(tmp, "layout.exe")]).split("\n")
        norm = lambda lines: sorted(l.strip() for l in lines if l.strip())
        c_out, p_out = norm(c_out), norm(p_out)
        diff = sorted(set(c_out) ^ set(p_out))
        if diff:
            print("LAYOUT MISMATCH (C vs Pascal):")
            for l in diff[:40]:
                print("  " + ("C:      " if l in c_out else "Pascal: ") + l)
            return 1
        print("layout OK: %d sizes/offsets identical in C and Pascal" % len(c_out))
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
