"""Write Godot .import files for game/audio/sfx with the settings the Sound autoload
needs, taken from a copy of the project that Godot has already imported:

  * WAV one-shots: compress/mode=0 (raw 16-bit PCM: no decoding on the hot path, and
    Sound.count_in() lays the raw count-in bytes into one stream);
  * OGG loops and ambiences: loop=true (Sound also sets it at load time).

Run:  python3 tools/audio/sfx/sync_imports.py /tmp/w-sound/game
then re-import that copy (or the real project) so the new settings take effect.
"""
import glob
import os
import re
import sys

from dsp import OUT


def main():
    src_game = sys.argv[1]
    src = os.path.join(src_game, "audio", "sfx")
    n = 0
    for p in glob.glob(os.path.join(src, "**", "*.import"), recursive=True):
        rel = os.path.relpath(p, src)
        text = open(p).read()
        if rel.endswith(".wav.import"):
            text = re.sub(r"compress/mode=\d+", "compress/mode=0", text)
        elif rel.endswith(".ogg.import") and rel.split(os.sep)[0] in ("loops", "ambience"):
            text = re.sub(r"loop=(true|false)", "loop=true", text)
        dst = os.path.join(OUT, rel)
        if os.path.exists(dst[: -len(".import")]):
            with open(dst, "w") as f:
                f.write(text)
            n += 1
    print("wrote", n, ".import files")


if __name__ == "__main__":
    main()
