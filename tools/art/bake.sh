#!/bin/bash
# Regenerates every art asset: textures and UI nine-patches (numpy), then the app icons and the stop
# cards (Godot, needs xvfb-run). Godot runs on a private copy of game/ so it never touches the shared
# import cache; the results are written back into game/art/.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$ROOT/tools/art/make_textures.py"
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
