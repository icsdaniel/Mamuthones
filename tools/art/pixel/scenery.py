"""Scenery for the story pictures: night sky, mountains, the stone houses of Mamoiada, cobbles, crowds,
bonfires, braziers, smoke and fog - all drawn on a px.Canvas from the one palette.

Everything that stands in the fire's light is coloured through a light map (Light): each material has a
ramp that runs from the cool night side (NIGHT/HILL) to the warm firelit side (STONE/FIRE), and a pixel
takes its colour from how much light reaches it, banded with one Bayer step at each band edge. That is
what makes a whole picture read as "one bonfire lights the square", as in Daniele's menu reference.

    L = Light(w, h, ambient=0.08)
    L.add(160, 150, 120, 1.0)           # a bonfire at (160, 150), reach 120 px
    sky(cv, 0, 110, seed=2)
    house(cv, L, 20, 150, 40, 30, ...)
"""
import math

import numpy as np

from px import Canvas, BAYER4

# Material ramps, darkest (unlit night side) to brightest (in the fire's glare).
RAMP = {
    "wall": ["K1", "NIGHT0", "NIGHT1", "HILL1", "HILL2", "STONE2", "STONE3", "STONE4", "STONE5", "STONE6"],
    "wall_cool": ["K1", "NIGHT0", "NIGHT1", "HILL0", "HILL1", "HILL2", "NIGHT3", "NIGHT4"],
    "plaster": ["K1", "NIGHT1", "HILL1", "HILL2", "STONE3", "STONE4", "STONE5", "STONE6", "BONE2"],
    "roof": ["K0", "K1", "NIGHT0", "HILL0", "LEATHER0", "LEATHER1", "RED1", "LEATHER2", "RED2", "LEATHER3"],
    "ground": ["K0", "K1", "NIGHT0", "SETT0", "SETT1", "SETT2", "STONE2", "STONE3", "STONE4", "STONE5"],
    "wood": ["K0", "K1", "WOOD0", "WOOD1", "WOOD2", "WOOD3", "LEATHER2", "WOOD4", "LEATHER3"],
    "plank": ["K0", "K1", "WOOD0", "WOOD1", "LEATHER0", "LEATHER1", "LEATHER2", "LEATHER3", "GOLD2", "GOLD3"],
    "crowd": ["K0", "K1", "NIGHT0", "FLEECE1", "FLEECE2", "FLEECE3"],
    "hill": ["K0", "K1", "HILL0", "HILL1", "HILL2"],
    "iron": ["K0", "K1", "SETT1", "SETT3", "SETT5"],
    # indoors the shadows are warm dark, not night blue
    "inwall": ["K0", "STONE0", "STONE1", "STONE2", "STONE3", "STONE4", "STONE5", "STONE6"],
    "inplaster": ["K0", "STONE0", "STONE1", "STONE2", "STONE3", "STONE4", "STONE5", "STONE6", "BONE2"],
    "infloor": ["K0", "STONE0", "STONE1", "SETT2", "STONE2", "STONE3", "STONE4", "STONE5"],
}


class Light:
    """A light map: ambient plus warm point lights (x, y, reach, strength). value(x, y) in 0..~1.2."""

    def __init__(self, w, h, ambient=0.08):
        self.w, self.h = w, h
        self.ambient = ambient
        self.power = 1.3
        self.src = []
        yy, xx = np.mgrid[0:h, 0:w]
        self.xx, self.yy = xx + 0.5, yy + 0.5
        self._map = None

    def add(self, x, y, reach, strength=1.0, flat=1.0):
        """flat < 1 squashes the light vertically (a fire lights a band of street more than the sky)."""
        self.src.append((x, y, reach, strength, flat))
        self._map = None

    def map(self):
        if self._map is None:
            m = np.full((self.h, self.w), self.ambient, float)
            for (x, y, r, s, fl) in self.src:
                d = np.hypot(self.xx - x, (self.yy - y) / fl) / r
                m += s * np.clip(1.0 - d, 0, 1) ** self.power
            self._map = m
        return self._map

    def at(self, x, y):
        return float(self.map()[int(min(max(y, 0), self.h - 1)), int(min(max(x, 0), self.w - 1))])


def lit_fill(cv, mask, ramp, light, albedo=0.0, gain=1.0, lo=0.0, dither=True):
    """Fills mask from a material ramp by light (array) plus albedo (scalar or array)."""
    names = RAMP[ramp] if isinstance(ramp, str) else ramp
    v = np.clip(lo + light * gain + albedo, 0, 0.999)
    cv.ramp_fill(mask, names, v, dither)


def rnd(seed):
    return np.random.default_rng(seed)


# ------------------------------------------------------------------------------------------ sky

