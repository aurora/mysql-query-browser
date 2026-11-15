#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Writes the images that carry the product name (ADR-0030) into app/images/: the original's
# pictures with the MySQL logo and the words "MySQL Query Browser" replaced by the QueryMole wordmark
# and icon, and the QueryMole artwork (ADR-0030, ADR-0032, ADR-0033) in the sizes the program needs.
# build_resources.py uses these files instead of the originals.
#
# Needs ImageMagick 7 (`magick`). Run it again after changing it; the
# results are committed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/legacy/mysql-query-browser/images"
OUT="$ROOT/app/images"

mkdir -p "$OUT"

# About dialog (ADR-0032): the QueryMole artwork (assets/querymole-about.png, the mole on the left, empty navy on
# the right) scaled to the height of the dialog's picture (341), and the wordmark with slogan and rule
# (assets/querymole-text-1.png, transparent) set top right, 250 pixels wide at x 400, y 14. The dialog writes its
# texts below the rule (x 405-647, y 100) in a column of its width (AboutColLeft/Top/Width in CommonFuncs, which
# also sets the text colours); change both together.
magick "$ROOT/assets/querymole-about.png" -resize x341 \
  \( "$ROOT/assets/querymole-text-1.png" -resize 250x \) -geometry +400+14 -composite \
  -alpha off -depth 8 -strip "$OUT/about.png"

# The QueryMole icon (ADR-0033) from assets/querymole-icon.png, made square on a transparent canvas. It replaces
# the original's lightning bolt everywhere.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
magick "$ROOT/assets/querymole-icon.png" -background none -gravity center -extent 304x304 "$tmp/icon.png"
# The simplified icon without the mole (assets/querymole-icon-small.png: database and magnifier) for 16 and 24
# pixels, where the mole is no longer recognisable.
magick "$ROOT/assets/querymole-icon-small.png" -background none -gravity center -extent 150x150 "$tmp/small.png"
# application icon (qbr.exe, window icon, Velopack) and the picture for the AppImage
magick \( "$tmp/icon.png" -resize 256x256 \) \( "$tmp/icon.png" -resize 128x128 \) \( "$tmp/icon.png" -resize 64x64 \) \
  \( "$tmp/icon.png" -resize 48x48 \) \( "$tmp/icon.png" -resize 32x32 \) \
  \( "$tmp/small.png" -resize 24x24 \) \( "$tmp/small.png" -resize 16x16 \) "$OUT/querymole.ico"
magick "$tmp/icon.png" -resize 256x256 -strip "$OUT/querymole.png"

# The QueryMole wordmark (assets/querymole-text.png, on an off-white background): background made
# transparent, trimmed to the letters.
magick "$ROOT/assets/querymole-text.png" -fuzz 10% -transparent "rgb(248,249,251)" -trim +repage "$tmp/text.png"

# Header of the connect dialog (418x67). The original's logo and words sit on white (x <= 148) and are
# painted over; the wordmark goes in their place, vertically centred on the icon. The blue line at the
# bottom (y >= 61) stays. The bolt on the right (x 367-407) is painted over with the column left of it,
# then the icon is set in its place.
magick "$SRC/connect_header_qb.png" \
  -fill white -draw 'rectangle 0,0 148,59' \
  \( "$tmp/text.png" -resize x30 \) -gravity west -geometry +12-3 -composite -gravity northwest \
  \( "$SRC/connect_header_qb.png" -crop 1x61+360+0 +repage -scale '58x61!' \) \
  -geometry +360+0 -composite \
  \( "$tmp/icon.png" -resize 50x50 \) -geometry +362+5 -composite \
  -strip "$OUT/connect_header_qb.png"

# Still picture top right in the main window (sakila, 56x54; the original shows the MySQL dolphin there): the
# icon, centred on a transparent canvas.
magick -size 56x54 xc:none \( "$tmp/icon.png" -resize 48x48 \) -gravity center -composite -strip "$OUT/sakila.png"

echo "written: $OUT/about.png $OUT/connect_header_qb.png $OUT/sakila.png $OUT/querymole.ico $OUT/querymole.png"
