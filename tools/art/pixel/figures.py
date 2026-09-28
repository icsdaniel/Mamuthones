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
# Mamuthone
# ---------------------------------------------------------------------------------------------------

FLEECE_RAMPS = {
    "black": ["FLEECE0", "FLEECE1", "FLEECE2", "FLEECE3"],
    "dark_brown": ["FLEECE1", "FLEECE2", "FLEECE3", "FLEECE4"],
}


def mamuthone(pose="stand", fleece="black", size="field", seed=3):
    W, H = CELL[size]
    fx, fy = FEET[size]
    k = 1.0 if size == "field" else 1.6          # design units -> pixels
    cv = Canvas(W, H)
    F = FLEECE_RAMPS.get(fleece, FLEECE_RAMPS["black"])

    # pose parameters (in design units, before k)
    drop = {"stand": 0, "crouch": 4, "air": -1, "land": 5}[pose]      # body lowered by
    wide = {"stand": 0, "crouch": 1, "air": -1, "land": 2}[pose]      # body widened by (each side)
    leg = {"stand": 0, "crouch": 1, "air": 2, "land": 1}[pose]        # 0 straight .. bent/tucked
    bell_lift = {"stand": 0, "crouch": 1, "air": -3, "land": 3}[pose]   # back bells: + lower, - lifted
    swing = {"stand": 0, "crouch": -1, "air": 1, "land": 2}[pose]       # chest bells swing (px)

    def X(u):
        return fx + u * k

    def Y(v):
        return fy - v * k

    # ---- legs and boots (drawn first, the fleece hangs over them)
    leg_top = 18 - drop * 0.7
    for side in (-1, 1):
        if leg == 2:
            # tucked: knees forward and up, boots under the hem
            knee = (X(side * 5 + 3), Y(leg_top - 5))
            foot = (X(side * 4 + 1), Y(4))
            cv.poly([(X(side * 5 - 3), Y(leg_top)), (X(side * 5 + 4), Y(leg_top)), (knee[0] + 3 * k, knee[1]), (foot[0] + 3 * k, foot[1]),
                     (foot[0] - 3 * k, foot[1]), (knee[0] - 4 * k, knee[1] + 1)], "NAVY1")
            by = Y(4)
            cv.poly([(foot[0] - 3 * k, by - 1 * k), (foot[0] + 5 * k, by - 1 * k), (foot[0] + 5 * k, by + 3 * k), (foot[0] - 3 * k, by + 3 * k)], "K1")
            continue
        spread = 6 + (2 if leg == 1 else 0) + wide
        bend = 2 if leg == 1 else 0
        hip = (X(side * 5), Y(leg_top))
        knee = (X(side * (spread - 1) + bend), Y(9 - bend))
        ankle = (X(side * spread), Y(4))
        cv.poly([(hip[0] - 3.5 * k, hip[1]), (hip[0] + 3.5 * k, hip[1]), (knee[0] + 3.5 * k, knee[1]), (ankle[0] + 3 * k, ankle[1]),
                 (ankle[0] - 3 * k, ankle[1]), (knee[0] - 3.5 * k, knee[1])], "NAVY1")
        # lit edge of the trousers (fire on the right)
        cv.line(knee[0] + 3 * k - 1, knee[1], ankle[0] + 3 * k - 1, ankle[1], "NAVY3" if side > 0 else "NAVY2")
        # boot: dark leather, toe pointing a little outward/right
        toe = 2 if side > 0 else 0
        cv.poly([(ankle[0] - 3.5 * k, Y(5)), (ankle[0] + 3.5 * k, Y(5)), (ankle[0] + (4 + toe) * k, Y(1)), (ankle[0] + (4 + toe) * k, Y(0) - 1),
                 (ankle[0] - 3.5 * k, Y(0) - 1)], "K1")
        cv.hline(int(ankle[0] - 2 * k), int(ankle[0] + (3 + toe) * k), int(Y(1)), "WOOD1")
        cv.pset(ankle[0] + (3 + toe) * k - 1, Y(2), "WOOD2")

    # ---- the back bells (carriga): a row of big bronze bells arching over the back, far side (left)
    body_top = 50 - drop
    hem = 17 - drop * 0.8
    bells_back = []
    arc = [(-14, 40), (-17, 35), (-18.5, 29.5), (-18, 24), (-16.5, 18.5)]
    for i, (u, v) in enumerate(arc):
        u2 = u - wide
        v2 = v - drop - bell_lift * (0.4 + 0.15 * i)
        bells_back.append((X(u2), Y(v2)))
    for (bx, by) in bells_back:
        cv.shade_ellipse(bx, by, 3.6 * k, 3.4 * k, ["GOLD1", "GOLD2", "GOLD3", "GOLD4"], light=(0.7, -0.5))
        cv.pset(bx - 1.6 * k, by + 1.8 * k, "GOLD0")

    # ---- the mastruca: a big shaggy mass from the shoulders to the hem
    sh = 13 + wide
    body = [(X(-sh + 1), Y(body_top - 6)), (X(-sh + 4), Y(body_top - 1)), (X(-6), Y(body_top + 3)), (X(6), Y(body_top + 3)),
            (X(sh - 3), Y(body_top - 1)), (X(sh), Y(body_top - 7)), (X(sh + 1.5), Y(hem + 12)), (X(sh + 1), Y(hem))]
    body += _jag_bottom(None, X(-sh - 1), X(sh + 1), Y(hem), 2.2 * k, seed, period=3.2 * k)[1:]
    body += [(X(-sh - 1.5), Y(hem + 12))]
    mbody = cv.m_poly(body)
    xx, yy = cv.grid()
    lit_side = (xx + 0.5 - fx) > (sh - 5) * k
    _tufts(cv, mbody, F[1], F[0], F[2], seed, lit_mask=lit_side, lit=F[3], length=int(round(3 * k)))
    # fire light down the right edge, cool night on the left edge
    cv._put(mbody & ((xx + 0.5 - fx) > (sh - 2.2) * k) & (yy % 3 != 0), "FIRE2")
    cv._put(mbody & ((xx + 0.5 - fx) > (sh - 1.0) * k), "FIRE4")
    cv._put(mbody & ((xx + 0.5 - fx) < (-sh + 1.5) * k) & ((yy + xx) % 2 == 0), "NAVY1")

    # ---- arms: shaggy sleeves hanging a little away from the body, dark hands
    for side in (-1, 1):
        ax = X(side * (sh - 1))
        top = Y(body_top - 5)
        bot = Y(hem + 6 - drop * 0.2 + (2 if pose == "air" else 0))
        spread = side * (2 + wide + (1 if pose in ("land", "air") else 0)) * k
        arm = [(ax - 3 * k, top), (ax + 3 * k, top), (ax + spread + 3.2 * k, bot), (ax + spread - 3.2 * k, bot)]
        am = cv.m_poly(arm)
        _tufts(cv, am, F[1], F[0], F[2] if side < 0 else F[3], seed + side, length=int(round(2 * k)))
        if side > 0:
            cv._put(am & ((xx + 0.5) > ax + spread + 1.2 * k), "FIRE3")
        # the seam between arm and body
        cv.line(ax - side * 3 * k, top + 2 * k, ax + spread - side * 3.2 * k, bot - 1, F[0])
        # hand
        hx = ax + spread
        cv.ellipse(hx, bot + 1.2 * k, 2.2 * k, 1.8 * k, "WOOD1")
        cv.pset(hx + 1 * k, bot + 0.6 * k, "WOOD3" if side > 0 else "WOOD2")

    # ---- chest harness: two leather straps crossing, small bronze bells hanging off them
    cy0 = body_top - 3
    s1 = [(X(-9 - wide), Y(cy0)), (X(8 + wide), Y(cy0 - 18))]
    s2 = [(X(9 + wide), Y(cy0)), (X(-8 - wide), Y(cy0 - 18))]
    for (a, b) in (s1, s2):
        cv.line(a[0], a[1], b[0], b[1], "LEATHER1", w=max(1, int(round(1.6 * k))))
        cv.line(a[0], a[1] - 1, b[0], b[1] - 1, "LEATHER2")
    # buckle where they cross
    cxm, cym = X(0), Y(cy0 - 9)
    cv.rect(cxm - 1 * k, cym - 1 * k, 2 * k + 1, 2 * k + 1, "GOLD3")
    cv.pset(cxm, cym, "GOLD5")
    # hanging bells: bigger in the middle
    chest = [(-7, 32, 4, 5), (-3, 29, 5, 6), (2, 29, 5, 6), (6.5, 32, 4, 5), (0, 23, 6, 7)]
    for (u, v, w, h) in chest:
        top = Y(v - drop + (1 if pose == "air" else 0))
        cv.vline(int(X(u)), int(top - 2 * k), int(top), "LEATHER0")
        _bell(cv, X(u), top, w * k, h * k, swing=swing * k * 0.6, big=size == "big")

    # ---- the head: a black kerchief (mucadore) hood over the head, the carved mask in front
    hy = body_top + 2
    hood = cv.m_ellipse(X(0.5), Y(hy + 7), 8.2 * k, 9 * k)
    cv._put(hood, F[0])
    # kerchief folds
    cv._put(hood & ((xx + 0.5 - X(0.5)) > 4.5 * k) & ((yy % 2) == 0), F[1])
    cv._put(hood & ((xx + 0.5 - X(0.5)) > 7.0 * k), "FIRE2")
    # the mask: dark wood, long face, heavy brow, turned a little to the right (3/4 view)
    mx = X(2)
    mtop = Y(hy + 12)
    mh = 13 * k
    mw = 5.2 * k
    face = cv.m_poly([(mx - mw, mtop + 1 * k), (mx + mw, mtop), (mx + mw + 0.4 * k, mtop + mh * 0.55), (mx + mw * 0.6, mtop + mh),
                      (mx - mw * 0.55, mtop + mh), (mx - mw - 0.3 * k, mtop + mh * 0.55)])
    cv._put(face, "WOOD2")
    cv._put(face & ((xx + 0.5) > mx + mw * 0.35), "WOOD3")
    cv._put(face & ((xx + 0.5) > mx + mw * 0.75), "WOOD4")
    cv._put(face & ((xx + 0.5) < mx - mw * 0.6), "WOOD1")
    # heavy brow ridge
    cv.hline(int(mx - mw + 1), int(mx + mw - 1), int(mtop + 3 * k), "WOOD4")
    cv.hline(int(mx - mw + 1), int(mx + mw - 1), int(mtop + 3 * k) + 1, "WOOD1")
    # eye holes: deep black, sad downturned
    for ex in (-2.4, 2.2):
        e0 = int(mx + ex * k - 1.2 * k)
        cv.rect(e0, mtop + 4.5 * k, max(2, round(2.4 * k)), max(1, round(1.6 * k)), "K0")
    # long nose, lit on the right
    cv.vline(int(mx), int(mtop + 3.5 * k), int(mtop + 8.5 * k), "WOOD1")
    cv.vline(int(mx) + 1, int(mtop + 3.5 * k), int(mtop + 8.5 * k), "WOOD4")
    cv.hline(int(mx - 1 * k), int(mx + 1.5 * k), int(mtop + 9 * k), "WOOD1")
    # grave mouth
    cv.hline(int(mx - 2.4 * k), int(mx + 2.4 * k), int(mtop + 11 * k), "K0")
    cv.pset(mx - 2.4 * k - 1, mtop + 11 * k + 1, "K0")
    cv.pset(mx + 2.4 * k + 1, mtop + 11 * k + 1, "K0")

    if size == "big":
        # more carving: cheek lines and a chin
        cv.line(mx - 3.5 * k, mtop + 7 * k, mx - 2.5 * k, mtop + 10 * k, "WOOD1")
        cv.line(mx + 3.5 * k, mtop + 7 * k, mx + 2.8 * k, mtop + 10 * k, "WOOD1")
        cv.hline(int(mx - 1.5 * k), int(mx + 1.5 * k), int(mtop + mh - 1), "WOOD1")

    cv.outline("K0")
    # clean single stray pixels inside the fleece
    cv.clean_orphans(mbody)
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
