"""Sonazzos main menu, alternative direction "Controluce".

One Mamuthone, cropped close in three-quarter profile, back-lit by the
Sant'Antonio bonfire; the menu is a cream bottom sheet.
Canvas 135x300 art px, 5 inks, scaled 4x nearest.

usage: python3 render.py OUTDIR
"""
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

from font import F3, F5, LH, LW, draw_text, logo_glyph, text_width

W, H = 135, 300
SCALE = 4
K, C, R, G, B = 0, 1, 2, 3, 4
PAL = [(0x14, 0x10, 0x14), (0xEF, 0xE6, 0xD2), (0xC8, 0x35, 0x2A),
       (0xC9, 0xBB, 0xA0), (0x4A, 0x3C, 0x38)]
BPM = 120.0
BEAT = 60.0 / BPM
HOLD = 0.03
RET = 0.15
LOOP = 2.0
FPS = 30

SHEET_Y = 174

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
BAY = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
YY, XX = np.mgrid[0:H, 0:W]


# ------------------------------------------------------------------ helpers
def beat_env(t):
    """1 on the beat, held 0.03 s, eased back to 0 over RET."""
    tb = t % BEAT
    if tb < HOLD:
        return 1.0
    u = (tb - HOLD) / RET
    if u >= 1:
        return 0.0
    return (1 - u) ** 2


def poly(points, dx=0, dy=0):
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).polygon([(x + dx, y + dy) for x, y in points], fill=1, outline=1)
    return np.array(im, dtype=bool)


def ellipse(x0, y0, x1, y1):
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).ellipse([x0, y0, x1, y1], fill=1)
    return np.array(im, dtype=bool)


def dither(cv, mask, a, b, level):
    """Fill mask with ink b on `level`/16 of the pixels, ink a elsewhere."""
    sel = BAY < level
    cv[mask & sel] = b
    cv[mask & ~sel] = a


def edge_right(mask):
    e = mask.copy()
    e[:, :-1] &= ~mask[:, 1:]
    return e


def edge_down(mask):
    e = mask.copy()
    e[:-1, :] &= ~mask[1:, :]
    return e


def edge_up(mask):
    e = mask.copy()
    e[1:, :] &= ~mask[:-1, :]
    return e


def dilate(mask, n=1):
    m = mask.copy()
    for _ in range(n):
        o = m.copy()
        o[1:, :] |= m[:-1, :]
        o[:-1, :] |= m[1:, :]
        o[:, 1:] |= m[:, :-1]
        o[:, :-1] |= m[:, 1:]
        m = o
    return m


def stamp(cv, bitmap, x, y, ink):
    ys, xs = np.nonzero(bitmap)
    ys = ys + y
    xs = xs + x
    ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
    cv[ys[ok], xs[ok]] = ink


def bm(rows):
    return np.array([[c == "#" for c in r] for r in rows], dtype=bool)


# --------------------------------------------------------------- bonfire
FIRE_CX, FIRE_BASE = 124, 140


def draw_glow(cv, t, env):
    d = np.hypot((XX - FIRE_CX) * 1.0, (YY - (FIRE_BASE - 40)) * 1.0)
    r = 1.0 + 0.06 * env
    bands = [(84, B, 3), (70, B, 6), (58, R, 3), (48, R, 6), (40, R, 9)]
    sky = YY < FIRE_BASE + 4
    for rad, ink, lvl in bands:
        m = sky & (d < rad * r)
        dither(cv, m, K, ink, lvl)


