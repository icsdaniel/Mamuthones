"""The visera: frontal carved Mamuthone mask, kerchief and sheepskin ring."""
import random
import numpy as np

W, H = 135, 300
K, C, R, GR, B = 0, 1, 2, 3, 4
CX = 67
FACE_TOP, FACE_BOT = 52, 101


def dilate(m, r):
    out = m.copy()
    ys, xs = np.nonzero(m)
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    disk = (xx ** 2 + yy ** 2) <= r * r + r
    for dy, dx in zip(yy[disk], xx[disk]):
        out[np.clip(ys + dy, 0, H - 1), np.clip(xs + dx, 0, W - 1)] = True
    return out


def face_halfwidth(y):
    top = {52: 8, 53: 13, 54: 16, 55: 18, 56: 19, 57: 20, 58: 21, 59: 22}
    if y in top:
        return top[y]
    if y <= 75:
        return 23
    p = (y - 75) / (FACE_BOT - 75)
    return int(round(23 - 16 * p ** 1.35))


def face_mask():
    m = np.zeros((H, W), bool)
    for y in range(FACE_TOP, FACE_BOT + 1):
        hw = face_halfwidth(y)
        m[y, CX - hw:CX + hw + 1] = True
    return m


FACE = face_mask()
KERCHIEF = dilate(FACE, 2) & ~FACE
FLEECE = dilate(FACE, 8) & ~dilate(FACE, 1)

CURLS = [[".##", "#..", ".##"],      # c
         ["##.", "..#", "##."],      # reversed c
         [".##", ".#.", "##."],      # s
         ["##.", ".#.", ".##"],      # z-ish s
         [".#.", "#.#", "#.."]]      # open curl


def _curls():
    rnd = random.Random(3)
    front = []
    for gy, y in enumerate(range(41, 118, 3)):
        off = (gy % 2) * 2
        for x in range(26 + off, 110, 4):
            cx, cy = x + 1, y + 1
            if not FLEECE[cy, cx]:
                continue
            lit = (-(cx - CX) * 0.9 - (cy - 72) * 0.7) + rnd.uniform(-10, 10)
            col = GR if lit > -22 else B
            front.append((rnd.choice(CURLS), x, y, col))
    return [], front


CURLS_BACK, CURLS_FRONT = _curls()


def _bitmap(cv, rows, x, y, c):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == '#':
                cv.px(x + i, y + j, c)


def build_face():
    """Return dict (x,y)->ink for the carved face at rest."""
    face = {}
    for y in range(FACE_TOP, FACE_BOT + 1):
        hw = face_halfwidth(y)
        for x in range(CX - hw, CX + hw + 1):
            face[(x, y)] = C
    feat = set()

    def put(x, y, c):
        if (x, y) in face:
            face[(x, y)] = c
            feat.add((x, y))

    def mir(x, y, c, c2=None):
        put(x, y, c)
        put(2 * CX - x, y, c if c2 is None else c2)

    # bevelled edge: the mask's thickness shows brown on the shadow (right) side and under the chin
    for y in range(FACE_TOP, FACE_BOT + 1):
        hw = face_halfwidth(y)
        put(CX + hw, y, B)
        if y >= 60:
            put(CX + hw - 1, y, B)
    for x in range(CX - 9, CX + 10):
        if (x, FACE_BOT) in face:
            put(x, FACE_BOT, B)

    # forehead: two shallow carved furrows, broken
    for x in range(58, 77):
        if x not in (62, 63, 71):
            put(x, 57 + (1 if abs(x - CX) > 6 else 0), B)
    for x in range(60, 75):
        if x not in (66, 67, 68):
            put(x, 60, B)

    # brow ridge: a heavy carved shelf. The groove under it is the dark recess above the eye.
    # inner ends a little higher than outer ends -> calm, slightly melancholy (as on real viseras)
    for x in range(51, 64):
        yb = 63 if x >= 57 else 64
        if x <= 53:
            yb = 65
        mir(x, yb, B)
        mir(x, yb + 1, B if 53 < x < 63 else C)
    put(64, 63, B); put(70, 63, B)

    # eye holes 6x4, cut through: black. A cream rim, then a thin brown recess on the lower/outer side.
    eye = [".####.",
           "######",
           "######",
           "..###."]          # outer corner is col 0 (droops) for the left eye
    for j, row in enumerate(eye):
        for i, ch in enumerate(row):
            if ch == '#':
                put(55 + i, 68 + j, K)          # left eye, x 55..60
                put(79 - i, 68 + j, K)          # right eye, x 74..79 (mirrored)
    for x, y in [(54, 71), (55, 72)]:
        mir(x, y, B)

    # nose: long, broad Mamuthone nose. Lit ridge on the left, brown shadow plane on the right,
    # both widening toward a heavy tip; a cast shadow under it.
    for y in range(65, 86):
        t = (y - 65) / 20.0
        sw = 2 + int(round(t * 1.4))
        for x in range(CX + 1, CX + 1 + sw):
            put(x, y, B)
        put(CX, y, C)
        hl = 1 + int(round(t * 1.6))
        if y >= 70 and y % 4 != 1:
            put(CX - hl - 1, y, B)                 # broken edge of the left plane
    for x in range(61, 74):
        put(x, 86, C)
    put(61, 86, B); put(72, 86, B); put(73, 86, B); put(71, 86, B)
    put(60, 87, B); put(74, 87, B)
    for x in range(61, 74):
        put(x, 87, C)
    put(72, 87, B); put(73, 87, B)
    put(62, 88, K); put(63, 88, K); put(70, 88, K); put(71, 88, K)       # nostrils
    for x in range(64, 70):
        put(x, 88, B)
    for x in range(64, 73):
        put(x, 89, B)                                                     # cast shadow
    # keep grain off the nose and the area right around it
    for y in range(63, 91):
        for x in range(61, 75):
            if (x, y) in face:
                feat.add((x, y))

    # cheekbones: carved grooves from the outer eye corner sweeping down and in
    for x, y in [(52, 73), (52, 74), (52, 75), (53, 76), (53, 77), (54, 78), (55, 79),
                 (56, 80), (57, 81)]:
        mir(x, y, B)
    # nasolabial folds: from the nose wings down to the mouth corners
    for x, y in [(59, 89), (59, 90), (59, 91)]:
        mir(x, y, B)

    # mouth: small closed slit, corners turned slightly down, lower lip catching light
    for x in range(63, 72):
        put(x, 93, K)
    for x in range(64, 71):
        put(x, 94, C)
    for x in range(65, 70):
        put(x, 95, B)
    # chin boss
    for x in range(64, 71):
        put(x, 98, B)
    put(63, 97, B); put(71, 97, B)
    return face, feat


