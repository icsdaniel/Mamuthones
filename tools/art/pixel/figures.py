"""The two characters of the game in pixel art, drawn at their true size, in every pose the game needs.

    mamuthone(pose, fleece="black", size="field")  -> Canvas, feet at (FEET_X, FEET_Y) of the cell
    issohadore(pose, size="field")                 -> Canvas

Poses: Mamuthone "stand", "crouch" (anticipation before the jump), "air" (legs tucked, bells
lifted), "land" (squashed, bells swung low). Issohadore "stand", "throw" (rope up and out).
They face the viewer's right, lit by the fire from the right (the left file of the play screen);
the right file uses them mirrored, which keeps the fire on the road side.

size "field" is the play screen (Mamuthone ~62 px tall); "big" is the title scene (~100 px): the same
design drawn with more detail, so the two read as one character.
"""
import math

import numpy as np

from px import Canvas

CELL = {"field": (88, 84), "big": (140, 132)}
MAM_POSES = ("stand", "crouch", "air", "land")
ISS_POSES = ("stand", "throw")
FEET = {"field": (44, 80), "big": (70, 127)}


def _tufts(cv, mask, base, dark, light, seed, lit_mask=None, lit=None, dens=0.28, length=3):
    """Shaggy sheepskin: short hanging tufts. Base colour, darker grooves, lighter tips; firelit tips on
    the lit side. Tufts are 1-px wide vertical runs, placed on a jittered grid so they read as locks."""
    cv._put(mask, base)
    r = np.random.default_rng(seed)
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    for y in range(mask.shape[0]):
        for x in range(mask.shape[1]):
            if not mask[y, x]:
                continue
            # jittered 2x3 grid of locks
            if (x + (y // 3) % 2) % 2 == 0 and y % 3 == 0 and r.random() < dens * 2.6:
                col = light
                if lit_mask is not None and lit_mask[y, x]:
                    col = lit
                L = length + (1 if r.random() < 0.4 else 0)
                for k in range(L):
                    yy = y + k
                    if yy < mask.shape[0] and mask[yy, x]:
                        cv.pset(x, yy, col if k < L - 1 else base)
                if y + L < mask.shape[0] and mask[y + L, x]:
                    cv.pset(x, y + L, dark)


def _jag_bottom(pts_y, x0, x1, y, depth, seed, period=3):
    """A ragged hem: a polygon edge along y from x1 back to x0 with downward tufts."""
    r = np.random.default_rng(seed)
    out = []
    x = x1
    i = 0
    while x > x0:
        d = depth if i % 2 == 0 else 0
        d = d + (1 if (d and r.random() < 0.4) else 0)
        out.append((x, y + d))
        x -= period / 2.0
        i += 1
    out.append((x0, y))
    return out


def _bell(cv, cx, top, w, h, swing=0, big=False):
    """A cowbell hanging from (cx, top): bronze body, dark mouth, a highlight on the fire side."""
    # body: a trapezoid widening down, rounded crown
    pts = [(cx - w * 0.30 + swing * 0.3, top), (cx + w * 0.30 + swing * 0.3, top),
           (cx + w * 0.5 + swing, top + h), (cx - w * 0.5 + swing, top + h)]
    m = cv.m_poly(pts) | cv.m_ellipse(cx + swing * 0.3, top + 1, w * 0.32, 1.6)
    cv._put(m, "GOLD2")
    # light from the right: a lit band on the right third, a hot highlight near the top-right
    xx, yy = cv.grid()
    rel = (xx + 0.5 - (cx + swing * (yy - top) / max(h, 1))) / (w * 0.5)
    cv._put(m & (rel > 0.05), "GOLD3")
    cv._put(m & (rel > 0.45), "GOLD4")
    cv._put(m & (rel < -0.55), "GOLD1")
    if big or w >= 5:
        cv._put(m & (rel > 0.2) & (rel < 0.45) & (yy < top + h * 0.45), "GOLD5")
    # mouth
    cv.hline(int(round(cx - w * 0.5 + swing)), int(round(cx + w * 0.5 + swing)) - 1, int(top + h), "GOLD1")
    cv.pset(cx + swing, top + h + 1, "K0")   # clapper
    return m


# ---------------------------------------------------------------------------------------------------
# Shared stamps
# ---------------------------------------------------------------------------------------------------

def stamp(cv, rows, x, y, cmap, flip=False):
    """Draws an ASCII sprite with its top-left at (x, y): each char maps to a colour via cmap, '.' is
    transparent."""
    for j, row in enumerate(rows):
        if flip:
            row = row[::-1]
        for i, ch in enumerate(row):
            if ch == "." or ch == " ":
                continue
            cv.pset(x + i, y + j, cmap[ch])


BELL_PROFILES = {
    # body widths from the crown down; the mouth row follows at the last width
    "xs": [1, 3, 3],
    "s": [1, 3, 3, 3, 5],
    "m": [1, 3, 5, 5, 5, 7],
    "l": [3, 5, 5, 5, 5, 7, 9],
    "xl": [3, 5, 7, 7, 7, 7, 9, 11],
}


def bell(size, outline=True):
    """A cowbell sprite lit from the right: [Canvas, (hang_x, hang_y)] - the point it hangs from."""
    prof = BELL_PROFILES[size]
    wmax = prof[-1]
    cv = Canvas(wmax + 4, len(prof) + 4)
    cx = 2 + wmax // 2
    for j, w in enumerate(prof):
        y = 1 + j
        x0 = cx - w // 2
        for i in range(w):
            f = (i + 0.5) / w
            if w == 1:
                col = "GOLD2"
            elif f < 0.25:
                col = "GOLD1"
            elif f < 0.5:
                col = "GOLD2"
            elif f < 0.8:
                col = "GOLD3"
            elif f < 0.93:
                col = "GOLD4"
            else:
                col = "GOLD3"
            cv.pset(x0 + i, y, col)
        # a hot highlight on the shoulder of the bell
        if 1 <= j <= 2 and w >= 5:
            cv.pset(x0 + int(w * 0.7), y, "GOLD5")
    # the mouth: a dark rim with the clapper under it
    y = 1 + len(prof)
    w = prof[-1]
    for i in range(w):
        cv.pset(cx - w // 2 + i, y, "GOLD1" if i < w * 0.6 else "GOLD2")
    if w >= 5:
        cv.pset(cx, y, "GOLD0")
    if outline:
        cv.outline("K0")
    return cv, (cx, 0)


def put_bell(cv, size, x, y, lift=0):
    """Hangs a bell of `size` from (x, y) on cv (its outline included)."""
    b, (hx, hy) = bell(size)
    cv.blit(b, int(round(x)) - hx, int(round(y)) - hy + lift)


# the carved mask (visera) of the Mamuthone, turned a little to the right, lit from the right
MASK_FIELD = [
    "..12333..",
    ".1223334.",
    "122333344",
    "144444444",
    "100014004",
    "110024004",
    "122224334",
    "122214334",
    "122110334",
    "122223333",
    "120000033",
    ".10222303",
    "..12233..",
    "...123...",
]
MASK_BIG = [
    "....123333....",
    "..1223333334..",
    ".122233333344.",
    "12222333333444",
    "14444444444444",
    "11111114111114",
    "10000112410004",
    "10000112410004",
    "11001122411044",
    "12222222433334",
    "12222221433334",
    "12222221433334",
    "12222211143334",
    "12221110003334",
    "12222222233334",
    "12222222233333",
    "12000000000333",
    ".1022222222033",
    "..10222222303.",
    "...122223333..",
    "....1223333...",
    "......123.....",
]
MASK_CMAP = {"0": "K0", "1": "WOOD0", "2": "WOOD1", "3": "WOOD3", "4": "WOOD4"}


# ---------------------------------------------------------------------------------------------------
# Mamuthone
# ---------------------------------------------------------------------------------------------------

FLEECE_RAMPS = {
    "black": ["FLEECE0", "FLEECE1", "FLEECE2", "FLEECE3", "FLEECE4"],
    "dark_brown": ["FLEECE1", "FLEECE2", "FLEECE3", "FLEECE4", "FLEECE5"],
}


def _ragged(cv, mask, seed, hem_from):
    """Makes a silhouette shaggy: locks hang below the hem (rows below hem_from) and stick out at
    the sides, pointing down."""
    r = np.random.default_rng(seed)
    h, w = mask.shape
    out = mask.copy()
    # hem: every column's lowest pixel below hem_from grows a lock 0..3 px long, in 2-px clusters
    lengths = []
    L = 0
    for x in range(w):
        if x % 2 == 0:
            L = int(r.choice([0, 1, 2, 2, 3]))
        lengths.append(L)
    for x in range(w):
        col = np.nonzero(mask[:, x])[0]
        if len(col) == 0:
            continue
        yb = col.max()
        if yb < hem_from:
            continue
        for k in range(1, lengths[x] + 1):
            if yb + k < h:
                out[yb + k, x] = True
    # sides: short locks pointing down and out, every few rows
    for y in range(h - 2):
        row = np.nonzero(mask[y])[0]
        if len(row) == 0:
            continue
        for x_edge, d in ((row.min(), -1), (row.max(), 1)):
            if r.random() < 0.45 and y > 3:
                xx = x_edge + d
                if 0 <= xx < w:
                    out[y, xx] = True
                    out[min(h - 1, y + 1), xx] = True
                    if r.random() < 0.4 and 0 <= xx + d < w:
                        out[min(h - 1, y + 2), xx + d] = True
    return out


def _fleece(cv, mask, ramp, light, seed, step=3):
    """Fills mask with sheepskin: a base shade by the light, then staggered hanging locks (a lit top,
    a body one shade up, a dark tip under it) so the fleece reads as heavy clumped wool, not noise."""
    n = len(ramp)
    base = np.clip((light * 3.0).astype(int), 0, 2)          # 0..2
    for b in range(3):
        cv._put(mask & (base == b), ramp[b])
    r = np.random.default_rng(seed)
    h, w = mask.shape
    LOCK = [(1, 0, "H"), (0, 1, "H"), (1, 1, "M"), (1, 2, "M"), (2, 2, "M"), (1, 3, "D")]
    for row, y in enumerate(range(-2, h, 4)):
        off = (row % 2) * 2 + int(r.integers(0, 2))
        for x in range(off - 3, w, step + 1):
            jx = x + int(r.integers(0, 2))
            jy = y + int(r.integers(0, 2))
            cx_, cy_ = min(max(jx + 1, 0), w - 1), min(max(jy + 1, 0), h - 1)
            if not mask[cy_, cx_]:
                continue
            b = int(base[cy_, cx_])
            lv = float(light[cy_, cx_])
            cols = {"H": ramp[min(n - 1, b + (2 if lv > 0.62 else 1))], "M": ramp[min(n - 1, b + 1)], "D": ramp[max(0, b - 1)]}
            if lv < 0.2:
                cols["H"] = ramp[min(n - 1, b + 1)]
                cols["M"] = ramp[b]
            for (dx, dy, kind) in LOCK:
                px_, py_ = jx + dx, jy + dy
                if 0 <= px_ < w and 0 <= py_ < h and mask[py_, px_]:
                    cv.pset(px_, py_, cols[kind])


def mamuthone(pose="stand", fleece="black", size="field", seed=3):
    W, H = CELL[size]
    fx, fy = FEET[size]
    k = 1.0 if size == "field" else 1.6          # design units -> pixels
    big = size == "big"
    cv = Canvas(W, H)
    F = FLEECE_RAMPS.get(fleece, FLEECE_RAMPS["black"])
    xx, yy = cv.grid()

    drop = {"stand": 0, "crouch": 4, "air": -1, "land": 5}[pose]     # the fleece lowered by
    wide = {"stand": 0, "crouch": 1, "air": 0, "land": 2}[pose]       # widened by (each side)
    flare = {"stand": 0, "crouch": 0, "air": 3, "land": 2}[pose]      # the hem spread by
    bell_lift = {"stand": 0, "crouch": 1, "air": -3, "land": 3}[pose]   # back bells: + lower
    chest_lift = {"stand": 0, "crouch": 1, "air": -2, "land": 2}[pose]  # chest bells: + lower

    def X(u):
        return fx + u * k

    def Y(v):
        return fy - v * k

    # ---- legs and boots, under the fleece
    hem = 15 - drop * 0.6 + (2 if pose == "air" else 0)
    for side in (-1, 1):
        if pose == "air":
            # tucked: knees up under the fleece, boots drawn in
            ax = X(side * 5 + 1)
            cv.poly([(ax - 3 * k, Y(hem + 2)), (ax + 3 * k, Y(hem + 2)), (ax + 3 * k, Y(5)), (ax - 3 * k, Y(5))], "NAVY1")
            cv.poly([(ax - 3.5 * k, Y(6)), (ax + (4.5 if side > 0 else 3) * k, Y(6)), (ax + (4.5 if side > 0 else 3) * k, Y(2)), (ax - 3.5 * k, Y(2))], "K1")
            cv.hline(int(ax - 2 * k), int(ax + 3 * k), int(Y(3)), "WOOD1")
            continue
        bend = {"stand": 0, "crouch": 2, "land": 2}[pose]
        spread = 7 + wide + bend
        hip = (X(side * 5), Y(hem + 3))
        knee = (X(side * (spread - 1)), Y(9 - bend))
        ankle = (X(side * spread), Y(4))
        cv.poly([(hip[0] - 3.5 * k, hip[1]), (hip[0] + 3.5 * k, hip[1]), (knee[0] + 3.5 * k, knee[1]), (ankle[0] + 3 * k, ankle[1]),
                 (ankle[0] - 3 * k, ankle[1]), (knee[0] - 3.5 * k, knee[1])], "NAVY1")
        cv.line(knee[0] + 3 * k - 1, knee[1], ankle[0] + 3 * k - 1, ankle[1], "NAVY3" if side > 0 else "NAVY2")
        toe = 2 if side > 0 else 1
        cv.poly([(ankle[0] - 3.5 * k, Y(5)), (ankle[0] + 3.5 * k, Y(5)), (ankle[0] + (4 + toe) * k, Y(1.5)), (ankle[0] + (4 + toe) * k, Y(0) - 1),
                 (ankle[0] - 4 * k, Y(0) - 1)], "K1")
        cv.hline(int(ankle[0] - 3 * k), int(ankle[0] + (3 + toe) * k), int(Y(0)) - 1, "WOOD1")
        cv.hline(int(ankle[0]), int(ankle[0] + (3 + toe) * k), int(Y(2)), "WOOD2" if side > 0 else "WOOD1")

    # ---- the carriga: big bronze bells on the back, an arc over the far (left) shoulder
    bb = Canvas(W, H)
    arc = [(-10, 53), (-14.5, 48), (-17.5, 42), (-19, 35.5), (-19, 29), (-17.5, 22.5)]
    for i, (u, v) in enumerate(arc):
        bx = X(u - wide)
        by = Y(v - drop - bell_lift * (0.3 + 0.14 * i))
        r_ = (3.3 if i else 3.0) * k
        one = Canvas(W, H)
        one.shade_ellipse(bx, by, r_, r_ * 0.95, ["GOLD1", "GOLD2", "GOLD3", "GOLD4"], light=(0.75, -0.45))
        # the bell's mouth faces back and down: a dark crescent on the lower left
        one._put(one.m_ellipse(bx - r_ * 0.45, by + r_ * 0.4, r_ * 0.55, r_ * 0.45) & one.solid(), "GOLD0")
        one.pset(bx + r_ * 0.35, by - r_ * 0.45, "GOLD5")
        one.outline("K0")
        bb.blit(one, 0, 0)
    cv.blit(bb, 0, 0)

    # ---- the mastruca: one shaggy mass from the hood's crown to the hem, wider at the bottom
    top = 64 - drop
    sil = [(X(1), Y(top)), (X(5), Y(top - 1)), (X(8.5), Y(top - 5)), (X(11 + wide * 0.5), Y(top - 12)),
           (X(15 + wide), Y(top - 20)), (X(17 + wide), Y(top - 30)), (X(17 + wide + flare * 0.6), Y(hem + 6)),
           (X(16 + wide + flare), Y(hem)),
           (X(-16 - wide - flare), Y(hem)), (X(-17 - wide - flare * 0.6), Y(hem + 6)), (X(-17 - wide), Y(top - 30)),
           (X(-14 - wide), Y(top - 20)), (X(-10 - wide * 0.5), Y(top - 12)), (X(-7), Y(top - 5)), (X(-3), Y(top - 1))]
    mbody = cv.m_poly(sil)
    mbody = _ragged(cv, mbody, seed, int(Y(hem + 3)))
    # light: from the fire on the right, a little from above; the hood's top catches it too
    cxp = fx + 0.5
    halfw = (17 + wide) * k
    nx = np.clip((xx + 0.5 - cxp) / halfw, -1, 1)
    ny = np.clip((yy + 0.5 - Y(top)) / ((top - hem) * k), 0, 1)
    light = np.clip(0.38 + 0.42 * nx - 0.18 * ny, 0, 0.999)
    _fleece(cv, mbody, F, light, seed, step=3 if not big else 3)
    # a groove where each arm hangs inside the fleece
    for side in (-1, 1):
        gx = X(side * (11 + wide))
        cv.line(gx, Y(top - 22), gx + side * 2 * k, Y(hem + 8), F[0])
    # firelit rim on the right edge, a cold night rim on the left
    edge_r = mbody & ~np.roll(mbody, -1, axis=1)
    edge_l = mbody & ~np.roll(mbody, 1, axis=1)
    cv._put(edge_r, F[4] if fleece == "black" else "LEATHER3")
    cv._put(edge_r & ((yy // 3) % 3 == 1), "FIRE2")
    cv._put(edge_l & (yy % 2 == 0) & (yy < Y(hem + 4)), "NAVY2")

    # ---- fists poking out of the fleece at the hips
    for side in (-1, 1):
        hx = X(side * (15.5 + wide + flare * 0.3))
        hy = Y(hem + 7 - drop * 0.1 + (2 if pose == "air" else 0))
        cv.ellipse(hx, hy, 2.3 * k, 2.0 * k, "WOOD1")
        cv.pset(hx + side * 0.8 * k, hy - 0.6 * k, "WOOD3" if side > 0 else "WOOD2")
        if side > 0:
            cv.pset(hx + 1.2 * k, hy + 0.4 * k, "WOOD2")

    # ---- the hood's opening and the carved mask inside it
    mask_rows = MASK_BIG if big else MASK_FIELD
    mw, mh = len(mask_rows[0]), len(mask_rows)
    mx0 = int(round(X(1.5) - mw / 2 + 1))
    my0 = int(round(Y(top - 3)))
    # a dark ring of shadow round the mask, the hood's inside
    hole = cv.m_ellipse(mx0 + mw / 2, my0 + mh / 2 - 0.5, mw / 2 + 1.6, mh / 2 + 1.2)
    cv._put(hole & mbody, "K1")
    stamp(cv, mask_rows, mx0, my0, MASK_CMAP)

    # ---- chest harness: two straps from the shoulders meeting on the chest (a yoke), bells hanging
    # along them and a big one where they meet
    strap_w = max(1, int(round(1.4 * k)))
    lsh = (X(-10 - wide), Y(top - 13))
    rsh = (X(11 + wide), Y(top - 14))
    mid = (X(1.5), Y(top - 22))
    for (a_, col) in ((lsh, "LEATHER1"), (rsh, "LEATHER2")):
        cv.line(a_[0], a_[1], mid[0], mid[1], col, w=strap_w)
        cv.line(a_[0], a_[1] - 1, mid[0], mid[1] - 1, "LEATHER3" if col == "LEATHER2" else "LEATHER2")
    cv.rect(mid[0] - 1, mid[1] - 1, 3, 3, "GOLD2")
    cv.pset(mid[0] + 1, mid[1] - 1, "GOLD4")
    sz_s, sz_m, sz_l = ("m", "l", "xl") if big else ("s", "m", "l")
    cl = chest_lift * k

    def on(a_, t):
        return (a_[0] + (mid[0] - a_[0]) * t, a_[1] + (mid[1] - a_[1]) * t)
    for (pt, sz, lf) in ((on(lsh, 0.3), sz_s, 0.5), (on(rsh, 0.3), sz_s, 0.5), (on(lsh, 0.68), sz_m, 0.8), (on(rsh, 0.68), sz_m, 0.8), (mid, sz_l, 1.2)):
        put_bell(cv, sz, pt[0], pt[1] + 1, lift=int(round(cl * lf)))

    cv.outline("K0")
    return cv


# ---------------------------------------------------------------------------------------------------
# Issohadore
# ---------------------------------------------------------------------------------------------------

def issohadore(pose="stand", size="field", seed=7):
    W, H = CELL[size]
    fx, fy = FEET[size]
    k = 1.0 if size == "field" else 1.6
    # the Issohadore is taller and slimmer: design units are the same, figure ~70 tall
    cv = Canvas(W, H)
    xx, yy = cv.grid()

    def X(u):
        return fx + u * k

    def Y(v):
        return fy - v * k

    throw = pose == "throw"
    # ---- legs: white trousers into dark leather gaiters and boots
    for side in (-1, 1):
        hip = (X(side * 3), Y(34))
        knee = (X(side * 4.5), Y(17))
        ankle = (X(side * 5.5 + (1 if side > 0 else 0)), Y(3))
        tr = cv.m_poly([(hip[0] - 3.2 * k, hip[1]), (hip[0] + 3.2 * k, hip[1]), (knee[0] + 3.4 * k, knee[1]), (knee[0] - 3.4 * k, knee[1])])
        cv._put(tr, "BONE3")
        cv._put(tr & ((xx + 0.5) > knee[0] + 1.2 * k), "BONE4")
        cv._put(tr & ((xx + 0.5) < knee[0] - 2.0 * k), "BONE2")
        # folds
        cv.line(hip[0], hip[1] + 3 * k, knee[0] - 1, knee[1] - 2, "BONE2")
        # gaiter + boot
        g = cv.m_poly([(knee[0] - 3 * k, knee[1]), (knee[0] + 3 * k, knee[1]), (ankle[0] + 2.6 * k, ankle[1]), (ankle[0] - 2.6 * k, ankle[1])])
        cv._put(g, "K1")
        cv._put(g & ((xx + 0.5) > ankle[0] + 1.0 * k), "WOOD2")
        # gaiter buttons
        for j in range(3):
            cv.pset(knee[0] + 1.5 * k, knee[1] + (3 + j * 4) * k, "GOLD3")
        cv.poly([(ankle[0] - 3 * k, Y(4)), (ankle[0] + 3 * k, Y(4)), (ankle[0] + 5 * k, Y(1)), (ankle[0] + 5 * k, Y(0) - 1), (ankle[0] - 3 * k, Y(0) - 1)], "K1")
        cv.hline(int(ankle[0] - 2 * k), int(ankle[0] + 4 * k), int(Y(1)), "WOOD2")

    # ---- hip shawl (sciallitu): a dark red embroidered cloth tied at the hip, fringe below
    shawl = cv.m_poly([(X(-7), Y(38)), (X(7.5), Y(38)), (X(6), Y(30)), (X(1), Y(26)), (X(-6.5), Y(30))])
    cv._put(shawl, "RED1")
    cv._put(shawl & ((xx + yy) % 4 == 0), "RED2")
    cv._put(shawl & ((xx - yy) % 6 == 0), "GOLD2")
    cv._put(shawl & ((xx + 0.5) > X(4)), "RED2")
    for j in range(-6, 6, 2):
        cv.vline(int(X(j + 0.5)), int(Y(29.5 - abs(j) * 0.35)), int(Y(28 - abs(j) * 0.35)), "GOLD2")

    # ---- red jacket (gurpette) over a white shirt; bell bandolier across the chest
    jacket = [(X(-7.5), Y(38)), (X(-8), Y(52)), (X(-5), Y(56)), (X(5.5), Y(56)), (X(8.5), Y(52)), (X(8), Y(38))]
    jm = cv.m_poly(jacket)
    cv._put(jm, "RED3")
    cv._put(jm & ((xx + 0.5) < X(-4)), "RED2")
    cv._put(jm & ((xx + 0.5) < X(-6.5)), "RED1")
    cv._put(jm & ((xx + 0.5) > X(5.5)), "RED4")
    # white shirt front and belt
    sm = cv.m_poly([(X(-2), Y(56)), (X(2.5), Y(56)), (X(1.5), Y(40)), (X(-1.5), Y(40))])
    cv._put(sm, "BONE4")
    cv._put(sm & ((xx + 0.5) < X(-0.5)), "BONE3")
    cv.rect(X(-7.5), Y(39.5), 15.5 * k, 2 * k, "K1")
    cv.rect(X(-0.8), Y(39.5), 1.8 * k, 2 * k, "GOLD3")
    # jacket buttons
    for j in range(4):
        cv.pset(X(3.2), Y(53 - j * 3.5), "GOLD4")
    # bandolier: a leather strap from the right shoulder to the left hip with small bronze bells
    cv.line(X(6), Y(55), X(-6), Y(40), "LEATHER1", w=max(1, int(round(1.4 * k))))
    for j in range(5):
        t = (j + 0.5) / 5.0
        bx = X(6 - 12 * t)
        by = Y(55 - 15 * t) + 1
        cv.rect(bx - 0.8 * k, by, 2 * k, 2 * k, "GOLD3")
        cv.pset(bx + 0.4 * k, by, "GOLD5")

    # ---- arms
    # near (right) arm: holds the rope, raised when throwing
    if throw:
        sx, sy = X(7.5), Y(54)
        ex, ey = X(10.5), Y(64)
        hx, hy = X(11.5), Y(72)
    else:
        sx, sy = X(7.5), Y(54)
        ex, ey = X(10.5), Y(45)
        hx, hy = X(11), Y(37)
    cv.line(sx, sy, ex, ey, "RED3", w=max(2, int(round(3.2 * k))))
    cv.line(ex, ey, hx, hy, "RED3", w=max(2, int(round(3 * k))))
    cv.line(sx + 1, sy, ex + 1, ey, "RED4")
    # white cuff and the white-gloved... bare hand
    cv.rect(hx - 1.5 * k, hy - 1.2 * k, 3 * k, 2.4 * k, "BONE4")
    cv.ellipse(hx, hy + (-2 if throw else 2) * k, 1.8 * k, 1.8 * k, "SKIN1")
    # far (left) arm: hangs holding the rope's coils
    lx, ly = X(-9), Y(38)
    cv.line(X(-7.5), Y(54), X(-9.5), Y(46), "RED2", w=max(2, int(round(3.2 * k))))
    cv.line(X(-9.5), Y(46), lx, ly, "RED2", w=max(2, int(round(3 * k))))
    cv.ellipse(lx, ly + 1.5 * k, 1.7 * k, 1.7 * k, "SKIN0")
    # coils of rope in the left hand
    for j in range(3):
        cv.ellipse(lx - 0.5 * k, ly + (6 + j * 0.6) * k, (3.8 - j * 0.6) * k, (5 - j * 0.5) * k, "ROPE1")
        cv.ellipse(lx - 0.5 * k, ly + (6 + j * 0.6) * k, (2.8 - j * 0.6) * k, (4 - j * 0.5) * k, None)

    # ---- head: white mask (visera crara), black berritta cap folded, a kerchief tied under the chin
    hx0, hy0 = X(0.5), Y(62)
    # hair at the back of the neck
    cv.ellipse(hx0 - 1.5 * k, hy0 + 1 * k, 4.5 * k, 5 * k, "K1")
    # kerchief under the chin
    cv.poly([(hx0 - 4 * k, hy0 + 3 * k), (hx0 + 4.5 * k, hy0 + 3 * k), (hx0 + 1.5 * k, hy0 + 7.5 * k)], "RED2")
    # the white mask, 3/4 to the right
    face = cv.m_ellipse(hx0 + 0.8 * k, hy0, 4.2 * k, 5.4 * k)
    cv._put(face, "BONE3")
    cv._put(face & ((xx + 0.5) > hx0 + 1.2 * k), "BONE4")
    cv._put(face & ((xx + 0.5) < hx0 - 2.2 * k), "BONE2")
    # calm features: eye slits, nose, closed mouth
    cv.hline(int(hx0 - 1.6 * k), int(hx0 - 0.4 * k), int(hy0 - 0.8 * k), "K0")
    cv.hline(int(hx0 + 1.8 * k), int(hx0 + 3.0 * k), int(hy0 - 0.8 * k), "K0")
    cv.vline(int(hx0 + 1.2 * k), int(hy0 - 0.2 * k), int(hy0 + 1.6 * k), "BONE1")
    cv.hline(int(hx0 + 0.2 * k), int(hx0 + 2.2 * k), int(hy0 + 3 * k), "BONE1")
    # the berritta: a black stocking cap, crown on the head, the long end folded back and hanging behind
    cap = cv.m_poly([(hx0 - 4.8 * k, hy0 - 2.5 * k), (hx0 - 3.5 * k, hy0 - 6.5 * k), (hx0 + 1 * k, hy0 - 7.5 * k),
                     (hx0 + 5 * k, hy0 - 5.5 * k), (hx0 + 5.2 * k, hy0 - 3 * k)])
    cv._put(cap, "K1")
    cv._put(cap & ((xx + 0.5) > hx0 + 2.5 * k), "NAVY2")
    tail = cv.m_poly([(hx0 - 3.5 * k, hy0 - 6 * k), (hx0 - 1 * k, hy0 - 7 * k), (hx0 - 6.5 * k, hy0 + 1 * k), (hx0 - 8 * k, hy0 - 0.5 * k)])
    cv._put(tail, "K1")
    cv._put(tail & (((xx + yy) % 3) == 0), "NAVY1")

    # ---- the rope (soha) when throwing: an arc of hemp from the raised hand
    if throw:
        pts = [(hx, hy - 2 * k), (hx - 4 * k, hy - 9 * k), (hx - 13 * k, hy - 11 * k), (hx - 18 * k, hy - 5 * k),
               (hx - 13 * k, hy + 1 * k), (hx - 6 * k, hy - 3 * k)]
        cv.curve(pts, "ROPE1", w=max(1, int(round(k))))
    else:
        # the rope hangs from the right hand to the ground in a loose loop
        pts = [(hx, hy + 2 * k), (hx + 1 * k, hy + 12 * k), (hx - 1 * k, hy + 22 * k), (hx + 3 * k, hy + 30 * k)]
        cv.curve(pts, "ROPE1", w=max(1, int(round(k))))

    cv.outline("K0")
    return cv


if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fig_preview.png"
    from PIL import Image
    tiles = []
    for size in ("field", "big"):
        row = [mamuthone(p, size=size) for p in ("stand", "crouch", "air", "land")]
        row += [mamuthone("stand", fleece="dark_brown", size=size)]
        row += [issohadore("stand", size=size), issohadore("throw", size=size)]
        tiles.append(row)
    sc = 4
    W = max(sum(c.w for c in r) for r in tiles) * sc
    H = sum(max(c.h for c in r) for r in tiles) * sc
    im = Image.new("RGBA", (W, H), (60, 50, 70, 255))
    y = 0
    for r in tiles:
        x = 0
        for c in r:
            im.alpha_composite(c.image(sc), (x, y))
            x += c.w * sc
        y += max(c.h for c in r) * sc
    im.save(out)
    print("wrote", out)
