#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Writes the images that carry the product name (ADR-0030) into app/images/: the original's
# pictures with the MySQL logo and the words "MySQL Query Browser" removed and "QueryMole" set in
# their place. The rest of each picture (gradient, lightning bolt) is the original artwork.
# build_resources.py uses these files instead of the originals.
#
# Needs ImageMagick 7 (`magick`) and the Liberation Sans font. Run it again after changing it; the
# results are committed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/legacy/mysql-query-browser/images"
OUT="$ROOT/app/images"
NAME="QueryMole"
BLUE="rgb(0,103,142)"            # the colour of "Query Browser" in the original pictures
FONT="$(fc-match -f '%{file}' 'Liberation Sans:style=Regular')"

mkdir -p "$OUT"

# About dialog and splash screen (444x341). The background behind the logo is a vertical gradient, so
# a clean column (x = 262, left of the bolt) stretched over the logo area removes it.
magick "$SRC/about.png" \
  \( "$SRC/about.png" -crop 1x110+262+125 +repage -scale '245x110!' \) \
  -geometry +15+125 -composite \
  -font "$FONT" -pointsize 40 -fill "$BLUE" -annotate +24+219 "$NAME" \
  -strip "$OUT/about.png"

# Header of the connect dialog (418x67). The logo and the words sit on white; the blue line at the
# bottom (y >= 61) stays.
magick "$SRC/connect_header_qb.png" \
  -fill white -draw 'rectangle 0,0 148,59' \
  -font "$FONT" -pointsize 26 -fill "$BLUE" -annotate +8+44 "$NAME" \
  -strip "$OUT/connect_header_qb.png"

echo "written: $OUT/about.png $OUT/connect_header_qb.png"
