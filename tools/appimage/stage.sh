#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Assembles the AppDir of the Linux AppImage. Runs INSIDE the qbr-appimage-el9 container (glibc 2.34), started by
# tools/package-appimage.sh with the repository at /src and the output folder at /out. QBR_WIDGETSET (gtk2 or qt6) names
# the widgetset app/bin/querymole was built with; GTK2 or Qt 6 is bundled accordingly.
#
# Everything the program needs besides the C library, the X11 core, the font stack and libstdc++ is copied from the
# container, so the result does not depend on what the host has (GTK2 is not installed by default any more, Qt 6 is not
# everywhere and not in the version the program needs).
set -eu

SRC=/src
APPDIR=/out/AppDir
BACKEND=$SRC/backend/build-el9
WIDGETSET=${QBR_WIDGETSET:-gtk2}
QTPLUGINS=/usr/lib64/qt6/plugins

# the program must be the one of this widgetset (app/bin holds the last one built)
case "$WIDGETSET" in
  gtk2) needed=libgtk-x11-2.0 ;;
  qt6)  needed=libQt6Pas ;;
  *) echo "unknown widgetset: $WIDGETSET" >&2; exit 2 ;;
esac
readelf -d "$SRC/app/bin/querymole" | grep -q "NEEDED.*\[$needed" \
  || { echo "app/bin/querymole was not built with $WIDGETSET (no $needed)" >&2; exit 1; }

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib"

install -m 755 "$SRC/app/bin/querymole" "$APPDIR/usr/bin/querymole"
strip --strip-debug "$APPDIR/usr/bin/querymole"
cp "$BACKEND"/*.so "$APPDIR/usr/lib/"
for d in XML doc fonts locale; do
  cp -r "$SRC/app/bin/$d" "$APPDIR/usr/bin/$d"
done
cp "$SRC/LICENSE" "$SRC/NOTICE" "$APPDIR/"

# Connector/C authentication plugins (caching_sha2_password for MySQL 8+, ...; the Kerberos one would drag in krb5)
GTKVER=2.10.0
mkdir -p "$APPDIR/usr/lib/mariadb/plugin"
if [ "$WIDGETSET" = gtk2 ]; then
  # GTK2 theme engine (the default theme needs none, a user's gtkrc may name "pixmap"), image loaders
  mkdir -p "$APPDIR/usr/lib/gtk-2.0/$GTKVER/engines" "$APPDIR/usr/lib/gdk-pixbuf-2.0/$GTKVER/loaders"
  cp /usr/lib64/gtk-2.0/$GTKVER/engines/libpixmap.so "$APPDIR/usr/lib/gtk-2.0/$GTKVER/engines/"
  for l in bmp gif ico pnm tga xbm xpm; do
    cp /usr/lib64/gdk-pixbuf-2.0/$GTKVER/loaders/libpixbufloader-$l.so "$APPDIR/usr/lib/gdk-pixbuf-2.0/$GTKVER/loaders/"
  done
else
  # the binding built by build-qt6pas.sh, and the Qt plugins a widget program needs: the X11 and Wayland platforms
  # (with Wayland's shell, decoration and graphics parts, and OpenGL on X11), compose and IBus input. No style or
  # platform theme plugins: the program sets Fusion, which is built in (ADR-0045). The image loaders are not needed
  # either, the LCL reads its pictures itself.
  cp -L "$BACKEND/qt6pas/libQt6Pas.so.6" "$APPDIR/usr/lib/"
  mkdir -p "$APPDIR/usr/lib/qt6/plugins/platforms" "$APPDIR/usr/lib/qt6/plugins/platforminputcontexts"
  cp "$QTPLUGINS"/platforms/libqxcb.so "$QTPLUGINS"/platforms/libqwayland*.so "$APPDIR/usr/lib/qt6/plugins/platforms/"
  for c in xcbglintegrations wayland-shell-integration wayland-decoration-client wayland-graphics-integration-client; do
    [ -d "$QTPLUGINS/$c" ] && cp -r "$QTPLUGINS/$c" "$APPDIR/usr/lib/qt6/plugins/"
  done
  cp "$QTPLUGINS"/platforminputcontexts/libcomposeplatforminputcontextplugin.so \
     "$QTPLUGINS"/platforminputcontexts/libibusplatforminputcontextplugin.so "$APPDIR/usr/lib/qt6/plugins/platforminputcontexts/"
  # Qt finds its plugins through qt.conf next to the program; QT_PLUGIN_PATH would leak into the programs the
  # application starts
  printf '[Paths]\nPrefix = ..\nPlugins = lib/qt6/plugins\n' > "$APPDIR/usr/bin/qt.conf"
fi
for p in caching_sha2_password client_ed25519 dialog mysql_clear_password sha256_password; do
  cp /usr/lib64/mariadb/plugin/$p.so "$APPDIR/usr/lib/mariadb/plugin/"
done

# Libraries that stay with the host: the C library and loader, graphics drivers, the X11 core (talks to the host's
# server), the font stack (reads the host's configuration and caches) and libstdc++/libgcc_s (newer ones on the host
# must not be shadowed). Everything else the closure finds is bundled, libOpenGL.so.0 included: Qt 6 needs it to load,
# the program does not draw with OpenGL, and many desktops do not have it (Ubuntu's libopengl0); it is only the
# libglvnd dispatcher in front of the host's GL.
excluded() {
  case "$1" in
    ld-linux-x86-64.so.*|linux-vdso.so.*|libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libutil.so.*|\
    libresolv.so.*|libnsl.so.*|libcrypt.so.*|libanl.so.*|libBrokenLocale.so.*|\
    libGL.so.*|libGLX.so.*|libGLdispatch.so.*|libEGL.so.*|libgbm.so.*|libdrm*.so.*|\
    libX11.so.*|libX11-xcb.so.*|libxcb.so.*|libXau.so.*|libXdmcp.so.*|\
    libfontconfig.so.*|libfreetype.so.*|libharfbuzz.so.*|\
    libstdc++.so.*|libgcc_s.so.*)
      return 0 ;;
  esac
  return 1
}

# closure over ldd, repeated until nothing new turns up
for pass in 1 2 3 4 5 6; do
  added=0
  for f in $(find "$APPDIR/usr" -type f \( -name '*.so' -o -name '*.so.*' -o -name querymole \)); do
    new=$(ldd "$f" 2>/dev/null | awk '/=> \// {print $1, $3}' | while read -r name path; do
      excluded "$name" && continue
      [ -e "$APPDIR/usr/lib/$name" ] && continue
      cp -L "$path" "$APPDIR/usr/lib/$name"
      echo "$name"
    done)
    if [ -n "$new" ]; then added=1; echo "bundled: $new" | tr '\n' ' '; echo; fi
  done
  [ "$added" = 1 ] || break
done

# Each file finds its neighbours through its own run path: LD_LIBRARY_PATH would leak into the programs the
# application starts (web browser, file manager).
chmod -R u+w "$APPDIR"
patchelf --set-rpath '$ORIGIN/../lib' "$APPDIR/usr/bin/querymole"
for f in "$APPDIR"/usr/lib/*.so "$APPDIR"/usr/lib/*.so.*; do
  patchelf --set-rpath '$ORIGIN' "$f"
done
for f in "$APPDIR"/usr/lib/gtk-2.0/$GTKVER/engines/*.so "$APPDIR"/usr/lib/gdk-pixbuf-2.0/$GTKVER/loaders/*.so \
         "$APPDIR"/usr/lib/qt6/plugins/*/*.so; do
  [ -e "$f" ] || continue
  patchelf --set-rpath '$ORIGIN/../../..' "$f"