def draw_fire(cv, t, env):
    ph = 2 * math.pi * t / LOOP
    lift = 1.0 + 0.16 * env
    tongues = [(101, 6, 40, 0.0), (110, 9, 66, 1.3), (121, 13, 96, 2.1),
               (131, 10, 74, 0.7), (139, 9, 52, 2.9)]
    hot = np.zeros((H, W), dtype=bool)
    core = np.zeros((H, W), dtype=bool)
    for bx, hw, hh, p0 in tongues:
        h = hh * lift * (0.86 + 0.14 * math.sin(2 * ph + p0))
        sway = 4 * math.sin(ph * 2 + p0 * 2)
        sway2 = 2 * math.sin(ph * 4 + p0)
        base = FIRE_BASE
        # S-curved tongue, tip bending with the sway
        pts = [(bx - hw, base),
               (bx - hw * 1.0 + sway2, base - h * 0.25),
               (bx - hw * 0.5 + sway2, base - h * 0.5),
               (bx - hw * 0.1 - sway * 0.3, base - h * 0.72),
               (bx + sway, base - h),
               (bx + hw * 0.35 + sway * 0.2, base - h * 0.74),
               (bx + hw * 0.55 - sway2 * 0.5, base - h * 0.5),
               (bx + hw * 0.95, base - h * 0.22), (bx + hw, base)]
        hot |= poly(pts)
        ch = h * 0.42
        cpts = [(bx - hw * 0.6, base), (bx - hw * 0.5 + sway2 * 0.5, base - ch * 0.5),
                (bx - hw * 0.1, base - ch * 0.85), (bx + sway * 0.4, base - ch),
                (bx + hw * 0.3, base - ch * 0.6), (bx + hw * 0.6, base)]
        core |= poly(cpts)
    fringe = dilate(hot, 2) & ~hot
    dither(cv, fringe & (cv != C), K, R, 6)
    cv[hot] = R
    # soft edge of the core: one dithered ring of cream on red
    cv[core] = C
    logs = lines_free([[(98, FIRE_BASE - 2), (134, FIRE_BASE - 9)],
                       [(104, FIRE_BASE - 10), (135, FIRE_BASE)],
                       [(114, FIRE_BASE - 1), (126, FIRE_BASE - 16)]], 2)
    cv[logs] = K


def draw_embers(cv, t, env):
    rng = np.random.default_rng(11)
    n = 22
    for i in range(n):
        x0 = rng.uniform(98, 134)
        off = rng.uniform(0, 1)
        sp = rng.choice([1, 2])  # cycles per loop -> loops cleanly
        amp = rng.uniform(2, 7)
        u = (t / LOOP * sp + off) % 1.0
        y = FIRE_BASE - 30 - u * 120
        x = x0 - u * 22 + amp * math.sin(2 * math.pi * (u * 2 + off))
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < W and 0 <= yi < SHEET_Y:
            cv[yi, xi] = C if (i % 3 == 0 and u < 0.5) else R


def draw_ground(cv, t, env):
    gm = (YY >= FIRE_BASE) & (YY < SHEET_Y)
    cv[gm] = K
    # cobbles lit by the fire: short dashes, warmer near the fire
    for y in range(FIRE_BASE + 2, SHEET_Y, 3):
        row = (y - FIRE_BASE) // 3
        for x in range((row * 3) % 7, W, 7):
            dd = abs(x - FIRE_CX) + (y - FIRE_BASE) * 2
            if dd < 26:
                ink = R
            elif dd < 60:
                ink = B
            else:
                continue
            cv[y, x:x + 4] = ink


def draw_far_figures(cv, t, env):
    return


def lines_free(pts_list, width=1):
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    for pts in pts_list:
        d.line(pts, fill=1, width=width)
    return np.array(im, dtype=bool)

# ------------------------------------------------------------------- bells
def draw_bell(cv, cx, cy, ang, L, w0, w1, light=1, tongue=0.0, band=True, clip=None):
    """Cowbell from closed end (cx,cy) along angle `ang` (radians, 0 = +x).

    light: +1 lit from the right/fire side of the bell's perpendicular.
    tongue: clapper offset along the perpendicular (in px), drawn past the mouth.
    """
    ax, ay = math.cos(ang), math.sin(ang)
    px, py = -ay, ax
    if px * light < 0:  # make +perp face the fire (+x)
        px, py = -px, -py
    rx = int(L + max(w0, w1) + 4)
    x0, x1 = max(0, int(cx - rx)), min(W, int(cx + rx + 1))
    y0, y1 = max(0, int(cy - rx)), min(H, int(cy + rx + 1))
    for y in range(y0, y1):
        for x in range(x0, x1):
            qx, qy = x + 0.5 - cx, y + 0.5 - cy
            u = (qx * ax + qy * ay) / L
            if u < 0 or u > 1:
                continue
            hw = w0 + (w1 - w0) * u
            v = (qx * px + qy * py) / hw
            if abs(v) > 1:
                continue
            if clip is not None and not clip[y, x]:
                continue
            if False:
                pass
            elif v > 0.78:
                ink = R
            elif 0.28 < v < 0.52:
                ink = C
            elif v > -0.15:
                ink = G
            elif v > -0.55:
                ink = B if (x + y) % 2 else G
            else:
                ink = B if (x + y) % 2 else K
            if band and 0.78 < u < 0.85 and abs(v) < 0.95:
                ink = B if v > -0.2 else K
            cv[y, x] = ink
    # the mouth: an open ellipse at the end, cream lip, dark inside
    mx, my = cx + ax * L, cy + ay * L
    a_ax, a_pp = max(1.5, w1 * 0.38), w1 + 0.5
    for y in range(y0, y1):
        for x in range(x0, x1):
            qx, qy = x + 0.5 - mx, y + 0.5 - my
            u = (qx * ax + qy * ay) / a_ax
            v = (qx * px + qy * py) / a_pp
            r2 = u * u + v * v
            if r2 <= 1.0:
                inner = (u / max(0.6, 1 - 1.4 / a_ax)) ** 2 + (v / (1 - 1.4 / a_pp)) ** 2
                if inner <= 1.0:
                    cv[y, x] = K
                else:
                    cv[y, x] = C if v > -0.3 else G
    # clapper hanging past the mouth
    if tongue is not None:
        tx = cx + ax * (L + 1.5) + px * tongue
        ty = cy + ay * (L + 1.5) + py * tongue
        for ddx, ddy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
            xi, yi = int(tx) + ddx - 1, int(ty) + ddy - 1
            if 0 <= xi < W and 0 <= yi < H:
                cv[yi, xi] = K if ddy == 0 else G