def sky(cv, y0, y1, bands=("NIGHT0", "NIGHT1", "NIGHT2", "NIGHT3"), seed=1, stars=90, clouds=3, warm=None, cloud_top="NIGHT4"):
    """Vertical night gradient from y0 (top, darkest band) to y1 (horizon), dithered between bands,
    with stars and a few long dithered cloud wisps. warm: (x, reach, col) tints the horizon near a fire."""
    w = cv.w
    xx, yy = cv.grid()
    m = (yy >= y0) & (yy < y1)
    t = np.clip((yy + 0.5 - y0) / max(1, (y1 - y0)), 0, 1)
    # bands stretch: the dark top takes more room, like a real night sky
    t = t ** 1.35
    cv.ramp_fill(m, list(bands), t, True)
    r = rnd(seed)
    # clouds: puffy banks of a few overlapping lobes, one band lighter than the sky, lit on top,
    # dithered at the edges
    th4 = BAYER4[yy % 4, xx % 4]
    for i in range(clouds):
        cy = y0 + (y1 - y0) * (0.12 + 0.45 * r.random())
        cx = r.random() * w
        cm = np.zeros_like(m)
        edge = np.zeros(m.shape)
        for j in range(5):
            lx = cx + (j - 2) * (7 + r.random() * 6)
            lr = 5 + r.random() * 6 - abs(j - 2) * 1.2
            ly = cy - lr * 0.3 + r.random() * 2
            d = np.hypot((xx + 0.5 - lx) / (lr * 1.5), (yy + 0.5 - ly) / lr)
            edge = np.maximum(edge, np.clip(1 - d, 0, 1))
        flat = yy + 0.5 < cy + 3
        cm = m & (edge > 0) & flat
        idx = np.clip(np.floor(t * len(bands)).astype(int), 0, len(bands) - 1)
        lighter = [bands[min(k + 1, len(bands) - 1)] for k in range(len(bands))]
        body = cm & (th4 < edge * 3.0)
        for k in range(len(bands)):
            cv._put(body & (idx == k), lighter[k])
        # moonlit tops
        topm = cm & (edge > 0.25) & ~np.roll(cm & (edge > 0.25), 1, axis=0)
        cv._put(topm, cloud_top)
    if warm is not None:
        wx, reach, col = warm
        dm = m & (np.abs(xx + 0.5 - wx) < reach * (1 - (y1 - yy) / (y1 - y0 + 1) * 1.6))
        th4 = BAYER4[yy % 4, xx % 4]
        lvl = np.clip(1 - np.abs(xx + 0.5 - wx) / reach, 0, 1) * np.clip(1 - (y1 - yy) / ((y1 - y0) * 0.55), 0, 1)
        cv._put(dm & (th4 < lvl * 0.7), col)
    # stars
    for i in range(stars):
        x = int(r.random() * w)
        y = int(y0 + (y1 - y0) * (r.random() ** 1.6) * 0.8)
        if not m[min(max(y, 0), cv.h - 1), min(max(x, 0), w - 1)]:
            continue
        b = r.random()
        if b > 0.93:
            cv.pset(x, y, "STAR1")
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv.pset(x + dx, y + dy, "STAR0" if b > 0.97 else "NIGHT4")
        elif b > 0.6:
            cv.pset(x, y, "STAR0")
        else:
            cv.pset(x, y, "NIGHT5")


def moon(cv, x, y, r=5, halo=True):
    if halo:
        xx, yy = cv.grid()
        d = np.hypot(xx + 0.5 - x, yy + 0.5 - y)
        th = BAYER4[yy % 4, xx % 4]
        ring = (d > r) & (d < r * 2.4)
        lvl = np.clip(1 - (d - r) / (r * 1.4), 0, 1) * 0.5
        base = cv.a[:, :, 3] > 0
        cv._put(ring & base & (th < lvl), "NIGHT4")
    cv.shade_ellipse(x, y, r, r, ["NIGHT5", "STAR0", "STAR1"], light=(0.6, -0.4))
    cv.pset(x - 1, y - 1, "STAR0")
    cv.pset(x + 1, y + 2, "STAR0")


# ------------------------------------------------------------------------------------------ land

def ridge(w, base, amp, seed, rough=1.0, peaks=3):
    """A mountain ridge line (array of y per x)."""
    r = rnd(seed)
    x = np.arange(w, dtype=float)
    y = np.zeros(w)
    for k in range(peaks):
        f = (k + 1) * (0.6 + r.random() * 0.8) * 2 * math.pi / w
        y += np.sin(x * f + r.random() * 6.28) * amp / (k + 1) ** 0.8
    # jagged detail: a small random walk
    walk = np.cumsum(r.normal(0, 0.6 * rough, w))
    walk -= np.linspace(walk[0], walk[-1], w)
    y += walk
    return base - (y - y.min()) * 1.0


def mountains(cv, line, fill="HILL1", rim="NIGHT3", dark="HILL0", seed=3, trees=0, tree_col="MOSS0", bottom=None):
    """Fills below a ridge line; a moonlit rim along the crest, darker gullies, dark tree dots."""
    xx, yy = cv.grid()
    top = line[xx]
    bot = cv.h if bottom is None else bottom
    m = (yy + 0.5 >= top) & (yy < bot)
    cv._put(m, fill)
    # gullies: diagonal darker streaks dithered
    r = rnd(seed)
    g = np.sin(xx * 0.33 + yy * 0.5 + r.random() * 6) + np.sin(xx * 0.11 - yy * 0.3)
    th = BAYER4[yy % 4, xx % 4]
    depth = np.clip((yy - top) / 18.0, 0, 1)
    cv._put(m & (g > 0.9) & (th < 0.5 + depth * 0.3), dark)
    cv._put(m & (yy + 0.5 > top + 8) & (th < depth * 0.6), dark)
    # rim: 1 px along the crest where it faces up-left (moonlight)
    crest = m & (yy + 0.5 < top + 1.0)
    cv._put(crest, rim)
    slope = np.gradient(line)
    cv._put(crest & (slope[xx] < 0) & (yy + 0.5 < top + 2.0), rim)
    for i in range(trees):
        x = int(r.random() * cv.w)
        y = int(line[x] + 2 + r.random() * 14)
        if y < bot - 1:
            cv.rect(x - 1, y, 3, 2, tree_col)
            cv.pset(x, y - 1, tree_col)