def add_grain(face, feat):
    """Wood grain: broken vertical brown lines, 4 px apart on the lit side, 2-3 px in shadow."""
    near = set()
    for (x, y) in feat:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                near.add((x + dx, y + dy))
    rnd = random.Random(11)
    xs = []
    x = CX - 21
    while x <= CX + 22:
        xs.append(x)
        x += 4 if x < CX + 3 else (3 if x < CX + 12 else 2)
    for x in xs:
        y = FACE_TOP + 2
        shade = x > CX + 3
        while y < FACE_BOT - 1:
            run = rnd.randint(3, 7) if not shade else rnd.randint(5, 10)
            gap = rnd.randint(2, 5) if not shade else rnd.randint(1, 3)
            for yy in range(y, min(y + run, FACE_BOT - 1)):
                if face.get((x, yy)) == C and (x, yy) not in near:
                    face[(x, yy)] = B
            y += run + gap


FACE_PIX, FEAT = build_face()
add_grain(FACE_PIX, FEAT)


def draw_mask(cv, dy):
    for rows, x, y, col in CURLS_BACK:
        _bitmap(cv, rows, x, y + dy, col)
    for rows, x, y, col in CURLS_FRONT:
        _bitmap(cv, rows, x, y + dy, col)
    for y, x in zip(*np.nonzero(KERCHIEF)):
        cv.px(x, y + dy, K)
    # kerchief knot under the chin: two black rows with brown fold marks, short tails
    ky = FACE_BOT + 2 + dy
    cv.rect(CX - 5, ky, 11, 2, K)
    cv.rect(CX - 2, ky + 2, 5, 1, K)
    cv.px(CX - 2, ky, B); cv.px(CX + 2, ky, B); cv.px(CX, ky + 1, B)
    cv.px(CX - 4, ky + 1, B); cv.px(CX + 4, ky + 1, B)
    for (x, y), c in FACE_PIX.items():
        cv.px(x, y + dy, c)


# ---------------------------------------------------------------------------------------------
# Round 2 (Daniele's photo): a black, glossy carved wooden visera under a brown headscarf.
# The face is shaded from a carved height field lit from the upper left: black wood, brown planes
# turned to the light, warm-grey sheen on the ridges, a few cream glints.
import math as _m

STYLE = 'black'


def _height(x, y):
    u = (x - CX) / 23.0
    v = (y - FACE_TOP) / float(FACE_BOT - FACE_TOP)
    g = lambda a, s: _m.exp(-(a / s) ** 2)
    h = 1.0 - 0.7 * u * u - 0.25 * (v - 0.45) ** 2
    h += 0.55 * g(v - 0.27, 0.055) * (1 if abs(u) < 0.8 else 0.4)        # heavy brow shelf
    h -= 0.3 * g(abs(u) - 0.33, 0.12) * g(v - 0.37, 0.05)                 # eye sockets
    tip = min(1.0, max(0.0, (v - 0.26) / 0.42))
    if 0.26 < v < 0.72:
        h += (0.45 + 0.6 * tip) * g(u, 0.07 + 0.05 * tip)                  # long nose, heavy tip
    h += 0.22 * g(abs(u) - 0.47, 0.13) * g(v - 0.55, 0.09)                 # cheekbones
    h += 0.38 * g(v - 0.785, 0.035) * g(u, 0.36)                          # upper lip
    h += 0.42 * g(v - 0.875, 0.04) * g(u, 0.33)                           # thick lower lip
    h += 0.2 * g(v - 0.97, 0.04) * g(u, 0.3)                              # chin
    return h