# --------------------------------------------------------------- mamuthone
FLEECE = [(0, 104), (12, 100), (24, 100), (36, 102), (48, 106), (60, 110), (70, 114),
          (84, 120), (96, 128), (104, 142), (108, 158), (110, SHEET_Y), (0, SHEET_Y)]

# The head is drawn from Daniele's photo (mamuthone_reference.jpg): every point
# below is in photo pixels and A() maps it onto the canvas.  Three-quarter view,
# turned to the viewer's right and a little down.
MS = 0.14                        # art px per photo px
MX0, MY0 = 60, 32                # where photo (885, 100) lands on the canvas


def A(pts):
    return [(MX0 + (x - 885) * MS, MY0 + (y - 100) * MS) for x, y in pts]


# hood of the brown headscarf: wide on the near side, a thin band over the top
# and down the far side of the forehead, then drawn in under the chin
SCARF = A([(690, 430), (698, 310), (735, 205), (795, 125), (875, 68), (975, 40),
           (1075, 42), (1155, 75), (1205, 135), (1218, 210), (1212, 285),
           (1150, 330), (1040, 600), (1000, 745), (930, 770), (840, 720),
           (760, 630), (705, 530)])

# the carved visera
MASK = A([(890, 175), (940, 135), (1000, 110), (1080, 102), (1140, 108),       # forehead top
          (1180, 132), (1186, 200), (1186, 262),                               # far edge, under the scarf
          (1205, 272), (1224, 292), (1232, 330), (1226, 370), (1206, 392),     # far end of the brow
          (1188, 398), (1192, 440), (1196, 482), (1188, 510), (1166, 524),     # nose, straight down to a heavy tip
          (1104, 528), (1128, 532), (1142, 544), (1134, 554),                  # upper lip juts out
          (1112, 556), (1124, 572), (1130, 592), (1124, 614), (1104, 630),     # open slit, lower lip
          (1104, 655), (1104, 700), (1088, 736), (1045, 754), (985, 752),      # strong chin
          (950, 730), (925, 660), (905, 560), (895, 450), (888, 330), (886, 240)])

KNOT = A([(870, 700), (950, 742), (1010, 760), (1030, 790), (1000, 815), (965, 805),
          (960, 890), (915, 895), (925, 810), (860, 750)])


def lines(pts_list, dy, width=1):
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    for pts in pts_list:
        d.line([(x, y + dy) for x, y in pts], fill=1, width=width)
    return np.array(im, dtype=bool)


