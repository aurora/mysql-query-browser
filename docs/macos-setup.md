<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# macOS (Apple Silicon): first build, checklist

**Deferred (ADR-0039):** no macOS release and no layout work until the widgetset decision of the Qt move
(ADR-0024). This file records where the work stopped.

Status: **first build done** (2026-11-17, macOS 26.4 on Apple Silicon, Apple clang 21, Homebrew glib
2.90 / libxml2 2.15 / pcre 8.45 / Connector/C 3.4.11, FPC 3.2.4rc1, Lazarus 4.8): the backend and
`app/bin/querymole` build, the program starts and `--shot-connect` writes the connect dialog. Steps 4.3
and later have not been tried. Findings are under "State" at the end. This is the list of steps for a
Mac with an M processor, and of the places where `build.sh` and the backend needed changes.
Write down what you find in `docs/linux-port.md` style (state and open problems), and write an ADR
(see ADR-0027 for the Linux counterpart) once the widgetset and the packaging are decided.

## 1. Tools

`tools/macos-setup.sh` installs the Homebrew packages and checks everything below (`--check` only
checks). By hand:

```bash
xcode-select --install                       # compiler, make, git, SDK
brew install cmake ninja pkgconf python@3 glib libxml2 pcre mariadb-connector-c mingw-w64
```

- `mingw-w64` brings `x86_64-w64-mingw32-windres` for `tools/build_resources.py` (the `.res` files are
  platform neutral, as on Linux). `iconv` comes with the SDK.
- No container: a container on a Mac is a Linux VM and can only build the Linux program (x86_64 under
  emulation on Apple Silicon). A macOS build needs the macOS SDK and the Cocoa LCL on the host. Podman
  (`podman machine`) is still useful for the test servers of `tests/run-matrix.sh`.

- `pcre` is PCRE1 (`pkg_check_modules(PCRE ... libpcre)` in `backend/CMakeLists.txt`). Homebrew has
  deprecated that formula; if it is gone, either build PCRE 8.45 from source into a prefix or move
  the backend to PCRE2 (a separate change with its own ADR, ADR-0003 territory).
- Check `pkg-config --modversion glib-2.0 gthread-2.0 libxml-2.0 libpcre libmariadb`; all five must
  answer. Homebrew installs on arm64 under `/opt/homebrew`; add
  `export PKG_CONFIG_PATH=/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libxml2/lib/pkgconfig:/opt/homebrew/opt/mariadb-connector-c/lib/pkgconfig`
  if a `.pc` file is not found.

## 2. Free Pascal and Lazarus

- Lazarus 4.8 for macOS aarch64 from
  <https://sourceforge.net/projects/lazarus/files/Lazarus%20macOS%20aarch64/>: two files. The `.dmg`
  holds the FPC package (3.2.4rc1, installs to `/usr/local/bin` and `/usr/local/lib/fpc`); the zip holds
  Lazarus **and the FPC sources** (`lazarus/fpc/3.2.4/sources`, already set in its
  `config/environmentoptions.xml`). Install the FPC package first, then
  `xattr -cr ~/Downloads/lazarus && mv ~/Downloads/lazarus /Applications/Lazarus` (without `xattr`
  Gatekeeper blocks `lazbuild`). The Lazarus folder is self-contained (`lazarus.cfg`: `--pcp=config`).
  The Homebrew cask `lazarus` is disabled. Check `fpc -iTP -iTO` prints `aarch64 darwin`.
- `tools/winapi_usage.py` needs `FPCSRC=/Applications/Lazarus/fpc/3.2.4/sources
  LAZARUSDIR=/Applications/Lazarus`.
- FPC 3.2.2 is the weak point on arm64: if it fails on the project, use FPC 3.2.3 (fixes branch) or
  3.3.1, the same family as in the Linux distrobox (3.2.3).
- Widgetset **cocoa** (`lazbuild --ws=cocoa`). GTK2/Qt from Homebrew are not an option for a Mac
  program (ADR-0024 lists GTK2 only for the first Linux release).

## 3. Backend

```bash
./build.sh --backend --runtime       # backend into backend/build-macos, resources, runtime files, application
```

or by hand (`build.sh` sets `PKG_CONFIG_PATH` for the keg-only Homebrew formulae):

```bash
cmake -S backend -B backend/build-macos -G Ninja
cmake --build backend/build-macos
```

Expect problems in `backend/compat` (shim headers) and in the old C code (ADR-0003: undefined
behaviour that a newer clang rejects or exposes). The link line for Windows adds `ws2_32` etc.; check
that nothing Linux- or Windows-only is missing for `APPLE`.

