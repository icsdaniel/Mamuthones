"""The play screen's files beside the road: the Mamuthones and the Issohadore, drawn at 1x.

    row_mamuthone(size, pose, var, fleece) -> Canvas, feet at ROW[size]["feet"]
    row_issohadore(pose)                   -> Canvas, feet at ISS["feet"]

Every depth has its own drawing ("near", "mid", "far": ~62, ~50 and ~40 art px tall), so the game
draws each at a whole 3 screen px per art px on the art grid and never scales a figure. Poses:
"stand", "crouch" (before the jump), "air", "land" and "land2" (squashed, the bells swung one way
or the other: the game alternates them each landing); variants "a" and "b" differ in lean and in
how the carriga hangs, so the files are not copies. row_dim() is a figure not yet dancing: palette
steps darker, never faded. The Issohadore: "stand", "swing" (the rope hand up, the loop spun over
his head) and "cast" (the hand thrown out to the crowd); the rope itself is drawn by the game from
ISS_HAND. They face right, lit by the fire from the right; the right file mirrors them.
"""
import math

import numpy as np

from px import Canvas
from palette import P, RAMPS

ROW_SIZES = ("near", "mid", "far")
ROW_MAM_POSES = ("stand", "crouch", "air", "land", "land2")
ROW_VARIANTS = ("a", "b")
ROW = {
    "near": dict(cell=(64, 78), feet=(34, 74), s=1.0, i=0),
    "mid": dict(cell=(54, 64), feet=(29, 60), s=0.8, i=1),
    "far": dict(cell=(44, 52), feet=(24, 49), s=0.64, i=2),
}

WOOD_CM = {"1": "WOOD0", "2": "WOOD1", "3": "WOOD2", "4": "WOOD3", "5": "WOOD4", "0": "K0"}
# the carved wooden mask (visera), facing 3/4 right, lit from the fire on the right
MASKS = [
    [".1222223.",
     "122223332",
     "234423453",
     "300131003",
     "200131002",
     "212234212",
     "222234432",
     "222235432",
     "221110443",
     "210000013",
     ".2111113.",
     ".2223332.",
     "..22332.."],
    [".12223.",
     "2344453",
     "1003002",
     "1003002",
     "2123413",
     "2223542",
     "2111042",
     "2000003",
     ".22332.",
     "..232.."],
    [".1223",
     "23443",
     "10302",
     "21342",
     "20003",
     ".2332"],
]

BELL_CM = {"0": "GOLD0", "1": "GOLD1", "2": "GOLD2", "3": "GOLD3", "4": "GOLD4", "5": "GOLD5", "k": "K0"}
# the small bells on the chest straps
CHEST_BELL = [
    [".4.", "345", "234", "101"],
    [".4.", "345", "101"],
    ["34", "01"],
]

def stamp(cv, rows, x, y, cmap):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch not in ". ":
                cv.pset(x + i, y + j, cmap[ch])


def _sprite(rows, cmap, outline=True):
    w = max(len(r) for r in rows)
    c = Canvas(w + 2, len(rows) + 2)
    stamp(c, rows, 1, 1, cmap)
    if outline:
        c.outline("K0")
    return c


