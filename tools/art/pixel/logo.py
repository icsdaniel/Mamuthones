"""The game's logo in pixel art, after Daniele's logo reference: the hooded black shaggy Mamuthone with
the dark carved mask, a cluster of bronze bells on leather straps, the hemp soha with red bindings
looping round, the MAMUTHONES word mark (hand-built letters, lettering.py), a banner for the subtitle
(the game writes the translated text on it) and the small bonfire in a lozenge below.

    python3 tools/art/pixel/logo.py [--preview out.png]

Writes (1x; the game draws them with nearest filtering at whole multiples):
  game/art/px/logo/logo.png      the full logo (LOGO_W x LOGO_H); the banner's text box is BANNER below
  game/art/px/logo/title.png     the word mark alone, for the title screen's sky
  game/art/px/logo/mark.png      the hooded mask with its bells (the credits' seal, small uses)
  game/art/icon.png (1024), icon_192.png, icon_fg_432.png, icon_bg_432.png   the app icon
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from px import Canvas  # noqa: E402
from palette import P  # noqa: E402
import lettering  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/logo")

LOGO_W, LOGO_H = 200, 232
## The banner's inner text box in the full logo (x, y, w, h in art px); logo.gd writes the subtitle there.
BANNER = (50, 151, 100, 12)


def h01(*k):
    """A stable hash in 0..1 (no noise fields: used to place tufts and chips by rule)."""
    v = 0
    for x in k:
        v = (v * 1103515245 + int(x) * 2654435761 + 12345) & 0xffffffff
    v ^= v >> 13
    v = (v * 0x5bd1e995) & 0xffffffff
    return (v & 0xffff) / 65535.0


# ------------------------------------------------------------------ the mask

def mask(w=40, h=62):
    """The dark carved mask: heavy brow, sad slanted eyes, long ridge of a nose, carved cheek furrows, a
    downturned mouth. Frontal light with a warm catch on the ridges; K0 in the holes."""
    cv = Canvas(w, h)
    sx, sy = w / 40.0, h / 62.0

    def S(pts):
        return [(x * sx, y * sy) for (x, y) in pts]

    face = S([(5, 1), (35, 1), (38, 9), (38.5, 28), (35, 45), (29, 57), (24, 61.5), (16, 61.5), (11, 57), (5, 45), (1.5, 28), (2, 9)])
    fm = cv.m_poly(face)
    xx, yy = cv.grid()
    # base: dark wood, lighter toward the middle of the face (it bulges toward the light)
    nx = (xx + 0.5 - w / 2) / (w / 2)
    ny = (yy + 0.5 - h * 0.45) / (h * 0.6)
    val = np.clip(0.62 - 0.45 * nx * nx - 0.25 * ny * ny, 0, 1)
    cv.ramp_fill(fm, ["WOOD0", "WOOD1", "WOOD2", "WOOD3"], val)
    # forehead: vertical carved planks
    for x in (10, 15, 20, 25, 30):
        cv.line(x * sx, 3 * sy, x * sx, 10 * sy, "WOOD0")
        cv.line(x * sx + 1, 3 * sy, x * sx + 1, 10 * sy, "WOOD3" if 12 <= x <= 28 else "WOOD2")
    # the brow: a heavy ridge across, lit along its top, deep shadow under it
    cv.poly(S([(3, 11), (37, 11), (37.5, 15), (22, 16.5), (18, 16.5), (2.5, 15)]), "WOOD2")
    cv.line(4 * sx, 11 * sy, 36 * sx, 11 * sy, "WOOD4")
    cv.line(5 * sx, 12 * sy, 35 * sx, 12 * sy, "WOOD3")
    cv.line(4 * sx, 16 * sy, 16 * sx, 17 * sy, "K0")
    cv.line(24 * sx, 17 * sy, 36 * sx, 16 * sy, "K0")
    # eyes: slanted almond holes, the outer corners dropping (the sad look)
    for side in (-1, 1):
        def mx(x):
            return w / 2 + side * (x - 20) * sx if side > 0 else w / 2 - (x - 20) * sx

        pts = [(22.5, 18), (31, 18.5), (35, 22.5), (31, 25), (24.5, 23)]
        eye = [(w / 2 + side * (x - 20) * sx, y * sy) for (x, y) in pts]
        rim_pts = [(w / 2 + side * (x - 20) * sx, y * sy) for (x, y) in [(21.5, 17), (32, 17.5), (36.5, 22.5), (32, 26.5), (23.5, 24.5)]]
        cv.poly(rim_pts, "WOOD3")
        cv.poly(eye, "K0")
        # lit lower lid
        cv.line(w / 2 + side * 25 * sx - side * 0, 24.5 * sy + 1, w / 2 + side * 31 * sx, 25.5 * sy + 1, "WOOD4")
    # nose: a long ridge, lit on the left, shadowed on the right, flaring at the tip
    cv.poly(S([(18, 14), (22, 14), (23, 36), (25.5, 41), (14.5, 41), (17, 36)]), "WOOD2")
    cv.line(18.5 * sx, 15 * sy, 17.5 * sx, 38 * sy, "WOOD4")
    cv.line(19.5 * sx, 15 * sy, 18.5 * sx, 37 * sy, "WOOD3")
    cv.line(22.5 * sx, 16 * sy, 23.5 * sx, 36 * sy, "WOOD0")
    cv.line(15 * sx, 41.5 * sy, 25 * sx, 41.5 * sy, "K0")
    cv.pset(16.5 * sx, 40.5 * sy, "K0")
    cv.pset(23.5 * sx, 40.5 * sy, "K0")
    # cheek furrows from the nose wings down past the mouth
    for side in (-1, 1):
        pts = [(w / 2 + side * 6.5 * sx, 36 * sy), (w / 2 + side * 9.5 * sx, 44 * sy), (w / 2 + side * 10 * sx, 52 * sy)]
        cv.curve(pts, "K0")
        cv.curve([(x - side * 1, y) for (x, y) in pts], "WOOD4" if side < 0 else "WOOD3")
    # mouth: a downturned slot with a heavy lower lip
    cv.polyline(S([(12, 50), (15, 47.5), (20, 47), (25, 47.5), (28, 50)]), "K0")
    cv.polyline(S([(13, 51), (15, 49), (20, 48.5), (25, 49), (27, 51)]), "K0")
    cv.line(15 * sx, 46.5 * sy, 25 * sx, 46.5 * sy, "WOOD3")
    cv.line(15 * sx, 51 * sy, 25 * sx, 51 * sy, "WOOD3")
    cv.line(15 * sx, 52.5 * sy, 25 * sx, 52.5 * sy, "WOOD1")
    # chin catch-light
    cv.line(17 * sx, 57 * sy, 23 * sx, 57 * sy, "WOOD3")
    cv._put(~fm, None)
    cv.outline()
    return cv


# ------------------------------------------------------------------ fleece

def fleece_mass(cv, m, seed=1, warm=1.0):
    """Fills mask m with shaggy black sheepskin: a dark ground, then hanging strands, lighter and warmer
    toward the silhouette's lower edges (the fire is below), ragged tufts spilling past the outline."""
    h, w = m.shape
    xx, yy = cv.grid()
    dist = np.zeros((h, w))
    cur = m.copy()
    for d in range(1, 9):
        er = cur.copy()
        er[1:, :] &= cur[:-1, :]
        er[:-1, :] &= cur[1:, :]
        er[:, 1:] &= cur[:, :-1]
        er[:, :-1] &= cur[:, 1:]
        dist[cur & ~er] = d
        cur = er
    dist[cur] = 9
    ys, xs = np.nonzero(m)
    y0, y1 = ys.min(), ys.max()
    cxm = xs.mean()
    rel_y = np.clip((yy - y0) / max(1, y1 - y0), 0, 1)
    rim = np.clip(1.0 - (dist - 1) / 3.0, 0, 1) * (0.3 + 0.7 * rel_y) * warm
    ground = np.clip(0.12 + 0.18 * rel_y + rim * 0.35, 0, 0.999)
    cv.ramp_fill(m, ["FLEECE0", "FLEECE1", "FLEECE2", "FLEECE3"], ground)
    ramp = ["FLEECE1", "FLEECE2", "FLEECE3", "FLEECE4", "FLEECE5", "LEATHER3"]
    # locks: long clumps of two strands hanging down and a little outward, lit at the top, a dark gap
    # under each; placed on a jittered grid so no rows show
    for gy in range(y0 - 3, y1 + 1, 5):
        for gx in range(xs.min() - 3, xs.max() + 1, 3):
            x = gx + int(h01(gx, gy, seed) * 4) - 1
            y = gy + int(h01(gy, gx, seed + 7) * 5)
            if not (0 <= x < w and 0 <= y < h) or not m[y, x]:
                continue
            ln = 5 + int(h01(x, y, seed + 3) * 6)
            lean = (x - cxm) / max(1.0, (xs.max() - xs.min()) / 2) * 0.4
            lv = 0.12 + 0.22 * rel_y[y, x] + 1.0 * rim[y, x] + (h01(y, x, seed + 5) - 0.5) * 0.35
            kk0 = int(np.clip(lv, 0, 0.999) * len(ramp))
            if rim[y, x] < 0.45:
                kk0 = min(kk0, 2 if h01(x, y, seed + 9) < 0.25 else 1)
            for j in range(2):
                for i in range(ln - j):
                    px1, py1 = round(x + j + lean * i), y + i
                    if not (0 <= px1 < w and 0 <= py1 < h):
                        break
                    if not m[py1, px1]:
                        break
                    kk = kk0 if i < ln // 2 else max(0, kk0 - 1)
                    cv.pset(px1, py1, ramp[kk])
                gx_, gy_ = round(x + j + lean * (ln - j)), y + ln - j
                if 0 <= gx_ < w and 0 <= gy_ < h and m[gy_, gx_] and dist[gy_, gx_] > 1:
                    cv.pset(gx_, gy_, "FLEECE0")
    # tufts on the silhouette: spikes of hair past the outline, pointing out and down, their tips lit
    # warm on the fire side
    edge = m & (dist == 1)
    ys, xs = np.nonzero(edge)
    for y, x in zip(ys, xs):
        r = h01(x, y, seed + 11)
        if r < 0.45:
            ln = 2 + int(h01(y, x, seed + 1) * 4)
            ox = -1.0 if x < cxm else 1.0
            ny = 1.0 if rel_y[y, x] > 0.15 else 0.4
            for i in range(1, ln + 1):
                px_ = round(x + ox * i * (0.5 + 0.5 * h01(x, y, 5)))
                py_ = round(y + ny * i * 0.8)
                if not (0 <= px_ < w and 0 <= py_ < h) or m[py_, px_]:
                    continue
                tip = i >= ln - 1 and rel_y[y, x] > 0.3 and warm > 0
                cv.pset(px_, py_, ("LEATHER3" if r < 0.18 else "FLEECE5") if tip else ("FLEECE3" if i > 1 else "FLEECE2"))