## 4. Application

`build.sh` builds on macOS with `--ws=cocoa`, links against `backend/build-macos` and gives the
program that folder as rpath (the backend's dylibs are named `@rpath/lib*.dylib`), so
`app/bin/querymole` starts without `DYLD_LIBRARY_PATH`. `LAZARUS_DIR`, `HOMEBREW_PREFIX` and
`QBR_FPC_OPTS` (extra compiler options) adjust it; see the script header and section 6 for the linker
options it sets. The program is a bare
executable, not yet a `.app` bundle (`UseAppBundle` is off in `qbr.lpi`); whether Cocoa runs it
properly that way is one of the things to find out.

Then, in this order (stop at the first failure and record it):

1. Does `qbr.lpi` compile? Windows-only code outside `{$IFDEF MSWINDOWS}` shows up here;
   `python3 tools/winapi_usage.py --where` lists it (needs the FPC/Lazarus sources).
2. Does it start? `--shot-connect out.png` (a timeout around everything, see AGENTS.md).
3. `--selftest-connect` against a server (`tests/run-matrix.sh` needs podman; a local MariaDB is enough
   for a first run).
4. The ported controls: `laz.VirtualTrees`, the SQL editor (SynEdit) and the result grid are less
   tested on Cocoa; check painting, selection, copy/paste, the menu bar (Cocoa uses the global
   menu) and HiDPI (ADR-0009, ADR-0023 is GTK only).
5. Fonts: ADR-0028 (bundled Tahoma substitute outside Windows) applies; check that it loads.

## 5. Open decisions

- **Architecture:** arm64 first. Intel (x86_64) only on demand, as a second build, not a Universal
  binary (it would need all Homebrew libraries as Universal).
- **Libraries in the bundle:** the `.app` must carry the Homebrew dylibs (`dylibbundler` or
  `install_name_tool`), otherwise it runs only on the build machine.
- **Packaging:** `.app` inside a `.dmg`. Signing and notarisation need an Apple Developer account;
  without them users must remove the quarantine flag (`xattr -dr com.apple.quarantine QueryMole.app`),
  which belongs in the release notes for an alpha.
- **Password storage:** ADR-0021 defers the Keychain; nothing to do for the first build.
- **Updates:** none in the alpha (ADR-0026); Velopack for macOS is a later question (ADR-0014).

## 6. State (first build)

What had to change:

- **Backend:** clang rejects a string literal directly followed by a macro in C++11 (`"...("RE_NAME")"`,
  read as a user-defined literal suffix; GCC only warns). Fixed in `myx_query.cpp` with spaces. Otherwise
  only warnings (deprecated glib functions, `register`, `sprintf`).
- **Linking the backend:** FPC on Darwin ignores the library named in `external 'libfoo.dylib'`
  (`timportlibdarwin.generatelib` is empty), so nothing from the backend was linked. The bindings now add
  `{$LINKLIB ...}` under `{$IFDEF DARWIN}` (`tools/gen_bindings.py`, `myx_types.pas` for glib).
  `build.sh` adds `-Fl$BREW/lib` for glib and passes Homebrew's `libxml2.dylib` by path for
  `xmlInitParser` in `qbr.lpr` (`-lxml2` would find the SDK's libxml2 first, a second copy next to the
  backend's).
- **Linker:** Apple's current `ld` rejects the Objective-C method lists FPC 3.2.4 writes ("malformed method
  list atom ... cocoawsextctrls.o"); `build.sh` passes `-k-ld_classic`. That linker is deprecated; when it
  is gone, a newer FPC (3.3.1) is the way out. Warnings that the dylibs are built for macOS 26 while the
  program targets 11.0 remain (harmless on the build machine, relevant for a release build).
- **Pascal:** `TThread.Handle` is a `TThreadID` (a pointer on macOS), not a `THandle` (32 bits outside
  Windows): `ConnectToInstance.pas`.
- **Screenshots** (`DevTools.CaptureWindowToPng`): copying the screen area shows whatever window is in
  front (a program started from a terminal does not come to the front); on macOS the form's `PaintTo`
  is used instead.

- macOS has no `timeout` (AGENTS.md, `tests/run-matrix.sh`): `perl -e 'alarm 60; exec @ARGV' ...` works
  for now; Homebrew `coreutils` has `gtimeout`.

Seen in the first screenshot of the connect dialog, not investigated yet: the password row is cut off at
the bottom of the group box, and the button next to "Stored Connection" shows "," instead of "...".
