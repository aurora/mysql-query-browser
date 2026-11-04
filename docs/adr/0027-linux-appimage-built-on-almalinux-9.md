# ADR-0027 — Linux release as an AppImage, bundled GTK2 and backend built on AlmaLinux 9

- Status: Accepted
- Date: 2026-11-04
- Deciders: Harald Lapp (project owner)

## Context

ADR-0026 provides an AppImage for Linux. Three things decide what it must do:

- **Distributions.** It has to run on current ones (Fedora 44, Ubuntu 26.04, which no longer install GTK2 by
  default) and on older ones in use (RHEL 9 and clones, Ubuntu 22.04, Debian 12). A program built against a
  newer glibc does not start on an older one; the other direction works.
- **What the build machine gives.** The development container is Fedora 44 (glibc 2.43, FPC 3.2.x, Lazarus 4.8).
  The Pascal program built there needs glibc 2.34 at most (checked with `objdump -T`); the C backend and the
  libraries it links in get whatever the build machine's toolchain produces.
- **Library versions.** The Fedora libraries differ from what older distributions ship. Bundled libraries must be
  the ones the program was tested with, and they must not need a newer glibc than the program.

## Decision

- **Build environment.** The backend (C/C++) and the libraries that are bundled come from an AlmaLinux 9
  container (`tools/appimage/Containerfile`): glibc 2.34, GTK 2.24, libxml2 2.9, Connector/C 3.2, OpenSSL 3.0.
  The Pascal program is still built in the Fedora container (`freepascal`), linked against that backend
  (`QBR_BACKEND_BUILD` in `build.sh`). The minimum is therefore glibc 2.34 (RHEL 9, Ubuntu 22.04, Debian 12,
  Fedora 35 and newer).
- **What is bundled** (`tools/appimage/stage.sh`): the program, the backend libraries, GTK2 with its dependencies
  (Pango, Cairo, GDK-Pixbuf, ATK, X11 extension libraries), libxml2, PCRE, OpenSSL and Connector/C with its
  authentication plugins (`MARIADB_PLUGIN_DIR` in `AppRun`), the data folders of the Windows package and the licence
  texts of what is shipped (`THIRD-PARTY-LIBS.txt`, `licenses/`).
- **What stays with the host:** the C library and loader, the graphics drivers (GL, EGL, DRM), the X11 core
  (libX11, libxcb, Xau, Xdmcp), the font stack (Fontconfig, FreeType, HarfBuzz) and libstdc++/libgcc_s. These talk
  to the host's server, configuration and drivers, or are newer on the host than what we could ship. Needed on the
  host: a C++ runtime (libstdc++ with GLIBCXX_3.4.29, GCC 11 or newer) and an X server (XWayland on a Wayland
  desktop; `AppRun` sets `GDK_BACKEND=x11`).
- **Run paths, not `LD_LIBRARY_PATH`.** Every bundled file gets its own `RUNPATH` (`patchelf`), so the programs the
  application starts (web browser) do not inherit our libraries.
- **FPU traps.** libxml2 2.9 computes NaN and infinity with `0.0/0.0` and `1.0/0.0` in `xmlInitParser`; FPC leaves
  the traps armed, so the program died with `EInvalidOp` on the bundled (and any 2.9) libxml2. `qbr.lpr` initialises
  libxml2 once with those two traps masked and restores the mask (non-Windows only), so the float semantics of
  the Pascal code stay as they are.
- **Packing** with `appimagetool` (downloaded to `tools/cache/`, not part of the repository), zstd-compressed
  squashfs. The script is `tools/package-appimage.sh`; the result is
  `dist/MySQL_Query_Browser-<version>-x86_64.AppImage`.
- **Checks.** `tests/run-matrix.sh --app-only` with `QBR_APP=dist/AppDir/AppRun` runs the application self-tests of
  the bundled stack against all six servers; the AppImage was started on Fedora 44 and on Ubuntu 26.04 (no GTK2,
  no FUSE 2 there: `--appimage-extract-and-run`).

## Consequences

- The AppImage is about 17 MB. GTK2 and its libraries are shipped by us and have to be updated by new releases
  (security fixes of AlmaLinux 9's packages are not picked up by the users' distributions).
- Connector/C is 3.2 in the AppImage, 3.4 in the development container (ADR-0005 notes the TLS default of
  3.4). The matrix passes with both; a difference in behaviour would show there first.
- The widgetset is GTK2 (ADR-0024); with a switch to Qt the bundle changes completely.
- The look follows GTK2's default theme (Raleigh) plus the user's `~/.gtkrc-2.0`; the host's themes are not bundled.
- Without FUSE 2 (Ubuntu 22.04 and newer do not install it by default) the image starts with
  `--appimage-extract-and-run` or after extracting it; the release notes say so.
- Not covered: aarch64, other C libraries (musl), macOS (separate work).