# ------------------------------------------------------------------ bells, straps, rope

def bell(cv, cx, top, bw, bh, lit=0.0):
    """A bronze cowbell hanging from a ring at (cx, top): a barrel body flaring to a heavy lip, seen a
    little from below so the dark mouth and the clapper show. Lit from the upper left, warm bronze."""
    L = Canvas(cv.w, cv.h)
    xx, yy = L.grid()
    v = (yy + 0.5 - top) / bh                     # 0 at the crown .. 1 at the lip
    half = bw * (0.3 + 0.2 * np.clip(v, 0, 1) ** 1.8)
    mouth_y = top + bh * 0.84
    bm = (np.abs(xx + 0.5 - cx) <= half) & (v >= 0.06) & (yy + 0.5 <= mouth_y)
    bm |= L.m_ellipse(cx, top + bh * 0.1, bw * 0.3, max(1.5, bh * 0.08))
    u = (xx + 0.5 - (cx - half)) / np.maximum(2 * half, 1)
    val = np.clip(0.85 - 1.0 * u - 0.15 * (v < 0.25) + lit, 0, 1)
    L.ramp_fill(bm, ["GOLD0", "GOLD1", "GOLD2", "GOLD3", "GOLD4"], val * 0.999)
    L._put(bm & (np.abs(u - 0.25) < 0.06) & (v > 0.18) & (v < 0.7), "GOLD5")
    # a raised band above the lip
    band = bm & (np.abs(yy + 0.5 - (top + bh * 0.72)) < 0.6)
    L._put(band & (u < 0.5), "GOLD4")
    L._put(band & (u >= 0.5), "GOLD1")
    # the mouth, seen from below: dark inside, a bright lip in front
    mw = bw * 0.5
    mh = max(1.6, bh * 0.1)
    L._put(L.m_ellipse(cx, mouth_y, mw, mh), "GOLD0")
    lip = L.m_ellipse(cx, mouth_y, mw, mh) & ~L.m_ellipse(cx, mouth_y - 1, mw - 1, mh)
    L._put(lip & (xx + 0.5 < cx), "GOLD4")
    L._put(lip & (xx + 0.5 >= cx), "GOLD2")
    L.ellipse(cx + bw * 0.06, mouth_y + mh * 0.6, max(1.2, bw * 0.09), max(1.2, bw * 0.09), "GOLD2")
    # the crown loop
    L.rect(round(cx - 1), top - 1, 2, 3, "GOLD2")
    L.outline()
    cv.blit(L, 0, 0)


