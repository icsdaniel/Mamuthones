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
BAY2 = BAYER[(YY // 2) % 4, (XX // 2) % 4]   # dither on the 2x2 grid of the low-res picture


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
FIRE_CX, FIRE_BASE = 126, 152


def draw_glow(cv, t, env):
    d = np.hypot((XX - FIRE_CX) * 1.0, (YY - (FIRE_BASE - 34)) * 0.8)
    if LOWRES:  # r23: night sky like the play screen, only a faint brown haze round the fire
        cv[(YY < FIRE_BASE + 4) & (d < 70 * (1 + 0.06 * env)) & (BAY2 < 3)] = B
        return
    r = 1.0 + 0.06 * env
    bands = [(96, B, 3), (80, B, 6), (66, R, 4), (52, R, 8)]
    sky = YY < FIRE_BASE + 4
    for rad, ink, lvl in bands:
        m = sky & (d < rad * r)
        sel = BAY2 < lvl
        cv[m & sel] = ink
        cv[m & ~sel] = K


def draw_fire(cv, t, env):
    ph = 2 * math.pi * t / LOOP
    lift = 1.0 + 0.16 * env
    tongues = [(106, 5, 44, 0.0), (115, 8, 70, 1.3), (125, 10, 92, 2.1),
               (134, 8, 66, 0.7)]
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
        ch = h * 0.55
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


def _lo_put(cv, hm, ink):
    """Write a half-res mask into the canvas as 2x2 blocks."""
    up = np.repeat(np.repeat(hm, 2, 0), 2, 1)[:H, :W]
    up[SHEET_Y:] = False
    cv[up] = ink


def draw_fire_lo(cv, t, env):
    """r23: the play screen's lino flames - separate tongues, outer first, each with a
    black outline, flat red with a cream heart, outer ones lagging the beat."""
    hy, hx = np.mgrid[0:H // 2, 0:W // 2 + 1]
    cx, by = FIRE_CX / 2, FIRE_BASE / 2
    h0 = 44.0
    n = 5
    for i in sorted(range(n), key=lambda i: -abs(i - (n - 1) / 2)):
        off = (i - (n - 1) / 2) / ((n - 1) / 2)
        p = beat_env(t - 0.033 * abs(off))
        ph = 2 * math.pi * 2 * t / LOOP + i * 2.3
        hh = h0 * (1 - 0.32 * abs(off) ** 1.5) * (1 + 0.16 * p) * (1 + 0.06 * math.sin(ph * 1.3 + i))
        w = 5.0 * (1.15 if abs(off) < 0.4 else 1.0) * (1 - 0.1 * p)
        x0 = cx + off * 9
        v = (by - hy) / hh
        c = x0 + 0.8 * np.sin(v * 4.2 - ph) * v * w * 0.7
        half = w * np.clip(1 - v, 0, 1) ** 0.85 * np.clip((v + 0.06) * 3.5, 0, 1)
        m = (v >= 0) & (v <= 1) & (np.abs(hx - c) <= half)
        _lo_put(cv, dilate_h(m) & ~m, K)
        _lo_put(cv, m, R)
        _lo_put(cv, m & (np.abs(hx - c) <= half * 0.4) & (v < 0.5), C)
    # crossed logs at the foot, cream with black edges like the play screen's pile
    lg = np.zeros(hy.shape, dtype=bool)
    for (xa, ya, xb, yb) in [(cx - 9, by - 1, cx + 7, by - 5), (cx - 6, by - 5, cx + 9, by - 1)]:
        for k in range(40):
            u = k / 39
            lg[int(round(ya + (yb - ya) * u)), min(lg.shape[1] - 1, int(round(xa + (xb - xa) * u)))] = True
    _lo_put(cv, dilate_h(lg) & ~lg, K)
    _lo_put(cv, lg, G)


def dilate_h(m):
    n = m.copy()
    n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]
    return n


def draw_embers_lo(cv, t, env):
    """Sparks on the 2x2 grid, rising from the fire."""
    rng = np.random.default_rng(11)
    hm_c = np.zeros((H // 2, W // 2 + 1), dtype=bool)
    hm_r = hm_c.copy()
    for i in range(16):
        x0 = rng.uniform(52, 67)
        off = rng.uniform(0, 1)
        sp = rng.choice([1, 2])
        amp = rng.uniform(1, 3)
        u = (t / LOOP * sp + off) % 1.0
        y = FIRE_BASE / 2 - 24 - u * 56
        x = x0 - u * 10 + amp * math.sin(2 * math.pi * (u * 2 + off))
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < hm_c.shape[1] and 0 <= yi < SHEET_Y // 2:
            (hm_c if (i % 3 == 0 and u < 0.5) else hm_r)[yi, xi] = True
    _lo_put(cv, hm_r, R)
    _lo_put(cv, hm_c, C)


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
# Close portrait.  The head (hood, visera, knot) is a hand-drawn pixel map at full
# art resolution, traced from the photo (mamuthone_reference.jpg) downscaled by
# 0.185 with photo (664, 39) at canvas (0, 0).  '.' is transparent.
INK = {"K": K, "C": C, "R": R, "G": G, "B": B}
HEAD_GRID = None  # filled at the end of the file


def head_layer():
    rows = [r for r in HEAD_GRID.strip("\n").split("\n")]
    h, w = len(rows), max(len(r) for r in rows)
    lay = np.full((h, w), 255, dtype=np.uint8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in INK:
                lay[y, x] = INK[ch]
    return lay


FLEECE = [(0, 116), (20, 122), (36, 130), (58, 134), (84, 132), (96, 128), (108, 128),
          (120, 134), (130, 146), (W, SHEET_Y), (0, SHEET_Y)]


def draw_fleece(cv, dy):
    """Long dark goat-hair locks; the ones toward the fire catch red."""
    m = poly(FLEECE, 0, dy) & (YY < SHEET_Y)
    rng = np.random.default_rng(7)
    top = edge_up(m)
    ys, xs = np.nonzero(top)
    for y, x in zip(ys, xs):
        if x % 4 < 2:
            ln = 2 + (x * 7) % 4
            m[max(0, y - ln):y, x] = True
    cv[m] = K
    ytop = np.full(W, H)
    for x in range(W):
        col = np.nonzero(m[:, x])[0]
        if len(col):
            ytop[x] = col[0]
    for row in range(3):
        for x0 in range(0, W, 6):
            x = x0 + row * 3 + int(rng.integers(-1, 2))
            if not (0 <= x < W) or ytop[x] >= SHEET_Y:
                continue
            y = ytop[x] + 1 + row * 12 + int(rng.integers(0, 4))
            ln = int(rng.integers(12, 22))
            lit = x > 92
            ink = R if lit else B
            for k in range(ln):
                yy = y + k
                xx = x + int(round(k * (0.3 if x > 60 else -0.15) + 1.5 * math.sin(k * 0.22 + x)))
                if 0 <= xx < W - 1 and yy < SHEET_Y and m[yy, xx]:
                    cv[yy, xx:xx + 2] = ink if k < ln - 3 else B
    cv[edge_right(m) & (XX > 90)] = R
    return m


def draw_body(cv, t, env):
    """Everything of the figure that stays low-res: fleece and a bell."""
    dy = int(round(2 * env))
    draw_fleece(cv, dy)
    # a sonazzu hanging on the fleece in front of the fire, swinging against the landing;
    # a black outline keeps it apart from the flames
    tmp = np.full((H, W), 255, dtype=np.uint8)
    a = math.radians(98 + 10 * env)
    draw_bell(tmp, 108, 128 + dy, a, 17, 4, 9, light=1, tongue=-3 * env)
    tmp[124 + dy:129 + dy, 108] = B
    ok = tmp != 255
    cv[dilate(ok, 1) & ~ok] = K
    cv[ok] = tmp[ok]


def draw_head(cv, t, env):
    dy = int(round(2 * env))
    dy -= dy % 2          # the head is drawn on the same 2 px grid as the rest, so it bobs a whole cell
    lay = head_layer()
    h, w = lay.shape
    full = np.full((H, W), 255, dtype=np.uint8)
    hh = min(h, H - dy)
    full[dy:dy + hh, :w] = lay[:hh]
    full[SHEET_Y:] = 255
    solid = full != 255
    # a black gap between the head and the glow, so the rim reads against the fire
    halo = dilate(solid, 2) & ~solid & (XX > 70) & (YY < SHEET_Y)
    cv[halo] = K
    cv[solid] = full[solid]


# big sonazzos tied on his back, drawn behind the silhouette so only their mouths and
# upper bodies show past his shoulder, against the fire; drawn straight on the
# 2 px grid (half-size coordinates, then doubled) so they match the low-res picture
BACK_BELLS = [(108, 170, -62, 36, 9, 18, -4), (120, 176, -44, 32, 8, 16, -6), (96, 164, -76, 40, 9, 18, -3), (12, 158, -118, 36, 9, 18, 4)]  # r20: two past the right shoulder, one nearer the face, one peeking on the left


def draw_back_bells(cv, t, env):
    dy = int(round(2 * env))
    dy -= dy % 2
    tmp = np.full((H, W), 255, dtype=np.uint8)
    for bx, by, deg, L, w0, w1, swing in BACK_BELLS:
        a = math.radians(deg + swing * env)          # they swing back on the landing
        draw_bell(tmp, bx / 2, (by + dy) / 2, a, L / 2, w0 / 2, w1 / 2, light=1, tongue=None)
    half = tmp[:H // 2, :W // 2 + 1]
    lay = np.repeat(np.repeat(half, 2, 0), 2, 1)[:H, :W]
    full = np.full((H, W), 255, dtype=np.uint8)
    full[:lay.shape[0], :lay.shape[1]] = lay
    full[SHEET_Y:] = 255
    ok = full != 255
    cv[dilate(ok, 2) & ~ok & (YY < SHEET_Y)] = K
    cv[ok] = full[ok]


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


# ------------------------------------------------- low-res logo and sheet (r21)
# Drawn on a half-size canvas, then doubled, so every pixel is a 2x2 block like the play screen.
LOGO_LO = {
    "S": [".#####", "######", "##....", "#####.", ".#####", "....##", "######", "#####."],
    "O": [".####.", "######", "##..##", "##..##", "##..##", "##..##", "######", ".####."],
    "N": ["##..##", "##..##", "###.##", "######", "######", "##.###", "##..##", "##..##"],
    "A": [".####.", "######", "##..##", "##..##", "######", "######", "##..##", "##..##"],
    "Z": ["######", "######", "...###", "..###.", ".###..", "###...", "######", "######"],
}
ICON_PLAY_LO = bm(["#...", "##..", "###.", "####", "###.", "##..", "#..."])
ICON_LEARN_LO = bm([".##.", "#..#", "..#.", "....", "..#."])
ICON_RANKS_LO = bm(["..#..", "..#..", "#.#..", "#.#.#", "#####"])
ICON_GEAR_LO = bm(["#.#.#", ".###.", "##.##", ".###.", "#.#.#"])


def draw_logo_lo(hv):
    hw = hv.shape[1]
    word = "SONAZZOS"
    gw, gh, gap = 6, 8, 1
    total = len(word) * gw + (len(word) - 1) * gap
    x0 = (hw - 1 - total) // 2 + 1
    y0 = SHEET_Y // 2 - gh - 5
    m = np.zeros(hv.shape, dtype=bool)
    for i, ch in enumerate(word):
        g = np.array([[c == "#" for c in row] for row in LOGO_LO[ch]])
        x = x0 + i * (gw + gap)
        m[y0:y0 + gh, x:x + gw] |= g
    ext = np.zeros_like(m)
    ext[1:, :] |= m[:-1, :]
    outline = dilate(m | ext, 1)
    hv[outline] = K
    hv[ext & ~m] = R
    hv[m] = C


def draw_sheet_lo(hv, pressed=None):
    sy = SHEET_Y // 2
    hv[sy:, :] = C
    hv[sy, :] = K
    # CONTINUE
    x, y, w, h = 2, sy + 5, 64, 25
    oy = block(hv, x, y, w, h, R, pressed == "continue", shadow=2)
    draw_text(hv, "CONTINUE", x + 3, oy + 3, C, F3)
    draw_text(hv, "STOP 4", x + 3, oy + 9, C, F5)
    cx = draw_text(hv, "CARNIVAL", x + 3, oy + 18, C, F3)
    draw_text(hv, "SUNDAY", cx + 1, oy + 18, C, F3)
    stamp(hv, ICON_PLAY_LO, x + w - 9, oy + 9, C)
    # STORY / SONGS
    y2 = y + h + 5
    bw, bh = 30, 13
    for i, label in enumerate(["STORY", "SONGS"]):
        bx = 2 + i * (bw + 4)
        oy2 = block(hv, bx, y2, bw, bh, G, pressed == label.lower(), shadow=2)
        draw_text(hv, label, bx + (bw - text_width(label, F3)) // 2, oy2 + 4, K, F3)
    # small row
    y3 = y2 + bh + 7
    hv[y3 - 3, 2:66] = np.where((np.arange(2, 66) % 2) == 0, B, C)
    stamp(hv, ICON_LEARN_LO, 3, y3, K)
    draw_text(hv, "LEARN", 10, y3, K, F3)
    stamp(hv, ICON_GEAR_LO, 61, y3, K)


def draw_front_lo(cv, pressed=None):
    hv = np.full((H // 2, W // 2 + 1), 255, dtype=np.uint8)
    draw_logo_lo(hv)
    draw_sheet_lo(hv, pressed)
    up = np.repeat(np.repeat(hv, 2, 0), 2, 1)[:H, :W]
    ok = up != 255
    cv[ok] = up[ok]


# ------------------------------------------------------------------- frames
def render(t, pressed=None):
    cv = np.zeros((H, W), dtype=np.uint8)
    env = beat_env(t)
    draw_glow(cv, t, env)
    if LOWRES:
        draw_fire_lo(cv, t, env)
    else:
        draw_fire(cv, t, env)
    draw_far_figures(cv, t, env)
    draw_ground(cv, t, env)
    if not LOWRES:
        draw_embers(cv, t, env)
    draw_body(cv, t, env)
    if LOWRES:
        cv[:SHEET_Y] = chunky(cv[:SHEET_Y])
    if LOWRES:
        draw_embers_lo(cv, t, env)
    draw_back_bells(cv, t, env)
    draw_head(cv, t, env)
    if LOWRES:
        draw_front_lo(cv, pressed)
    else:
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
    if os.environ.get("QUICK"):
        return
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


HEAD_GRID = """
................................................................................................................
................................................................................................................
............................................................RRRRRRRRRRRRRRRR....................................
............................................................RRRRRRRRRRRRRRRR....................................
....................................................BBBBBBBBBBBBBBBBBBBBBBBBRRRRRR..............................
....................................................BBBBBBBBBBBBBBBBBBBBBBBBRRRRRR..............................
................................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRR..........................
................................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRR..........................
..........................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRR......................
..........................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRR......................
........................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRR....................
........................................BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRR....................
....................................BBBBBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBRR..................
....................................BBBBBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBRR..................
................................BBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBRR................
................................BBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBRR................
..............................KKBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKBBBBRR..............
..............................KKBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKBBBBRR..............
..........................BBBBKKBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBRR............
..........................BBBBKKBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBRR............
......................BBBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRRBBBBBBKKKKRR............
......................BBBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRRBBBBBBKKKKRR............
....................BBKKBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRRBBBBBBGGKKRR............
....................BBKKBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBRRRRBBBBBBGGKKRR............
................BBBBBBKKBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBGGGGGGGGGGBBBBBBKKKKBBBBBBGGBBKKRR..........
................BBBBBBKKBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBGGGGGGGGGGBBBBBBKKKKBBBBBBGGBBKKRR..........
............KKKKKKBBKKBBBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
............KKKKKKBBKKBBBBBBKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
..........KKKKKKBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
..........KKKKKKBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
........KKKKKKKKBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
........KKKKKKKKBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
......KKKKKKKKBBBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
......KKKKKKKKBBBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKRR..........
....KKKKKKKKKKBBBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKBBRR........
....KKKKKKKKKKBBBBBBKKBBBBKKBBBBBBBBBBBBKKKKBBBBGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKBBRR........
....KKKKKKKKKKBBBBBBKKBBBBKKBBBBBBKKBBBBKKGGGGGGGGBBBBBBBBGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKBBRR........
....KKKKKKKKKKBBBBBBKKBBBBKKBBBBBBKKBBBBKKGGGGGGGGBBBBBBBBGGGGGGGGGGGGBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKBBRR........
..KKKKKKKKKKBBBBBBKKBBBBBBKKBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGGGBBBBBBBBBBBBBBBBBBGGGGKKBBRR........
..KKKKKKKKKKBBBBBBKKBBBBBBKKBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBGGGGGGBBBBBBBBBBBBBBBBBBGGGGKKBBRR........
..KKKKKKKKKKBBBBBBKKBBBBBBKKBBBBBBKKBBBBKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBGGGGGGBBBBBBBBBBBBBBGGGGKKBBRR........
..KKKKKKKKKKBBBBBBKKBBBBBBKKBBBBBBKKBBBBKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBGGGGGGBBBBBBBBBBBBBBGGGGKKBBRR........
KKKKKKKKKKKKBBBBBBKKBBBBBBKKBBBBBBKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBBBGGGGBBBBBBBBBBBBGGGGKKRR..........
KKKKKKKKKKKKBBBBBBKKBBBBBBKKBBBBBBKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBBBGGGGBBBBBBBBBBBBGGGGKKRR..........
KKKKKKKKKKKKBBBBBBKKBBBBBBKKBBBBKKKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBGGGGGGBBBBBBBBKKGGGGKKRR..........
KKKKKKKKKKKKBBBBBBKKBBBBBBKKBBBBKKKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBGGGGGGBBBBBBBBKKGGGGKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBKKBBBBKKBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKGGGGBBBBBBGGGGGGGGGGGGGGKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBKKBBBBKKBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKGGGGBBBBBBGGGGGGGGGGGGGGKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBKKBBBBKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKGGBBBBBBBBBBBBBBGGKKBBBBBBGGRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBKKBBBBKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKGGBBBBBBBBBBBBBBGGKKBBBBBBGGRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBKKBBBBBBBBCCRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBKKBBBBBBBBCCRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKGGRR......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKGGRR......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKGG......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKGG......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKRR....
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKRR....
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKGGGGBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKRR......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKGGGGBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKRR......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBGGGGGGGGGGGGGGKKBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKRR......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKBBBBBBBBBBBBBBGGGGGGGGGGGGGGKKBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKRR......
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKKKBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKKKBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKGGKKKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKGGKKKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKGGGGKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKGGGGKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKBBGGGGGGGGBBBBBBBBBBBBBBGGGGKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKBBGGGGGGGGBBBBBBBBBBBBBBGGGGKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKGGKKKKKKKKBBBBBBBBBBBBBBGGGGKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBKKKKGGKKKKKKKKBBBBBBBBBBBBBBGGGGKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKKKBBBBBBKKKKBBBBBBBBBBBBGGGGKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKKKBBBBBBKKKKBBBBBBBBBBBBGGGGKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBKKBBBBBBBBBBBBGGGGKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBKKBBBBBBBBBBBBGGGGKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBGGCCKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBGGCCKKKKBBRR........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBGGCCKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBGGCCKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKKKRR..........
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBGGGGKKKKRR..........
KKKKKKKKKKBBBBBBBBBBBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBBBBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBBBBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBBBBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKRR..........
KKKKKKKKKKBBBBBBBBBBBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBRR..........
KKKKKKKKKKBBBBBBBBBBBBBBBBBBBBKKBBBBKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBRR..........
KKKKKKKKKKBBBBBBKKBBBBBBBBBBBBKKKKBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKKBBRR..........
KKKKKKKKKKBBBBBBKKBBBBBBBBBBBBKKKKBBBBKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKKBBRR..........
KKKKKKKKKKBBBBBBKKBBBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKRR............
KKKKKKKKKKBBBBBBKKBBBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBKKRR............
KKKKKKKKKKBBBBBBKKBBBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBBBBBKKBBRR............
KKKKKKKKKKBBBBBBKKBBBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBBBBBKKBBRR............
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBKKBBRR............
KKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBKKBBRR............
KKKKKKKKKKKKBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBKKBBRR..............
KKKKKKKKKKKKBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBKKBBRR..............
KKKKKKKKKKKKBBBBBBKKBBBBBBBBBBBBBBKKBBKKKKKKKKBBBBBBBBBBBBGGGGGGKKKKKKKKKKKKKKKKKKKKKKBBCCBBKKBBRR..............
KKKKKKKKKKKKBBBBBBKKBBBBBBBBBBBBBBKKBBKKKKKKKKBBBBBBBBBBBBGGGGGGKKKKKKKKKKKKKKKKKKKKKKBBCCBBKKBBRR..............
KKKKKKKKKKKKBBBBBBKKKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBBBBBBBGGGGGGGGGGGGGGGGGGGGGGGGCCCCCCBBBBRR..............
KKKKKKKKKKKKBBBBBBKKKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBBBBBBBBBGGGGGGGGGGGGGGGGGGGGGGGGCCCCCCBBBBRR..............
KKKKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKKBBRR................
KKKKKKKKKKKKBBBBBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBKKBBRR................
KKKKKKKKKKKKKKKKBBBBBBKKBBBBBBBBBBKKKKBBKKKKKKBBBBBBBBKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBKKBBBBRR................
KKKKKKKKKKKKKKKKBBBBBBKKBBBBBBBBBBKKKKBBKKKKKKBBBBBBBBKKKKKKKKBBBBBBBBBBBBBBBBBBBBBBBBBBKKBBBBRR................
KKKKKKKKKKKKKKBBKKBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBRR..................
KKKKKKKKKKKKKKBBKKBBBBKKBBBBBBBBBBBBKKBBBBKKKKKKBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBRR..................
KKKKKKKKKKKKKKBBBBKKKKBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBRR..................
KKKKKKKKKKKKKKBBBBKKKKBBKKBBBBBBBBBBBBBBBBKKKKKKBBBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBRR..................
KKKKKKKKKKKKKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBKKKKBBBBRR..................
KKKKKKKKKKKKKKBBBBBBKKKKBBBBBBBBBBBBBBBBBBBBKKKKKKBBBBKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBKKKKBBBBRR..................
KKKKKKKKKKKKKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKBBKKKKKKBBBBBBBBBBGGGGGGGGKKBBKKBBBBRR....................
KKKKKKKKKKKKKKBBBBBBBBBBKKKKBBBBBBBBBBBBBBBBKKKKKKKKKKBBKKKKKKBBBBBBBBBBGGGGGGGGKKBBKKBBBBRR....................
KKKKKKKKKKKKKKKKBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBGGBBBBKKBBBBRR....................
KKKKKKKKKKKKKKKKBBBBBBBBBBKKKKKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBGGBBBBKKBBBBRR....................
..............KKBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBGGKKBBBBBBRR....................
..............KKBBBBBBBBBBBBBBKKKKKKBBBBBBBBBBBBKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBBBGGKKBBBBBBRR....................
......................BBBBBBBBBBBBKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKBBBBRR......................
......................BBBBBBBBBBBBKKBBBBBBBBBBBBBBKKKKKKKKKKKKKKBBBBBBBBBBBBBBBBKKKKBBBBRR......................
..............................BBBBBBBBBBKKKKKKBBKKKKKKKKKKKKKKKKKKBBBBBBBBBBBBKKKKBBBBBBRR......................
..............................BBBBBBBBBBKKKKKKBBKKKKKKKKKKKKKKKKKKBBBBBBBBBBBBKKKKBBBBBBRR......................
....................................BBKKBBGGKKKKBBBBGGKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBRR......................
....................................BBKKBBGGKKKKBBBBGGKKKKKKKKKKKKKKKKKKKKKKKKKKKKBBBBBBRR......................
....................................KKBBBBBBKKBBKKBBGGGGKKBBKKKKKKKKKKKKKKKKKKKKBBBBBBRR........................
....................................KKBBBBBBKKBBKKBBGGGGKKBBKKKKKKKKKKKKKKKKKKKKBBBBBBRR........................
......................................KKBBKKBBKKBBBBBBGGKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBRR........................
......................................KKBBKKBBKKBBBBBBGGKKBBBBBBBBBBBBBBBBBBBBBBBBBBBBRR........................
........................................KKKKBBKKKKBBBBGGKKKKKKKKKKKKKKKKKKKKKKKKKKBBBB..........................
........................................KKKKBBKKKKBBBBGGKKKKKKKKKKKKKKKKKKKKKKKKKKBBBB..........................
............................................KKBBKKBBBBBBKKBBBBBBBBBBBBBBBBBBBBBBRR..............................
............................................KKBBKKBBBBBBKKBBBBBBBBBBBBBBBBBBBBBBRR..............................
..........................................KKKKBBKKBBBBKKKK..BBBBBBBBBBBBBBBBBB..................................
..........................................KKKKBBKKBBBBKKKK..BBBBBBBBBBBBBBBBBB..................................
..........................................KKBBGGKKKKKKGGKK......................................................
..........................................KKBBGGKKKKKKGGKK......................................................
..........................................KKBBGGKKKKBBGGKK......................................................
..........................................KKBBGGKKKKBBGGKK......................................................
..........................................KKBBGGKKKKBBBBGG......................................................
..........................................KKBBGGKKKKBBBBGG......................................................
........................................KKBBBBGG....KKBBGGKK....................................................
........................................KKBBBBGG....KKBBGGKK....................................................
........................................KKBBBBGG....KKBBGGKK....................................................
........................................KKBBBBGG....KKBBGGKK....................................................
........................................KKBBGGKK....KKBBGGKK....................................................
........................................KKBBGGKK....KKBBGGKK....................................................
........................................KKKKGGKK....KKKKGGKK....................................................
........................................KKKKGGKK....KKKKGGKK....................................................
"""

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "out")