def draw_fleece(cv, dy):
    m = poly(FLEECE, 0, dy) & (YY < SHEET_Y)
    rng = np.random.default_rng(5)
    top = edge_up(m)
    ys, xs = np.nonzero(top)
    for y, x in zip(ys, xs):
        if rng.random() < 0.45:
            ln = rng.integers(1, 4)
            m[max(0, y - ln):y, x] = True
    cv[m] = K
    ytop = np.full(W, H)
    for x in range(W):
        col = np.nonzero(m[:, x])[0]
        if len(col):
            ytop[x] = col[0]
    # shingled locks: rows of 3 px wide clumps, each a curved lock with a tip
    for row in range(12):
        for x0 in range(-2, W, 5):
            x = x0 + (row % 2) * 2 + int(rng.integers(-1, 2))
            if not (0 <= x < W) or ytop[min(W - 1, max(0, x))] >= SHEET_Y:
                continue
            y = ytop[max(0, min(W - 1, x))] + row * 9 + int(rng.integers(0, 4))
            if y >= SHEET_Y:
                continue
            ln = int(rng.integers(9, 16))
            ph = rng.uniform(0, 6.28)
            lit = x > 64 + (y - 120) * 0.6
            main = R if lit else B
            for k in range(ln):
                yy = y + k
                cx = x + int(round(1.0 * math.sin(ph + k * 0.3)))
                for j, ink in enumerate([main, B if lit else B, K]):
                    xx = cx + j
                    if 0 <= xx < W and yy < SHEET_Y and m[yy, xx]:
                        if j == 1 and k > ln - 4:
                            continue  # taper the tip
                        cv[yy, xx] = ink
            # a glint where the lock turns
            if not lit and rng.random() < 0.3 and y + 2 < SHEET_Y and 0 <= x < W and m[y + 2, x]:
                cv[y + 2, x] = G
    cv[edge_right(m) & (XX > 60)] = R
    return m


def draw_scarf(cv, dy):
    m = poly(SCARF, 0, dy)
    # dark cloth: black with brown folds running from the crown down round the face,
    # so it reads as fabric and stays darker than the carved planes of the mask
    cv[m] = K
    folds = lines([A([(1150, 70), (1040, 52), (940, 62), (850, 100), (780, 170), (730, 260)]),
                   A([(1180, 110), (1100, 80), (980, 82), (880, 130), (810, 220), (770, 330), (760, 450)]),
                   A([(860, 160), (820, 260), (800, 380), (810, 500), (850, 620)]),
                   A([(740, 300), (720, 420), (740, 540), (790, 640)]),
                   A([(1200, 160), (1202, 260)]),
                   A([(900, 680), (960, 735)])], dy, 2)
    cv[folds & m] = B
    sheen = lines([A([(812, 210), (796, 260)])], dy, 2)
    cv[sheen & m] = G
    # fire rim on the crown and on the far fold beside the forehead
    cv[edge_up(m) & (XX > 84)] = R
    cv[edge_right(m) & (YY < MY0 + 30 + dy)] = R
    return m