done
for f in "$APPDIR"/usr/lib/mariadb/plugin/*.so; do
  patchelf --set-rpath '$ORIGIN/../..' "$f"
done

# image loader cache with a placeholder that AppRun replaces by the mount point
if [ "$WIDGETSET" = gtk2 ]; then
  gdk-pixbuf-query-loaders-64 "$APPDIR"/usr/lib/gdk-pixbuf-2.0/$GTKVER/loaders/*.so \
    | sed "s|$APPDIR|@APPDIR@|g" > "$APPDIR/usr/lib/gdk-pixbuf-2.0/$GTKVER/loaders.cache.in"
fi

# what was bundled and under which licence (the package database of the container knows)
mkdir -p "$APPDIR/licenses/rpm"
{
  echo "Libraries shipped in usr/lib, taken from the AlmaLinux 9 packages named below (the libmysql*.so are built from"
  echo "this repository). The licence texts the packages carry are in licenses/rpm/. docs/licenses.md has the review."
  echo "Sources of these packages: https://almalinux.org/ (SRPMs), https://vault.centos.org/ and upstream projects."
  echo
  find "$APPDIR/usr" -type f \( -name '*.so' -o -name '*.so.*' \) | sort | while read -r f; do
    rel=${f#$APPDIR/}
    base=$(basename "$f")
    case "$base" in libmysql*) echo "$rel | this project (GPL-2.0-or-later / LGPL-2.1-or-later parts, see NOTICE)"; continue ;; esac
    case "$base" in libQt6Pas.so*) echo "$rel | Free Pascal Qt6 binding $(sed -n 's/^else:VERSION = //p' $SRC/tools/cache/qt6pas-src/Qt6Pas.pro), built from the Lazarus sources | LGPL with linking exception (licenses/qt6pas/COPYING.TXT)"; continue ;; esac
    # the copy keeps the name of the soname link, the package owns the real file
    owner=$(rpm -qf "$(ls /usr/lib64/$base /usr/lib64/gtk-2.0/$GTKVER/engines/$base /usr/lib64/gdk-pixbuf-2.0/$GTKVER/loaders/$base \
            /usr/lib64/mariadb/plugin/$base $QTPLUGINS/*/$base 2>/dev/null | head -1)" --qf '%{NAME}' 2>/dev/null || true)
    if [ -z "$owner" ]; then echo "$rel | unknown package"; continue; fi
    echo "$rel | $(rpm -q "$owner" --qf '%{NAME}-%{VERSION}-%{RELEASE} | %{LICENSE}')"
  done
} > "$APPDIR/THIRD-PARTY-LIBS.txt"

for pkg in $(grep -o '| [A-Za-z0-9_+.-]*-[0-9][^ ]* |' "$APPDIR/THIRD-PARTY-LIBS.txt" | tr -d '|' | sed 's/-[0-9].*//' | sort -u); do
  for lf in $(rpm -ql "$pkg" | grep '^/usr/share/licenses/.*[^/]$' || true); do
    [ -f "$lf" ] || continue
    mkdir -p "$APPDIR/licenses/rpm/$pkg"
    cp "$lf" "$APPDIR/licenses/rpm/$pkg/"
  done
done

if [ "$WIDGETSET" = qt6 ]; then
  mkdir -p "$APPDIR/licenses/qt6pas"
  cp "$SRC/tools/cache/qt6pas-src/COPYING.TXT" "$APPDIR/licenses/qt6pas/"
fi

echo "staged $APPDIR ($(du -sh "$APPDIR" | cut -f1))"