# ------------------------------------------------------------------------------------------ houses

def house(cv, L, x, base, w, h, roof=6, seed=0, windows=None, door=True, lit=0.75, cool_side=None,
          plaster=False, balcony=False, chimney=False, gable=False, far=False):
    """A stone house of Mamoiada: rough granite courses, a low tile roof (lean or gable), small windows
    (lit warm or dark), a door. x, base: bottom-left; w, h: wall size. Colours come from the light map."""
    r = rnd(seed)
    xx, yy = cv.grid()
    lm = L.map()
    wall = (xx >= x) & (xx < x + w) & (yy >= base - h) & (yy < base)
    # stone courses: mortar lines every 3 px, joints staggered; blocks vary a little
    if far:
        alb = np.where((yy % 4 == 0) & (xx % 2 == 0), -0.05, 0.0)
    else:
        course = (yy - (base - h)) // 3
        joint = ((xx + course * 3 + seed) % 7 == 0)
        mortar = ((yy - (base - h)) % 3 == 2) | joint
        block = np.sin(course * 12.9898 + ((xx + course * 3) // 7) * 78.233 + seed) * 43758.5453
        block = (block - np.floor(block)) * 0.08 - 0.04
        alb = np.where(mortar, -0.09, block)
        if plaster:
            alb = np.where(mortar & (np.sin(xx * 0.7 + yy * 1.3 + seed) > 0.6), -0.07, 0.0)
    lit_fill(cv, wall, "plaster" if plaster else "wall", lm * lit, alb)
    # the wall's far edge in shadow (a corner turning away from the light)
    if cool_side is not None:
        cs = wall & ((xx < x + 2) if cool_side == "l" else (xx >= x + w - 2))
        lit_fill(cv, cs, "wall", lm * lit * 0.55, -0.05)
    # the roof: lean-to or gable, with tile rows and a dark eave
    if gable:
        apex = x + w / 2.0
        pts = [(x - 2, base - h), (apex, base - h - roof), (x + w + 2, base - h)]
        rm = cv.m_poly(pts + [(x + w + 2, base - h + 1), (x - 2, base - h + 1)])
    else:
        rm = cv.m_poly([(x - 2, base - h + 1), (x - 1, base - h - roof), (x + w + 1, base - h - roof + 1), (x + w + 2, base - h + 1)])
    tiles = np.where(((xx + ((yy // 2) % 2)) % 3 == 0) | (yy % 2 == 0), -0.08, 0.02)
    lit_fill(cv, rm, "roof", lm * lit, tiles)
    eave = (xx >= x - 2) & (xx < x + w + 2) & (yy == base - h + 1)
    cv._put(eave & (cv.a[:, :, 3] > 0), "K1")
    # shadow under the eave on the wall
    under = wall & (yy == base - h) & (BAYER4[yy % 4, xx % 4] < 0.6)
    lit_fill(cv, under, "wall", lm * lit * 0.5, -0.1)
    if chimney:
        cx = int(x + w * (0.2 + 0.6 * r.random()))
        ch = cv.m_rect(cx, base - h - roof - 4, 3, 5)
        lit_fill(cv, ch, "wall", lm * lit, -0.05)
        cv.hline(cx - 1, cx + 3, base - h - roof - 5, "K1")
    # windows: rows of small openings; lit ones glow warm with a sill
    if windows is None:
        windows = []
        rows = max(1, int((h - 6) // 11))
        cols = max(1, int(w // 10))
        for j in range(rows):
            for i in range(cols):
                if r.random() < 0.8:
                    wx = x + 3 + i * (w - 6) / max(1, cols) + (w - 6) / max(1, cols) / 2 - 2
                    wy = base - h + 4 + j * 11
                    windows.append((int(wx), int(wy), r.random() < 0.55))
    for (wx, wy, on) in windows:
        ww, wh = (2, 3) if far else (3, 5)
        if on:
            cv.rect(wx, wy, ww, wh, "FIRE5")
            cv.rect(wx, wy, ww, 1, "FIRE6" if not far else "FIRE5")
            if not far:
                cv.rect(wx + 1, wy + 1, 1, wh - 2, "FIRE6")
                cv.pset(wx + 1, wy + 1, "FIRE7")
                cv.vline(wx, wy, wy + wh - 1, "FIRE4")
                cv.hline(wx, wx + ww - 1, wy + wh - 1, "FIRE4")
        else:
            cv.rect(wx, wy, ww, wh, "K1")
            if not far:
                cv.vline(wx + ww - 1, wy, wy + wh - 1, "NIGHT0")
        if not far:
            # stone lintel and sill
            sill = cv.m_rect(wx - 1, wy + wh, ww + 2, 1)
            lit_fill(cv, sill, "wall", lm * lit, 0.08)
            lint = cv.m_rect(wx - 1, wy - 1, ww + 2, 1)
            lit_fill(cv, lint, "wall", lm * lit, 0.05)
    if balcony and not far:
        by = base - h + 11
        bx0, bx1 = x + 3, x + w - 4
        cv.hline(bx0, bx1, by, "K1")
        for bx in range(bx0, bx1 + 1, 2):
            cv.vline(bx, by - 4, by, "K1")
        cv.hline(bx0, bx1, by - 4, "K1")
    if door and not far:
        dw = 5 if w > 16 else 4
        dx = int(x + w * (0.25 + 0.5 * r.random()) - dw / 2)
        dh = min(9, h - 3)
        dm = cv.m_rect(dx, base - dh, dw, dh) | cv.m_ellipse(dx + dw / 2, base - dh, dw / 2, 1.5)
        lit_fill(cv, dm, "plank", lm * lit * 0.7, -0.05)
        cv.vline(dx + dw // 2, base - dh, base - 1, "K1")
        # step
        st = cv.m_rect(dx - 1, base - 1, dw + 2, 1)
        lit_fill(cv, st, "wall", lm * lit, 0.1)


def bell_tower(cv, L, x, base, w=12, h=56, seed=5, lit=0.7, belfry_lit=True):
    """The church tower: a tall stone shaft, an arched belfry with a bell, a small pyramid roof and cross."""
    xx, yy = cv.grid()
    lm = L.map()
    shaft = cv.m_rect(x, base - h, w, h)
    course = (yy // 3)
    alb = np.where((yy % 3 == 2) | ((xx + course * 2) % 5 == 0), -0.08, 0.0)
    lit_fill(cv, shaft, "wall", lm * lit, alb)
    # corner quoins
    for yq in range(base - h, base, 4):
        q = cv.m_rect(x, yq, 2, 2) | cv.m_rect(x + w - 2, yq + 2, 2, 2)
        lit_fill(cv, q & shaft, "wall", lm * lit, 0.1)
    # cornice
    cor = cv.m_rect(x - 1, base - h - 1, w + 2, 2)
    lit_fill(cv, cor, "wall", lm * lit, 0.06)
    # belfry opening
    bx, by = x + w // 2, base - h + 9
    op = cv.m_rect(bx - 3, by - 3, 6, 7) | cv.m_ellipse(bx, by - 3, 3, 3)
    cv._put(op, "FIRE4" if belfry_lit else "K1")
    if belfry_lit:
        cv._put(op & cv.m_rect(bx - 3, by, 6, 4), "FIRE3")
    # the bell
    cv.rect(bx - 1, by - 2, 3, 3, "GOLD2")
    cv.pset(bx, by - 3, "GOLD3")
    cv.hline(bx - 2, bx + 2, by + 1, "GOLD1")
    # a clock/window lower down
    cv.rect(bx - 1, base - h + 22, 3, 4, "FIRE5")
    cv.pset(bx, base - h + 22, "FIRE6")
    # roof and cross
    roof = cv.m_poly([(x - 1, base - h - 1), (bx + 0.5, base - h - 9), (x + w + 1, base - h - 1)])
    lit_fill(cv, roof, "roof", lm * lit, 0.0)
    cv.vline(bx, base - h - 14, base - h - 9, "K1")
    cv.hline(bx - 1, bx + 1, base - h - 12, "K1")


def church(cv, L, x, base, w=40, h=30, seed=6, lit=0.7):
    """A simple stone church front: gable, round window, a big door."""
    xx, yy = cv.grid()
    lm = L.map()
    front = cv.m_rect(x, base - h, w, h) | cv.m_poly([(x - 1, base - h), (x + w / 2, base - h - 12), (x + w + 1, base - h)])
    alb = np.where((yy % 3 == 2) | ((xx + (yy // 3) * 3) % 7 == 0), -0.08, 0.0)
    lit_fill(cv, front, "wall", lm * lit, alb)
    # gable edge
    cv.line(x - 1, base - h, x + w / 2, base - h - 12, "K1")
    cv.line(x + w / 2, base - h - 12, x + w + 1, base - h, "K1")
    cx = x + w // 2
    cv.ellipse(cx + 0.5, base - h - 2, 3, 3, "FIRE4")
    cv.ellipse(cx + 0.5, base - h - 2, 1.5, 1.5, "FIRE6")
    door = cv.m_rect(cx - 5, base - 14, 11, 14) | cv.m_ellipse(cx + 0.5, base - 14, 5.5, 4)
    lit_fill(cv, door, "plank", lm * lit * 0.8, -0.05)
    cv.vline(cx, base - 17, base - 1, "K1")
    arch = door & ~cv.m_rect(cx - 4, base - 16, 9, 16) & ~cv.m_ellipse(cx + 0.5, base - 14, 4.5, 3)
    lit_fill(cv, arch, "wall", lm * lit, 0.12)


# ------------------------------------------------------------------------------------------ ground

def cobbles(cv, L, y0, y1, x0=0, x1=None, seed=4, lit=1.0, persp=1.25, ramp="ground"):
    """Setts laid in rows that grow toward the viewer (perspective); lit by the light map."""
    x1 = cv.w if x1 is None else x1
    xx, yy = cv.grid()
    lm = L.map()
    m = (yy >= y0) & (yy < y1) & (xx >= x0) & (xx < x1)
    # row boundaries: heights grow geometrically downward
    rows = []
    y = y0
    hgt = 1.6
    while y < y1:
        rows.append((int(y), max(1, int(round(hgt)))))
        y += max(1, int(round(hgt)))
        hgt *= persp
    alb = np.zeros((cv.h, cv.w))
    r = rnd(seed)
    for i, (ry, rh) in enumerate(rows):
        sw = max(3, int(rh * 2.2))
        off = int(r.random() * sw)
        band = (yy >= ry) & (yy < ry + rh)
        # joints
        jx = ((xx + off + (i % 2) * sw // 2) % sw == 0)
        alb[band & jx] = -0.18
        # mortar line at the row top
        alb[(yy == ry) & band] = -0.16
        # each sett's top-left highlight and a random tone
        tone = np.sin(((xx + off) // sw) * 91.3 + i * 17.1) * 0.05
        alb[band] += tone[band]
        if rh >= 3:
            alb[(yy == ry + 1) & band & ~jx] += 0.07
    lit_fill(cv, m, ramp, lm * lit, alb)


def ground_band(cv, L, y0, y1, ramp="ground", lit=1.0, alb=0.0):
    xx, yy = cv.grid()
    m = (yy >= y0) & (yy < y1)
    lit_fill(cv, m, ramp, L.map() * lit, alb)


# ------------------------------------------------------------------------------------------ people

def crowd(cv, L, x0, x1, base, size=1.0, seed=8, density=1.0, fire_x=None, rim=True, faces=0.35, lit=1.0,
          kerchiefs=0.25, jitter=2):
    """A row of onlookers, heads and shoulders, dark winter clothes, packed shoulder to shoulder. The side
    toward the fire (fire_x) catches a warm rim on the head and shoulder, and some faces turn to the light.
    size 1: about 12 px tall; 0.5: small far heads."""
    r = rnd(seed)
    lm = L.map()
    x = x0 + r.random() * 3
    step = 5.2 * size / max(0.3, density)
    people = []
    while x < x1:
        hgt = (10 + r.random() * 4) * size
        people.append((x + r.normal(0, 0.7), base + int(r.random() * (jitter + 1) * size), hgt, r.random(), r.random(), r.random()))
        x += step * (0.8 + r.random() * 0.45)
    people.sort(key=lambda p: p[1])
    clothes = [["K0", "K1", "NIGHT0", "NIGHT1", "HILL1"], ["K0", "K1", "FLEECE1", "FLEECE2", "FLEECE3"],
               ["K0", "NAVY0", "NAVY1", "NAVY2", "NAVY3"], ["K0", "K1", "NIGHT0", "HILL0", "HILL1"],
               ["K0", "K1", "FLEECE2", "FLEECE3", "FLEECE4"]]
    xx, yy = cv.grid()
    for (px_, pb, hgt, kind, face, kr) in people:
        hr = max(1.0, 2.0 * size)
        sw = max(2.2, 3.9 * size)
        hy = pb - hgt + hr + 0.5
        sh = pb - hgt + hr * 2.3
        body = cv.m_poly([(px_ - sw, pb + 2), (px_ - sw, sh + 2.0 * size), (px_ - sw + 1.4 * size, sh), (px_ + sw - 1.4 * size, sh),
                          (px_ + sw, sh + 2.0 * size), (px_ + sw, pb + 2)])
        head = cv.m_ellipse(px_, hy, hr, hr * 1.15)
        ly = int(min(max(pb - hgt * 0.6, 0), cv.h - 1))
        light = lm[ly, int(min(max(px_, 0), cv.w - 1))] * lit
        side = 0 if fire_x is None else (1 if fire_x > px_ else -1)
        ramp = clothes[int(kind * len(clothes)) % len(clothes)]
        shawl = kr < kerchiefs and size >= 0.8
        if shawl:
            ramp = ["K0", "RED0", "RED1", "RED2", "RED3"] if kind < 0.5 else ["K0", "NAVY1", "NAVY2", "NAVY3", "NIGHT4"]
        val = np.full(body.shape, 0.25 + light * 0.35)
        if side != 0:
            val = val + np.where((xx + 0.5 - px_) * side > 0.5, light * 0.3, -0.05)
        cv.ramp_fill(body, ramp, np.clip(val, 0, 0.999), False)
        # the far edge of each body is a dark fold, so neighbours in the crowd stay apart
        if side != 0 and size >= 0.6:
            ex = int(round(px_ - side * sw + (0 if side > 0 else -1)))
            for yy_ in range(int(sh + 1), int(pb + 2)):
                if body[min(max(yy_, 0), cv.h - 1), min(max(ex, 0), cv.w - 1)]:
                    cv.pset(ex, yy_, "K0")
        cv._put(head, "K1" if kind < 0.75 else "FLEECE1")
        if shawl and kr < kerchiefs * 0.6:
            cv._put(head & (cv.grid()[1] + 0.5 < hy + 0.3), "RED1" if kind < 0.5 else "NAVY3")
        if size >= 0.8 and face < faces and light > 0.3 and side != 0:
            fxp = int(round(px_ + side * (hr - 0.8)))
            cv.pset(fxp, int(hy), "SKIN1" if light > 0.7 else "SKIN0")
            cv.pset(fxp, int(hy) + 1, "SKIN0")
        if rim and side != 0 and light > 0.28:
            rc = "FIRE2" if light < 0.45 else ("FIRE3" if light < 0.65 else ("FIRE4" if light < 0.95 else "FIRE5"))
            # the fire-side edge of the head and the top of that shoulder
            hx = int(round(px_ + side * hr - (0.5 if side > 0 else -0.5)))
            for y_ in range(int(hy - hr + 0.5), int(hy + hr * 0.6) + 1):
                if head[min(max(y_, 0), cv.h - 1), min(max(hx, 0), cv.w - 1)]:
                    cv.pset(hx, y_, rc)
            sx0 = px_ + side * 1.0
            sx1 = px_ + side * (sw - 0.5)
            for xx_ in range(int(min(sx0, sx1)), int(max(sx0, sx1)) + 1):
                ys = int(sh + (abs(xx_ - px_) > sw - 1.6) * 1)
                if body[min(max(ys, 0), cv.h - 1), min(max(xx_, 0), cv.w - 1)]:
                    cv.pset(xx_, ys, rc)


# ------------------------------------------------------------------------------------------ fire

def logs(cv, cx, base, w, h, seed=11, glow=1.0):
    """The bonfire's stack: long logs leaning in a cone with gaps for the flames, lit along their tops by
    the fire inside, charred dark below, glowing ember tips; short logs crossed at the foot with round
    cut ends; an ember bed."""
    r = rnd(seed)
    n = max(4, int(w / 5))
    for i in range(n):
        t = (i + 0.5) / n
        side = -1 if t < 0.5 else 1
        bx = cx + (t - 0.5) * w * 1.05
        tx = cx + (t - 0.5) * w * 0.2 + r.normal(0, 1.2)
        ty = base - h * (0.75 + 0.35 * r.random())
        cv.line(bx, base, tx, ty, "K1", w=3)
        cv.line(bx, base - 1, tx, ty - 1, "WOOD2", w=2)
        # the edge that faces the fire in the middle glows
        cv.line(bx - side, base - 1, tx - side, ty, "LEATHER3" if abs(t - 0.5) > 0.25 else "FIRE4")
        cv.pset(tx, ty, "FIRE5")
        cv.pset(tx - side, ty + 1, "FIRE4")
    # logs crossed at the foot, cut ends toward the viewer
    for (x0, x1, y) in ((cx - w * 0.65, cx + w * 0.15, base + 1), (cx + w * 0.65, cx - w * 0.15, base + 1),
                        (cx - w * 0.3, cx + w * 0.35, base + 3)):
        cv.line(x0, y, x1, y - 4, "K1", w=4)
        cv.line(x0, y - 1, x1, y - 5, "WOOD2", w=2)
        cv.line(x0, y - 2, x1, y - 6, "LEATHER3")
        cv.ellipse(x0, y - 1.5, 2.2, 2.2, "WOOD3")
        cv.ellipse(x0, y - 1.5, 1.1, 1.1, "WOOD1")
        cv.pset(x0 + 1, y - 3, "LEATHER3")
    # the ember bed under it all
    xx, yy = cv.grid()
    em = cv.m_ellipse(cx, base + 1, w * 0.5, 2.5) & (cv.a[:, :, 3] == 0)
    cv._put(em, "FIRE1")
    cv._put(em & (BAYER4[yy % 4, xx % 4] < 0.5), "FIRE3")
    cv._put(em & cv.m_ellipse(cx, base + 0.5, w * 0.25, 1.5), "FIRE5")


def flame(w, h, t, seed=0, tongues=5, flare=0.0):
    """One frame of a bonfire flame, drawn in a (w x h) canvas with its base centre at (w/2, h-1).
    t in 0..1 loops. flare 0..1: a beat flare, taller with a whiter core. Bands: FIRE2 edge .. FIRE7 core.
    Built column by column: each column of the flame reaches its own height (a few licking tongues that
    rise and fall), the whole flame wavers, and loose licks break off the tips."""
    cv = Canvas(w, h)
    xx, yy = cv.grid()
    cx = w / 2.0
    u = (h - 0.5 - yy) / float(h)            # 0 at base, 1 at top
    ph = 2 * math.pi * t
    r = rnd(seed)
    p1, p2, p3 = r.random() * 6.28, r.random() * 6.28, r.random() * 6.28
    # waver: higher parts sway more
    X0 = (xx + 0.5 - cx) / (w / 2.0)
    X = X0 - 0.16 * u ** 1.4 * np.sin(u * 4.0 - ph + p1) - 0.06 * u * np.sin(u * 9.0 - 2 * ph + p2)
    # narrower at the very base (the fire sits in its logs), fullest a quarter of the way up
    X = X / (0.72 + 0.28 * np.clip(u / 0.22, 0, 1))
    env = np.clip(1 - np.abs(X) ** 1.8, 0, 1) ** 0.7
    # tongues: height per column
    k = tongues
    tong = 0.5 + 0.5 * np.sin(X * k * 2.2 + 1.3 * np.sin(X * 3 + p3) - ph * (1 if seed % 2 else -1))
    tong2 = 0.5 + 0.5 * np.sin(X * k * 3.7 + p2 + ph * 2)
    top = env * (0.45 + 0.38 * tong + 0.17 * tong2) * (0.92 + 0.08 * flare) + 0.1 * flare * env
    I = np.clip(1 - u / np.maximum(top, 0.01), 0, 1)
    # a body: the flame is fullest low down
    body = np.clip(1 - np.abs(X) / (0.95 * np.clip(1 - u * 1.5, 0.0, 1) + 1e-3), 0, 1)
    I = np.maximum(I, body * 0.65)
    # loose licks breaking off above the tongues
    for j in range(3):
        tt = (t * 2 + j / 3.0) % 1.0
        lx = 0.45 * math.sin(p1 + j * 2.1 + ph)
        ly = 0.55 + 0.4 * tt
        d = np.hypot((X0 - lx) / 0.07, (u - ly) / (0.07 * (1 - 0.5 * tt)))
        I = np.maximum(I, np.clip(1 - d, 0, 1) * (0.7 - 0.5 * tt))
    # hot core low in the flame
    core = np.clip(1 - np.hypot(X / (0.42 + 0.1 * flare), (u - 0.18) / (0.3 + 0.15 * flare)), 0, 1)
    I = np.clip(I * 0.75 + core * (0.55 + 0.3 * flare), 0, 1.0)
    m = I > 0.05
    cols = ["FIRE2", "FIRE3", "FIRE4", "FIRE5", "FIRE6", "FIRE7"]
    cv.ramp_fill(m, cols, np.clip(I, 0, 0.999), True)
    cv.clean_orphans()
    return cv


def brazier(cv, x, base, lit_col="FIRE4"):
    """An iron brazier on three legs (the flame is animated separately, sitting at (x, base-10))."""
    cv.line(x - 4, base, x - 2, base - 7, "K1")
    cv.line(x + 4, base, x + 2, base - 7, "K1")
    cv.vline(x, base - 7, base, "K1")
    bowl = cv.m_poly([(x - 5, base - 11), (x + 6, base - 11), (x + 4, base - 7), (x - 3, base - 7)])
    cv._put(bowl, "SETT1")
    cv.hline(x - 5, x + 5, base - 11, "SETT4")
    cv.hline(x - 4, x + 4, base - 10, lit_col)
    cv.pset(x + 4, base - 9, "SETT3")


def torch_post(cv, x, base, h=18):
    """A wall torch: a short wooden stick in an iron ring (flame animated separately)."""
    cv.line(x, base, x, base - h, "WOOD1", w=1)
    cv.pset(x + 1, base - h + 1, "WOOD3")
    cv.hline(x - 1, x + 1, base - h + 4, "SETT3")


def smoke_puff(r=6, seed=0):
    """A soft dithered smoke puff sprite (for drifting smoke). HILL/NIGHT greys, 50% dither."""
    cv = Canvas(r * 2 + 2, r * 2 + 2)
    xx, yy = cv.grid()
    d = np.hypot(xx + 0.5 - (r + 1), (yy + 0.5 - (r + 1)) * 1.2) / r
    rr = rnd(seed)
    n = np.sin(xx * 0.9 + rr.random() * 6) * 0.15 + np.sin(yy * 1.1 + rr.random() * 6) * 0.15
    lvl = np.clip(1 - d + n, 0, 1)
    th = BAYER4[yy % 4, xx % 4]
    cv._put((th < lvl * 0.7) & (d < 1.2), "HILL2")
    cv._put((th < lvl * 0.35) & (d < 1.0), "NIGHT4")
    return cv


def glow_sprite(rx, ry, col="FIRE5", bands=4):
    """A stepped radial glow (for additive light): concentric bands, alpha steps outward."""
    w, h = int(rx * 2) + 2, int(ry * 2) + 2
    cv = Canvas(w, h)
    xx, yy = cv.grid()
    d = np.hypot((xx + 0.5 - w / 2) / rx, (yy + 0.5 - h / 2) / ry)
    from palette import P
    c = P[col]
    for i in range(bands):
        lim = 1.0 - i / bands
        m = d <= lim
        a = int(18 + 16 * i)
        cv.a[m, 0], cv.a[m, 1], cv.a[m, 2], cv.a[m, 3] = c[0], c[1], c[2], a
    return cv


def fog(cv, y0, y1, col="NIGHT3", amount=0.3, seed=9):
    """Low fog: dithered horizontal wisps over what is already drawn."""
    xx, yy = cv.grid()
    r = rnd(seed)
    n = np.sin(xx * 0.05 + r.random() * 6 + yy * 0.1) + np.sin(xx * 0.13 - yy * 0.3 + r.random() * 6) * 0.6
    t = np.clip((yy - y0) / max(1, y1 - y0), 0, 1)
    lvl = np.clip((n * 0.5 + 0.5) * amount * np.sin(t * math.pi), 0, 1)
    th = BAYER4[yy % 4, xx % 4]
    m = (yy >= y0) & (yy < y1) & (th < lvl) & (cv.a[:, :, 3] > 0)
    cv._put(m, col)


# ------------------------------------------------------------------------------------------ figures

def _ramp_maps():
    """Colour -> one step darker colour (same ramp), for dimming baked figures without leaving the palette."""
    from palette import RAMPS, hexrgb
    down = {}
    for name, cols in RAMPS.items():
        for i, c in enumerate(cols):
            down[hexrgb(c)] = hexrgb(cols[max(0, i - 1)])
    return down


def dim(cv, steps=1, keep_rim=False):
    """A figure one (or more) ramp steps darker: the back line of the row, further from the fire."""
    out = cv.copy()
    down = _ramp_maps()
    a = out.a
    for _ in range(steps):
        m = a[:, :, 3] > 0
        cols = np.unique(a[m][:, :3], axis=0)
        new = a.copy()
        for c in cols:
            t = tuple(int(v) for v in c)
            if keep_rim and t in _RIMS:
                continue
            d = down.get(t, t)
            sel = m & np.all(a[:, :, :3] == c, axis=2)
            new[sel, :3] = d
        a = new
    out.a = a
    return out


def _rims():
    from palette import P
    return {P[k] for k in ("FIRE3", "FIRE4", "FIRE5", "FIRE2")}


_RIMS = _rims()


def half(cv):
    """A figure at half size: each 2x2 block takes its most common opaque colour (outline wins ties at the
    silhouette edge so the shape keeps its K0 line), then a clean K0 outline."""
    h, w = cv.h // 2, cv.w // 2
    out = Canvas(w, h)
    a = cv.a
    from palette import P
    k0 = np.array(P["K0"], np.uint8)
    for y in range(h):
        for x in range(w):
            blk = a[y * 2:y * 2 + 2, x * 2:x * 2 + 2].reshape(-1, 4)
            op = blk[blk[:, 3] > 0]
            if len(op) < 2:
                continue
            inner = op[~np.all(op[:, :3] == k0, axis=1)]
            pool = inner if len(inner) >= 1 else op
            vals, counts = np.unique(pool[:, :3], axis=0, return_counts=True)
            # prefer bright accents (bells, rim, mask) when they appear, so small details survive
            best = vals[np.argmax(counts)]
            out.a[y, x, :3] = best
            out.a[y, x, 3] = 255
    # redo the outline cleanly
    s = out.solid()
    out.a[out.is_color("K0")] = 0
    out.outline("K0")
    return out


def silhouette(cv, col="K1", rim=None):
    """The figure as a dark shape (against a bright sky), with an optional 1-px rim kept on its lit side."""
    out = cv.copy()
    m = out.solid()
    rimmask = np.zeros_like(m)
    if rim is not None:
        from palette import P
        for k in ("FIRE2", "FIRE3", "FIRE4", "GOLD4", "GOLD5"):
            rimmask |= out.is_color(k)
    out._put(m & ~rimmask & ~out.is_color("K0"), col)
    if rim is not None:
        out._put(rimmask, rim)
    return out


# ------------------------------------------------------------------------------------------ interior

def small_mask(cv, x, y, s=1.0, wood=("WOOD1", "WOOD2", "WOOD3", "WOOD4"), lit_side=1):
    """A small carved Mamuthone mask (about 8 x 11 px at s=1), for walls and benches. (x, y) top centre."""
    w, h = 4.2 * s, 11 * s
    face = cv.m_poly([(x - w, y + 1 * s), (x + w, y + 1 * s), (x + w + 0.3, y + h * 0.55), (x + w * 0.55, y + h),
                      (x - w * 0.55, y + h), (x - w - 0.3, y + h * 0.55)]) | cv.m_ellipse(x, y + 1.2 * s, w, 1.6 * s)
    cv._put(face, wood[1])
    xx, yy = cv.grid()
    cv._put(face & ((xx + 0.5 - x) * lit_side > w * 0.35), wood[2])
    cv._put(face & ((xx + 0.5 - x) * lit_side > w * 0.75), wood[3])
    cv._put(face & ((xx + 0.5 - x) * lit_side < -w * 0.55), wood[0])
    by = int(y + 3.5 * s)
    cv.hline(int(x - w + 1), int(x + w - 1), by, wood[3])
    for ex in (-2.2, 1.2):
        cv.rect(int(x + ex * s), by + 1, max(1, int(round(1.6 * s))), max(1, int(round(1.4 * s))), "K0")
    cv.vline(int(x), by + 1, int(y + 8 * s), wood[0])
    cv.pset(x + lit_side, y + 7 * s, wood[3])
    cv.hline(int(x - 1.5 * s), int(x + 1.5 * s), int(y + 9.5 * s), "K0")
    cv.outline("K0") if False else None
    return face


def cowbell(cv, x, top, w, h, lit_side=1):
    """A bronze cowbell hanging from (x, top): trapezoid body, rim, dark mouth, highlight."""
    pts = [(x - w * 0.3, top), (x + w * 0.3, top), (x + w * 0.5, top + h), (x - w * 0.5, top + h)]
    m = cv.m_poly(pts) | cv.m_ellipse(x, top + 0.8, w * 0.32, 1.4)
    xx, yy = cv.grid()
    rel = (xx + 0.5 - x) / (w * 0.5) * lit_side
    cv._put(m, "GOLD2")
    cv._put(m & (rel > -0.1), "GOLD3")
    cv._put(m & (rel > 0.4), "GOLD4")
    cv._put(m & (rel > 0.15) & (rel < 0.4) & (yy < top + h * 0.5), "GOLD5")
    cv._put(m & (rel < -0.55), "GOLD1")
    cv.hline(int(round(x - w * 0.5)), int(round(x + w * 0.5)) - 1, int(top + h), "GOLD1")
    cv.pset(x, top + h + 1, "K0")
    return m


def fleece_patch(cv, mask, seed=0, cols=("FLEECE0", "FLEECE1", "FLEECE2", "FLEECE3"), lit=None):
    """Shaggy sheepskin inside mask: dark base, hanging locks with lighter tips."""
    cv._put(mask, cols[1])
    r = rnd(seed)
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        if (x + (y // 3) % 2) % 2 == 0 and y % 3 == 0 and r.random() < 0.7:
            L = 3 + (1 if r.random() < 0.4 else 0)
            for k in range(L):
                if y + k < cv.h and mask[y + k, x]:
                    cv.pset(x, y + k, cols[2] if k < L - 1 else cols[1])
            if y + L < cv.h and mask[y + L, x]:
                cv.pset(x, y + L, cols[0])
    if lit is not None:
        cv._put(mask & lit, cols[3])


def sky_day(cv, y0, y1, seed=1, warm="BONE3"):
    """A cold winter afternoon: blue overhead paling to a warm haze at the horizon; a few flat clouds."""
    sky(cv, y0, y1, bands=("NIGHT4", "NIGHT5", "STAR0", warm), seed=seed, stars=0, clouds=4, cloud_top="STAR1")


def sky_dusk(cv, y0, y1, seed=1):
    """The last light of Shrove Tuesday: night above, a deep red band low down, a hot line at the horizon."""
    sky(cv, y0, y1, bands=("NIGHT0", "NIGHT1", "NIGHT2", "RED0", "RED1", "RED2", "FIRE3"), seed=seed, stars=40, clouds=3, cloud_top="RED3")


def sky_blue_hour(cv, y0, y1, seed=1):
    """Carnival dusk: the blue hour, lighter than night, the last warmth on the horizon."""
    sky(cv, y0, y1, bands=("NIGHT1", "NIGHT2", "NIGHT3", "NIGHT4", "NIGHT5"), seed=seed, stars=25, clouds=4, cloud_top="STAR0")
