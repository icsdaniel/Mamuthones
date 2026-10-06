"""The Mamuthone and the Issohadore as pixel-art puppets, cut from Daniele's figures
(game/art/street/<figure>_bob_0.png, his standing pose) into parts that slide on their own:

    python3 tools/art/pixel3d/bake_figures.py

  mamuthone   legs, body (the fleece), back_bells, front_bells, head (hood and black mask)
  issohadore  legs, body, rope, head (berritta and white mask)

Every part is a picture of the same size (the whole figure's canvas, feet at the bottom centre), so
they line up when none has moved. What a part covers is painted into the parts under it (fleece
under the bells, a dark shadow under the head), so nothing shows a hole when a part slides. Each
part is shrunk to the play screen's grid, snapped to the figure's own palette and outlined (see bake).

Writes game/art/pixel/<figure>_<part>.png and prints the pivots for PixelFigure.PARTS.
"""
import os
import numpy as np
from PIL import Image
import cv2
from scipy import ndimage
import pixelate as px

SRC = os.path.join(px.GAME, "art/street")
OUT = os.path.join(px.GAME, "art/pixel")
H = 172   # cells tall (the figure in its portrait on the base screen; 118, then 140, until Daniele asked for figures that fill their portraits, 2026-10-05)

K = 40          # colours in each figure's own palette
SHARPEN = 0.7   # unsharp amount on the grid

HSV_GOLD =((12, 31), (110, 256), (100, 256))


def gold(a, box):
    hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2HSV)
    m = (a[..., 3] > 128)
    for c, (lo, hi) in enumerate(HSV_GOLD):
        m &= (hsv[..., c] >= lo) & (hsv[..., c] < hi)
    b = np.zeros_like(m)
    l, t, r, bt = box
    b[t:bt, l:r] = True
    m &= b
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)) > 0
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    if n == 0:
        return m
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    keep = [i + 1 for i, s in enumerate(sizes) if s > 600]
    m = np.isin(lab, keep)
    m = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    return m & (a[..., 3] > 60)


def region(a, box, poly=None):
    m = np.zeros(a.shape[:2], bool)
    if poly is not None:
        img = np.zeros(a.shape[:2], np.uint8)
        cv2.fillPoly(img, [np.array(poly, np.int32)], 1)
        m = img > 0
    else:
        l, t, r, b = box
        m[t:b, l:r] = True
    return m & (a[..., 3] > 60)


def inpaint_under(a, hole):
    """The figure with `hole` painted over from its surroundings (what shows when a part moves)."""
    rgb = np.ascontiguousarray(a[..., :3])
    filled = cv2.inpaint(rgb, hole.astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    out = a.copy()
    out[..., :3] = np.where(hole[..., None], filled, rgb)
    return out


def shrink_rgba(a, size):
    f = a.astype(np.float32) / 255.0
    pm = f[..., :3] * f[..., 3:4]
    pm = cv2.resize(pm, size, interpolation=cv2.INTER_AREA)
    al = cv2.resize(f[..., 3], size, interpolation=cv2.INTER_AREA)
    rgb = np.where(al[..., None] > 0.01, pm / np.maximum(al[..., None], 0.01), 0)
    out = np.zeros((size[1], size[0], 4), np.uint8)
    out[..., :3] = np.clip(rgb * 255.0 + 0.5, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(al > 0.5, 255, 0)
    return out


def tone(rgb, alpha, contrast=1.15, sat=1.25):
    """In the game the figures stand in warm firelight that washes them a little: a touch more value
    contrast and colour than the picture (a straight stretch, not the old local CLAHE that turned
    the fleece to noise)."""
    lab = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2LAB).astype(np.float32)
    m = lab[..., 0][alpha > 0].mean() if (alpha > 0).any() else 128.0
    lab[..., 0] = (lab[..., 0] - m) * contrast + m
    lab[..., 1:] = (lab[..., 1:] - 128.0) * sat + 128.0
    out = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2RGB)
    return np.where(alpha[..., None] > 0, out, rgb)