def draw_mask(cv, dy):
    """The black visera from Daniele's photo, three-quarter view, back-lit by the fire."""
    m = poly(MASK, 0, dy)
    cv[m] = K
    cv[dilate(m, 1) & ~m & (XX < MX0 + 40)] = K      # a dark seam where the scarf meets the mask

    def P(pts, ink, lvl=None):
        pm = poly(A(pts), 0, dy) & m
        if lvl is None:
            cv[pm] = ink
        else:
            dither(cv, pm, K, ink, lvl)

    def Lz(pts_list, ink, w=2):
        cv[lines([A(p) for p in pts_list], dy, w) & m] = ink

    # forehead: broad flat plane facing the viewer, a sheen high on it, the small red mark
    P([(886, 176), (1000, 112), (1100, 106), (1150, 112), (1156, 240), (886, 222)], B)
    Lz([[(950, 156), (1060, 128)]], G)
    P([(1102, 132), (1126, 132), (1126, 154), (1102, 154)], R)
    # heavy brow shelf sloping down across the face, lit top edge, deep shadow under it
    P([(892, 228), (1186, 258), (1196, 284), (892, 254)], B)
    Lz([[(910, 234), (1110, 254)]], G)
    # near cheek: one big plane under the eye, sheen high on it; it turns away into shadow at the scarf
    P([(886, 290), (950, 300), (1000, 356), (1062, 352), (1074, 455), (990, 470), (900, 470)], B)
    Lz([[(925, 392), (950, 425)]], G)
    Lz([[(900, 490), (930, 620)]], K, 3)
    # the eyes: the near one a round hole with the wearer's skin deep inside; the far one a
    # sliver past the nose, under the end of the brow
    def oval(x0, y0, x1, y1):
        e = ellipse(*[v for p in A([(x0, y0), (x1, y1)]) for v in p])
        return np.roll(e, dy, axis=0) & m

    cv[oval(938, 262, 1074, 384)] = B                               # the carved socket round it
    cv[oval(960, 280, 1054, 362)] = K
    Lz([[(950, 340), (972, 370), (1010, 380), (1046, 370)]], G)   # lower rim of the eye hole catches light
    P([(1176, 330), (1200, 330), (1198, 404), (1180, 404)], K)
    # far end of the brow, rounding off past the nose root
    P([(1186, 262), (1224, 292), (1232, 330), (1226, 368), (1200, 380), (1190, 300)], K)
    # the long nose: flat front plane widening to a heavy tip, bright ridge, dark near side
    Lz([[(1088, 296), (1080, 400), (1066, 500)]], K, 4)
    P([(1100, 296), (1174, 316), (1194, 470), (1186, 506), (1168, 518), (1080, 504), (1090, 460)], B)
    Lz([[(1108, 312), (1104, 400), (1098, 480)]], G)
    Lz([[(1140, 490), (1176, 496)]], G)
    Lz([[(1016, 446), (1046, 426), (1072, 436)]], K, 2)  # carved nostril wing
    # the lower face follows the tilt of the head: everything slopes down to the right
    P([(980, 478), (1080, 500), (1180, 510), (1166, 534), (980, 504)], K)   # shadow under the nose
    P([(966, 502), (1130, 532), (1142, 544), (1134, 554), (966, 528)], B)   # thick upper lip
    Lz([[(984, 508), (1126, 536)]], G)
    P([(960, 528), (1134, 554), (1116, 578), (960, 556)], K)                # open slit
    P([(964, 556), (1116, 576), (1130, 594), (1122, 614), (1100, 626), (964, 600)], B)  # lower lip
    Lz([[(1000, 568), (1116, 590)]], G)
    P([(950, 600), (1104, 626), (1104, 654), (950, 630)], K)   # shadow under the lower lip
    # strong chin
    P([(980, 646), (1094, 664), (1088, 712), (1050, 738), (998, 724)], B)
    Lz([[(1030, 674), (1080, 680)]], G)
    # a black gap between the mask and the glow, so the face reads against the fire
    halo = dilate(m, 3) & ~m & (XX > MX0 + 36) & (YY > MY0 + 22 + dy)
    cv[halo] = K
    # fire rim down the far side; cream where the carving juts out furthest
    rim = edge_right(m) & (XX > MX0 + 20)
    cv[rim] = R
    cv[rim & (XX > MX0 + 41) & (YY > MY0 + 23 + dy)] = C   # brow end and nose
    cv[rim & (XX > MX0 + 33) & (YY > MY0 + 60 + dy) & (YY < MY0 + 75 + dy)] = C   # lips
    cv[edge_down(m) & (XX > MX0 + 26)] = R
    return m


def draw_knot(cv, dy):
    k = poly(KNOT, 0, dy)
    dither(cv, k, K, B, 9)
    cv[lines([A([(900, 740), (1000, 775)]), A([(960, 800), (935, 885)])], dy, 2) & k] = K
    cv[edge_right(k)] = R

def draw_mamuthone(cv, t, env):
    dy = int(round(2 * env))
    # big back bell, mouth up and out over the left shoulder; lags the jump
    ang = math.radians(-116 + 8 * env)
    draw_bell(cv, 26, 116 + dy + int(round(env)), ang, 42, 7, 14, light=1, tongue=None)
    draw_fleece(cv, dy)
    # two smaller sonazzos hanging on the back, swinging against the landing
    for bx, by, L, w0, w1, ph in [(10, 124, 16, 4, 8, 1), (30, 130, 14, 3, 7, -1)]:
        a = math.radians(90 + ph * 10 * env)
        draw_bell(cv, bx, by + dy, a, L, w0, w1, light=1, tongue=-3 * env * ph)
        cv[by + dy - 3:by + dy + 1, bx] = B  # leather loop
    # the head (scarf, visera, knot) is a hand-placed sprite stamped after chunky()