def ring(cv, cx, cy, r=2.5):
    L = Canvas(cv.w, cv.h)
    L._put(L.m_ellipse(cx, cy, r, r) & ~L.m_ellipse(cx, cy, r - 1.2, r - 1.2), "BONE2")
    L.pset(cx - r + 0.5, cy - 0.5, "BONE4")
    L.outline()
    cv.blit(L, 0, 0)


def strap(cv, pts, w=4):
    """A leather strap along pts, with stitching dots."""
    L = Canvas(cv.w, cv.h)
    L.polyline(pts, "LEATHER2", w)
    path = L.polyline(pts, "LEATHER2", w)
    # lit upper edge and stitches
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        n = int(max(abs(x1 - x0), abs(y1 - y0)))
        for s in range(0, n, 3):
            t = s / max(1, n)
            L.pset(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, "LEATHER3" if s % 6 else "GOLD3")
    L.outline()
    cv.blit(L, 0, 0)


def rope(cv, pts, w=5, bindings=(), seed=0):
    """Twisted natural hemp along a Catmull-Rom path, with red bindings at the given fractions of its
    length. Rasterised from a distance field, so the twist runs in clean diagonal strands."""
    probe = Canvas(cv.w, cv.h)
    path = probe.curve(pts, "ROPE1") or []
    if len(path) < 2:
        return
    P_ = np.array(path, float) + 0.5
    seg = np.hypot(*(P_[1:] - P_[:-1]).T)
    acc = np.concatenate([[0.0], np.cumsum(seg)])
    total = acc[-1]
    half = w / 2.0
    x0, y0 = max(0, int(P_[:, 0].min() - w)), max(0, int(P_[:, 1].min() - w))
    x1, y1 = min(cv.w, int(P_[:, 0].max() + w + 1)), min(cv.h, int(P_[:, 1].max() + w + 1))
    yy, xx = np.mgrid[y0:y1, x0:x1]
    cx_, cy_ = xx + 0.5, yy + 0.5
    d2 = (cx_[..., None] - P_[None, None, :, 0]) ** 2 + (cy_[..., None] - P_[None, None, :, 1]) ** 2
    idx = np.argmin(d2, axis=2)
    dist = np.sqrt(np.take_along_axis(d2, idx[..., None], axis=2)[..., 0])
    # signed offset across the rope: + on the right of the direction of travel (the shadow side)
    j0 = np.clip(idx - 2, 0, len(P_) - 1)
    j1 = np.clip(idx + 2, 0, len(P_) - 1)
    dx = P_[j1, 0] - P_[j0, 0]
    dy = P_[j1, 1] - P_[j0, 1]
    ln = np.hypot(dx, dy) + 1e-6
    k = ((cx_ - P_[idx, 0]) * (-dy) + (cy_ - P_[idx, 1]) * dx) / ln
    sa = acc[idx]
    inside = dist <= half
    # the shadow side follows the light (upper left): pick the sign so the lower right is dark
    shade = ((cx_ - P_[idx, 0]) + (cy_ - P_[idx, 1])) / (half * 1.414)
    tw = np.mod(sa * 0.8 + k * 1.1, 4.0)
    col = np.where(tw < 1.6, 2, np.where(tw < 3.0, 1, 0))
    col = np.where(shade > 0.55, np.minimum(col, 1), col)
    col = np.where(shade > 0.8, 0, col)
    col = np.where((shade < -0.5) & (col == 1), 2, col)
    L = Canvas(cv.w, cv.h)
    names = ["ROPE0", "ROPE1", "ROPE2"]
    for i, nm in enumerate(names):
        m = np.zeros((cv.h, cv.w), bool)
        m[y0:y1, x0:x1] = inside & (col == i)
        L._put(m, nm)
    for bpos in bindings:
        bs = bpos * total
        near = inside & (np.abs(sa - bs) < 3.2)
        wrap = np.mod(np.floor(sa - bs + 3.2), 2) == 0
        for cond, nm in ((near & wrap & (shade <= 0.3), "RED3"), (near & ~wrap & (shade <= 0.3), "RED2"),
                         (near & (shade > 0.3), "RED1"), (near & (shade < -0.55), "RED4")):
            m = np.zeros((cv.h, cv.w), bool)
            m[y0:y1, x0:x1] = cond
            L._put(m, nm)
    L.outline()
    cv.blit(L, 0, 0)


