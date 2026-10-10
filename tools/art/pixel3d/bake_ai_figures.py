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
AI = os.path.join(px.GAME, "../tools/art/sources/ai")   # the figure pictures are kept out of the game
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


def mirror_fill(s, src, hole, only_above=False):
    """What lies behind `hole`, as the picture around it seen in a mirror at the hole's nearest edge:
    a piece that moves a pixel or two up shows the fleece below it carrying on, one that moves down
    the fleece above, with its strands and light (a smooth fill read as a dark smudge trailing the
    piece). Up and down first, as the pieces mostly move that way; then across; else painted in.
    only_above: for a piece that only ever moves down (the head nods): only the band its top edge
    uncovers is filled, from what is above it; the rest of `done` is False and stays see-through
    (a fill there showed as dark specks over the hood)."""
    rgb = np.ascontiguousarray(np.where(src[..., None], s[..., :3], 0).astype(np.uint8))
    out = cv2.inpaint(rgb, (~src).astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA)
    h, w = hole.shape
    done = np.zeros_like(hole)
    from_y = np.full(hole.shape, -1)

    def runs(line):
        idx = np.flatnonzero(line)
        if idx.size == 0:
            return []
        cut = np.flatnonzero(np.diff(idx) > 1)
        return list(zip(np.r_[idx[0], idx[cut + 1]], np.r_[idx[cut], idx[-1]] + 1))

    for x in range(w):
        for a, b in runs(hole[:, x]):
            for y in range(a, b):
                up, down = a - 1 - (y - a), b + (b - 1 - y)
                order = (up,) if only_above else ((up, down) if y - a <= b - 1 - y else (down, up))
                for sy in order:
                    if 0 <= sy < h and src[sy, x]:
                        out[y, x] = s[sy, x, :3]
                        done[y, x] = True
                        from_y[y, x] = sy
                        break
    if only_above:
        return out, done, from_y
    for y in range(h):
        for a, b in runs(hole[y] & ~done[y]):
            for x in range(a, b):
                left, right = a - 1 - (x - a), b + (b - 1 - x)
                for sx in ((left, right) if x - a <= b - 1 - x else (right, left)):
                    if 0 <= sx < w and src[y, sx]:
                        out[y, x] = s[y, sx, :3]
                        break
    return out, np.ones_like(hole), from_y


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
    # bits of rope the coil's outline left on the body (a loop's end, a strand by the skirt) would
    # stay behind as a few light pixels when the coil swings: they go with the coil
    for k, (p, m) in enumerate(pieces):
        if p != "rope":
            continue
        hsv = cv2.cvtColor(np.ascontiguousarray(s[..., :3]), cv2.COLOR_RGB2HSV)
        tan = rest & (hsv[..., 0] >= 8) & (hsv[..., 0] < 32) & (hsv[..., 1] >= 40)
        lab, n = ndimage.label(tan)
        near = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        for i, z in enumerate(ndimage.sum(tan, lab, range(1, n + 1)), 1):
            bit = lab == i
            if z < 40 and (bit & near).any():
                m = m | bit
                taken |= bit
        pieces[k] = (p, m)
    rest = opaque & ~taken
    # specks of the body left between pieces (a fleece tip between the hood and a bell) would hang
    # in the air when the pieces move: each goes to the piece it touches most
    # ... and so do small bright bits beside a piece (a glint of bronze, a strand of rope): left on
    # the body they show as a few light pixels hanging there while the piece moves
    hsv = cv2.cvtColor(np.ascontiguousarray(s[..., :3]), cv2.COLOR_RGB2HSV)
    bits = []
    for mask, most in ((rest, 15), (rest & (hsv[..., 2] > 150), 25)):
        lab, n = ndimage.label(mask)
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        bits += [lab == i for i, z in enumerate(sizes, 1) if z < most]
    for speck in bits:
        speck = speck & ~taken
        if not speck.any():
            continue
        ring = (cv2.dilate(speck.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0) & ~speck
        touch = [int((ring & m).sum()) for _, m in pieces]
        if max(touch) > 0:
            k = int(np.argmax(touch))
            pieces[k] = (pieces[k][0], pieces[k][1] | speck)
            taken |= speck
    rest = opaque & ~taken
    core = cv2.morphologyEx(rest.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))) > 0
    core = ndimage.binary_fill_holes(core)
    # ... and a band along every edge a piece shares with the body, as wide as a piece moves
    # ... and along every edge a piece shares with the body or with another piece (the hood and the
    # top bell move apart by a pixel or two: the sky must not show between them)
    behind = taken & (core | (cv2.dilate(rest.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0))
    for p, m in pieces:
        behind |= m & (cv2.dilate((taken & ~m).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0)
    # each piece's share painted in from around it, the other pieces too (between the hood and a bell
    # it is bronze and hood that show, not the fleece further off)
    body = np.zeros_like(s)
    body[..., :3] = np.where(rest[..., None], s[..., :3], 0)
    extra = {}
    for p, m in pieces:
        fill, ok, from_y = mirror_fill(s, opaque & ~m, m, p == "head")
        behind &= ~m | ok
        body[..., :3] = np.where((m & behind)[..., None], fill, body[..., :3])
        if p == "head":
            # where the head hides part of a piece behind it (the top bell under the hood), that
            # piece carries on under the head instead, so the head's nod never chips it
            ys, xs = np.nonzero(m & ok)
            for q, (other, mq) in enumerate(pieces):
                if other == p:
                    continue
                hit = mq[from_y[ys, xs], xs]
                if hit.any():
                    grow = np.zeros_like(mq)
                    grow[ys[hit], xs[hit]] = True
                    extra[other] = (grow, fill)
                    behind &= ~grow
    keep = rest | behind
    body[..., 3] = np.where(keep, 255, 0)
    body[~keep] = 0
    out = {"body": body}
    for p, m in pieces:
        out[p] = np.where(m[..., None], s, 0).astype(np.uint8)
        if p in extra:
            grow, fill = extra[p]
            out[p][grow, :3] = fill[grow]
            out[p][grow, 3] = 255
    for p, img in out.items():
        # turned to face the road
        Image.fromarray(img[:, ::-1]).save(os.path.join(OUT, "%s_%s.png" % (name, p)))
    print(name, s.shape[1::-1], {p: int(m.sum()) for p, m in pieces}, "behind", int(behind.sum()))


if __name__ == "__main__":
    bake("mamuthone", mamuthone_pieces)
    bake("issohadore", issohadore_pieces)