# the carriga's big cowbells, hanging mouth down (1-5 GOLD1..5, 0 GOLD0, k K0, l the leather loop)
BACK_BELLS = [
    ["...ll...",
     "..1233..",
     ".122354.",
     ".122354.",
     ".122344.",
     ".122344.",
     "12223443",
     "12223443",
     "23334444",
     ".100001.",
     "...kk..."],
    ["..ll..",
     ".1235.",
     ".1235.",
     ".1234.",
     "122344",
     "122344",
     "233444",
     ".1001."],
    ["..l..",
     ".235.",
     ".234.",
     "12344",
     "23444",
     ".100."],
]
# where the carriga's bells hang (u from the feet toward the road, v up, their tilt), per depth and
# variant: an arc from behind the far shoulder down the back, poking out past the fleece
CARRIGA = {
    "near": {"a": [(-9, 55, -1), (-14, 46, -1), (-17, 37, 0), (-17, 28, 0)],
             "b": [(-10, 54, -1), (-15, 45, -1), (-17, 36, -1), (-16, 27, 0)]},
    "mid": {"a": [(-7, 44, -1), (-11, 37, -1), (-14, 30, 0), (-14, 23, 0)],
            "b": [(-8, 43, -1), (-12, 36, -1), (-14, 29, -1), (-13, 22, 0)]},
    "far": {"a": [(-7, 35, 0), (-11, 30, -1), (-13, 24, 0), (-13, 18, 0)],
            "b": [(-7, 34, -1), (-12, 28, -1), (-13, 22, 0)]},
}
BELL_CM = dict(BELL_CM, l="LEATHER1")