# ------------------------------------------------------------------ bonfire lozenge

def bonfire_lozenge(cv, top, x0, x1, bottom):
    cx = (x0 + x1) / 2
    L = Canvas(cv.w, cv.h)
    tri = [(x0, top), (x1, top), (cx, bottom)]
    tm = L.m_poly(tri)
    xx, yy = L.grid()
    # sky of the scene: dark, glowing red-orange around the fire
    fy = top + (bottom - top) * 0.4
    d = np.sqrt(((xx + 0.5 - cx) / 46.0) ** 2 + ((yy + 0.5 - fy) / 24.0) ** 2)
    val = np.clip(1.0 - d, 0, 1) ** 1.3
    L.ramp_fill(tm, ["K0", "K1", "FIRE0", "FIRE1", "FIRE2"], val * 0.999)
    # standing stones (menhirs) in silhouette, rim-lit toward the fire
    for (sxp, sw, shh) in ((x0 + 22, 9, 17), (x0 + 36, 7, 13), (x1 - 36, 7, 14), (x1 - 22, 9, 18)):
        base = top + 34
        stone = [(sxp - sw / 2, base), (sxp - sw / 2 + 1, base - shh + 2), (sxp, base - shh), (sxp + sw / 2 - 1, base - shh + 2), (sxp + sw / 2, base)]
        L.poly(stone, "STONE0")
        side = 1 if sxp < cx else -1
        edge_x = sxp + side * (sw / 2 - 1)
        L.line(edge_x, base - shh + 3, edge_x, base - 1, "FIRE2")
    # the fire: logs, flames stepping from red to white-hot
    base_y = top + 38
    L.line(cx - 14, base_y + 2, cx + 11, base_y - 4, "WOOD2", 2)
    L.line(cx + 14, base_y + 2, cx - 11, base_y - 4, "WOOD2", 2)
    flames = [
        ([(cx - 15, base_y), (cx - 11, base_y - 14), (cx - 6, base_y - 10), (cx - 2, base_y - 30), (cx + 3, base_y - 13), (cx + 7, base_y - 20), (cx + 10, base_y - 12), (cx + 15, base_y)], "FIRE3"),
        ([(cx - 10, base_y), (cx - 7, base_y - 10), (cx - 3, base_y - 8), (cx - 1, base_y - 22), (cx + 3, base_y - 9), (cx + 6, base_y - 13), (cx + 10, base_y)], "FIRE4"),
        ([(cx - 7, base_y), (cx - 3, base_y - 9), (cx - 1, base_y - 15), (cx + 2, base_y - 8), (cx + 7, base_y)], "FIRE5"),
        ([(cx - 4, base_y), (cx - 1, base_y - 8), (cx + 4, base_y)], "FIRE6"),
    ]
    for pts, col in flames:
        L.poly(pts, col)
    L.ellipse(cx, base_y - 1, 2.5, 2, "FIRE7")
    # glowing stones heaped round the fire
    # coals and fire-blackened stones heaped below: dark, their tops caught by the fire
    k = 0
    for row, (ry, n, r) in enumerate(((2, 9, 4.2), (7, 8, 4.6), (12, 7, 4.6), (17, 5, 4.4), (22, 4, 4.0), (27, 2, 3.6))):
        span = (x1 - x0) * (1.0 - (base_y + ry - top) / (bottom - top)) * 0.86
        for i in range(n):
            k += 1
            ox = -span / 2 + span * (i + 0.5) / n + (h01(k, 3) - 0.5) * 3
            oy = base_y + ry + (h01(k, 5) - 0.5) * 2
            rr = r * (0.8 + 0.4 * h01(k, 7))
            m = L.m_ellipse(cx + ox, oy, rr, rr * 0.78)
            near = max(0.0, 1.0 - (abs(ox) + (oy - base_y) * 1.5) / 40.0)
            cols = ["K1", "STONE0", "STONE1", "FIRE2" if near > 0.55 else "STONE2"]
            if near > 0.8:
                cols = ["STONE0", "FIRE1", "FIRE3", "FIRE5"]
            L.shade_ellipse(cx + ox, oy, rr, rr * 0.78, cols, light=(-0.25 * np.sign(ox), -0.85), mask=m, dither=False)
            L._put(m & ~L.m_ellipse(cx + ox, oy, rr - 1, rr * 0.78 - 1) & (yy + 0.5 > oy), "K0")
    L._put(~tm, None)
    # frame: gold rule with K0 outline
    edge = tm.copy()
    er = tm.copy()
    er[1:, :] &= tm[:-1, :]
    er[:-1, :] &= tm[1:, :]
    er[:, 1:] &= tm[:, :-1]
    er[:, :-1] &= tm[:, 1:]
    L._put(edge & ~er, "GOLD4")
    er2 = er.copy()
    er2[1:, :] &= er[:-1, :]
    er2[:-1, :] &= er[1:, :]
    er2[:, 1:] &= er[:, :-1]
    er2[:, :-1] &= er[:, 1:]
    L._put(er & ~er2, "GOLD2")
    L.outline()
    cv.blit(L, 0, 0)