def build_black():
    face = {}
    L = (-0.62, -0.58, 0.53)
    for y in range(FACE_TOP, FACE_BOT + 1):
        hw = face_halfwidth(y)
        for x in range(CX - hw, CX + hw + 1):
            dx = (_height(x + 0.5, y) - _height(x - 0.5, y)) * 9
            dy = (_height(x, y + 0.5) - _height(x, y - 0.5)) * 9
            n = (-dx, -dy, 1.0)
            k = 1 / _m.sqrt(n[0] ** 2 + n[1] ** 2 + 1)
            lit = (n[0] * L[0] + n[1] * L[1] + n[2] * L[2]) * k
            edge = hw - abs(x - CX)
            if lit > 0.95 and (x + y) % 2 == 0:
                c = C                                   # glossy glint
            elif lit > 0.86:
                c = GR
            elif lit > 0.52:
                c = B
            else:
                c = K
            if edge == 0 and x < CX:
                c = B if c == K else c                  # lit rim on the left edge
            face[(x, y)] = c
    def put(x, y, c):
        if (x, y) in face:
            face[(x, y)] = c
    for (x, y), c in list(face.items()):                # the lit cheek stays brown wood, no black holes
        if c == K and x < CX - 2 and 74 <= y <= 89 and face_halfwidth(y) - abs(x - CX) > 0:
            face[(x, y)] = B
    # brow shelf: a sheen along its top edge, black shadow under it
    for x in range(CX - 17, CX + 18):
        put(x, 64, GR if x < CX + 6 else B)
        put(x, 66, K)
    # eye holes: cut through, black, ringed by brown wood, a lit lower lid
    for sx in (-1, 1):
        ex = CX + sx * 8
        for i in range(-4, 5):
            for j in range(67, 74):
                put(ex + i, j, B)
        for j, w in enumerate((2, 3, 3, 2)):
            for i in range(-w, w + 1):
                put(ex + i, 68 + j, K)
        for i in range(-3, 4):
            put(ex + i, 72, GR)
    # the long nose: a lit ridge, its shadow plane to the right, a heavy tip
    for y in range(65, 87):
        t = (y - 65) / 21
        w = 1 + int(t * 3)
        put(CX - 1, y, GR); put(CX - 2, y, B)
        for k in range(w):
            put(CX + k, y, K if k else B)
        if y > 78:
            put(CX - 2 - int(t * 2), y, B)
    for x in range(CX - 5, CX + 5):
        put(x, 86, GR if x < CX + 1 else B)
        put(x, 87, B if x < CX + 2 else K)
    put(CX - 4, 88, K); put(CX + 3, 88, K)
    for x in range(CX - 3, CX + 4):
        put(x, 88, K)                                   # shadow under the nose
    # lips: thick, slightly open, carved
    for x in range(CX - 7, CX + 8):
        put(x, 90, GR if x < CX else B)
        put(x, 91, K)
        if abs(x - CX) < 6:
            put(x, 92, K)
            put(x, 93, GR if x < CX + 1 else B)
            put(x, 94, B)
    put(CX - 8, 91, K); put(CX + 8, 91, K)
    return face


SCARF = None


def _scarf():
    s = dilate(FACE, 6) & ~FACE
    yy, xx = np.mgrid[0:H, 0:W]
    s &= (yy < FACE_BOT - 4) | (np.abs(xx - CX) > 14)        # open under the chin, where it ties
    return s


def draw_black(cv, dy):
    global SCARF
    if SCARF is None:
        SCARF = _scarf()
    for rows, x, y, col in CURLS_FRONT:
        _bitmap(cv, rows, x, y + dy, B if col == B else B if (x + y) % 3 else GR)
    # the brown headscarf, with black fold lines sweeping down to the knot
    ys, xs = np.nonzero(SCARF)
    for y, x in zip(ys, xs):
        fold = ((x - CX) * 0.7 + (y - 50) * (1 if x < CX else -1) * 0.6) % 7 < 1
        top = y < FACE_TOP + 2
        lit = x < CX - 6 and not fold
        cv.px(x, y + dy, K if fold and not top else (GR if (top or (lit and (x + y) % 3 == 0)) else B))
    for y in range(FACE_TOP - 6, FACE_BOT + 4):                   # dark seam between scarf and mask
        pass
    edge = dilate(FACE, 1) & ~FACE
    for y, x in zip(*np.nonzero(edge)):
        cv.px(x, y + dy, K)
    # knot and tails under the chin
    ky = FACE_BOT + 2 + dy
    cv.rect(CX - 4, ky, 9, 3, B)
    cv.px(CX - 1, ky + 1, K); cv.px(CX + 1, ky + 1, K)
    for k in range(5):
        cv.px(CX - 3 - k // 2, ky + 3 + k, B); cv.px(CX + 3 + k // 2, ky + 3 + k, B)
    for (x, y), c in BLACK_PIX.items():
        cv.px(x, y + dy, c)


BLACK_PIX = build_black()
_draw_old = draw_mask


def draw_mask(cv, dy):
    (draw_black if STYLE == 'black' else _draw_old)(cv, dy)