def back_bell(si, tilt=0):
    """A carriga bell with its K0 outline, its mouth swung `tilt` px sideways (a shear): (Canvas,
    (hang_x, hang_y))."""
    rows = BACK_BELLS[si]
    h = len(rows)
    w = max(len(r) for r in rows)
    pad = abs(tilt) + 1
    c = Canvas(w + 2 * pad + 2, h + 2)
    for j, row in enumerate(rows):
        sh_ = int(round(tilt * j / max(1, h - 1)))
        stamp(c, [row], pad + 1 + sh_, 1 + j, BELL_CM)
    c.outline("K0")
    return c, (pad + 1 + w // 2, 1)


def _drape_head(size_i, lean):
    """The black kerchief tied over the head, with the mask in it: returns a canvas and the mask's
    top-left in it."""
    mask = MASKS[size_i]
    mw, mh = max(len(r) for r in mask), len(mask)
    pad_l = [4, 3, 2][size_i]
    pad_t = [3, 2, 2][size_i]
    W, H = mw + pad_l + 3, mh + pad_t + 3
    cv = Canvas(W, H)
    mx, my = pad_l, pad_t
    # the kerchief: a dome over the head, falling behind to the shoulders on the left
    cx = mx + mw / 2.0 - 0.5
    cy = my + mh * 0.42
    rx, ry = mw / 2.0 + 1.6, mh / 2.0 + 1.2
    k = cv.m_ellipse(cx, cy, rx, ry)
    back = cv.m_poly([(cx - rx, cy), (cx, cy), (cx - 1, H), (cx - rx - 1.5, H)])
    kmask = k | back
    cv._put(kmask, "K1")
    xx, yy = cv.grid()
    # a cool sheen over the top, from the night sky; a fold on the drape
    sheen = kmask & (((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy + 0.8) / ry) ** 2 <= 1.0) & \
        (((xx + 0.5 - cx + 0.9) / rx) ** 2 + ((yy + 0.5 - cy + 1.9) / ry) ** 2 > 1.0) & (xx < cx + 1)
    cv._put(sheen, "NAVY2")
    stamp(cv, mask, mx, my, WOOD_CM)
    # the fire's rim on the kerchief's right edge
    # the fire's rim on the kerchief: its right shoulder, hot at the top, fading down the side
    right = kmask & ~np.roll(kmask, -1, axis=1) & (xx > cx)
    top_e = kmask & ~np.roll(kmask, 1, axis=0) & (xx > cx + 1)
    rim = (right | top_e) & (yy < cy + 1)
    cv._put(rim, "FIRE1")
    cv._put(rim & (yy < cy - ry * 0.35), "FIRE2")
    cv._put(top_e & (xx > cx + rx * 0.45), "FIRE3")
    return cv, (mx, my)


LOCK_SHAPES = [
    # per depth: one hanging lock of wool; h its lit top, b its body ('.' shows the groove under it)
    [".h.", "hbb", "bbb", "bbb", "bb.", ".b."],
    [".h.", "hbb", "bbb", "bb.", ".b."],
    ["hb", "bb", "b."],
]
LOCK_STEP = [(4, 5), (4, 4), (3, 3)]     # columns and rows between locks, per depth
# per band (shadow, mid, lit): groove, lock body, lock top - black sheepskin stays in K0/FLEECE0-3
FLEECE_BANDS = {
    "black": [("K0", "FLEECE1", "FLEECE1"), ("FLEECE0", "FLEECE1", "FLEECE2"), ("FLEECE0", "FLEECE2", "FLEECE3")],
    "dark_brown": [("FLEECE0", "FLEECE2", "FLEECE2"), ("FLEECE1", "FLEECE2", "FLEECE3"), ("FLEECE1", "FLEECE3", "FLEECE4")],
}


def fleece_draw(cv, core, si, seed, top_y, hem_y, fleece="black"):
    """Sheepskin over the mask `core`, as clustered locks of wool: three value bands by the fire's
    light (from the right, a little from above), the grooves between locks dark, each lock one shade
    up with a lighter top on the lit side, lock tips hanging ragged below the hem and out at the
    sides, and the locks on the fire side's edge lit warm (rim light, lock by lock). Returns the
    fleece's final silhouette."""
    H, W = core.shape
    rng = np.random.default_rng(seed)
    bands = FLEECE_BANDS["dark_brown" if fleece == "dark_brown" else "black"]
    shape = LOCK_SHAPES[si]
    lw, lh = len(shape[0]), len(shape)
    cs, rs = LOCK_STEP[si]

    def band_at(x, y, span):
        lo, hi = span
        c = (lo + hi + 1) / 2.0
        hw = max(1.0, (hi + 1 - lo) / 2.0)
        nx = (x + 0.5 - c) / hw
        ny = (y - top_y) / max(1.0, hem_y - top_y)
        L = 0.5 + 0.5 * nx + 0.18 * (0.5 - ny)
        return 0 if L < 0.32 else (1 if L < 0.74 else 2)

    spans = {}
    for y in range(H):
        cols = np.nonzero(core[y])[0]
        if len(cols):
            spans[y] = (int(cols.min()), int(cols.max()))
    fl = Canvas(W, H)
    for y, sp in spans.items():
        for x in range(sp[0], sp[1] + 1):
            fl.pset(x, y, bands[band_at(x, y, sp)][0])
    # where a lock may hang: the core, and below it (the ragged hem)
    hang = core.copy()
    for d in range(1, lh - 1):
        hang[d:, :] |= core[:-d, :]
    sky_cols = []                               # the edge column of each lock high on the night side
    for r_i, y0 in enumerate(range(top_y - 1, hem_y + 1, rs)):
        off = (r_i % 2) * (cs // 2) + (1 if r_i % 4 == 3 else 0)
        for x0 in range(off - lw, W, cs):
            y = y0 + (1 if rng.random() < 0.4 else 0)
            cx_, cy_ = x0 + lw // 2, y + 1
            if not (0 <= cy_ < H and 0 <= cx_ < W and core[cy_, cx_]):
                continue
            b = band_at(cx_, cy_, spans[cy_])
            groove, body, top = bands[b]
            if cy_ > top_y + (hem_y - top_y) * 0.7 and b == 2:
                top = body
            drawn = []
            for j, row in enumerate(shape):
                for i, ch in enumerate(row):
                    px_, py_ = x0 + i, y + j
                    if ch == "." or not (0 <= px_ < W and 0 <= py_ < H) or not hang[py_, px_]:
                        continue
                    fl.pset(px_, py_, top if ch == "h" else body)
                    drawn.append((px_, py_))
            if drawn and b == 0 and cy_ < top_y + (hem_y - top_y) * 0.55:
                xl = min(p[0] for p in drawn)
                if xl <= spans[cy_][0] + 1:
                    sky_cols.append(sorted([p for p in drawn if p[0] == xl], key=lambda p: p[1]))
    m = fl.solid()
    # side tufts: a lock tip out at each side, every row of locks
    tufts = []
    for y in range(top_y + 3, hem_y - 1):
        if (y - top_y) % rs != 2 or y not in spans:
            continue
        lo, hi = spans[y]
        for xe, dd in ((lo, -1), (hi, 1)):
            if rng.random() < (0.9 if dd > 0 else 0.7):
                col = fl.get(xe, y)
                tuft = []
                for k in range(2 + (1 if si < 2 and rng.random() < 0.5 else 0)):
                    if col is not None:
                        fl.pset(xe + dd, y + k, col)
                        tuft.append((xe + dd, y + k))
                if dd > 0 and tuft:
                    tufts.append(tuft)
    # a cool sheen from the night sky on the far side's upper locks
    for colpx in sky_cols:
        for n_, (x, y) in enumerate(colpx[:2]):
            fl.pset(x, y, "NAVY2" if n_ == 0 else "NAVY1")
    # the fire's rim: down the fire side, the outermost pixel of every lock (not the grooves between
    # them) turns warm, hot where a lock begins; over the right shoulder too
    sol = fl.solid()
    rim = np.zeros_like(sol)
    span = max(1, hem_y - top_y)
    for y in range(top_y, min(H, hem_y + 2)):
        xs = np.nonzero(sol[y])[0]
        if len(xs) == 0:
            continue
        c = (xs.min() + xs.max()) / 2.0
        if y < top_y + span * 0.8:
            rim[y, xs.max()] = True
        if y < top_y + span // 3:
            for x in xs:
                if x > c + 2 and (y == 0 or not sol[y - 1, x]):
                    rim[y, x] = True
    fl._put(rim, "FIRE1")
    for tuft in tufts:
        hot = tuft[0][1] < top_y + span * 0.65
        for n_, (x, y) in enumerate(tuft):
            fl.pset(x, y, ("FIRE3" if hot else "FIRE2") if n_ == 0 else ("FIRE2" if hot else "FIRE1"))
            # the lock the tuft grows from catches the light with it
            if n_ == 0 and hot:
                fl.pset(x - 1, y, "FIRE2")
    fl.clean_orphans()
    cv.blit(fl, 0, 0)
    return fl.solid()


def row_mamuthone(size="near", pose="stand", var="a", fleece="black"):
    R = ROW[size]
    W, H = R["cell"]
    fx, fy = R["feet"]
    s = R["s"]
    si = R["i"]
    cv = Canvas(W, H)

    def q(v):
        return int(round(v * s))

    drop = {"stand": 0, "crouch": q(3), "air": -1, "land": q(4.5), "land2": q(4.5)}[pose]
    wide = {"stand": 0, "crouch": 1, "air": 0, "land": q(2.5), "land2": q(2.5)}[pose]
    flare = {"stand": 0, "crouch": 0, "air": q(2.5), "land": 1, "land2": 1}[pose]
    lean = {"a": 0, "b": 1}[var]

    def X(u):
        return fx + u

    def Y(v):
        return fy - v

    leg = q(12)
    hem = leg + 1 - drop + (q(3) if pose == "air" else 0)
    sh = q(44) - drop
    top = sh + q(5)

    def shear(v):
        return lean if v > (hem + sh) * 0.5 else 0

    # ---- the carriga: big bronze cowbells on the back, behind the far (left) shoulder and down it
    lift = {"stand": 0, "crouch": 1, "air": -q(3), "land": q(2), "land2": q(2)}[pose]
    swing = {"stand": 0, "crouch": 0, "air": -1, "land": 2, "land2": -2}[pose]
    backs = CARRIGA[size][var]
    for n_, (u, v, a0) in reversed(list(enumerate(backs))):
        k_ = n_ / max(1, len(backs) - 1)
        b, (hx, hy) = back_bell(si, a0 + int(round(swing * (0.5 + 0.5 * k_))))
        bx = X(u - wide + shear(v))
        by = Y(v - drop - int(round(lift * (0.5 + 0.5 * k_))))
        cv.blit(b, bx - hx, by - hy)

    # ---- legs: dark trousers, black leather leggings, heavy shoes
    for side in (-1, 1):
        if pose == "air":
            lx = X(side * q(5) + (1 if side > 0 else 0))
            cv.rect(lx - q(2), Y(hem + 1), q(4) + 1, hem - q(5), "K1")
            cv.rect(lx - q(2.5), Y(q(6)), q(5) + 1 + (1 if side > 0 else 0), q(3), "K1")
            cv.hline(lx - q(1), lx + q(2.5) + (1 if side > 0 else 0), Y(q(6)), "LEATHER1" if side > 0 else "LEATHER0")
            if side > 0:
                cv.vline(lx + q(2), Y(hem + 1), Y(q(6)) - 1, "NAVY2")
            continue
        bend = {"stand": 0, "crouch": 1, "land": 2, "land2": 2}[pose]
        kx = X(side * (q(5) + bend + wide))
        ax = X(side * (q(6) + wide))
        top_y = Y(hem + 1)
        knee_y = Y(q(7))
        cv.poly([(kx - q(2.5), top_y), (kx + q(2.5) + 1, top_y), (ax + q(2.5) + 1, Y(q(2))), (ax - q(2.5), Y(q(2)))], "K1")
        cv.poly([(kx - q(2.5), knee_y), (kx + q(2.5) + 1, knee_y), (ax + q(2.5) + 1, Y(q(2))), (ax - q(2.5), Y(q(2)))], "LEATHER0")
        if side > 0:
            cv.line(kx + q(2.5), top_y, kx + q(2.5), knee_y - 1, "NAVY2")
            cv.line(kx + q(2.5), knee_y, ax + q(2.5), Y(q(2)) - 1, "LEATHER2")
        else:
            cv.line(kx + q(2.5), knee_y, ax + q(2.5), Y(q(2)) - 1, "LEATHER1")
        toe = 1 if side > 0 else 0
        cv.rect(ax - q(3), Y(q(2)), q(6) + 1 + toe, q(2) + 1, "K1")
        cv.hline(ax, ax + q(3) + toe, Y(q(2)), "WOOD2" if side > 0 else "WOOD1")

    # ---- the mastruca
    hw_l = [q(7), q(11.5), q(14), q(15), q(16)]
    hw_r = [q(5), q(10.5), q(12.5), q(14), q(15)]
    vs = [top, sh, sh - q(9), sh - q(19), hem + q(3)]
    pts = []
    for i, v in enumerate(vs):
        pts.append((X(hw_r[i] + wide * (i > 1) + flare * (i == 4) + shear(v)) + 1, Y(v)))
    pts.append((X(hw_r[-1] + wide + flare) + 1, Y(hem)))
    pts.append((X(-hw_l[-1] - wide - flare), Y(hem)))
    for i in range(len(vs) - 1, -1, -1):
        v = vs[i]
        pts.append((X(-hw_l[i] - wide * (i > 1) - flare * (i == 4) + shear(v)), Y(v)))
    core = cv.m_poly(pts)
    fleece_draw(cv, core, si, fleece=fleece, seed={"a": 11, "b": 23}[var] + si + 5 * ROW_MAM_POSES.index(pose),
                top_y=Y(top), hem_y=Y(hem))

    # ---- fists at the fleece's sides
    fy_ = Y(hem + q(8) + (q(2) if pose == "air" else 0))
    edge = X(q(14) + wide + (flare if pose == "air" else 0))
    FIST = [[".12.", "1221", "0110"], ["12", "01"], ["1", "0"]][si]
    stamp(cv, FIST, edge - 1, fy_, {"0": "SKIN0", "1": "SKIN1", "2": "SKIN2"})

    # ---- chest harness: two straps from the shoulders to a yoke on the chest, small bells on them
    cl = {"stand": 0, "crouch": 1, "air": -1, "land": 1, "land2": 1}[pose]
    lsh = (X(-q(8)) + lean, Y(sh - 1))
    rsh = (X(q(9)) + lean, Y(sh - 1))
    yoke = (X(q(1)) + lean, Y(sh - q(11)))
    for a_ in (lsh, rsh):
        cv.line(a_[0], a_[1], yoke[0], yoke[1], "LEATHER2")
        cv.line(a_[0], a_[1] + 1, yoke[0], yoke[1] + 1, "LEATHER1")
    cb = _sprite(CHEST_BELL[si], BELL_CM)

    def on(a_, t):
        return (int(round(a_[0] + (yoke[0] - a_[0]) * t)), int(round(a_[1] + (yoke[1] - a_[1]) * t)))
    hangs = [on(lsh, 0.5), on(rsh, 0.5)] if size != "far" else []
    if size == "near":
        hangs = [on(lsh, 0.15), on(rsh, 0.15)] + hangs
    for (hx, hy) in hangs:
        cv.blit(cb, hx - cb.w // 2, hy + 1 + cl)
    big, (bhx, bhy) = back_bell(min(2, si + 1), 0)
    cv.blit(big, yoke[0] - bhx, yoke[1] + cl - bhy + 1)

    # ---- the head: the black kerchief and the carved mask
    head, (mx, my) = _drape_head(si, lean)
    mw = max(len(r) for r in MASKS[si])
    hx0 = X(q(2)) + lean * 2 - mx - mw // 2 + (1 if var == "b" else 0)
    hy0 = Y(top + q(10)) + (1 if pose in ("land", "land2") else 0) - my
    cv.blit(head, hx0, hy0)

    cv.outline("K0")
    return cv


def row_dim(cv):
    """The figure one or two steps darker, fire rim gone: a Mamuthone not yet dancing."""
    inv = {}
    for name, cols in RAMPS.items():
        for i, c in enumerate(cols):
            inv[P[f"{name}{i}"]] = (name, i)
    out = cv.copy()
    a = out.a
    m = a[:, :, 3] > 0
    for c in np.unique(a[m][:, :3], axis=0):
        t = tuple(int(v) for v in c)
        name, i = inv[t]
        if name == "FIRE":
            new = "FLEECE2"
        elif name in ("GOLD", "WOOD", "SKIN"):
            new = f"{name}{max(0, i - 2)}"
        elif name == "K":
            continue
        else:
            new = f"{name}{max(0, i - 1)}"
        sel = m & np.all(a[:, :, :3] == c, axis=2)
        a[sel, :3] = P[new]
    return out


# ---------------------------------------------------------------------------------------------------
# The Issohadore at the head of each file (one size: he stands nearest, by the hit line)
# ---------------------------------------------------------------------------------------------------

ROW_ISS_POSES = ("stand", "swing", "cast")
ISS = dict(cell=(52, 80), feet=(28, 76))
# his rope hand (the far, outer one) in each pose, from the feet: the rope is drawn from here in the
# game so the loop can spin and fly
ISS_HAND = {"stand": (-9, 31), "swing": (-6, 72), "cast": (-16, 62)}   # (u, up)

ISS_HEAD = [
    "...KKKK...",
    "..KnnnKK..",
    ".KKKKKKKK.",
    "KKKsWWwww.",
    "KK.sW0Ww0.",
    "KK.sWWswx.",
    "K..sWWWsw.",
    "K..sWddd..",
    "...ssWWw..",
    "...rRRRr..",
]
ISS_CM = {"K": "K1", "n": "NAVY2", "w": "BONE4", "W": "BONE3", "s": "BONE2", "d": "BONE1", "0": "K0",
          "r": "RED1", "R": "RED2", "x": "BONE4"}


def _limb(cv, pts, cols, w):
    """A sleeve or leg along pts, w px thick: the first colour, the lit (right) edge the second."""
    for i in range(len(pts) - 1):
        cv.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], cols[0], w=w)
    if len(cols) > 1:
        for i in range(len(pts) - 1):
            cv.line(pts[i][0] + w // 2, pts[i][1], pts[i + 1][0] + w // 2, pts[i + 1][1], cols[1])


def row_issohadore(pose="stand"):
    W, H = ISS["cell"]
    fx, fy = ISS["feet"]
    cv = Canvas(W, H)
    xx, yy = cv.grid()

    def X(u):
        return fx + u

    def Y(v):
        return fy - v

    # ---- far arm behind the body when it is not throwing
    if pose == "stand":
        _limb(cv, [(X(-7), Y(50)), (X(-9), Y(42)), (X(-9), Y(33))], ["RED1"], 3)
    # ---- legs: boots, black leather gaiters, white linen trousers
    for side in (-1, 1):
        ax = X(side * 4)
        cv.rect(ax - 2, Y(3), 5 + (1 if side > 0 else 0), 4, "K1")
        cv.hline(ax, ax + 2 + (1 if side > 0 else 0), Y(3), "WOOD2" if side > 0 else "WOOD1")
        cv.rect(ax - 2, Y(13), 5, 10, "K1")
        cv.vline(ax + 2, Y(13), Y(4), "NAVY3" if side > 0 else "NAVY2")
        for j in range(3):
            cv.pset(ax + (1 if side > 0 else 0), Y(11 - j * 3), "GOLD3" if side > 0 else "GOLD2")
        tr = cv.m_poly([(ax - 3, Y(29)), (ax + 3.5, Y(29)), (ax + 4, Y(19)), (ax + 3, Y(13)), (ax - 2.5, Y(13)), (ax - 3.5, Y(19))])
        cv._put(tr, "BONE3")
        cv._put(tr & (xx >= ax + 2), "BONE4")
        cv._put(tr & (xx <= ax - 2), "BONE2")
        cv.line(ax, Y(26), ax - 1, Y(16), "BONE2")
        cv.hline(ax - 2, ax + 3, Y(13), "BONE2")
    cv.rect(X(-1), Y(29), 2, 6, "BONE2")
    # ---- the shawl tied at the hips, fringed
    shawl = cv.m_poly([(X(-8), Y(36)), (X(8), Y(36)), (X(6), Y(29)), (X(1), Y(24)), (X(-6), Y(29))])
    cv._put(shawl, "RED1")
    cv._put(shawl & (xx > X(2)), "RED2")
    cv._put(shawl & ((xx + yy) % 4 == 0) & ((yy % 2) == 0), "GOLD2")
    for u in range(-5, 7, 2):
        vb = 28.5 - abs(u - 1) * 0.55
        cv.vline(X(u), Y(vb) + 1, Y(vb) + 2, "GOLD2" if u < 3 else "GOLD3")
    # ---- red jacket over the white shirt, belt, buttons
    jk = cv.m_poly([(X(-7.5), Y(36)), (X(-8), Y(50)), (X(-5), Y(53)), (X(6), Y(53)), (X(8.5), Y(50)), (X(8), Y(36))])
    cv._put(jk, "RED3")
    cv._put(jk & (xx < X(-3)), "RED2")
    cv._put(jk & (xx < X(-6)), "RED1")
    cv._put(jk & (xx >= X(6)), "RED4")
    shirt = cv.m_poly([(X(-1), Y(53)), (X(3), Y(53)), (X(2), Y(38)), (X(0), Y(38))])
    cv._put(shirt, "BONE4")
    cv._put(shirt & (xx <= X(0)), "BONE3")
    cv.line(X(-1), Y(52), X(0), Y(38), "RED1")
    cv.rect(X(-7), Y(37), 15, 2, "K1")
    cv.rect(X(0), Y(37), 2, 2, "GOLD3")
    for j in range(3):
        cv.pset(X(4), Y(50 - j * 4), "GOLD4")
    # the bandolier of small bells from the right shoulder to the left hip
    cv.line(X(6), Y(52), X(-6), Y(38), "LEATHER1", w=2)
    for j in range(4):
        t = (j + 0.5) / 4.0
        bx = int(round(X(6 - 12 * t)))
        by = int(round(Y(52 - 14 * t))) + 1
        cv.rect(bx - 1, by, 2, 2, "GOLD3")
        cv.pset(bx, by, "GOLD4")
    # ---- near (right) arm: hangs, the hand holding the coiled rope's end
    _limb(cv, [(X(7), Y(51)), (X(9), Y(43)), (X(9), Y(35))], ["RED3", "RED4"], 3)
    cv.line(X(7) - 1, Y(49), X(8) - 1, Y(37), "RED1")
    cv.rect(X(8), Y(35), 3, 3, "SKIN1")
    cv.pset(X(10), Y(35), "SKIN2")
    # ---- far (left) arm: the rope hand
    hu, hv = ISS_HAND[pose]
    if pose == "stand":
        cv.rect(X(-10), Y(33), 3, 3, "SKIN0")
        # coils of hemp rope in the hand
        for j, (rx, ry) in enumerate(((3.2, 5.2), (2.6, 4.6))):
            ring = cv.m_ellipse(X(-9) + 0.5 - j, Y(26) + 0.5 + j * 0.5, rx, ry) & ~cv.m_ellipse(X(-9) + 0.5 - j, Y(26) + 0.5 + j * 0.5, rx - 1.1, ry - 1.1)
            cv._put(ring, "ROPE1")
            cv._put(ring & (xx > X(-9) - j), "ROPE2")
            cv._put(ring & (yy > Y(24)) & (xx < X(-10)), "ROPE0")
    else:
        if pose == "swing":
            arm = [(X(-6), Y(50)), (X(-9), Y(58)), (X(hu), Y(hv) + 2)]
        else:
            arm = [(X(-6), Y(50)), (X(-11), Y(56)), (X(hu) + 2, Y(hv))]
        _limb(cv, arm, ["RED2", "RED3"], 3)
        cv.rect(X(hu) - 1, Y(hv) - 1, 3, 3, "SKIN1")
        cv.pset(X(hu) + 1, Y(hv) - 1, "SKIN2")
        # the coils left in the near hand
        for j, (rx, ry) in enumerate(((3.0, 4.6),)):
            ring = cv.m_ellipse(X(9) + 0.5, Y(29) + 0.5, rx, ry) & ~cv.m_ellipse(X(9) + 0.5, Y(29) + 0.5, rx - 1.1, ry - 1.1)
            cv._put(ring, "ROPE1")
            cv._put(ring & (xx > X(9)), "ROPE2")
    # ---- head: the white mask, the black berritta folded back, a kerchief knotted under the chin
    stamp(cv, ISS_HEAD, X(-5), Y(63), ISS_CM)
    cv.outline("K0")
    return cv


if __name__ == "__main__":
    import sys
    from PIL import Image
    out = sys.argv[1]
    tiles = []
    for size in ROW_SIZES:
        row = []
        for var in ("a", "b"):
            for pose in ROW_MAM_POSES:
                row.append(row_mamuthone(size, pose, var))
        row.append(row_mamuthone(size, "stand", "a", "dark_brown"))
        row.append(row_dim(row_mamuthone(size, "stand", "a")))
        tiles.append(row)
    sc = 4
    W = max(sum(c.w for c in r) for r in tiles) * sc
    H = sum(max(c.h for c in r) for r in tiles) * sc
    im = Image.new("RGBA", (W, H), (58, 46, 44, 255))
    y = 0
    for r in tiles:
        x = 0
        for c in r:
            im.alpha_composite(c.image(sc), (x, y))
            x += c.w * sc
        y += max(c.h for c in r) * sc
    im.save(out)
    print(im.size)
