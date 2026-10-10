"""The street as pixel art: Daniele's street picture (tools/art/sources/street/street.png) on the play
screen's grid, one texel per 3 x 3 base px cell on the 720 x 1440 base screen.

    python3 tools/art/pixel3d/bake_street.py

Writes game/art/pixel/street.png. StreetBackdrop draws it in place of the picture (same geometry:
the painted lines, the fire and the frames keep their picture coordinates).
"""
import os
import numpy as np
from PIL import Image
import cv2
import pixelate as px

os.path.join(px.GAME, "../tools/art/sources/street/street.png")
OUT = os.path.join(px.GAME, "art/pixel/street.png")
CELL = 3.0 / max(720.0 / 941.0, 1440.0 / 1672.0)   # picture px per cell on the base screen
K = 56   # colours in the street's own palette


def main(src=SRC, out_path=OUT, haze=True):
    rgb = np.asarray(Image.open(src).convert("RGB")) if isinstance(src, str) else src
    h, w = rgb.shape[:2]
    size = (int(round(w / CELL)), int(round(h / CELL)))
    # an edge-keeping smooth over the whole picture: the stones' texture goes, the flames, walls
    # and lines keep their edges
    mixed = px.smooth(rgb, 9, 20, 7)
    # the red haze the picture puts above the flames reads as a solid red column once it is pixels:
    # let the night sky show through it (only dim, red, above the flames)
    if haze:
        hz = mixed.astype(np.float32)
        lum = hz.mean(-1)
        red = (hz[..., 0] > hz[..., 1] * 2.2) & (lum < 95)
        rows = np.clip((345.0 - np.arange(hz.shape[0])[:, None]) / 50.0, 0.0, 1.0)
        m = red.astype(np.float32) * rows
        m = cv2.GaussianBlur(m, (0, 0), 3)[..., None]
        sky = np.array([28, 26, 52], np.float32)
        mixed = (hz * (1 - 0.8 * m) + sky * 0.8 * m).astype(np.uint8)
    small = px.sharpen(px.shrink(mixed, size), 0.6)
    # the street's own colours; the bright fire counted four times over, so its yellows and whites
    # each get a colour instead of all snapping to one red
    flat = small.reshape(-1, 3)
    pal = px.kpalette(np.concatenate([flat, np.repeat(flat[flat.mean(-1) > 150], 3, 0)]), K)
    idx = px.despeckle(px.nearest(small, pal), np.ones(small.shape[:2], bool), pal, 2, 22.0)
    out = pal[idx]
    Image.fromarray(out.astype(np.uint8)).save(out_path)
    print("street", size)


if __name__ == "__main__":
    main()