# ------------------------------------------------------------------- head
# Hand-placed sprite at the chunky cell grid: one character = one 2x2 cell.
# Traced from mamuthone_reference.jpg: cell (cx, cy) <-> photo (690 + 12.5 cx, 40 + 12.5 cy).
# '.' transparent, K black, C cream, R vermilion, G warm grey, B brown.
# Stamped after chunky() so nothing crushes it; it replaces draw_scarf/draw_mask/draw_knot.
HEAD_X, HEAD_Y = 22, 12
HEAD_SPRITE = """
..............................................
........................KKKRRRRK..............
.....................KKKBBBBBBRRRRK...........
...................KKBBBBBBBBBBBBRRRK.........
.................KKBBBKKKKKBBBBBBBBRRRK.......
...............KBBBKKKBBBBBBBBBBBBBBBRRK......
.............KBBBKKBBBBBBBBBBBBBBBBBBBBRRK....
...........KBBBKKBBBBKKKKKKKKKKKKKKKKKKKGRK...
..........KBBBKBBKKBBBBBBBBBBBBBBGGGGGGGCKRK..
........KBBBBKBKKKBBBBBBBBBBBBBBBGGGGGGGGKRK..
.......KBBBBKBBKKBBBBBBBBBBBBBBBGGGRRGGGGKRK..
......KBBBBKBBBKKBBBBBBBBBBBBBBBGGGRRGGGGKRK..
.....KBBKBBKBBBKKBBBBBBBBBBBBBBGGGGGGGGGGKRK..
....KBBKBBKBBBBKKBBBBBBBBBBBBBBGGGGGGGGGGKRK..
...KBBKBBBKBBBBKKBBBBBBBBBBBBBBGGGGGGGGGGKRK..
...KBBKBBBKBBBBKKGGGGGGBBBBBBBGGGGGGGGGGCKRK..
..KBBKBBBKBBBBBKBBBBBBBGGGGGGGGGGGGGGGGGCKRK..
.KBBBKBBBKBBBKKKKKKKKKKBBBBBBCCCCCCGGGGGCCRK..
.KBBBKBBBKBBBKKKKKKKKKKKKKKKKBBBBBBCCCCGGCRK..
.KBBBKBBBKBBBKKKKKBBBBBBBBBBBKKKKKKBBBBBBGCRK.
.KBBBKBBBKBBBKKKKKBBBBBBKKKBBKKGGGGKKKBBBBGCRK
.KBBBKBBBKBBBKKKKKBBBBBKKKKKBKBGGGGGGKBBBBGCRK
.KBBBKBBBKBBBKKKKKBBBBBKKKKKBKBGGGGGGCKBBBGCRK
.KBBBKBBBKBBBKKKKKBBBBBKKKKKBKBGGGGGGCKKBBGCRK
.KBBBKBBBKBBBKKKKKBBBBBBKKKBKKBGGGGGGCKKKBGRK.
.KBBBKBBBBBBBKKKKKBBBBBGGGGGKKBGGGGGGCKKKBRK..
.KBBBKBBBBBBBKKKKBBBBBBBBBBKKKBGGGGGGCKKRK....
.KBBBKBBBBBBBKKKKBBGGGBBBBKKKKBGGGGGGCKBRK....
.KBBBKBBBBBBBKKKKBBBBBBBBKKKKKBGGGGGGCKBRK....
.KBBBKBBBBBBBKKKKBBBBBBBBKKKKKBGGGGGGCKBRK....
.KBBBKBBBBBBBKKKKBBBBBBBBBBBBBGGGGGGGCKBRK....
.KBBBKBBBBBBBKKKKBBBBBBBBKKKKBGGGGGGGCKBRK....
.KBBBKBBBBBBBKKKKBBBBBBBKBBBBKGGGGGGGCKBRK....
.KBBBKBBBBBBBKKKKBBBBBKBBBBBBBGGGGGCCCKBRK....
.KBBBKBBBBBBBKKKKBBBBBKBBBBBBBBGGGGCCCKBRK....
.KBBBKBBBBBBBKKKKBBBKKKKKKKKBBBBBBBCCCKBRK....
.KBBKBBBBBBBBKKKKBBBKKKKKKKKKKKKKKKBBBKBRK....
.KBBKBBBBBBBBKKKKBBBKKKKKKKKKKKKKKKKKKBRK.....
.KBBKBBBBBBBBKKKKBBBKKKBBGGGKKKKKKKKKKBRK.....
.KBBKBBBBBBBBKKKKBBBKKBBBBBBGGGGGGGCCRK.......
.KBBKBBBBBBBBKKKKBBBKBKKKKKKBBBBBBBBCRK.......
.KBBKBBBBBBBBKKKKBBBKBKKKKKKKKKKKKKBRK........
.KBBKBBBBBBBBKKKKBBBKBBGGGGGKKKKKKKBRK........
.KBBKBBBBBBBBKKKKBBBKKBBBBBBGGGGGGCCRK........
.KBBKBBBBBBBBKKKKBBBKKBBBBBBBBBBBBGCRK........
.KBBKBBBBBBBBKKKKBBBKKBBBBBBBBBBBBGRK.........
.KKKKBKKKKBKKKKKKKBBBKKKKKKKBBBBBBGRK.........
..KKKKBKKKBKKKKKKKKBBBBBBBBBKKKKKKKK..........
..KKKKBKKKKBGGGCKKKBBBBBBBBBBBBBBGRK..........
...KKKKBKKBGGGGCKKKKBBBBBBBBBBBBBGRK..........
....KKKKBKBBGGGGRKKKBBBBBBBBBBBBGRK...........
.....KKKKKKBBGGGRKKKKBBBBBBBBBBBGRK...........
......KKKKKKBBBRKKKKKKBBBBBBBBBGRK............
.......KKKKKKKKKKKBGKKKBBBBBBBBGRK............
.........KKKBGGRKKBGRKKKBBBBBBGRK.............
...........KBGGRKKKBGRKKKKKKKRK...............
............KBGGRKKBGRKKKKKBBBKK..............
............KBBGRKKKBRKBBBBKKKK...............
............KBBGRKKKBRKKKKKKKK................
.............KBBGRKKKKK.......................
.............KBBRK............................
.............KBBRK............................
..............KBRK............................
..............KBRK............................
..............KKK.............................
"""
INK = {"K": K, "C": C, "R": R, "G": G, "B": B}


