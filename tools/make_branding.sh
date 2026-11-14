#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Writes the images that carry the product name (ADR-0030) into app/images/: the original's
# pictures with the MySQL logo and the words "MySQL Query Browser" removed and "QueryMole" set in
# their place. The rest of each picture (gradient, lightning bolt) is the original artwork.
# build_resources.py uses these files instead of the originals.
#
# Needs ImageMagick 7 (`magick`), icotool (icoutils) and the Liberation Sans font. Run it again after changing it; the
# results are committed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/legacy/mysql-query-browser/images"
OUT="$ROOT/app/images"
NAME="QueryMole"
BLUE="rgb(0,103,142)"            # the colour of "Query Browser" in the original pictures
FONT="$(fc-match -f '%{file}' 'Liberation Sans:style=Regular')"

mkdir -p "$OUT"

# About dialog (720x341, ADR-0032): the QueryMole artwork (assets/querymole-about.png) scaled to 720x277, on its
# background colour, the lowest rows faded into the band below. The dialog writes its texts into the empty area
# right of the mole, below the line under the slogan (x >= 468, y >= 104; CommonFuncs.CreateAboutForm, which also
# sets the text colours). If the artwork changes, check those numbers.
NAVY="rgb(13,32,53)"             # background of the artwork
magick -size 720x341 "xc:$NAVY" \
  \( "$ROOT/assets/querymole-about.png" -resize 720x -alpha set \
     \( -size 720x261 xc:white -size 720x16 gradient:white-black -append \) \
     -compose CopyOpacity -composite \) \
  -compose Over -geometry +0+0 -composite \
  -alpha off -depth 8 -strip "$OUT/about.png"

# Header of the connect dialog (418x67). The logo and the words sit on white; the blue line at the
# bottom (y >= 61) stays.
magick "$SRC/connect_header_qb.png" \
  -fill white -draw 'rectangle 0,0 148,59' \
  -font "$FONT" -pointsize 26 -fill "$BLUE" -annotate +8+44 "$NAME" \
  -strip "$OUT/connect_header_qb.png"

# Still picture top right in the main window (sakila, 56x54; the original shows the MySQL dolphin there): the
# lightning bolt of the application icon, centred on a transparent canvas. Placeholder until QueryMole has a logo.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
icotool -x -w 32 -h 32 -b 32 -o "$tmp" "$SRC/icons/MySQLQueryBrowser.ico"
magick -size 56x54 xc:none "$tmp"/*.png -gravity center -composite -strip "$OUT/sakila.png"

echo "written: $OUT/about.png $OUT/connect_header_qb.png $OUT/sakila.png"
