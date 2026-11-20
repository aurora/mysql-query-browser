<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# Licence review

Status: 2026-10-12 (updated the same day: IpHtml and the manual extract are no longer part of the program, ADR-0016). This is an engineering review of what the project contains and ships, done
from the sources and the package metadata on the development machine. **It is not legal advice**;
the items marked *open* need a decision, and a public release should be checked by someone
qualified.

The project is GPL-2.0-or-later (ADR-0011). Everything below asks: can the thing be part of, or be
shipped with, a program under that licence?

## 1. This repository's own code

| What | Finding |
|---|---|
| Ported Delphi/C code from MySQL AB (`app/src`, `backend/src`) | Headers say "version 2 of the License, or (at your option) any later version" (checked by scanning all file headers: 55 + 63 files with the GPL-or-later text or the SPDX line; no "version 2 only" header found). |
| 17 ported files with **no licence header** in the original (e.g. `Toolbar.pas`, `Sections.pas`, `EditorTable.pas`, `ConnectToInstance.pas`, parts of the SQL parser) | They come from the same GPL-2.0-or-later repository (`COPYING`), so the project licence applies; the absence of a header is the original's. Kept as ported. |
| 21 backend files (utilities, generic runtime headers) | LGPL-2.1-or-later headers: compatible, may be combined into the GPL program. |
| `ColorTools.pas`, `StringContainers.pas`, `UniCodeConsole.pas` (Mike Lischke / Mike Zinner) | MIT licence in the header, compatible with GPL. Obligations: keep the notice (done, headers are kept) and the authors' request for credit in the product documentation; `NOTICE` records it (added). |
| PCRE exception from MySQL AB | In `NOTICE`, unchanged. |
| New files | SPDX line only; no invented copyright holders (`AGENTS.md`). |

## 2. Libraries shipped next to `querymole.exe` (dynamic linking)

From the MSYS2 packages the DLLs come from (`pacman -Qi`); `THIRD-PARTY-DLLS.txt` in the package
lists the exact names and versions, `licenses/msys2/` carries the licence files that the packages
contain.

| Library (DLL) | Licence (package metadata) | Fit with GPL-2.0-or-later |
|---|---|---|
| MariaDB Connector/C (libmariadb) | LGPL-2.1-or-later | OK, dynamic linking. |
| glib, gettext-runtime (libintl), libiconv | LGPL-2.1-or-later (libintl package also lists GPL-3.0-or-later for non-library parts) | OK. |
| libxml2, curl, nghttp2/3, ngtcp2, libpsl, brotli | MIT | OK. |
| pcre, pcre2, libssh2 | BSD-3-Clause | OK. |
| zlib | Zlib | OK. |
| zstd | BSD-3-Clause OR GPL-2.0-or-later | OK. |
| libwinpthread | MIT AND BSD-3-Clause-Clear | OK. |
| libgcc, libstdc++ | GPL-3.0-or-later WITH GCC-exception-3.1 | OK: the runtime library exception covers programs compiled with GCC. |
| libidn2 | GPL-2.0-or-later and LGPL-3.0-or-later | OK. The package carries **no licence file**; texts are in `licenses/lazarus/` (GPL/LGPL). |
| libunistring | LGPL-3.0-or-later OR GPL-3.0-or-later | OK. |
| velopack_libc (Velopack native library, optional) | MIT | OK. Added with ADR-0018. `package.sh` and `package-appimage.sh --velopack` take the library from the velopack-pas release the submodule is pinned to (`fetch-native.py --with-license`) and ship both licences, velopack-pas's and Velopack's own (`LICENSE-velopack.txt` from the release archive), in `licenses/velopack/`. |
| **OpenSSL 3 (libssl, libcrypto)** | **Apache-2.0** | Apache-2.0 is compatible with GPL **version 3**, not with GPL-2.0-only. Because the project is "2 or later", the combined binary can be distributed under GPL-3.0-or-later. This is why the "or later" must not be dropped (a `GPL-2.0-only` relicensing would break it). |
| Backend DLLs `libmysql*.dll` | built from this repository (GPL/LGPL, see §1) | OK. |

Not a licence matter but relevant: libcurl, libssh2, nghttp*, ngtcp2 and their dependencies are only
there because libmariadb is built with them; a smaller package needs a different Connector/C
build (ADR-0003/ADR-0014).

### Linux AppImage