def draw_head(cv, dy):
    rows = [r for r in HEAD_SPRITE.strip("\n").split("\n")]
    for cy, row in enumerate(rows):
        for cx, ch in enumerate(row):
            if ch == ".":
                continue
            y, x = HEAD_Y + dy + 2 * cy, HEAD_X + 2 * cx
            cv[max(0, y):max(0, min(SHEET_Y, y + 2)), max(0, x):min(W, x + 2)] = INK[ch]


# --------------------------------------------------------------------- logo
def draw_logo(cv, t, env):
    word = "SONAZZOS"
    gap = 2
    total = len(word) * LW + (len(word) - 1) * gap
    x0 = (W - total) // 2
    y0 = SHEET_Y - LH - 9
    m = np.zeros((H, W), dtype=bool)
    for i, ch in enumerate(word):
        g = logo_glyph(ch)
        x = x0 + i * (LW + gap)
        m[y0:y0 + LH, x:x + LW] |= g
    ext = np.zeros_like(m)
    ext[2:, :] |= m[:-2, :]
    ext[1:, :] |= m[:-1, :]
    outline = dilate(m | ext, 1)
    cv[outline] = K
    cv[ext & ~m] = R
    cv[m] = C
    # carved nick: brown chisel line through each letter's top stroke
    cv[y0 + 1, :][m[y0 + 1, :] & (XX[0] % 13 == 5)] = G
    # caption above the logo


# -------------------------------------------------------------------- icons
ICON_PLAY = bm([
    "##.......", "####.....", "######...", "########.", "#########",
    "########.", "######...", "####.....", "##.......",
])
ICON_STORY = bm([  # a small carved mask in profile, facing right
    "..#####....", ".#######...", "#########..", "####...##..", "####.#.###.",
    "#########..", "#######.###", "#######....", "########...", ".#######...",
    "..#####....",
])
ICON_SONGS = bm([  # a bell with sound strokes
    "...#.......", "..###....#.", ".#####..#..", ".#####.....", ".#####..##.",
    ".#####.....", "#######.#..", "#######..#.", "...........", "...#.......",
    "...........",
])
ICON_LEARN = bm([
    ".#######.", "#.......#", "#..###..#", "#.#...#.#", "#....#..#",
    "#...#...#", "#.......#", "#...#...#", ".#######.",
])
ICON_RANKS = bm([
    "...###...", "...#.#...", "...###...", "...###...", "###.#.###",
    "#.#####.#", "#########", "#########", "#########",
])
ICON_GEAR = bm([
    "....###....", ".##.###.##.", ".#########.", "..##...##..", "###.....###",
    "###..#..###", "###.....###", "..##...##..", ".#########.", ".##.###.##.",
    "....###....",
])


# ------------------------------------------------------------------- sheet
def block(cv, x, y, w, h, fill, pressed=False, shadow=3):
    """Hard-shadow block: 1 px black outline, shadow straight down."""
    if not pressed:
        cv[y + shadow:y + h + shadow, x:x + w] = K
        oy = y
    else:
        oy = y + shadow
    cv[oy:oy + h, x:x + w] = K
    cv[oy + 1:oy + h - 1, x + 1:x + w - 1] = fill
    return oy