def banner(cv, x, y, w, h):
    """A dark ribbon with gold edges and folded swallow-tail ends (the subtitle is written by the game)."""
    L = Canvas(cv.w, cv.h)
    # folded tails behind
    for side in (-1, 1):
        ex = x - 1 if side < 0 else x + w
        tail = [(ex, y + 3), (ex + side * 12, y + 3), (ex + side * 8, y + h / 2 + 3), (ex + side * 12, y + h + 3), (ex, y + h + 3)]
        L.poly(tail, "RED1")
        L.line(ex, y + h + 3, ex + side * 11, y + h + 3, "RED0")
    L.outline()
    F = Canvas(cv.w, cv.h)
    F.rect(x, y, w, h, "NAVY0")
    F.hline(x, x + w - 1, y, "GOLD4")
    F.hline(x, x + w - 1, y + 1, "GOLD2")
    F.hline(x, x + w - 1, y + h - 2, "GOLD2")
    F.hline(x, x + w - 1, y + h - 1, "GOLD3")
    F.outline()
    L.blit(F, 0, 0)
    cv.blit(L, 0, 0)


def embers(cv, pts):
    for (x, y, big) in pts:
        cv.pset(x, y, "FIRE6" if big else "FIRE4")
        if big:
            cv.pset(x, y + 1, "FIRE3")