The AppImage takes its libraries from AlmaLinux 9 packages; `THIRD-PARTY-LIBS.txt` in the image lists each file with
its package, version and the licence the package states, `licenses/rpm/` carries the packages' licence files. Added
for the Qt6 widgetset (ADR-0044; the GTK2 image bundles GTK2 instead):

| Library | Licence | Fit with GPL-2.0-or-later |
|---|---|---|
| Qt 6 (Core, Gui, Widgets, PrintSupport, DBus, XcbQpa, WaylandClient and the platform plugins; EPEL `qt6-qtbase`, `qt6-qtwayland`) | LGPL-3.0-only OR GPL-3.0-only WITH Qt-GPL-exception-1.0 (package metadata) | OK under LGPL-3.0, dynamic linking; like Apache-2.0 above, LGPL-3.0 parts make the combination GPL-3.0-or-later, another reason the "or later" must stay. The libraries are shipped unmodified as separate files, so a user can replace them. |
| libQt6Pas (Free Pascal Qt6 binding, built from the Lazarus sources by `tools/appimage/build-qt6pas.sh`) | LGPL with the same linking exception as the LCL (`COPYING.TXT` of the binding, shipped in `licenses/qt6pas/`) | OK. The sources are part of the Lazarus distribution the program is built with. |
| libssh 0.12 (SSH tunnel, ADR-0048; built from the libssh.org release by `tools/appimage/build-libssh.sh`, checksum checked) | LGPL-2.1-or-later (`COPYING`, shipped in `licenses/libssh/`) | OK, dynamic linking. Bundled only once the program links it; on Windows it will come from MSYS2 (`mingw-w64-x86_64-libssh`, same licence). |

## 3. Pascal components linked into `querymole.exe` (static linking)

Found by listing the units in the executable and reading their headers.

| Component | Licence | Fit |
|---|---|---|
| FPC RTL/FCL, LCL, LazUtils, LCLExtensions, regexpr | LGPL with the Lazarus/FPC linking exception (`COPYING.modifiedLGPL`) | OK, the exception allows static linking into any licence. |
| laz.VirtualTrees (VirtualTreeView) | MPL-1.1 **or** LGPL-2.1-or-later | OK: use it under the LGPL alternative. |
| SynEdit (29 linked units with the dual statement; 9 more units carry no licence header at all) | MPL-1.1 **or** GPL-2.0-or-later | OK: use it under the GPL alternative. The header-less units are part of the same package and are taken to follow it. |
| **SynEdit units `SynEditHighlighter`, `SynEditHighlighterFoldBase`, `SynTextDrawer`** | **MPL-1.1 only** in the headers of the Lazarus copy (the upstream "alternatively GPL" paragraph is missing in these files) | *Open.* See below. |
| IpHtml (TurboPower Internet Professional) | MPL-1.1 only | *Resolved:* not linked any more; the help pane is a read-only SynEdit (ADR-0016). |

**The MPL-1.1 question** (now only for the three SynEdit units; IpHtml was removed). The FSF classes MPL-1.1 as free but *not compatible with the GPL*
(MPL-2.0 is). A GPL program that statically links MPL-1.1-only units is, by the FSF's reading, a
combination the GPL cannot cover. Counter-points: the Lazarus IDE (GPL) itself ships SynEdit and
IpHtml, and MPL-1.1's "Larger Work" clause allows combination as long as the MPL parts stay under the
MPL with their source available (they do, in the Lazarus distribution). Neither point settles the
question; this is a risk to decide on, not a verified problem.

Options:

1. ~~IpHtml~~ removed (ADR-0016).
2. **SynEdit's three units:** the file-level headers are what counts, so asking the Lazarus maintainers
   whether the missing "alternatively GPL" paragraph is intended is the way to clear it; there is no
   technical alternative short of replacing the editor (ADR-0015 E).

Recommendation: ask the Lazarus maintainers before the first public release.

## 4. Data and content that is shipped

