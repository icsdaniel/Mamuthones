"""The Mamuthone and the Issohadore from Daniele's pixel-art pictures (made with an outside image AI;
the second set, 2026-10-08, cut by ai_cut.py into game/art/ai/), for PixelFigure:

    python3 tools/art/pixel3d/bake_ai_figures.py

The pictures are already pixel art on a grid of their own (about 7.5 px a cell for the Mamuthone,
5.7 for the Issohadore), so each is only taken down to the game's 172 cells tall, snapped back to
its own colours and turned to face the road (the Mamuthone stands on the right, the Issohadore on
the left).

The loose pieces that bob on their own (the head, the bells, the rope) are then cut from that one
finished picture, so at rest they put it back together pixel for pixel: no seams, no halos. The
body keeps everything else, with what the pieces cover painted in from around them (fleece behind
the bells, the neck behind the head), so when a piece moves its couple of pixels nothing shows
through and nothing doubles.

Writes game/art/pixel/<figure>_body.png and <figure>_<piece>.png, all on one
canvas (PixelFigure.PIECES lists the pieces).
"""
import os
import numpy as np
from PIL import Image
import cv2
from scipy import ndimage
import pixelate as px
from bake_figures import shrink_rgba, region, H, OUT

K = 40
AI = os.path.join(px.GAME, "art/ai")
# where across its picture each figure stands on its spot (0 its left edge, 1 its right, before it
# is turned): these figures stride wide and reach out with rope and bells, so neither their feet
# nor their middle keeps them on screen; picked by eye on the play screen
ANCHOR = {"mamuthone": 0.35, "issohadore": 0.68}
# where the pieces are in each picture (its own px, before it is turned to face the road)
MAM = {
    "back_bells": [(215, 0, 405, 175), (85, 135, 285, 305), (35, 275, 165, 415), (5, 555, 145, 705)],
    "front_bells": (320, 470, 665, 765),
    "hand": (285, 680, 405, 800),   # his fist, in front of the bells but not swinging with them
    "head": [(390, 95), (560, 55), (690, 95), (705, 300), (640, 485), (520, 475), (420, 335), (385, 200)],
}
ISS = {
    "coil": (830, 495, 1027, 885),
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


def mamuthone_pieces(a):
    """The pieces, front to back: each wins the pixels it shares with the ones after it."""
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
    back = cv2.dilate(back.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool) & (a[..., 3] > 0)
    return [("head", region(a, None, MAM["head"])), ("front_bells", front), ("back_bells", back)]


def issohadore_pieces(a):
    tan = hue_mask(a, (8, 32), (40, 200), (90, 245))
    # the coil in his hand: a heavy thing that bounces (the thin rope he swings stays with the body,
    # too thin at the game's size to move on its own without breaking)
    coil = blobs(tan, ISS["coil"], 25, 300)
    # with the rope's dark outline round it, and nothing of the skirt beside it
    l, t, r, b = ISS["coil"]
    near = cv2.dilate(coil.astype(np.uint8), np.ones((15, 15), np.uint8)) > 0
    coil |= near & hue_mask(a, (0, 256), (0, 256), (0, 90))
    coil[:, :l] = False
    return [("head", region(a, None, ISS["head"])), ("rope", coil)]


def frame(a, name):
    """The crop and size that take the picture to the game's canvas."""
    ys, xs = np.nonzero(a[..., 3])
    top, bottom = ys.min(), ys.max() + 1
    k = H / float(bottom - top)
    cx = xs.min() + ANCHOR[name] * (xs.max() + 1 - xs.min())
    half = max(cx - xs.min(), xs.max() + 1 - cx) + 4.0 / k
    l, r = int(round(cx - half)), int(round(cx + half))
    pad = max(0, -l, r - a.shape[1])
    size = (int(round((r - l) * k)), H)

    def to_canvas(img):
        if img.ndim == 2:
            img = np.pad(img.astype(np.float32), ((0, 0), (pad, pad)))[top:bottom, l + pad:r + pad]
            return cv2.resize(img, size, interpolation=cv2.INTER_AREA) > 0.5
        return shrink_rgba(np.pad(img, ((0, 0), (pad, pad), (0, 0)))[top:bottom, l + pad:r + pad], size)
    return to_canvas, k


def bake(name, pieces_fn):
    a = np.asarray(Image.open(os.path.join(AI, name + ".png")).convert("RGBA")).copy()
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    to_canvas, k = frame(a, name)
    s = to_canvas(a)
    opaque = s[..., 3] > 0
    pal = px.kpalette(s[..., :3][opaque], K)
    idx = px.despeckle(px.nearest(s[..., :3], pal), opaque, pal)
    s[..., :3] = np.where(opaque[..., None], pal[idx], 0)
    # the pieces on the canvas, each its own pixels only (a whole partition of the picture)
    taken = np.zeros_like(opaque)
    pieces = []
    for p, m in pieces_fn(a):
        m = to_canvas(m)
        if p == "rope":
            # all of the coil, its loops' outline too: what its hull holds, but not the skirt
            # beside its lower end (canvas px, before the turn)
            hull = np.zeros(m.shape, np.uint8)
            cv2.fillPoly(hull, [cv2.convexHull(cv2.findNonZero(m.astype(np.uint8)))], 1)
            m = hull > 0
            m[100:, :120] = False
        m &= opaque & ~taken
        # no crumbs: a piece is its big blobs, the specks stay with the body
        lab, n = ndimage.label(m)
        if n:
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            m = np.isin(lab, [i + 1 for i, z in enumerate(sizes) if z >= 12])
        taken |= m
        pieces.append((p, m))
    # the body: the rest, with what the pieces cover painted in from around them, inside the body's
    # own outline (where a bell sticks out past the fleece, the body has nothing behind it)
    rest = opaque & ~taken
    core = cv2.morphologyEx(rest.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))) > 0
    core = ndimage.binary_fill_holes(core)
    # ... and a band along every edge a piece shares with the body, as wide as a piece moves
    # ... and along every edge a piece shares with the body or with another piece (the hood and the
    # top bell move apart by a pixel or two: the sky must not show between them)
    behind = taken & (core | (cv2.dilate(rest.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0))
    for p, m in pieces:
        behind |= m & (cv2.dilate((taken & ~m).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0)
    # each piece's share painted in from all that lies around it, the other pieces too (between the
    # hood and a bell it is bronze and hood that show, not the fleece further off)
    body = np.zeros_like(s)
    body[..., :3] = np.where(rest[..., None], s[..., :3], 0)
    for p, m in pieces:
        src = opaque & ~m
        rgb = np.ascontiguousarray(np.where(src[..., None], s[..., :3], 0).astype(np.uint8))
        filled = cv2.inpaint(rgb, (~src).astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA)
        body[..., :3] = np.where((m & behind)[..., None], pal[px.nearest(filled, pal)], body[..., :3])
    keep = rest | behind
    body[..., 3] = np.where(keep, 255, 0)
    body[~keep] = 0
    out = {"body": body}
    for p, m in pieces:
        out[p] = np.where(m[..., None], s, 0).astype(np.uint8)
    for p, img in out.items():
        # turned to face the road
        Image.fromarray(img[:, ::-1]).save(os.path.join(OUT, "%s_%s.png" % (name, p)))
    print(name, s.shape[1::-1], {p: int(m.sum()) for p, m in pieces}, "behind", int(behind.sum()))


if __name__ == "__main__":
    bake("mamuthone", mamuthone_pieces)
    bake("issohadore", issohadore_pieces)
