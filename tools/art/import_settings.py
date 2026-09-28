"""Writes Godot import settings for the baked art next to the PNGs in game/art, so every checkout
imports them the same way:
  notes/*.png  mipmaps on (sprites are baked at 2x and drawn smaller on narrow phones; LaneSkin draws
               them with a mipmapped filter so they stay crisp instead of shimmering)
  cards/*.png  VRAM compressed (big, static, drawn at their size or smaller)
  fire/*.png   the Fire Night play-screen sprites (tools/art/fire_night): mipmaps on, except the
               full-screen sky and ground
Usage: import_settings.py WORK_GAME_DIR ROOT_GAME_DIR
WORK_GAME_DIR must be a copy of game/ that Godot has already imported (it supplies uid and paths)."""
import pathlib
import re
import sys

PARAMS = {
    "notes": {"mipmaps/generate": "true", "compress/mode": "0"},
    "cards": {"compress/mode": "2", "mipmaps/generate": "true"},
    "fire": {"mipmaps/generate": "true", "compress/mode": "0"},
}
## Full-screen backdrops drawn at their size: no mipmaps.
NO_MIPS = {"sky.png", "ground.png"}


def main() -> None:
    work, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    for folder, params in PARAMS.items():
        for png in sorted((root / "art" / folder).glob("*.png")):
            src = work / "art" / folder / (png.name + ".import")
            if not src.exists():
                print("no import file for", png.name, "- import the work copy first")
                continue
            text = src.read_text()
            for key, value in params.items():
                if key == "mipmaps/generate" and png.name in NO_MIPS:
                    value = "false"
                text, n = re.subn(r"^%s=.*$" % re.escape(key), "%s=%s" % (key, value), text, flags=re.M)
                if n == 0:
                    text = text.replace("[params]\n", "[params]\n\n%s=%s\n" % (key, value), 1)
            (png.parent / (png.name + ".import")).write_text(text)
            print("import settings", folder + "/" + png.name)


if __name__ == "__main__":
    main()
