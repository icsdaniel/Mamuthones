#!/bin/sh
# Builds every pxl art file (tools/art/pxl/art/*.px.js) into game/art/pxl/<file>/<sprite>.png.
#   sh tools/art/pxl/build.sh [rings ...]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GAME="$HERE/../../../game"
TMP=$(mktemp -d)
names="$*"
[ -z "$names" ] && names=$(cd "$HERE/art" && ls *.px.js | grep -v '^palette' | sed 's/\.px\.js$//')
for n in $names; do
  node "$HERE/bin/pxl.js" build "$HERE/art/$n.px.js" --out "$TMP/$n" --no-preview > /dev/null
  mkdir -p "$GAME/art/pxl/$n"
  rm -f "$GAME/art/pxl/$n"/*.png
  cp "$TMP/$n"/sprites/*.png "$GAME/art/pxl/$n/" 2>/dev/null || true
  [ -d "$TMP/$n/anims" ] && cp "$TMP/$n"/anims/*.png "$TMP/$n"/anims/*.json "$GAME/art/pxl/$n/"
  echo "$n: $(ls "$GAME/art/pxl/$n" | grep -c png) pictures"
done
rm -rf "$TMP"
