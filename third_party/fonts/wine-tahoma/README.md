<!-- SPDX-License-Identifier: LGPL-2.1-or-later -->
# Wine Tahoma

`tahoma.ttf` and `tahomabd.ttf` are the free stand-in for Microsoft's Tahoma that the Wine project ships
(`fonts/` in <https://gitlab.winehq.org/wine/wine>, taken from the GitHub mirror `wine-mirror/wine`, master at
7692c6213e2c1c2f9cea92cc29ea13afc582865f, 2026-11-04). Unmodified copies of the prebuilt files.

| File | SHA-256 |
|---|---|
| `tahoma.ttf` | `90f1abad4da0ce03da5d2277ee75a9600ce812d37c90eab76e0838ffa7937e55` |
| `tahomabd.ttf` | `d6fcea0c44f27a390de57e86cfbc10d06a169342d56422bd66698a8158c0993b` |

- **Authors:** Copyright (c) 2004 Larry Snyder, based on Bitstream Vera Sans, Copyright (c) 2003 Bitstream, Inc.
  The font was renamed as the Bitstream Vera licence requires (`docs/third-party/Bitstream-Vera-fonts.txt`).
- **Licence:** GNU Lesser General Public License 2.1 or later (the text is in the font's licence field; `LICENSE-LGPL-2.1.txt`
  is Wine's copy of it).
- **Why:** the forms of the original are laid out for Tahoma. Where it is missing (Linux, macOS) the substitute chosen
  by the system is wider and cuts texts off (ADR-0028). Windows has the real Tahoma, so the Windows package does not
  carry these files.
- The family name is "Tahoma", as in Wine, so that the program's font requests find it. It is a stand-in, not
  Microsoft's font.
