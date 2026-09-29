#!/bin/bash
# Regenerates every art asset: textures, the pixel UI kit, logo and icons (numpy), then the stop
# cards (Godot, needs xvfb-run). Godot runs on a private copy of game/ so it never touches the shared
# import cache; the results are written back into game/art/.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$ROOT/tools/art/make_textures.py"
# The pixel UI kit, menu backdrop, logo, word mark and app icons (numpy).
python3 "$ROOT/tools/art/pixel/ui_kit.py"
python3 "$ROOT/tools/art/pixel/logo.py"
# The characters, then everything drawn with them.
python3 "$ROOT/tools/art/pixel/bake_figures.py"
# The play field and title scene in pixel art: scenery, field sprites and pixel type (numpy).
python3 "$ROOT/tools/art/pixel/scenery.py"
python3 "$ROOT/tools/art/pixel/field.py"
python3 "$ROOT/tools/art/pixel/type.py"
# The story stops, workshop overlays and setup pictures.
python3 "$ROOT/tools/art/pixel/stops.py"
python3 "$ROOT/tools/art/pixel/workshop.py"
python3 "$ROOT/tools/art/pixel/setup_pics.py"
WORK="${ART_WORK:-/tmp/w-art-bake}"
mkdir -p "$WORK/game"
find "$WORK/game" -mindepth 1 -maxdepth 1 ! -name .godot -exec rm -rf {} +
cp -r "$ROOT/game/." "$WORK/game/"
(cd "$WORK/game" && godot --headless --import >/dev/null 2>&1 || true)
xvfb-run -a godot --path "$WORK/game" --rendering-driver opengl3 -s res://tests/art/bake.gd -- "$ROOT/game/art" 2>&1 | grep -E "baked|ERROR" || true
# Import settings for the baked sprites and cards (mipmaps, VRAM compression), written next to them.
rm -rf "$WORK/game/art" && cp -r "$ROOT/game/art" "$WORK/game/art"
(cd "$WORK/game" && godot --headless --import >/dev/null 2>&1 || true)
python3 "$ROOT/tools/art/import_settings.py" "$WORK/game" "$ROOT/game" | tail -1
