<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# macOS (Apple Silicon): first build, checklist

Status: **nothing here has been tried yet.** This is the list of steps for the first attempt on a
Mac with an M processor, and of the places where `build.sh` and the backend will need changes.
Write down what you find in `docs/linux-port.md` style (state and open problems), and write an ADR
(see ADR-0027 for the Linux counterpart) once the widgetset and the packaging are decided.

## 1. Tools

```bash
xcode-select --install                       # compiler, make, git, SDK
brew install cmake ninja pkg-config python@3 glib libxml2 pcre mariadb-connector-c libiconv
```

- `pcre` is PCRE1 (`pkg_check_modules(PCRE ... libpcre)` in `backend/CMakeLists.txt`). Homebrew has
  deprecated that formula; if it is gone, either build PCRE 8.45 from source into a prefix or move
  the backend to PCRE2 (a separate change with its own ADR, ADR-0003 territory).
- Check `pkg-config --modversion glib-2.0 gthread-2.0 libxml-2.0 libpcre libmariadb`; all five must
  answer. Homebrew installs on arm64 under `/opt/homebrew`; add
  `export PKG_CONFIG_PATH=/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libxml2/lib/pkgconfig:/opt/homebrew/opt/mariadb-connector-c/lib/pkgconfig`
  if a `.pc` file is not found.

## 2. Free Pascal and Lazarus

- Lazarus 4.x for macOS aarch64 from <https://www.lazarus-ide.org> (the installer brings FPC).
  Check `fpc -iTP -iTO` prints `aarch64 darwin`.
- FPC 3.2.2 is the weak point on arm64: if it fails on the project, use FPC 3.2.3 (fixes branch) or
  3.3.1, the same family as in the Linux distrobox (3.2.3).
- Widgetset **cocoa** (`lazbuild --ws=cocoa`). GTK2/Qt from Homebrew are not an option for a Mac
  program (ADR-0024 lists GTK2 only for the first Linux release).

## 3. Backend

```bash
cmake -S backend -B backend/build-macos -G Ninja
cmake --build backend/build-macos
```

Expect problems in `backend/compat` (shim headers) and in the old C code (ADR-0003: undefined
behaviour that a newer clang rejects or exposes). The link line for Windows adds `ws2_32` etc.; check
that nothing Linux- or Windows-only is missing for `APPLE`.

## 4. Application

`build.sh` does not know macOS yet: it treats everything that is not MSYS as Linux. For a try, call
the pieces by hand:

```bash
export DYLD_LIBRARY_PATH="$PWD/backend/build-macos:${DYLD_LIBRARY_PATH:-}"
python3 tools/gen_version.py
cd app && lazbuild --ws=cocoa --opt="-Fl$PWD/../backend/build-macos" qbr.lpi
```

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