# ------------------------------------------------------------------ compositions

def hooded(cv, cx, top, scale=1.0, bells=True, seed=4):
    """The hooded Mamuthone bust: fleece hood and body, the kerchief, the mask, straps and bells."""
    s = scale
    F = Canvas(cv.w, cv.h)
    hood = F.m_ellipse(cx, top + 36 * s, 31 * s, 36 * s) | F.m_poly([(cx - 6 * s, top), (cx + 6 * s, top), (cx + 22 * s, top + 14 * s), (cx - 22 * s, top + 14 * s)])
    body = F.m_poly([(cx - 30 * s, top + 36 * s), (cx - 60 * s, top + 90 * s), (cx - 80 * s, top + 126 * s), (cx + 80 * s, top + 126 * s),
                     (cx + 60 * s, top + 90 * s), (cx + 30 * s, top + 36 * s)])
    shoulders = F.m_ellipse(cx, top + 104 * s, 76 * s, 36 * s)
    m = (hood | body | shoulders)
    m[int(top + 126 * s):, :] = False
    fleece_mass(F, m, seed)
    F.outline()
    cv.blit(F, 0, 0)
    # the black kerchief round the face
    K = Canvas(cv.w, cv.h)
    K.ellipse(cx, top + 44 * s, 23 * s, 31 * s, "K1")
    K.ellipse(cx, top + 42 * s, 21 * s, 28 * s, "FLEECE0")
    cv.blit(K, 0, 0)
    mk = mask(round(40 * s), round(62 * s))
    cv.blit(mk, round(cx - mk.w / 2), round(top + 17 * s))
    if not bells:
        return
    # straps across the chest and the bells hanging from them
    sw = max(3, round(4 * s))
    strap(cv, [(cx - 46 * s, top + 64 * s), (cx - 22 * s, top + 84 * s), (cx - 4 * s, top + 94 * s)], sw)
    strap(cv, [(cx + 46 * s, top + 64 * s), (cx + 22 * s, top + 84 * s), (cx + 4 * s, top + 94 * s)], sw)
    bells_at = ((-58, 66, 19, 21), (56, 62, 21, 24), (-44, 98, 12, 13), (-30, 78, 29, 33), (42, 96, 14, 15),
                (26, 80, 25, 28), (-12, 102, 12, 14), (2, 94, 21, 24))
    for (ox, oy, bw, bh) in bells_at:
        ring(cv, cx + ox * s, top + (oy - 2) * s, max(1.8, 2.4 * s))
    for (ox, oy, bw, bh) in bells_at:
        bell(cv, cx + ox * s, top + oy * s, bw * s, bh * s)