def draw_sheet(cv, pressed=None):
    cv[SHEET_Y:, :] = C
    # torn top edge of the sheet: a carved wolf-tooth lip of black
    for x in range(W):
        cv[SHEET_Y, x] = K
    # CONTINUE
    x, y, w, h = 8, SHEET_Y + 9, 119, 47
    oy = block(cv, x, y, w, h, R, pressed == "continue")
    draw_text(cv, "CONTINUE", x + 7, oy + 6, C, F5)
    draw_text(cv, "STOP 4", x + 7, oy + 17, C, F5, scale=2)
    draw_text(cv, "CARNIVAL SUNDAY", x + 7, oy + 35, C, F5)
    stamp(cv, ICON_PLAY, x + w - 17, oy + (h - 9) // 2, C)
    # STORY / SONGS
    y2 = y + h + 9
    bw, bh = 57, 27
    for i, (label, icon) in enumerate([("STORY", ICON_STORY), ("SONGS", ICON_SONGS)]):
        bx = 8 + i * (bw + 5)
        oy2 = block(cv, bx, y2, bw, bh, G, pressed == label.lower())
        stamp(cv, icon, bx + 6, oy2 + (bh - 11) // 2, K)
        draw_text(cv, label, bx + 21, oy2 + (bh - 7) // 2, K, F5)
    # small row: LEARN, RANKS, gear in the corner
    y3 = y2 + bh + 12
    stamp(cv, ICON_LEARN, 9, y3, K)
    draw_text(cv, "LEARN", 21, y3 + 1, K, F5)
    stamp(cv, ICON_RANKS, 60, y3, K)
    draw_text(cv, "RANKS", 72, y3 + 1, K, F5)
    stamp(cv, ICON_GEAR, W - 8 - 11, y3 - 1, K)
    # thin rule above the small row
    cv[y3 - 6, 8:W - 8] = np.where((np.arange(8, W - 8) % 2) == 0, B, C)


# ------------------------------------------------------------------- frames
def render(t, pressed=None):
    cv = np.zeros((H, W), dtype=np.uint8)
    env = beat_env(t)
    draw_glow(cv, t, env)
    draw_fire(cv, t, env)
    draw_far_figures(cv, t, env)
    draw_ground(cv, t, env)
    draw_embers(cv, t, env)
    draw_mamuthone(cv, t, env)
    if LOWRES:
        cv[:SHEET_Y] = chunky(cv[:SHEET_Y])
    draw_head(cv, int(round(2 * env)))
    draw_logo(cv, t, env)
    draw_sheet(cv, pressed)
    return cv


LOWRES = True


def chunky(a, k=2):
    """Redraw the picture on a grid twice as coarse: each 2x2 cell takes its most common ink."""
    h, w = a.shape
    hh, ww = h // k * k, w // k * k
    out = a.copy()
    blk = a[:hh, :ww].reshape(hh // k, k, ww // k, k).transpose(0, 2, 1, 3).reshape(hh // k, ww // k, k * k)
    wgt = [1.0, 2.1, 1.6, 2.1, 1.2]        # K C R G B: thin light lines survive, lone specks drop out
    cnt = np.stack([(blk == i).sum(-1) * wgt[i] for i in range(5)], -1)
    mode = cnt.argmax(-1).astype(np.uint8)
    out[:hh, :ww] = np.repeat(np.repeat(mode, k, 0), k, 1)
    return out


def to_image(cv):
    pal = np.array(PAL, dtype=np.uint8)
    rgb = pal[cv]
    im = Image.fromarray(rgb, "RGB")
    return im.resize((W * SCALE, H * SCALE), Image.NEAREST)


def main(out):
    os.makedirs(out, exist_ok=True)
    rest = 0.3  # between beats: everything at rest
    to_image(render(rest)).save(os.path.join(out, "main_screen.png"))
    to_image(render(rest, pressed="continue")).save(os.path.join(out, "main_screen_pressed.png"))
    to_image(render(0.0)).save(os.path.join(out, "main_screen_beat.png"))
    fdir = os.path.join(out, "frames")
    os.makedirs(fdir, exist_ok=True)
    n = int(LOOP * FPS)
    for i in range(n):
        to_image(render(i / FPS)).save(os.path.join(fdir, f"f{i:03d}.png"))
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS),
        "-i", os.path.join(fdir, "f%03d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-crf", "16", "-preset", "slow", "-tune", "animation", "-movflags", "+faststart",
        os.path.join(out, "main_screen.mp4")], check=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "out")