def bake(name, parts, order, layers_fn, contrast=1.15):
    """Second pass (2026-10-05): the figure's own look kept. Each part is smoothed (edges kept),
    shrunk by area, sharpened a little, snapped to the figure's OWN K colours (taken from the whole
    figure at this size, so the parts match), cleared of lone stray cells and outlined in a dark
    shade of the colour beside it. No more contrast push, firelit rim or lifted mask: the picture
    already has its firelight, and the push made the fleece noisy and the black mask pale."""
    a = np.asarray(Image.open(os.path.join(SRC, name + "_bob_0.png")).convert("RGBA")).copy()
    a[..., 3] = np.where(a[..., 3] > 100, 255, 0)
    h, w = a.shape[:2]
    k = H / h
    size = (int(round(w * k)), H)
    soft = a.copy()
    soft[..., :3] = px.smooth(a[..., :3])
    whole = shrink_rgba(soft, size)
    pal = px.kpalette(tone(px.sharpen(whole[..., :3], SHARPEN), whole[..., 3], contrast)[whole[..., 3] > 0], K)
    layers = layers_fn(soft, parts)
    union = np.zeros((H, size[0]), bool)
    small = {}
    for p in order:
        s = shrink_rgba(layers[p], size)
        opaque = s[..., 3] > 0
        idx = px.despeckle(px.nearest(tone(px.sharpen(s[..., :3], SHARPEN), s[..., 3], contrast), pal), opaque, pal)
        s[..., :3] = np.where(opaque[..., None], pal[idx], 0)
        small[p] = s
        union |= opaque
    for p in order:
        s = px.selout(small[p], 0.15)
        # no ink inside the figure's own silhouette for the big base parts: only round its outside
        if p in ("body", "legs"):
            ring = (s[..., 3] > 0) & (small[p][..., 3] == 0)
            s[ring & union] = 0
        Image.fromarray(s).save(os.path.join(OUT, "%s_%s.png" % (name, p)))
    print(name, size)


def mamuthone_layers(a, parts):
    back = gold(a, (225, 0, 470, 300))
    front = gold(a, (40, 320, 270, 490))
    head = region(a, None, [(85, 0), (240, 0), (250, 60), (230, 175), (150, 185), (90, 150)]) & ~back
    legs = region(a, (0, 560, a.shape[1], a.shape[0]))
    # the fleece under the bells: only where the fleece would plausibly go on (closed round the bells),
    # not where the bells stick out past it
    rest = (a[..., 3] > 0) & ~(back | front)
    core = cv2.morphologyEx(rest.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (41, 41))) > 0
    body_m = (rest | front | (core & (a[..., 3] > 0))) & (np.arange(a.shape[0])[:, None] < 650)
    body = inpaint_under(a, back | front)
    body[~body_m] = 0
    shade = head & ~cv2.erode(head.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
    body[..., :3] = np.where(head[..., None], (body[..., :3] * 0.35).astype(np.uint8), body[..., :3])
    out = {}
    out["legs"] = np.where(legs[..., None], a, 0).astype(np.uint8)
    out["body"] = body
    out["back_bells"] = np.where(back[..., None], a, 0).astype(np.uint8)
    out["front_bells"] = np.where(front[..., None], a, 0).astype(np.uint8)
    out["head"] = np.where(head[..., None], a, 0).astype(np.uint8)
    return out


def issohadore_layers(a, parts):
    rope = gold(a, (20, 290, 250, 560))
    head = region(a, None, [(215, 0), (400, 0), (400, 120), (360, 160), (300, 170), (230, 150), (200, 90)])
    legs = region(a, (0, 590, a.shape[1], a.shape[0]))
    rest = (a[..., 3] > 0) & ~rope
    core = cv2.morphologyEx(rest.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31))) > 0
    body_m = (rest | (core & (a[..., 3] > 0))) & (np.arange(a.shape[0])[:, None] < 680)
    body = inpaint_under(a, rope)
    body[~body_m] = 0
    body[..., :3] = np.where(head[..., None], (body[..., :3] * 0.35).astype(np.uint8), body[..., :3])
    out = {}
    out["legs"] = np.where(legs[..., None], a, 0).astype(np.uint8)
    out["body"] = body
    out["rope"] = np.where(rope[..., None], a, 0).astype(np.uint8)
    out["head"] = np.where(head[..., None], a, 0).astype(np.uint8)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    bake("mamuthone", None, ["legs", "body", "back_bells", "front_bells", "head"], mamuthone_layers)
    bake("issohadore", None, ["legs", "body", "rope", "head"], issohadore_layers)


if __name__ == "__main__":
    main()