| What | Finding |
|---|---|
| ~~`doc/mysqlqb_statements.html`, `mysqlqb_functions.html`~~ (extract of the **MySQL 5.0 reference manual**) — **no longer shipped** (ADR-0016; the reference comes from the connected server). Earlier finding: | The MySQL reference manual is **not** GPL. The Oracle-hosted copy of the 5.0 manual states that the documentation is not distributed under a GPL licence; copies of 1997-2008 (MySQL AB) allow conversion to other formats if the content is not altered and do not allow redistribution except in the way MySQL disseminates it. The original GPL product shipped these files (MySQL AB was the rightsholder); that does not give this fork the same permission. Resolved by not shipping them. The `mysqlqb_quickstart.html` is the Query Browser's own guide (GPL, original product). |
| `XML/*.xml` (function and statement index, charsets, datatypes) | Part of the original GPL product. OK. |
| `fonts/Vera*.ttf` (Bitstream Vera Mono) | Bitstream Vera licence: free to use, copy and redistribute, with the licence text accompanying; names may not be used for modified fonts. The text is embedded in the font; `docs/third-party/Bitstream-Vera-fonts.txt` holds it and the package includes it (`licenses/fonts/`). |
| `fonts/tahoma.ttf`, `tahomabd.ttf` (Wine's stand-in for Tahoma; Linux and macOS packages only) | Copyright (c) 2004 Larry Snyder, derived from Bitstream Vera Sans (renamed, as the Vera licence demands), distributed by the Wine project under LGPL-2.1-or-later (the text is in the font's licence field and in `third_party/fonts/wine-tahoma/LICENSE-LGPL-2.1.txt`). The packages ship them with one change: `tools/prepare_runtime.py` removes the embedded bitmap glyph tables (EBDT/EBLC/EBSC; 2026-11-20, so that Qt uses the outline line metrics), the outlines and all other tables are unchanged. LGPL-2.1 allows modified copies; the change is stated in the shipped `licenses/fonts/wine-tahoma/README.md`, and the unmodified files with their checksums are in the repository. The licence is met by shipping the notices (`licenses/fonts/`); the fonts are loaded as data files, not linked into the program. Microsoft's Tahoma is not shipped. Provenance and checksums: `third_party/fonts/wine-tahoma/README.md`. |
| Icons, images, resources compiled from `legacy/` | Part of the original GPL product (Copyright MySQL AB). OK; trademark aspects are separate (see below). |
| QueryMole artwork, icon and wordmark (`assets/querymole-about.png`, `assets/querymole-icon.png`, `assets/querymole-icon-small.png`, `assets/querymole-text.png`, `assets/querymole-text-1.png`; About picture, application icon and the other pictures made from them, ADR-0032, ADR-0033) | Generated by the project owner with an OpenAI image model (2026-11-15). OpenAI's terms assign the rights in the output, as far as any exist, to the user; a picture made without human authorship is probably not protected by copyright at all (DE, US). Either way nothing restricts shipping it with the program; it is distributed under the project's licence. No third party's notice is needed in `NOTICE`. |
| `locale/*.po` translations | Original GPL product; translators' names are in the files. OK. |
| Velopack (installer and `Update.exe` in the Setup) | Velopack is MIT licensed (not verified against the installed vpk 1.2.0 for this review). |

## 5. Trademarks

"MySQL" is Oracle's trademark. Resolved by ADR-0030: the program is called QueryMole; window title,
version resource, package title and the pictures with the MySQL logo were changed. "MySQL Query Browser"
remains only where the program says what it is based on (About dialog) and where it looks for an
installed original.

## 6. What changed because of this review

- `NOTICE`: MIT-licensed parts by Lischke/Zinner, MPL-licensed components and the documentation
  status added.
- `tools/package.sh`: the package now carries `THIRD-PARTY-DLLS.txt` (package, version, SPDX
  expression per DLL), the licence files of the MSYS2 packages (`licenses/msys2/`), the Lazarus
  licence texts (`licenses/lazarus/`), the Bitstream Vera licence (`licenses/fonts/`), and this document.
- This document.

## 7. Open decisions (for the project owner)

1. The three SynEdit units (MPL-1.1 only): ask the Lazarus maintainers (§3). (IpHtml and the manual extract are gone.)
2. What the server's help tables contain is the vendor's content shown at run time; nothing is redistributed.
3. Name and trademark (§5).
4. Code signing and legal review before a public release.

## Sources used for the statements about third parties

- FSF licence list: MPL-1.1 is not GPL-compatible, MPL-2.0 is (mirrored in e.g. the R licence database
  and described on the [Mozilla Public License](https://en.wikipedia.org/wiki/Mozilla_Public_License) page).
- [MySQL 5.0 Reference Manual (Oracle-hosted copy)](https://docs.oracle.com/cd/E19078-01/mysql/mysql-refman-5.0/index.html):
  licence notice of the documentation.
- MSYS2 package metadata (`pacman -Qi`), Lazarus source headers (`C:\lazarus\components\...`).
