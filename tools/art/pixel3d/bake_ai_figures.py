"""The Mamuthone and the Issohadore from Daniele's pixel-art pictures (made with an outside image AI,
2026-10-07), cut into the same puppet parts as bake_figures.py so they bob the same way:

    python3 tools/art/pixel3d/bake_ai_figures.py <mamuthone.png> <issohadore.png>

The pictures are already pixel art on a grid of their own (about 7.5 px a cell for the Mamuthone,
5.7 for the Issohadore), so each is only taken down to the game's 172 cells tall, snapped back to
its own colours and turned to face the road (the Mamuthone stands on the right, the Issohadore on
the left). The Mamuthone's picture has a checkerboard painted in where its background should be:
it is cut away from the edges in.

Writes game/art/pixel/<figure>_<part>.png (the parts PixelFigure.PARTS lists).
"""
import os
import sys
import numpy as np
from PIL import Image
import cv2
from scipy import ndimage
import pixelate as px
from bake_figures import inpaint_under, shrink_rgba, region, H, OUT

K = 40
LEGS_M = 925   # source rows where the legs begin (they squash on the beat)
LEGS_I = 935
# the Mamuthone's big bells in the source picture (left, top, right, bottom)
BACK_BELLS = [(495, 115, 650, 250), (345, 170, 530, 335), (285, 305, 420, 440), (300, 570, 515, 765), (830, 635, 940, 805)]


def cut_checker(rgb):
    """The figure's mask: everything but the light grey checkerboard joined to the picture's edges."""
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    light = (rgb.min(-1) > 165) & (hsv[..., 1] < 40)
    lab, _ = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(edge))
    l2, n = ndimage.label(fg)
    fg = l2 == (np.argmax(ndimage.sum(fg, l2, range(1, n + 1))) + 1)
    fg = ndimage.binary_fill_holes(fg)
    # light specks the checkerboard left on the edge of the fleece
    near = cv2.dilate((~fg).astype(np.uint8), np.ones((25, 25), np.uint8)) > 0
    return fg & ~(light & near)


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
    front = blobs(gold, (585, 590, 835, 860), 7, 150)
    # the big bells of the load: each the hull of its lit bronze, in its own box (the fleece tips
    # share the bronze's hue, so a looser mask would carry tufts away with the bells)
    lit = hue_mask(a, (10, 30), (120, 256), (95, 256))
    back = np.zeros_like(front)
    for l, t, r, b in BACK_BELLS:
        m = np.zeros_like(lit)
        m[t:b, l:r] = lit[t:b, l:r]
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
        pts = cv2.findNonZero(m)
        if pts is not None:
            hull = np.zeros(m.shape, np.uint8)
            cv2.fillPoly(hull, [cv2.convexHull(pts)], 1)
            back |= hull > 0
    back = cv2.dilate(back.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool) & (a[..., 3] > 0) & ~front
    head = region(a, None, [(600, 140), (835, 140), (850, 330), (835, 425), (700, 435), (610, 330)])
    legs = region(a, (0, LEGS_M, a.shape[1], a.shape[0]))
    # what the load hides is dark fleece, not the picture's background
    dark = a.copy()
    dark[a[..., 3] == 0, :3] = (38, 26, 22)
    body = inpaint_under(dark, back | front)
    body[..., 3] = np.where((a[..., 3] > 0) | back | front, 255, 0)
    # the load hides the fleece behind it: only keep what lies inside the fleece's outline
    rest = (a[..., 3] > 0) & ~(back | front)
    core = cv2.morphologyEx(rest.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (91, 91))) > 0
    body[~(rest | front | (core & back))] = 0
    body[LEGS_M + 40:] = 0
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
    rope = blobs(tan, (790, 640, 1000, 1120), 7, 300)
    head = region(a, None, [(520, 40), (830, 40), (830, 250), (700, 335), (595, 335), (560, 240)])
    legs = region(a, (0, LEGS_I, a.shape[1], a.shape[0])) & ~rope
    body = inpaint_under(a, rope)
    rest = (a[..., 3] > 0) & ~rope
    body[~rest] = 0
    body[LEGS_I + 40:] = 0
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
    # the feet: the middle of the figure's lowest tenth
    low = ys > bottom - (bottom - top) * 0.1
    cx = 0.5 * (xs[low].min() + xs[low].max())
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
    mam = np.asarray(Image.open(sys.argv[1]).convert("RGB"))
    m = np.dstack([mam, cut_checker(mam).astype(np.uint8) * 255])
    bake("mamuthone", m, mamuthone_layers, ["legs", "body", "back_bells", "front_bells", "head"])
    iss = np.asarray(Image.open(sys.argv[2]).convert("RGBA"))
    bake("issohadore", iss, issohadore_layers, ["legs", "body", "rope", "head"])


if __name__ == "__main__":
    main()
