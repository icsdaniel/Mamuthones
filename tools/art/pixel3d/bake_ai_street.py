"""The street from Daniele's second outside-AI set (tools/art/sources/ai/street.png, 2026-10-08) as the pixel
look's street:

    python3 tools/art/pixel3d/bake_ai_street.py

The game's lanes, fire and portraits are placed in the first street picture's coordinates
(StreetBackdrop: IMG, RAILS, FIRE, FRAME...). The new picture is laid into that same frame instead
of moving them: scaled and shifted so its bonfire sits where the old one was and its road runs up
to it under the lanes. It has no glowing lines, so the four lines are painted on along RAILS in the
old picture's colours (pale yellow cores widening down the road in an orange glow). Then it goes
through bake_street.py's steps to the play screen's grid.

Writes game/art/pixel/street.png (same size as before).
"""
import os
import numpy as np
from PIL import Image
import cv2
import pixelate as px
import bake_street

os.path.join(px.GAME, "../tools/art/sources/ai/street.png")   # the source picture is kept out of the game
IMG = (941, 1672)                     # StreetBackdrop.IMG
RAILS = [(609.17, -0.45827), (510.90, -0.14397), (445.17, 0.12678), (356.72, 0.43025)]
FAR_Y = 468.0
SCALE = 1.09                          # the new picture in the old one's px
NEW_FIRE = (512.0, 330.0)             # the bonfire's heart in the new picture
OLD_FIRE = (480.0, 370.0)             # StreetBackdrop.FIRE


def lay_in(rgb):
    off = (OLD_FIRE[0] - NEW_FIRE[0] * SCALE, OLD_FIRE[1] - NEW_FIRE[1] * SCALE)
    m = np.float32([[SCALE, 0, off[0]], [0, SCALE, off[1]]])
    # the sky above the picture's top: its top row carried up
    return cv2.warpAffine(rgb, m, IMG, flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)


def lines(rgb):
    f = rgb.astype(np.float32)
    h, w = f.shape[:2]
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    core_c = np.array([255, 250, 135], np.float32)
    rim_c = np.array([255, 150, 40], np.float32)
    glow_c = np.array([235, 105, 25], np.float32)
    on = np.clip((ys - FAR_Y) / 12.0, 0.0, 1.0)
    for a, b in RAILS:
        d = np.abs(xs - (a + b * ys)) * np.cos(np.arctan(b))
        half = np.maximum(1.2, 0.0068 * (ys - 330.0))
        glow = np.exp(-(d / (half * 3.2)) ** 2) * 0.55 * on
        f = f * (1 - glow[..., None]) + glow_c * glow[..., None]
        rim = np.clip(1.6 - d / half, 0.0, 1.0) * on
        f = f * (1 - rim[..., None]) + rim_c * rim[..., None]
        core = np.clip(1.0 - d / (half * 0.55), 0.0, 1.0) ** 0.6 * on
        f = f * (1 - core[..., None]) + core_c * core[..., None]
    return np.clip(f, 0, 255).astype(np.uint8)


def main():
    rgb = np.asarray(Image.open(SRC).convert("RGB"))
    laid = lines(lay_in(rgb))
    Image.fromarray(laid).save(os.path.join(px.GAME, "art/ai/street_laid.png"))
    bake_street.main(laid, haze=False)


if __name__ == "__main__":
    main()
