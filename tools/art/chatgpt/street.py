"""The play screen's street from Daniele's latest ChatGPT backdrop (tools/art/sources/chatgpt/
street_road.png: a paved causeway with kerbs running to the mountains under a night sky):

    python3 tools/art/chatgpt/street.py

StreetBackdrop places the lanes, the fire and the portraits in the first street picture's frame
(IMG 941 x 1672, RAILS, FIRE ...). The new picture is laid into that frame so its road runs under the
lanes: scaled about the road's vanishing point onto the rails' own vanishing point, a little wider
than tall so the kerbs' inner edges fall on the outer rails. Then, so the notes stay the clearest
thing on screen, the paving between the kerbs is darkened and its colour taken down, and the two
lane dividers are painted on as thin warm lines (the edges are the kerbs themselves). Every colour is
snapped to the style palette (common.py).

Writes game/art/ai/street_laid.png.
"""
import os
import numpy as np
import cv2
from PIL import Image
import common as c

IMG = (941, 1672)
RAILS = [(609.17, -0.45827), (510.90, -0.14397), (445.17, 0.12678), (356.72, 0.43025)]
# the new picture's kerbs (inner edges, its own px), read off it: x = a + b * y
NEW_L = (357.0 + 0.4333 * 600, -0.4333)
NEW_R = (482.0 - 0.4333 * 600, 0.4333)
SCALE = 1.2                                   # the new picture's px in the old frame's (down the road)
FAR_Y = 468.0


def meet(l, r):
    y = (r[0] - l[0]) / (l[1] - r[1])
    return np.array([l[0] + l[1] * y, y])


def lay_in(rgb):
    vn = meet(NEW_L, NEW_R)
    vo = meet(RAILS[0], RAILS[3])
    # across: the old road's widening per row over the new one's, so the kerbs land on the edge rails
    sx = SCALE * (RAILS[3][1] - RAILS[0][1]) / (NEW_R[1] - NEW_L[1])
    m = np.float32([[sx, 0, vo[0] - sx * vn[0]], [0, SCALE, vo[1] - SCALE * vn[1]]])
    out = cv2.warpAffine(rgb, m, IMG, flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)
    horizon = vo[1] + SCALE * (570.0 - vn[1])
    return out, horizon


def calm_road(rgb, horizon):
    """The paving between the outer rails darker and greyer (notes ride on it)."""
    h, w = rgb.shape[:2]
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    l = RAILS[0][0] + RAILS[0][1] * ys
    r = RAILS[3][0] + RAILS[3][1] * ys
    inside = np.clip(np.minimum(xs - l, r - xs) / 6.0, 0, 1) * (ys > horizon + 2)
    f = rgb.astype(np.float32)
    grey = f @ np.array([0.299, 0.587, 0.114], np.float32)
    calm = (f * 0.45 + grey[..., None] * 0.55) * 0.62
    k = inside[..., None]
    return np.clip(f * (1 - k) + calm * k, 0, 255).astype(np.uint8)


def lines(rgb, horizon):
    """The two lane dividers as thin warm lines, faint far off and fuller near."""
    f = rgb.astype(np.float32)
    h, w = f.shape[:2]
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    core_c = np.array(c._rgb("#f6c48a"), np.float32)
    rim_c = np.array(c._rgb("#c0683a"), np.float32)
    on = np.clip((ys - FAR_Y + 20) / 30.0, 0.0, 1.0) * (0.55 + 0.45 * np.clip((ys - FAR_Y) / 900.0, 0, 1))
    for a, b in RAILS[1:3]:
        d = np.abs(xs - (a + b * ys)) * np.cos(np.arctan(b))
        half = np.maximum(1.0, 0.0045 * (ys - 330.0))
        rim = np.clip(1.8 - d / half, 0.0, 1.0) * on * 0.8
        f = f * (1 - rim[..., None]) + rim_c * rim[..., None]
        core = np.clip(1.0 - d / (half * 0.6), 0.0, 1.0) * on
        f = f * (1 - core[..., None]) + core_c * core[..., None]
    return np.clip(f, 0, 255).astype(np.uint8)


def main():
    rgb = np.asarray(Image.open(c.src("street_road.png")).convert("RGB"))
    laid, horizon = lay_in(rgb)
    laid = lines(calm_road(laid, horizon), horizon)
    rgba = np.dstack([laid, np.full(laid.shape[:2], 255, np.uint8)])
    out = c.snap(rgba, c.palette(reserved=False))[..., :3]
    Image.fromarray(out).save(os.path.join(c.GAME, "art/ai/street_laid.png"))
    print("horizon at", round(horizon, 1), "(old frame px)")


if __name__ == "__main__":
    main()
