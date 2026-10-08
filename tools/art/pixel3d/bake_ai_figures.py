"""The Mamuthone and the Issohadore from Daniele's pixel-art pictures (made with an outside image AI;
the second set, 2026-10-08, cut by ai_cut.py into game/art/ai/), cut into the same puppet parts as
bake_figures.py so they bob the same way:

    python3 tools/art/pixel3d/bake_ai_figures.py

The pictures are already pixel art on a grid of their own (about 7.5 px a cell for the Mamuthone,
5.7 for the Issohadore), so each is only taken down to the game's 172 cells tall, snapped back to
its own colours and turned to face the road (the Mamuthone stands on the right, the Issohadore on
the left). The Mamuthone's picture has a checkerboard painted in where its background should be:
it is cut away from the edges in.

Writes game/art/pixel/<figure>_<part>.png (the parts PixelFigure.PARTS lists).
"""
import os
import numpy as np
from PIL import Image
import cv2
from scipy import ndimage
import pixelate as px
from bake_figures import inpaint_under, shrink_rgba, region, H, OUT

K = 40
AI = os.path.join(px.GAME, "art/ai")
# where the parts are in each picture (its own px, before it is turned to face the road)
MAM = {
    "legs": 1060,   # the row the legs begin (they squash on the beat)
    "back_bells": [(215, 0, 405, 175), (85, 135, 285, 305), (35, 275, 165, 415), (5, 555, 145, 705)],
    "front_bells": (320, 470, 665, 765),
    "hand": (285, 680, 405, 800),   # his fist, in front of the bells but not swinging with them
    "head": [(390, 95), (560, 55), (690, 95), (705, 300), (640, 485), (520, 475), (420, 335), (385, 200)],
}
# where across its picture each figure stands on its spot (0 its left edge, 1 its right, before it
# is turned): these figures stride wide and reach out with rope and bells, so neither their feet
# nor their middle keeps them on screen; picked by eye on the play screen
ANCHOR = {"mamuthone": 0.35, "issohadore": 0.68}
ISS = {
    "legs": 940,
    "rope": (775, 495, 1015, 885),
    "head": [(480, 0), (800, 0), (815, 130), (720, 235), (600, 245), (540, 175), (495, 90)],
}


def hue_mask(a, h, s, v):
    hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2HSV)
    m = a[..., 3] > 128
    for c, (lo, hi) in enumerate((h, s, v)):
        m &= (hsv[..., c] >= lo) & (hsv[..., c] < hi)
    return m


def blobs(m, box, close=9, min_area=400):
    l, t, r, b = box
    keep = np.zeros_like(m)
    keep[t:b, l:r] = True
    m = m & keep
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((close, close), np.uint8)) > 0
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        m = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= min_area])
    return m


def mamuthone_layers(a):
    gold = hue_mask(a, (5, 35), (60, 256), (40, 256))
    front = blobs(gold, MAM["front_bells"], 7, 150) & ~region(a, MAM["hand"])
    # the big bells of the load: each the hull of its lit bronze, in its own box (the fleece tips
    # share the bronze's hue, so a looser mask would carry tufts away with the bells)
    lit = hue_mask(a, (10, 30), (120, 256), (95, 256))
    back = np.zeros_like(front)
    for l, t, r, b in MAM["back_bells"]:
        m = np.zeros_like(lit)
        m[t:b, l:r] = lit[t:b, l:r]
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
        pts = cv2.findNonZero(m)
        if pts is not None:
            hull = np.zeros(m.shape, np.uint8)
            cv2.fillPoly(hull, [cv2.convexHull(pts)], 1)
            back |= hull > 0
    back = cv2.dilate(back.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool) & (a[..., 3] > 0) & ~front
    head = region(a, None, MAM["head"])
    legs = region(a, (0, MAM["legs"], a.shape[1], a.shape[0]))
    # what the load hides is dark fleece, not the picture's background
    dark = a.copy()
    dark[a[..., 3] == 0, :3] = (38, 26, 22)
    body = inpaint_under(dark, back | front)
    body[..., 3] = np.where((a[..., 3] > 0) | back | front, 255, 0)
    # the load hides the fleece behind it: only keep what lies inside the fleece's outline
    rest = (a[..., 3] > 0) & ~(back | front)
    core = cv2.morphologyEx(rest.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (91, 91))) > 0
    body[~(rest | front | (core & back))] = 0
    body[MAM["legs"] + 40:] = 0
    body[..., :3] = np.where(head[..., None], (body[..., :3] * 0.35).astype(np.uint8), body[..., :3])
    return {
        "legs": np.where(legs[..., None], a, 0).astype(np.uint8),
        "body": body,
        "back_bells": np.where(back[..., None], a, 0).astype(np.uint8),
        "front_bells": np.where(front[..., None], a, 0).astype(np.uint8),
        "head": np.where(head[..., None], a, 0).astype(np.uint8),
    }


def issohadore_layers(a):
    tan = hue_mask(a, (8, 32), (40, 200), (90, 245))
    rope = blobs(tan, ISS["rope"], 7, 300)
    head = region(a, None, ISS["head"])
    legs = region(a, (0, ISS["legs"], a.shape[1], a.shape[0])) & ~rope
    body = inpaint_under(a, rope)
    rest = (a[..., 3] > 0) & ~rope
    body[~rest] = 0
    body[ISS["legs"] + 40:] = 0
    body[..., :3] = np.where(head[..., None], (body[..., :3] * 0.35).astype(np.uint8), body[..., :3])
    return {
        "legs": np.where(legs[..., None], a, 0).astype(np.uint8),
        "body": body,
        "rope": np.where(rope[..., None], a, 0).astype(np.uint8),
        "head": np.where(head[..., None], a, 0).astype(np.uint8),
    }


def bake(name, a, layers_fn, order):
    a = a.copy()
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    layers = layers_fn(a)
    ys, xs = np.nonzero(a[..., 3])
    top, bottom = ys.min(), ys.max() + 1
    k = H / float(bottom - top)
    cx = xs.min() + ANCHOR.get(name, 0.5) * (xs.max() + 1 - xs.min())
    half = max(cx - xs.min(), xs.max() + 1 - cx) + 4.0 / k
    l, r = int(round(cx - half)), int(round(cx + half))
    pad = max(0, -l, r - a.shape[1])
    size = (int(round((r - l) * k)), H)
    whole = shrink_rgba(np.pad(a, ((0, 0), (pad, pad), (0, 0)))[top:bottom, l + pad:r + pad], size)
    pal = px.kpalette(whole[..., :3][whole[..., 3] > 0], K)
    for p in order:
        s = shrink_rgba(np.pad(layers[p], ((0, 0), (pad, pad), (0, 0)))[top:bottom, l + pad:r + pad], size)
        opaque = s[..., 3] > 0
        idx = px.despeckle(px.nearest(s[..., :3], pal), opaque, pal)
        s[..., :3] = np.where(opaque[..., None], pal[idx], 0)
        # turned to face the road
        Image.fromarray(s[:, ::-1]).save(os.path.join(OUT, "%s_%s.png" % (name, p)))
    print(name, size)


def main():
    m = np.asarray(Image.open(os.path.join(AI, "mamuthone.png")).convert("RGBA"))
    bake("mamuthone", m, mamuthone_layers, ["legs", "body", "back_bells", "front_bells", "head"])
    iss = np.asarray(Image.open(os.path.join(AI, "issohadore.png")).convert("RGBA"))
    bake("issohadore", iss, issohadore_layers, ["legs", "body", "rope", "head"])


if __name__ == "__main__":
    main()
