"""The street as pixel art: Daniele's street picture (game/art/street/street.png) on the play
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

SRC = os.path.join(px.GAME, "art/street/street.png")
OUT = os.path.join(px.GAME, "art/pixel/street.png")
CELL = 3.0 / max(720.0 / 941.0, 1440.0 / 1672.0)   # picture px per cell on the base screen


def main():
    rgb = np.asarray(Image.open(SRC).convert("RGB"))
    h, w = rgb.shape[:2]
    size = (int(round(w / CELL)), int(round(h / CELL)))
    # the cobbles and walls flattened into areas; the fire and the sky kept as they are (mean shift
    # would melt the flames and their sparks into one red smear)
    flat = px.flatten(rgb, 4, 12)
    keep = np.zeros(rgb.shape[:2], np.float32)
    keep[:470] = 1.0
    keep = cv2.GaussianBlur(keep, (0, 0), 12)[..., None]
    soft = cv2.bilateralFilter(np.ascontiguousarray(rgb), 7, 30, 5)
    mixed = (soft * keep + flat * (1.0 - keep)).astype(np.uint8)
    small = px.shrink(mixed, size)
    # dither only the dark, plain sky (not the fire's glow): bands there would show
    m = px.gradient_mask(small)
    lum = small.astype(np.float32).mean(-1)
    m *= (lum < 60).astype(np.float32)
    out = px.snap(small, dither=m, amount=6.0)
    Image.fromarray(out.astype(np.uint8)).save(OUT)
    print("street", size)


if __name__ == "__main__":
    main()
