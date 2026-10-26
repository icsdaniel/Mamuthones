"""The play screen's street from Daniele's latest ChatGPT backdrop (tools/art/sources/chatgpt/
street_road.png: a paved causeway with kerbs running to the mountains under a night sky):

    python3 tools/art/chatgpt/street.py

StreetBackdrop places the lanes, the fire and the portraits in the first street picture's frame
(IMG 941 x 1672, RAILS, FIRE ...). The new picture is laid into that frame at one uniform scale
(never stretched: Daniele, 2026-10-26; the game shows it unstretched too), its road's vanishing point
placed so its kerbs' inner edges meet the outer rails at the road's far end. Further down the
picture's road opens a little wider than the lanes (its perspective is not quite the game's), so the
kerbs stand just outside the outer rails. The sky and mountains are laid at about their own size (the
snow peak over the fire), and Daniele's village house fronts (village_sides.png) stand along both
sides of the causeway. So the notes stay the clearest thing on screen, the paving between the kerbs is
darkened and its colour taken down. The lane lines are drawn by the game (StreetBackdrop's shader), on
the lanes themselves. Every colour is snapped to the style palette (common.py).

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
SCALE = 1.2                                   # the new picture's px in the old frame's (uniform)
FAR_Y = 468.0
KERB_OUT = 4.0                                # frame px the kerbs stand outside the rails at the far end


def meet(l, r):
    y = (r[0] - l[0]) / (l[1] - r[1])
    return np.array([l[0] + l[1] * y, y])


def vanish():
    """Where the laid road's vanishing point goes: its kerbs (their spread per row is the same at any
    uniform scale) just outside the outer rails at the road's far end."""
    y = FAR_Y + 2.0
    l = RAILS[0][0] + RAILS[0][1] * y - KERB_OUT
    r = RAILS[3][0] + RAILS[3][1] * y + KERB_OUT
    spread = NEW_R[1] - NEW_L[1]
    return np.array([(l + r) * 0.5, y - (r - l) / spread])


def kerbs(ys):
    v = vanish()
    half = (NEW_R[1] - NEW_L[1]) * 0.5
    return v[0] - half * (ys - v[1]), v[0] + half * (ys - v[1])


def lay_in(rgb):
    vn = meet(NEW_L, NEW_R)
    vo = vanish()
    m = np.float32([[SCALE, 0, vo[0] - SCALE * vn[0]], [0, SCALE, vo[1] - SCALE * vn[1]]])
    out = cv2.warpAffine(rgb, m, IMG, flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)
    horizon = vo[1] + SCALE * (570.0 - vn[1])
    return out, horizon


def calm_road(rgb, horizon):
    """The paving between the kerbs darker and greyer (notes ride on it)."""
    h, w = rgb.shape[:2]
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(w, dtype=np.float32)[None, :]
    l, r = kerbs(ys)
    inside = np.clip(np.minimum(xs - l, r - xs) / 6.0, 0, 1) * (ys > horizon + 2)
    f = rgb.astype(np.float32)
    grey = f @ np.array([0.299, 0.587, 0.114], np.float32)
    calm = (f * 0.45 + grey[..., None] * 0.55) * 0.62
    k = inside[..., None]
    return np.clip(f * (1 - k) + calm * k, 0, 255).astype(np.uint8)


SRC_HORIZON = 570.0     # the source picture's horizon row (where the plain meets the mountains)
SKY_SCALE = 0.76        # the sky's px in the frame's: near its own size, so the peak and stars show


def sky(rgb, laid, horizon):
    """The sky and mountains above the horizon laid at about their own size (not blown up with the
    road), the snow peak over the fire."""
    s = SKY_SCALE
    m = np.float32([[s, 0, 479.0 - s * 420.5], [0, s, horizon - s * SRC_HORIZON]])
    band = cv2.warpAffine(rgb, m, IMG, flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)
    ys = np.arange(IMG[1])[:, None, None]
    return np.where(ys < horizon, band, laid)


VILLAGE_VANISH = (471.0, 525.0)   # the house rows' vanishing point in village_sides.png
VILLAGE_SCALE = 1.0


def village(laid, horizon):
    """Daniele's village house fronts (village_sides.png: two rows of lit stone houses with the
    street left out between them) along both sides of the causeway, standing back from the kerbs,
    darkened so the lanes stay the brightest thing; never over the road."""
    v = np.asarray(Image.open(c.src("village_sides.png")).convert("RGBA"))
    f = VILLAGE_SCALE
    m = np.float32([[f, 0, 479.0 - f * VILLAGE_VANISH[0]], [0, f, horizon + 3.0 - f * VILLAGE_VANISH[1]]])
    pre = v.astype(np.float32)
    pre[..., :3] *= pre[..., 3:4] / 255.0
    w = cv2.warpAffine(pre, m, IMG, flags=cv2.INTER_AREA, borderMode=cv2.BORDER_CONSTANT)
    al = w[..., 3:4] / 255.0
    h = IMG[1]
    ys = np.arange(h, dtype=np.float32)[:, None]
    xs = np.arange(IMG[0], dtype=np.float32)[None, :]
    kerb = 10.0 + 0.11 * np.maximum(ys - horizon, 0)
    l, r = kerbs(ys)
    l, r = l - kerb, r + kerb
    off_road = np.clip(np.maximum(l - xs, xs - r) / 3.0, 0, 1)
    al = al * off_road[..., None]
    rgb = np.where(al > 0.01, w[..., :3] / np.maximum(w[..., 3:4] / 255.0, 1e-6), 0) * 0.72
    al = (al > 0.5).astype(np.float32)
    return (laid * (1 - al) + rgb * al).astype(np.uint8)


def main():
    rgb = np.asarray(Image.open(c.src("street_road.png")).convert("RGB"))
    laid, horizon = lay_in(rgb)
    laid = sky(rgb, laid, horizon)
    laid = calm_road(laid, horizon)
    laid = village(laid, horizon)
    rgba = np.dstack([laid, np.full(laid.shape[:2], 255, np.uint8)])
    out = c.snap(rgba, c.palette(reserved=False))[..., :3]
    Image.fromarray(out).save(os.path.join(c.GAME, "art/ai/street_laid.png"))
    print("horizon at", round(horizon, 1), "(old frame px)")


if __name__ == "__main__":
    main()