def full_logo():
    W, H = LOGO_W, LOGO_H
    cv = Canvas(W, H)
    cx = W // 2
    # the rope's far run, behind the fleece: over the right shoulder into the big loop
    rope(cv, [(138, 58), (152, 36), (174, 30), (190, 46), (188, 76), (176, 102)], 7, bindings=(0.14, 0.66), seed=2)
    hooded(cv, cx, 4, 1.0)
    # the rope's near runs: up the left side behind the bells, and down the right side to the noose
    rope(cv, [(46, 222), (26, 202), (14, 166), (14, 128), (24, 100), (42, 84)], 7, bindings=(0.16, 0.52, 0.88), seed=1)
    bonfire_lozenge(cv, 158, 32, 168, 230)
    rope(cv, [(176, 102), (184, 130), (182, 164), (170, 194), (156, 210)], 7, bindings=(0.3, 0.78), seed=3)
    rope(cv, [(156, 210), (142, 220), (148, 230), (166, 228), (172, 212), (162, 204)], 6, seed=5)
    bx, by, bw, bh = BANNER
    banner(cv, bx - 2, by - 2, bw + 4, bh + 4)
    arch = [29, 27, 25, 24, 23, 23, 24, 25, 27, 29]
    word = lettering.word("MAMUTHONES", arch, base="top", shadow=(1, 2), speckle=True, gap=0, weight=1.2, wscale=0.78, border=True)
    assert word.w <= W - 2, word.w
    cv.blit(word, cx - word.w // 2, 120)
    embers(cv, [(12, 60, True), (190, 128, False), (24, 150, False), (172, 16, True), (30, 30, False), (196, 150, True), (4, 96, False), (180, 152, False)])
    return cv


def title_block():
    return lettering.word("MAMUTHONES", [18] * 10, base="top", shadow=(1, 2), gap=1)


def mark(size=72):
    """The hooded mask with a few bells, square, for the credits seal and small places."""
    cv = Canvas(size, size)
    hooded(cv, size / 2, 2, size / 132.0, bells=True, seed=9)
    return cv


# ------------------------------------------------------------------ app icon

def icon_art(n=64, mark_frac=1.0, background=True):
    """The icon: the hooded mask over a banded fire glow on night blue."""
    cv = Canvas(n, n, "NAVY0" if background else None)
    if background:
        for f, col in ((0.62, "NAVY1"), (0.48, "RED0"), (0.36, "FIRE0"), (0.26, "FIRE1")):
            cv.ellipse(n / 2, n * 0.66, n * f, n * f * 0.9, col)
    s = n / 64.0 * mark_frac
    top = n / 2 - 30 * s
    I = Canvas(n, n)
    F = Canvas(n, n)
    cx = n / 2
    hood = F.m_ellipse(cx, top + 22 * s, 21 * s, 22 * s)
    body = F.m_poly([(cx - 18 * s, top + 26 * s), (cx - 30 * s, top + 60 * s), (cx + 30 * s, top + 60 * s), (cx + 18 * s, top + 26 * s)])
    m = hood | body
    fleece_mass(F, m, 3)
    F.outline()
    I.blit(F, 0, 0)
    K = Canvas(n, n)
    K.ellipse(cx, top + 27 * s, 15 * s, 20 * s, "FLEECE0")
    I.blit(K, 0, 0)
    mk = mask(round(26 * s), round(40 * s))
    I.blit(mk, round(cx - mk.w / 2), round(top + 10 * s))
    bell(I, cx - 15 * s, top + 44 * s, 12 * s, 13 * s)
    bell(I, cx + 15 * s, top + 44 * s, 12 * s, 13 * s)
    bell(I, cx, top + 50 * s, 10 * s, 11 * s)
    cv.blit(I, 0, 0)
    return cv


def main():
    os.makedirs(OUT, exist_ok=True)
    logo = full_logo()
    logo.save(os.path.join(OUT, "logo.png"))
    title_block().save(os.path.join(OUT, "title.png"))
    mark().save(os.path.join(OUT, "mark.png"))
    icon = icon_art(64)
    icon.save(os.path.join(ROOT, "art/icon.png"), scale=16)
    icon.save(os.path.join(ROOT, "art/icon_192.png"), scale=3)
    # Android adaptive icon: 72 x 72 art px x6 = 432; the mark inside the central safe zone
    fg = icon_art(72, mark_frac=0.62, background=False)
    fg.save(os.path.join(ROOT, "art/icon_fg_432.png"), scale=6)
    bg = Canvas(72, 72, "NAVY0")
    for f, col in ((0.62, "NAVY1"), (0.48, "RED0"), (0.36, "FIRE0"), (0.26, "FIRE1")):
        bg.ellipse(36, 36 + 72 * 0.16, 72 * f, 72 * f * 0.9, col)
    bg.save(os.path.join(ROOT, "art/icon_bg_432.png"), scale=6)
    print("logo", logo.w, logo.h, "title", title_block().w, title_block().h)
    if "--preview" in sys.argv:
        from PIL import Image
        out = sys.argv[sys.argv.index("--preview") + 1]
        sheet = Canvas(LOGO_W + 90, LOGO_H, "K0")
        sheet.blit(logo, 0, 0)
        sheet.blit(icon, LOGO_W + 10, 4)
        sheet.blit(mark(), LOGO_W + 6, 80)
        sheet.image(3).save(out)


if __name__ == "__main__":
    main()
