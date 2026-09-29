"""The world of the play screen and the title in pixel art: the night sky, the mountains, Mamoiada's
houses and its bell tower, the crowd at the edge of the square, the square's cobbles, the bonfire's
log pyre and the iron braziers. Every piece is a function drawing into a px.Canvas, so the play
screen's backdrop and the title scene are composed from the same parts:

    python3 tools/art/pixel/scenery.py          # bakes game/art/px/scenery/*.png

Light: the bonfire is the one light. Pieces take the fire's position (or a heat 0..1) and draw
themselves warm on the side facing it and cool away from it. For the beat, pieces are baked three
times: base, "lit" (every lit surface one step up its ramp, windows hotter) and "dim" (one step
down). The game swaps pixels between them by an ordered-dither threshold of the fire's light, so the
light pulse on the beat stays pure pixel art: no blending, no off-palette colours.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from palette import P, RAMPS  # noqa: E402
from px import BAYER4, Canvas  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/scenery")


# ------------------------------------------------------------------------------------------ helpers

def ridge(w, seed, base, amp, octaves=((0.013, 1.0), (0.031, 0.45), (0.07, 0.2), (0.17, 0.08))):
    """A mountain ridge line: y per column (smaller = higher), a sum of seeded sines."""
    r = np.random.default_rng(seed)
    x = np.arange(w, dtype=float)
    y = np.zeros(w)
    for f, a in octaves:
        ph = r.random() * math.tau
        ph2 = r.random() * math.tau
        y += a * (np.sin(x * f * math.tau + ph) * 0.6 + np.sin(x * f * 1.7 * math.tau + ph2) * 0.4)
    y = (y - y.min()) / max(1e-6, (y.max() - y.min()))
    return base - y * amp


def bayer(xx, yy):
    return BAYER4[yy % 4, xx % 4]


def band_index(value, n, xx, yy, soft=0.5):
    """Bands a 0..1 field into n levels, dithering the top `soft` share of each band one step up."""
    v = np.clip(value, 0, 0.9999) * n
    idx = np.floor(v).astype(int)
    frac = v - idx
    th = bayer(xx, yy)
    up = (frac > 1 - soft) & (th < (frac - (1 - soft)) / soft)
    return np.clip(idx + up, 0, n - 1)


def ramp_names(name):
    return [f"{name}{i}" for i in range(len(RAMPS[name]))]


def _lv(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, int(i)))]


def _step_map(up=True):
    m = {}
    for name, cols in RAMPS.items():
        for i in range(len(cols)):
            j = min(i + 1, len(cols) - 1) if up else max(i - 1, 0)
            m[P[f"{name}{i}"]] = P[f"{name}{j}"]
    return m


STEP_UP = _step_map(True)
STEP_DOWN = _step_map(False)


def shifted(cv, mask, table):
    """A copy of cv with every pixel under mask recoloured through table (colour -> colour)."""
    out = cv.copy()
    a = out.a
    src = cv.a
    for s, d in table.items():
        m = mask & (src[:, :, 3] > 0) & np.all(src[:, :, :3] == np.array(s, np.uint8), axis=2)
        a[m, :3] = d
    return out


def colour_mask(cv, names):
    m = np.zeros((cv.h, cv.w), bool)
    for n in names:
        m |= cv.is_color(n)
    return m


# ------------------------------------------------------------------------------------------ sky

SKY_BANDS = ["NIGHT0", "NIGHT1", "NIGHT2", "NIGHT3"]
# The fire's haze: navy and hill pixels near the flames warm by steps.
HAZE_MAP = [
    {"NIGHT0": "NIGHT1", "NIGHT1": "NIGHT2", "NIGHT2": "NIGHT3", "NIGHT3": "NIGHT4", "HILL0": "HILL1", "HILL1": "HILL2", "HILL2": "STONE2"},
    {"NIGHT0": "STONE1", "NIGHT1": "STONE1", "NIGHT2": "STONE2", "NIGHT3": "STONE2", "NIGHT4": "STONE3", "HILL0": "STONE1", "HILL1": "STONE2", "HILL2": "STONE3"},
    {"NIGHT0": "RED1", "NIGHT1": "RED1", "NIGHT2": "FIRE1", "NIGHT3": "FIRE1", "NIGHT4": "FIRE2", "STONE1": "FIRE1", "STONE2": "FIRE1", "HILL0": "RED1", "HILL1": "FIRE1", "HILL2": "FIRE2"},
]


def sky(cv, horizon, seed=11, stars=True, moon=None, top=0, avoid=None, density=45, glow=False, curve=1.5):
    """Night sky over rows top..horizon: navy bands deepening upward, dithered at the seams, and
    stars (thinner toward the horizon). avoid: (x, y, rx, ry) kept free of stars (the fire). glow: a
    last, paler band low over the horizon, so the mountains stand dark against it."""
    xx, yy = cv.grid()
    region = (yy >= top) & (yy < horizon)
    bands = SKY_BANDS + (["NIGHT4"] if glow else [])
    t = np.clip((yy - top) / max(1, horizon - top), 0, 1) ** curve
    idx = band_index(t, len(bands), xx, yy, soft=0.5)
    for i, c in enumerate(bands):
        cv._put(region & (idx == i), c)
    if stars:
        r = np.random.default_rng(seed)
        n = int(cv.w * max(1, horizon - top) / density)
        for _ in range(n):
            x = int(r.integers(0, cv.w))
            y = int(top + (r.random() ** 1.8) * (horizon - top) * 0.85)
            if avoid is not None and ((x - avoid[0]) / avoid[2]) ** 2 + ((y - avoid[1]) / avoid[3]) ** 2 < 1:
                continue
            k = r.random()
            if k < 0.05:
                cv.pset(x, y, "STAR1")
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    cv.pset(x + dx, y + dy, "NIGHT4")
            elif k < 0.3:
                cv.pset(x, y, "STAR0")
            elif k < 0.7:
                cv.pset(x, y, "NIGHT5")
            else:
                cv.pset(x, y, "NIGHT4")
    if moon is not None:
        mx, my, mr = moon
        cv.ellipse(mx, my, mr + 2, mr + 2, "NIGHT2")
        cv.ellipse(mx, my, mr + 1, mr + 1, "NIGHT3")
        cv.shade_ellipse(mx, my, mr, mr, ["STAR0", "STAR1"], light=(-0.5, -0.5))
        cv.pset(mx + mr * 0.3, my + mr * 0.1, "STAR0")
        cv.pset(mx - mr * 0.25, my + mr * 0.4, "STAR0")
        cv.pset(mx + mr * 0.1, my - mr * 0.45, "STAR0")


def haze(cv, fire, radii, strength=1.0):
    """Warms the sky and hills near the fire by up to three dithered steps (HAZE_MAP)."""
    xx, yy = cv.grid()
    fx, fy = fire
    d = np.sqrt(((xx + 0.5 - fx) / radii[0]) ** 2 + ((yy + 0.5 - fy) / radii[1]) ** 2)
    g = np.clip(1.0 - d, 0, 1) * strength
    gi = band_index(g, len(HAZE_MAP) + 1, xx, yy, soft=0.7)
    base = cv.copy()
    for lvl in range(1, len(HAZE_MAP) + 1):
        table = {P[a]: P[b] for a, b in HAZE_MAP[lvl - 1].items()}
        out = shifted(base, gi == lvl, table)
        m = gi == lvl
        cv.a[m] = out.a[m]


def peak_ridge(w, seed, base, peaks, rough=1.5):
    """A mountain ridge through explicit peaks [(x, height, half width)]: each a rounded cone (the
    Barbagia's worn granite tops), the ridge the highest of them, roughened a little."""
    x = np.arange(w, dtype=float)
    top = np.zeros(w)
    for (px_, ph, hw) in peaks:
        d = np.clip(1 - np.abs(x - px_) / hw, 0, 1)
        top = np.maximum(top, ph * (d ** 1.35) * (1.6 - 0.6 * d))
    r = np.random.default_rng(seed)
    n = np.zeros(w)
    for f, a in ((0.09, 1.0), (0.23, 0.5)):
        n += a * np.sin(x * f * math.tau + r.random() * math.tau)
    return base - top - n * rough * np.clip(top / 4.0, 0, 1)


def _range(cv, line, bottom, fill, lit, crest, face=3):
    """Fills a mountain range under its ridge line: faces turned up-left (toward the moon) catch
    `lit` in a stepped band under the crest, the crest itself `crest`."""
    xx, yy = cv.grid()
    m = (yy >= np.round(line)[None, :]) & (yy < bottom)
    cv._put(m, fill)
    slope = np.gradient(line)
    depth = face + 2 * (np.clip(slope, 0, 2))[None, :]
    lit_m = m & (slope[None, :] > 0.15) & (yy < np.round(line)[None, :] + depth)
    cv._put(lit_m, lit)
    top = m & (yy == np.round(line)[None, :].astype(int))
    cv._put(top, crest)
    return m


def mountains(cv, horizon, seed=5, far_base=None, far_amp=18, near_amp=8, near_base=None, peaks=None):
    """Three ranges, farther ones paler: the far peaks (NIGHT1 with moonlit faces in NIGHT2 and a
    NIGHT3 crest) stand dark against the sky's paler horizon band, a darker middle range, and a
    near one almost black with a fringe of trees. peaks: explicit [(x, height, half width)] for the far
    range (else a seeded ridge)."""
    far_base = horizon - 4 if far_base is None else far_base
    near_base = horizon - 1 if near_base is None else near_base
    if peaks is not None:
        far = peak_ridge(cv.w, seed, far_base, peaks)
    else:
        far = ridge(cv.w, seed, far_base, far_amp)
    mid = ridge(cv.w, seed + 5, (far_base + near_base) / 2 + 2, max(4, (far_amp + near_amp) * 0.4),
                octaves=((0.017, 1.0), (0.043, 0.35), (0.11, 0.12)))
    near = ridge(cv.w, seed + 7, near_base, near_amp, octaves=((0.02, 1.0), (0.05, 0.4), (0.12, 0.15)))
    _range(cv, far, horizon, "NIGHT1", "NIGHT2", "NIGHT3")
    _range(cv, np.maximum(mid, far + 3), horizon, "NIGHT0", "HILL0", "HILL1", face=2)
    _range(cv, np.maximum(near, far + 5), horizon, "K1", "NIGHT0", "HILL0", face=1)
    r = np.random.default_rng(seed + 3)
    nr = np.maximum(near, far + 5)
    for _ in range(cv.w // 5):
        x = int(r.integers(0, cv.w))
        y = int(round(nr[x]))
        h = int(r.integers(1, 4))
        cv.rect(x, y - h, 1 + int(r.integers(0, 2)), h + 1, "K1")
    return far, near


# ------------------------------------------------------------------------------------------ village

# Walls by heat (0 = moonlight only .. 1 = beside the fire), per material: Mamoiada's houses are
# granite, ochre plaster or whitewash. The front faces the viewer and stays in the night's cool
# shade (dull cool greys, warming only near the fire); the side wall turned toward the fire takes
# its light; SHADE is the eave's shadow and the far edge.
MATERIALS = {
    "granite": {
        "front": ["SETT1", "SETT2", "SETT3", "SETT3", "SETT4", "BONE0", "STONE3"],
        "side": ["SETT2", "SETT4", "STONE3", "STONE4", "BONE1", "STONE5", "STONE5"],
        "shade": ["K1", "SETT0", "SETT1", "SETT1", "SETT2", "STONE1", "STONE2"],
        "course": ["SETT0", "SETT1", "SETT2", "SETT2", "SETT3", "STONE1", "STONE2"],
    },
    "ochre": {
        "front": ["SETT1", "SETT2", "STONE1", "STONE2", "STONE2", "STONE3", "STONE4"],
        "side": ["SETT2", "STONE3", "STONE4", "STONE5", "STONE5", "STONE6", "STONE6"],
        "shade": ["K1", "SETT0", "STONE0", "STONE0", "STONE1", "STONE1", "STONE2"],
    },
    "white": {
        "front": ["SETT2", "SETT3", "SETT4", "SETT5", "BONE0", "BONE0", "BONE1"],
        "side": ["SETT3", "SETT5", "BONE1", "STONE5", "BONE2", "BONE2", "BONE3"],
        "shade": ["SETT0", "SETT1", "SETT2", "SETT2", "SETT3", "STONE2", "STONE2"],
    },
}
FRONT = MATERIALS["granite"]["front"]
SIDE = MATERIALS["granite"]["side"]
SHADE = MATERIALS["granite"]["shade"]
ROOF = ["K1", "RED0", "LEATHER0", "LEATHER1", "LEATHER1", "LEATHER2", "LEATHER2"]
ROOF_LIT = ["RED0", "LEATHER0", "RED1", "LEATHER2", "RED2", "LEATHER3", "FIRE2"]
WALL = SIDE   # (kept for the tower)


def house(cv, x, base, w, h, fire_x, heat, seed=0, roof_h=None, side=None, windows=True, door=True, mat=None):
    """A stone house facing the square: its front wall in the night's shade (granite courses, ochre
    plaster or whitewash), the side wall turned toward the fire lit by it, a terracotta roof with
    tile courses, warm windows. heat 0..1: how much firelight reaches it."""
    r = np.random.default_rng(seed)
    x, base, w, h = int(x), int(base), int(w), int(h)
    roof_h = roof_h if roof_h is not None else max(3, int(round(h * 0.28)))
    side = side if side is not None else max(2, int(round(w * 0.3)))
    toward = 1 if fire_x > x + w / 2 else -1
    if mat is None:
        mat = ["granite", "ochre", "white", "ochre", "granite"][int(r.integers(0, 5))]
    M = MATERIALS[mat]
    k = heat * (len(FRONT) - 1)
    front = _lv(M["front"], k)
    lit = _lv(M["side"], k + 0.5)
    shade = _lv(M["shade"], k)
    top = base - h
    cv.rect(x, top, w, h, front)
    if "course" in M:
        # granite: rough courses of dressed stone, their joints a step darker
        cc = _lv(M["course"], k)
        for j, yy in enumerate(range(top + 3, base - 1, 3)):
            cv.hline(x, x + w - 1, yy, cc)
            for xx in range(x + 2 + (j % 2) * 3, x + w - 1, 6):
                cv.vline(xx, yy - 2, yy - 1, cc)
    # the front's edge nearest the fire catches a warm rim
    if heat > 0.25:
        cv.vline(x + w - 1 if toward > 0 else x, top + 1, base - 2, _lv(M["side"], k - 1))
    if toward > 0:
        sx0, sx1 = x + w, x + w + side
    else:
        sx0, sx1 = x - side, x
    far_x = sx1 if toward > 0 else sx0
    near_x = sx0 if toward > 0 else sx1
    cv.poly([(near_x, top), (far_x, top + 1), (far_x, base), (near_x, base)], lit)
    # the front's far edge in shade, a darker foot where it meets the ground
    cv.vline(x if toward > 0 else x + w - 1, top, base - 1, shade)
    cv.hline(x, x + w - 1, base - 1, shade)
    # the roof: a sloped band over the front with tile courses, the slope running back over the side
    rc = _lv(ROOF, k)
    rl = _lv(ROOF_LIT, k)
    ry = top - roof_h
    cv.poly([(x - 1, top), (x + w + 1, top), (x + w, ry), (x, ry)], rc)
    for j in range(1, roof_h, 2):
        for xx in range(x, x + w):
            if (xx + j) % 2 == 0:
                cv.pset(xx, ry + j, rl)
    if toward > 0:
        cv.poly([(x + w + 1, top), (sx1 + 1, top + 1), (sx1, ry + 1), (x + w, ry)], rl)
    else:
        cv.poly([(x - 1, top), (sx0 - 1, top + 1), (sx0, ry + 1), (x, ry)], rl)
    # the eave's shadow on the wall, the ridge catching the fire
    cv.hline(x, x + w - 1, top, shade)
    cv.hline(x if toward > 0 else sx0, sx1 if toward > 0 else x + w - 1, ry, _lv(ROOF_LIT, k + 1))
    if windows:
        nx = max(1, (w - 2) // 5)
        ny = max(1, (h - 4) // 5)
        for i in range(nx):
            for j in range(ny):
                if r.random() < 0.25:
                    continue
                wx = x + 2 + int(round(i * (w - 5) / max(1, nx - 1))) if nx > 1 else x + w // 2 - 1
                wy = top + 2 + j * 5
                if wy + 2 >= base - 1:
                    continue
                on = r.random() < 0.45 + 0.5 * heat
                cv.rect(wx, wy, 2, 2, "FIRE5" if on else "K1")
                if on:
                    cv.pset(wx, wy + 1, "FIRE4")
                    if heat > 0.4:
                        cv.pset(wx + 1, wy, "FIRE6")
        if side >= 4 and h >= 8:
            sx = (sx0 + sx1) // 2
            cv.rect(sx, top + 3, 1, 2, "FIRE5" if heat > 0.2 else "K1")
    if door and h >= 9 and r.random() < 0.6:
        dx = x + int(r.integers(1, max(2, w - 3)))
        cv.rect(dx, base - 4, 2, 4, "WOOD1" if heat > 0.35 else "K1")
        cv.pset(dx + 1, base - 3, "GOLD2" if heat > 0.35 else "K1")
    return (min(x, sx0) - 1, ry, max(x + w, sx1) + 1, base)


def bell_tower(cv, x, base, w, h, fire_x, heat=0.6, bell_lit=True, cap_k=0.9):
    """Mamoiada's church tower: a tall shaft of dressed granite with string courses, a belfry with
    its bronze bells hanging in arched openings, a cornice, a terracotta pyramid cap and an iron
    cross. The face toward the fire takes its light; the rest stays in the night's cool shade."""
    x, base, w, h = int(x), int(base), int(w), int(h)
    top = base - h
    toward = 1 if fire_x > x + w / 2 else -1
    M = MATERIALS["granite"]
    k = heat * (len(FRONT) - 1)
    front = _lv(M["front"], k)
    lit = _lv(M["side"], k + 1)
    lit2 = _lv(M["side"], k + 2)
    shade = _lv(M["shade"], k)
    course = _lv(M["course"], k)
    cv.rect(x, top, w, h, front)
    sw = max(2, w // 3)
    lx0 = x + w - sw if toward > 0 else x
    cv.rect(lx0, top, sw, h, lit)
    cv.vline(x + w - 1 if toward > 0 else x, top, base - 1, lit2)
    cv.vline(x if toward > 0 else x + w - 1, top, base - 1, shade)
    # ashlar courses on the shaft
    for j, yy in enumerate(range(top + 13, base - 1, 3)):
        cv.hline(x + 1, x + w - 2, yy, course)
        for xx in range(x + 2 + (j % 2) * 2, x + w - 1, 4):
            cv.pset(xx, yy - 1, course)
    # string courses: a lit upper lip, a shadow under
    for yy in (top + 11, top + int(h * 0.62)):
        cv.hline(x - 1, x + w, yy, lit)
        cv.hline(x - 1, x + w, yy + 1, shade)
    # the belfry: two arched openings, a bronze bell in each (one catching the fire)
    bw = max(2, (w - 3) // 2)
    for i in range(2):
        ox = x + 1 + i * (bw + 1)
        oy = top + 3
        cv.rect(ox, oy + 1, bw, 6, "K0")
        cv.hline(ox + 1, ox + max(1, bw - 2), oy, "K0")
        bcx = ox + bw // 2
        near = (i == 1) == (toward > 0)
        cv.rect(ox, oy + 3, bw, 2, "GOLD3" if (bell_lit and near) else "GOLD2")
        cv.pset(bcx, oy + 2, "GOLD2")
        cv.hline(ox, ox + bw - 1, oy + 5, "GOLD1")
        if bell_lit and near:
            cv.pset(ox + (bw - 1 if toward > 0 else 0), oy + 3, "GOLD5")
    # the cornice under the cap
    cv.hline(x - 1, x + w, top, lit)
    cv.hline(x - 1, x + w, top + 1, shade)
    # a lit slit window low on the shaft
    cv.rect(x + w // 2, top + int(h * 0.75), 1, 2, "FIRE5")
    cap_h = max(5, int(round(w * cap_k)))
    cv.poly([(x - 1, top), (x + w + 1, top), (x + w / 2 + 0.5, top - cap_h)], _lv(ROOF, 1 + k))
    if toward > 0:
        cv.poly([(x + w / 2 + 0.5, top - cap_h), (x + w + 1, top), (x + w / 2, top)], _lv(ROOF_LIT, 1 + k))
    else:
        cv.poly([(x + w / 2 + 0.5, top - cap_h), (x - 1, top), (x + w / 2, top)], _lv(ROOF_LIT, 1 + k))
    cx = int(x + w / 2)
    cv.vline(cx, top - cap_h - 4, top - cap_h, "K0")
    cv.hline(cx - 1, cx + 1, top - cap_h - 3, "K0")
    return (x - 1, top - cap_h - 4, x + w + 1, base)


def village(cv, ground_y, fire_x, seed=21, scale=1.0, tower_x=None, gap=(0, 0), heat_r=130.0,
            rows=((0, 1.0), (7, 0.72), (13, 0.5)), tower_h=40, tower_w=8, tower_heat=None, tower_cap=0.9):
    """The village climbing the slope behind the square: rows of houses (farthest first), each row
    higher up and smaller, cooler with distance from the fire; the bell tower behind the near row.
    The middle (gap: x from, to) is left for the bonfire. rows: (rise in px, size)."""
    boxes = []
    for ri in range(len(rows) - 1, -1, -1):
        rise, size = rows[ri]
        r = np.random.default_rng(seed + ri * 101)
        y = ground_y - int(round(rise * scale))
        x = -int(r.integers(0, 10))
        while x < cv.w:
            w = int(round(r.integers(12, 20) * size * scale))
            h = int(round(r.integers(10, 16) * size * scale))
            cx = x + w / 2
            heat = max(0.0, 1.0 - abs(fire_x - cx) / heat_r) * (1.0 - 0.3 * ri)
            if tower_x is not None and ri == 0 and tower_x - w - 4 * scale < x < tower_x + (tower_w + 2) * scale:
                x = int(tower_x + (tower_w + 2) * scale)
                continue
            if not (gap[0] - w < x < gap[1]):
                boxes.append(house(cv, x, y + int(r.integers(-1, 2)), w, h, fire_x, heat, seed=int(r.integers(0, 99999))))
            x += w + int(round(r.integers(4, 9) * size * scale))
        if ri == 1 and tower_x is not None:
            tw = int(round(tower_w * scale))
            heat = max(0.0, 1.0 - abs(fire_x - tower_x) / heat_r) * 0.9 if tower_heat is None else tower_heat
            bell_tower(cv, tower_x, ground_y - int(round(2 * scale)), tw, int(round(tower_h * scale)), fire_x, heat=heat, cap_k=tower_cap)
    return boxes


# ------------------------------------------------------------------------------------------ crowd

def person(cv, x, feet, h, toward, heat, r, back=False):
    """One onlooker, h px tall: a dark coat, a head (bare, capped or in a red kerchief), a face and a
    shoulder catching the fire on the side facing it."""
    body = "K1" if not back else "NAVY0"
    roll = r.random()
    if roll < 0.2:
        body = "FLEECE1"
    elif roll < 0.32:
        body = "NAVY1"
    w = max(4, int(round(h * 0.5)))
    top = feet - h
    head_h = 3 if h >= 9 else 2
    hw = 3 if h >= 9 else 2
    sh = top + head_h
    x = int(round(x))
    x0 = x - w // 2
    # coat: square shoulders, a little narrower at the hem
    cv.rect(x0, sh + 1, w, feet - sh - 1, body)
    cv.hline(x0 + 1, x0 + w - 2, sh, body)
    # head: hair or cap on top, the face below (lit on the fire's side)
    hx = x - hw // 2
    face = _lv(["SKIN0", "SKIN0", "SKIN1", "SKIN1", "SKIN2"], 1 + heat * 3.5)
    shade_face = _lv(["K1", "SKIN0", "SKIN0", "SKIN1"], heat * 3.5)
    cv.rect(hx, top, hw, head_h, face)
    cv.hline(hx, hx + hw - 1, top, "K0")
    far_col = hx if toward > 0 else hx + hw - 1
    cv.vline(far_col, top + 1, top + head_h - 1, shade_face)
    kind = r.random()
    if kind < 0.25:
        cv.hline(hx - 1, hx + hw, top, "K0")             # a black berritta
    elif kind < 0.35:
        cv.rect(hx, top, hw, 2, "RED1")                  # a red kerchief
        cv.pset(hx + (hw - 1 if toward > 0 else 0), top + 1, face)
    elif kind < 0.5 and back:
        cv.rect(hx, top, hw, head_h, "K1")               # turned away
    # the shoulder on the fire's side catches its light
    rim = _lv(["NAVY1", "NAVY2", "STONE2", "STONE3", "FIRE2"], heat * 4.5)
    ex = x0 + w - 1 if toward > 0 else x0
    cv.vline(ex, sh + 1, sh + 2 + int(heat * 3), rim)
    cv.pset(ex - toward, sh, rim)
    if r.random() < 0.15 and not back:
        cv.hline(x0 + 1, x0 + w - 2, sh + 1, "RED2")    # a red scarf


def torch(cv, x, top, bottom):
    """A torch on a pole: a pitch head and a small flame (the game adds its flicker)."""
    cv.vline(x, top, bottom, "WOOD2")
    cv.rect(x - 1, top - 1, 3, 2, "LEATHER1")
    cv.pset(x - 1, top - 2, "FIRE3")
    cv.pset(x + 1, top - 2, "FIRE4")
    cv.pset(x, top - 2, "FIRE6")
    cv.pset(x, top - 3, "FIRE5")
    cv.pset(x - 1, top - 3, "FIRE3")
    cv.pset(x, top - 4, "FIRE4")
    cv.pset(x + 1, top - 5, "FIRE3")


def crowd(cv, x0, x1, feet_y, fire_x, seed=31, scale=1.0, torches=1, heat_r=110.0):
    """Onlookers at the edge of the square, two rows deep (the back row a little higher and
    darker), torches held up among them."""
    r = np.random.default_rng(seed)
    for row in (1, 0):
        y = feet_y - row * int(round(3 * scale))
        x = x0 + int(r.integers(0, 4)) + (3 if row else 0)
        while x < x1:
            heat = max(0.0, 1.0 - abs(fire_x - x) / heat_r)
            h = int(round((11 + r.integers(0, 2) - row) * scale))
            person(cv, x, y, h, 1 if fire_x > x else -1, heat * (0.75 if row else 1.0), r, back=row == 1)
            x += int(round((6 + r.integers(0, 2)) * scale))
    for i in range(torches):
        tx = int(x0 + (i + 0.5) * (x1 - x0) / torches + r.integers(-5, 5))
        torch(cv, tx, feet_y - int(round(15 * scale)), feet_y - int(round(5 * scale)))


# ------------------------------------------------------------------------------------------ ground

STONE_LEVELS = ["SETT1", "SETT2", "SETT3", "STONE1", "STONE2", "STONE3", "STONE4", "STONE5"]
MORTAR_LEVELS = ["K1", "SETT0", "SETT0", "STONE0", "STONE0", "STONE1", "STONE2", "STONE3"]
HI_LEVELS = ["SETT2", "SETT3", "SETT4", "STONE2", "STONE3", "STONE4", "STONE5", "STONE6"]


def fire_light(cv, fire, radii, power=0.9):
    """The bonfire's light on the ground: 1 at the fire, falling off over an ellipse of radii."""
    xx, yy = cv.grid()
    fx, fy = fire
    d = np.sqrt(((xx + 0.5 - fx) / radii[0]) ** 2 + ((yy + 0.5 - fy) / radii[1]) ** 2)
    return np.clip(1.0 - d, 0, 1) ** power


def square(cv, horizon, fire, depth, light_r=(150, 260), seed=41, moss=True, extra_light=None,
           light=None, levels=None, per_stone=False, bottom=None, stone_w=(3.0, 3.5), rounded=False):
    """The square's cobbles in perspective from the horizon row down: courses of rough stones that
    grow toward the viewer, warm near the fire, cool and mossy far from it. Returns the light
    field it used (0..1). light: a light field to use instead of the fire's ellipse; levels: the
    (stone, mortar, top-edge) colour ramps it bands into; per_stone: each stone takes one band (the
    light's value at the stone), so the light falls in steps stone by stone; bottom: last row + 1;
    stone_w: (least, spread) of a stone's width in course units; rounded: knock the corners off
    each stone (the joint's colour), so they read as worn setts rather than bricks."""
    xx, yy = cv.grid()
    fx, fy = fire
    region = (yy >= horizon) & (yy < (cv.h if bottom is None else bottom))
    S_LV, M_LV, H_LV = levels if levels is not None else (STONE_LEVELS, MORTAR_LEVELS, HI_LEVELS)
    nl = len(S_LV)
    course = np.zeros(cv.h, int)
    edge = np.zeros(cv.h, bool)
    y = horizon
    n = 0
    while y < cv.h:
        t = (y - horizon) / max(1.0, depth)
        ch = max(3, int(round(3 + 10 * t ** 1.1)))
        course[y:y + ch] = n
        edge[y] = True
        y += ch
        n += 1
    stone_id = np.zeros((cv.h, cv.w), np.int64)
    joint = np.zeros((cv.h, cv.w), bool)
    for row in range(horizon, cv.h):
        c = course[row]
        t = (row - horizon) / max(1.0, depth)
        scale = 1.6 + 3.4 * t
        rr = np.random.default_rng(seed * 1000 + c)
        bounds = []
        u = -cv.w + rr.random() * 6
        while u < cv.w * 2:
            bounds.append(u)
            u += stone_w[0] + rr.random() * stone_w[1]
        bounds = np.array(bounds)
        xs = (np.arange(cv.w) + 0.5 - fx) / scale
        ids = np.searchsorted(bounds, xs)
        stone_id[row] = ids + c * 10007
        joint[row, 1:] = ids[1:] != ids[:-1]
    if light is None:
        light = fire_light(cv, fire, light_r)
    if extra_light is not None:
        light = np.clip(light + extra_light, 0, 1)
    h = ((stone_id * 2654435761) % (2 ** 32)) / 2 ** 32
    offs = np.where(h < 0.25, -1, np.where(h > 0.8, 1, 0))
    if per_stone:
        # one band per stone: the light at the stone, so its edge steps along the stones
        ids, inv = np.unique(stone_id[region], return_inverse=True)
        mean = np.bincount(inv, weights=light[region]) / np.maximum(np.bincount(inv), 1)
        ls = np.zeros_like(light)
        ls[region] = mean[inv]
        lv = np.clip((np.clip(ls, 0, 0.9999) * nl).astype(int), 0, nl - 1)
        offs = np.where(h < 0.15, -1, np.where(h > 0.9, 1, 0))
    else:
        lv = band_index(light, nl, xx, yy, soft=0.5)
    si = np.clip(lv + offs, 0, nl - 1)
    for i, col in enumerate(S_LV):
        cv._put(region & (si == i), col)
    top_row = np.zeros((cv.h, cv.w), bool)
    top_row[1:] = edge[:-1, None]
    # each stone's lit top edge (toward the fire) and a darker foot: a little bevel
    hi = region & top_row & ~joint & (lv >= 2)
    for i, col in enumerate(H_LV):
        cv._put(hi & (si == i), col)
    foot = np.zeros((cv.h, cv.w), bool)
    foot[:-1] = edge[1:, None]
    lo = region & foot & ~joint
    for i, col in enumerate(S_LV):
        cv._put(lo & (np.clip(si - 1, 0, nl - 1) == i), col)
    mortar = region & (edge[:, None] | joint)
    if rounded:
        side = np.zeros_like(joint)
        side[:, 1:] |= joint[:, :-1]
        side[:, :-1] |= joint[:, 1:]
        mortar |= region & (top_row | foot) & side
    for i, col in enumerate(M_LV):
        cv._put(mortar & (lv == i), col)
    if moss:
        noise = np.random.default_rng(seed + 9).random((cv.h, cv.w))
        edge_w = np.clip(np.abs(xx + 0.5 - fx) / (cv.w * 0.5), 0, 1)
        near = np.clip((yy - horizon) / max(1.0, depth), 0, 1)
        dens = 0.1 + 0.6 * edge_w * near
        mz = mortar & (light < 0.5)
        cv._put(mz & (noise < dens * 0.7), "MOSS1")
        cv._put(mz & (noise < dens * 0.3), "MOSS2")
        tuft = region & ~mortar & (light < 0.35) & (noise > 1 - 0.03 * dens)
        cv._put(tuft, "MOSS0")
    return light


# ------------------------------------------------------------------------------------------ fire pieces

def log(cv, x0, y0, x1, y1, th, heat=1.0, end0=False, end1=True, char=0.0):
    """A split log from (x0, y0) to (x1, y1), th px thick: dark bark, its upper edge lit by the
    flames above it, its underside black, cut ends glowing (end0 / end1). char 0..1 blackens it."""
    ang = math.atan2(y1 - y0, x1 - x0)
    nx, ny = -math.sin(ang), math.cos(ang)
    if ny < 0:                     # (nx, ny) points down-screen: the underside
        nx, ny = -nx, -ny
    h = th / 2.0
    poly = [(x0 - nx * h, y0 - ny * h), (x1 - nx * h, y1 - ny * h), (x1 + nx * h, y1 + ny * h), (x0 + nx * h, y0 + ny * h)]
    m = cv.m_poly(poly)
    xx, yy = cv.grid()
    # position across the log: -1 top .. +1 underside
    L2 = max(1e-6, (x1 - x0) ** 2 + (y1 - y0) ** 2)
    t_along = ((xx + 0.5 - x0) * (x1 - x0) + (yy + 0.5 - y0) * (y1 - y0)) / L2
    across = ((xx + 0.5 - x0) * nx + (yy + 0.5 - y0) * ny) / max(h, 0.5)
    cv._put(m, "WOOD1")
    cv._put(m & (across > 0.35), "WOOD0")
    cv._put(m & (across > 0.75), "K1")
    cv._put(m & (across < -0.2), "WOOD2")
    top = m & (across < -0.55)
    cv._put(top, "FIRE2" if heat > 0.5 else "WOOD3")
    cv._put(top & (across < -0.8) & (heat > 0.8) & ((xx + yy) % 3 != 0), "FIRE3")
    # bark cracks
    cv._put(m & (across > -0.45) & (across < 0.3) & (((xx * 3 + yy * 5) % 7) == 0), "WOOD0")
    if char > 0:
        cv._put(m & (across > -0.5) & (t_along > 0.25) & (t_along < 0.75) & (((xx + 2 * yy) % 5) < char * 4), "K1")
    for (ex, ey, on) in ((x0, y0, end0), (x1, y1, end1)):
        if on:
            cv.ellipse(ex, ey, h + 0.4, h + 0.6, "FIRE3")
            cv.ellipse(ex, ey, max(0.6, h - 0.8), max(0.6, h - 0.6), "FIRE5")
            cv.pset(ex, ey, "FIRE6")


def ember_bed(cv, cx, cy, rx, ry, seed=0, heat=1.0):
    """A bed of glowing coals on the ground, an ellipse (cx, cy, rx, ry): coal lumps (cells of a
    seeded Voronoi) with dark cracks between them, white-hot at the heart, cooling outward through
    the FIRE ramp to a rim of grey ash."""
    r = np.random.default_rng(seed)
    xx, yy = cv.grid()
    d = np.sqrt(((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2)
    m = d <= 1.0
    n = int(rx * ry * 0.4) + 6
    pts = np.stack([cx + (r.random(n) - 0.5) * 2 * rx, cy + (r.random(n) - 0.5) * 2 * ry], 1)
    # nearest and second-nearest lump (cracks where they are nearly equal)
    dx = (xx[..., None] + 0.5 - pts[:, 0]) * 1.0
    dy = (yy[..., None] + 0.5 - pts[:, 1]) * 2.2
    dd = dx * dx + dy * dy
    part = np.partition(dd, 1, axis=2)
    first, second = np.sqrt(part[..., 0]), np.sqrt(part[..., 1])
    crack = (second - first) < 0.9
    cell = np.argmin(dd, axis=2)
    jitter = r.random(n)[cell] * 0.35
    heat_f = np.clip((1.0 - d) * 1.25 * heat + jitter - 0.1, 0, 1)
    cols = ["FIRE1", "FIRE2", "FIRE3", "FIRE4", "FIRE5", "FIRE6"]
    idx = np.clip((heat_f * len(cols)).astype(int), 0, len(cols) - 1)
    for i, c in enumerate(cols):
        cv._put(m & ~crack & (idx == i), c)
    cv._put(m & crack, "K1")
    cv._put(m & crack & (heat_f > 0.45), "FIRE0")
    cv._put(m & crack & (heat_f > 0.8), "FIRE2")
    # grey ash at the rim, crumbling into the cobbles
    rim = m & (d > 0.84)
    cv._put(rim & ~crack, "STONE2")
    cv._put(rim & ((xx + yy) % 3 == 0), "BONE0")
    cv._put(rim & crack, "STONE1")


def pyre(w=92, h=34, seed=51, part="back"):
    """The bonfire's pyre, seated on the ground where the road ends: a tepee of split logs leaning
    into the flames (part 'back', drawn behind them), and in front of their root two logs crossed in
    an X, a log lying end-on with its glowing ring, and a wide bed of coals and ash spilling out on
    the cobbles (part 'front'). The bottom row is the ground line (the road's far end)."""
    cv = Canvas(w, h)
    cx = w / 2
    base = h - 1
    r = np.random.default_rng(seed + (0 if part == "back" else 1))
    if part == "back":
        # the tepee: logs leaning in to a point high in the flames
        for (x0, y0, x1, y1, th) in [
            (cx - 30, base - 3, cx - 3, base - 31, 5),
            (cx + 30, base - 3, cx + 3, base - 31, 5),
            (cx - 18, base - 2, cx + 4, base - 32, 4),
            (cx + 18, base - 2, cx - 4, base - 32, 4),
            (cx - 38, base - 2, cx - 10, base - 22, 4),
            (cx + 38, base - 2, cx + 10, base - 22, 4),
        ]:
            log(cv, x0, y0, x1, y1, th, end0=True, end1=False, char=0.5)
    else:
        # the coal bed heaped under the logs and spilling out over the cobbles
        ember_bed(cv, cx, base + 3, 38, 10.0, seed=seed + 3, heat=0.9)
        # logs laid crosswise at the root, glowing through their gaps
        log(cv, cx - 22, base - 5, cx + 20, base - 9, 4, end0=True, end1=True, char=0.5)
        log(cv, cx + 24, base - 4, cx - 18, base - 11, 4, end0=True, end1=False, char=0.5)
        # two logs crossed in an X in front of the flames' root, ends burning
        log(cv, cx - 30, base - 3, cx + 12, base - 17, 5, end0=True, end1=False, char=0.6)
        log(cv, cx + 30, base - 3, cx - 12, base - 17, 5, end0=True, end1=False, char=0.6)
        # half-burnt logs fallen out of the pile, lying on the ground and pointing in
        log(cv, cx - 45, base - 1, cx - 24, base - 4, 4, end0=False, end1=False, char=0.4)
        log(cv, cx + 45, base - 1, cx + 24, base - 4, 4, end0=False, end1=False, char=0.4)
        log(cv, cx - 16, base, cx - 2, base - 3, 3, end0=True, end1=False, char=0.2)
        # stray embers on the cobbles beyond the bed
        for _ in range(14):
            ex = cx + (r.random() - 0.5) * w * 0.9
            ey = base - r.random() * 3
            if cv.get(int(ex), int(ey)) is None:
                cv.pset(ex, ey, ["FIRE2", "FIRE3", "FIRE4", "FIRE1"][int(r.integers(0, 4))])
    return cv


FLAME_BANDS = ["FIRE1", "FIRE2", "FIRE3", "FIRE4", "FIRE5", "FIRE6", "FIRE7"]


def flame(w, h, t, seed=0, power=1.0):
    """One frame of a small flame (braziers, torches): a licking teardrop through the FIRE ramp,
    white-hot at its root. t in 0..1 loops."""
    cv = Canvas(w, h)
    xx, yy = cv.grid()
    cx = w / 2
    v = (h - 0.5 - yy) / (h * power)
    ph = t * math.tau
    wav = (np.sin((yy * 0.9) - ph * 2 + seed) * 0.5 + np.sin((yy * 0.37) + ph + seed * 2) * 0.5)
    sway = wav * v * (w * 0.14)
    half = (w * 0.46) * np.clip(1 - v, 0, 1) ** 0.7 * (1 + 0.15 * np.sin(ph * 3 + yy * 0.5))
    d = np.abs(xx + 0.5 - cx - sway) / np.maximum(half, 0.01)
    lick = 0.18 * np.sin(xx * 1.7 + ph * 3 + seed) * v
    I = (1 - d) * 1.2 - v * 0.75 + 0.25 + lick
    I = np.where(v < 0, 0, I)
    idx = band_index(np.clip(I, 0, 1), len(FLAME_BANDS) + 1, xx, yy, soft=0.35)
    for i, c in enumerate(FLAME_BANDS):
        cv._put((I > 0.02) & (idx == i + 1), c)
    cv._put((I > 0.02) & (idx == 0), "FIRE1")
    return cv


BRAZIER_COALS = 3     # the coals' row from the brazier sprite's top: where its flames stand


def brazier(w=17, h=25, fire_side=1):
    """A wrought-iron brazier: an open basket of iron bars heaped with glowing coals, on a collar
    and three splayed legs braced by a ring. Black iron with its own fire glinting on the rim and
    bars, and the bonfire's light on the side facing it (fire_side +1: the fire is to the right).
    The flames are the game's (Brazier), standing on the coals."""
    cv = Canvas(w, h)
    cx = w // 2               # the middle column
    top = BRAZIER_COALS
    bowl_b = top + 6          # the basket's bottom row
    # legs: two splayed in front, one straight behind, a brace ring, little feet
    cv.line(cx - 2, bowl_b + 1, cx - 5, h - 2, "K1")
    cv.line(cx + 2, bowl_b + 1, cx + 5, h - 2, "K1")
    cv.vline(cx, bowl_b + 1, h - 2, "K0")
    ring = bowl_b + 8
    cv.hline(cx - 4, cx + 4, ring, "K1")
    cv.pset(cx - 5, h - 2, "K1")
    cv.pset(cx + 5, h - 2, "K1")
    cv.pset(cx - 6, h - 2, "K1")
    cv.pset(cx + 6, h - 2, "K1")
    # the collar under the basket
    cv.rect(cx - 2, bowl_b, 5, 2, "K1")
    # the basket: a trapezoid of bars, coals glowing between them
    for j in range(top, bowl_b):
        t = (j - top) / max(1, bowl_b - top - 1)
        half = int(round(7 - 3 * t))
        glow = ["FIRE3", "FIRE2", "FIRE2", "FIRE1", "FIRE1", "FIRE0"][min(5, j - top)]
        for xx in range(cx - half, cx + half + 1):
            bar = (xx - cx) % 2 == 0 or j == top + 3
            cv.pset(xx, j, "K1" if bar else glow)
    # the rim: a lip of iron catching the coals' light from above, hotter on the fire's side
    cv.hline(cx - 7, cx + 7, top, "LEATHER0")
    for xx in range(cx - 6, cx + 7):
        if (xx - cx) * fire_side > 1:
            cv.pset(xx, top, "GOLD2")
    cv.pset(cx + 7 * fire_side, top, "GOLD3")
    # the bonfire's light down the bars and legs on its side
    for j in range(top + 1, bowl_b):
        t = (j - top) / max(1, bowl_b - top - 1)
        half = int(round(7 - 3 * t))
        cv.pset(cx + half * fire_side, j, "LEATHER1")
    cv.line(cx + 2 * fire_side, bowl_b + 1, cx + 5 * fire_side, h - 2, "LEATHER0")
    cv.pset(cx + 2 * fire_side, bowl_b, "LEATHER1")
    # the heap of coals rising above the rim
    heap = ["FIRE2", "FIRE4", "FIRE3", "FIRE5", "FIRE6", "FIRE5", "FIRE6", "FIRE4", "FIRE5", "FIRE3", "FIRE4", "FIRE2", "FIRE3"]
    for i, col in enumerate(heap):
        xx = cx - 6 + i
        cv.pset(xx, top - 1, col)
        if 3 <= i <= 9:
            cv.pset(xx, top - 2, "FIRE5" if i % 2 else "FIRE4")
    cv.pset(cx, top - 2, "FIRE6")
    cv.outline("K0")
    # no outline over the coals: the flames stand straight on them
    over = np.zeros((cv.h, cv.w), bool)
    over[:top - 1, cx - 5:cx + 6] = True
    cv._put(over & cv.is_color("K0"), None)
    return cv


# ------------------------------------------------------------------------------------------ compositions

PLAY_GROUND_LEVELS = (
    ["SETT2", "STONE1", "STONE2", "STONE3", "STONE4", "STONE5", "STONE6"],
    ["K1", "SETT0", "STONE0", "STONE1", "STONE2", "STONE3", "STONE4"],
    ["SETT3", "STONE2", "STONE3", "STONE4", "STONE5", "STONE6", "STONE6"],
)


def spill_light(cv, fire, radii=(250, 560), power=0.75, lift=0.0):
    """The bonfire's light falling down the square from the road's far end: bright round the fire
    and stepping down the sides to the screen's foot (never quite dark: the square is lit)."""
    return np.clip(fire_light(cv, fire, radii, power) + lift, 0, 1)


def play_strip(W=400, H=84, far_y=68, seed=3):
    """The play screen's back strip: sky, mountains, village with Mamoiada's bell tower, crowd, and
    the back of the square where the pyre stands, W wide centred on the fire, the road's far end on
    row far_y. Returns the canvas and the fire's centre."""
    cv = Canvas(W, H)
    cx = W // 2
    fire = (cx, far_y - 16)
    back = far_y - 8                 # the square's back edge, the houses' feet
    sky(cv, back - 22, seed=seed + 1, avoid=(cx, far_y - 20, 40, 40), glow=True, curve=0.75)
    cv.rect(0, back - 22, W, 22, "NIGHT4")
    # the Barbagia's peaks, placed to show between the figures and the fire on a phone
    peaks = [(cx - 172, 26, 34), (cx - 126, 34, 34), (cx - 86, 26, 24), (cx - 52, 33, 28),
             (cx - 20, 20, 20), (cx + 24, 22, 22), (cx + 58, 34, 30), (cx + 98, 27, 26),
             (cx + 134, 36, 34), (cx + 180, 26, 32)]
    mountains(cv, back, seed=seed + 2, far_base=back - 12, far_amp=16, near_base=back - 12, near_amp=5, peaks=peaks)
    haze(cv, fire, (40, 30), strength=0.55)
    village(cv, back, cx, seed=seed + 3, tower_x=cx - 97, gap=(cx - 26, cx + 26), heat_r=210.0,
            rows=((0, 1.0), (8, 0.8), (15, 0.6)), tower_h=27, tower_w=10, tower_heat=0.62, tower_cap=0.8)
    # the back of the square round the pyre: cobbles in the fire's hottest light
    xx, yy = cv.grid()
    light = fire_light(cv, (cx, far_y), (62, 15), 0.8)
    square(cv, back, (cx, far_y), depth=40, seed=seed + 9, light=light, levels=PLAY_GROUND_LEVELS,
           per_stone=True, bottom=far_y, moss=False, stone_w=(2.3, 1.7), rounded=True)
    crowd(cv, 0, cx - 40, far_y + 1, cx, seed=seed + 4, torches=2)
    crowd(cv, cx + 40, W, far_y + 1, cx, seed=seed + 5, torches=2)
    # the crowd's shadow on the cobbles at their feet, thrown back from the fire
    for x0, x1 in ((0, cx - 40), (cx + 40, W)):
        cv.rect(x0, far_y + 1, x1 - x0, 1, "STONE1")
        for x in range(x0, x1):
            if (x // 2) % 3 != 0:
                cv.pset(x, far_y + 2, "STONE2")
    return cv, fire


def play_ground(W=360, H=480, seed=7):
    """The square either side of the road, from the road's far end (row 0) down: cobbles in
    perspective lit by the bonfire, its light falling in steps stone by stone down the sides of the
    screen, mossy only in the darkest joints. The road is drawn over its middle by the game. Centred
    on the fire (column W/2)."""
    cv = Canvas(W, H)
    fire = (W / 2, -6)
    light = spill_light(cv, fire)
    square(cv, 0, fire, depth=330, seed=seed, light=light, levels=PLAY_GROUND_LEVELS, per_stone=True,
           stone_w=(2.3, 1.7), rounded=True)
    return cv, fire


def pillar(cv, x, top, w, bottom, fire_x, heat=0.6):
    """A squat pillar of dressed stone blocks (a brazier stands on it): ashlar courses with mortar,
    the face toward the fire lit, the other in shadow, a capstone on top."""
    x, top, w, bottom = int(x), int(top), int(w), int(bottom)
    toward = 1 if fire_x > x + w / 2 else -1
    k = heat * 6
    face = _lv(["NIGHT2", "HILL2", "STONE2", "STONE3", "STONE3", "STONE4", "STONE4"], k)
    lit = _lv(["HILL2", "STONE3", "STONE4", "STONE5", "STONE5", "STONE6", "STONE6"], k)
    shade = _lv(["K1", "NIGHT1", "NIGHT2", "STONE1", "STONE1", "STONE2", "STONE2"], k)
    mortar = _lv(["K1", "K1", "STONE0", "STONE1", "STONE1", "STONE2", "STONE2"], k)
    cv.rect(x, top, w, bottom - top, face)
    sw = max(2, w // 4)
    if toward > 0:
        cv.rect(x + w - sw, top, sw, bottom - top, lit)
        cv.rect(x, top, 2, bottom - top, shade)
    else:
        cv.rect(x, top, sw, bottom - top, lit)
        cv.rect(x + w - 2, top, 2, bottom - top, shade)
    y = top + 3
    row = 0
    while y < bottom:
        cv.hline(x, x + w - 1, y, mortar)
        off = 0 if row % 2 == 0 else w // 3
        for jx in range(x + off + w // 2, x + w, max(4, w // 2)):
            cv.vline(jx, y - 5 if y - 5 > top + 3 else top + 3, y, mortar)
        y += 6
        row += 1
    # the capstone
    cv.rect(x - 1, top - 3, w + 2, 3, lit)
    cv.hline(x - 1, x + w, top - 3, _lv(["STONE3", "STONE4", "STONE5", "STONE6", "STONE6", "STONE6", "STONE6"], k))
    cv.hline(x - 1, x + w, top - 1, shade)


def title_scene(W=400, H=250, seed=13):
    """The title's night in the square: sky with stars and the moon, mountains, the village climbing
    behind with the bell tower (right), the crowd round the square, and the cobbles lit by the
    bonfire (the fire, the figures and the braziers are drawn by the game). The picture's bottom
    row is the scene's bottom; the fire's root at FIRE."""
    cv = Canvas(W, H)
    cx = W // 2
    fire = (cx, 192)
    ground = 146
    sky(cv, 112, seed=seed + 1, moon=(cx + 94, 60, 6), avoid=(cx, 120, 50, 110), density=100, glow=True, curve=1.2)
    cv.rect(0, 112, W, ground - 112, "NIGHT4")
    mountains(cv, ground - 38, seed=seed + 2, far_base=88, far_amp=22, near_base=100, near_amp=9)
    cv.rect(0, ground - 38, W, 38, "HILL0")
    haze(cv, (cx, 150), (70, 95), strength=0.9)
    village(cv, ground - 3, cx, seed=seed + 3, scale=1.7, tower_x=cx + 60, gap=(cx - 16, cx + 16), heat_r=170.0,
            rows=((0, 1.0), (9, 0.82), (17, 0.66), (24, 0.5)), tower_h=46)
    # the back wall of the square under the houses
    xx, yy = cv.grid()
    heat = np.clip(1 - np.abs(xx + 0.5 - cx) / 130.0, 0, 1)
    wall = (yy >= ground - 4) & (yy < ground + 1)
    cv._put(wall, "STONE1")
    cv._put(wall & (yy == ground - 4), "STONE2")
    cv._put(wall & (heat > 0.4) & (yy == ground - 4), "STONE4")
    cv._put(wall & (heat > 0.4) & (yy > ground - 4), "STONE2")
    cv._put(wall & (heat < 0.15) & (yy > ground - 4), "HILL0")
    square(cv, ground + 1, fire, depth=110, light_r=(170, 95), seed=seed + 4, extra_light=None)
    crowd(cv, 0, cx - 40, ground + 3, cx, seed=seed + 5, scale=1.35, torches=2, heat_r=150.0)
    crowd(cv, cx + 40, W, ground + 3, cx, seed=seed + 6, scale=1.35, torches=2, heat_r=150.0)
    # pillars for the braziers at the square's front corners
    for sx in (-1, 1):
        px_ = cx + sx * 108 - 9
        pillar(cv, px_, 205, 18, H, cx, heat=0.45)
    return cv, fire


def lit_twins(cv, fire, radius=(90, 50)):
    """The lit and dim twins: every pixel one step up (lit) or down (dim) its ramp; the plain night
    sky, stars and far hills take the fire's pulse only inside its haze."""
    xx, yy = cv.grid()
    fx, fy = fire
    near = ((xx + 0.5 - fx) / radius[0]) ** 2 + ((yy + 0.5 - fy) / radius[1]) ** 2 < 1.0
    keep = colour_mask(cv, ramp_names("NIGHT") + ramp_names("STAR") + ramp_names("HILL") + ["K0", "K1"])
    up = dict(STEP_UP)
    up[P["FIRE5"]] = P["FIRE6"]
    up[P["FIRE6"]] = P["FIRE7"]
    lit = shifted(cv, ~keep | near, up)
    dim = shifted(cv, ~keep, STEP_DOWN)
    return lit, dim


def save_triplet(name, base, lit, dim):
    base.save(os.path.join(OUT, name + ".png"))
    lit.save(os.path.join(OUT, name + "_lit.png"))
    dim.save(os.path.join(OUT, name + "_dim.png"))


def main(preview=None):
    os.makedirs(OUT, exist_ok=True)
    strip, fire = play_strip()
    lit, dim = lit_twins(strip, fire)
    save_triplet("play_strip", strip, lit, dim)
    ground, gfire = play_ground()
    glit, gdim = lit_twins(ground, gfire, radius=(9999, 9999))
    save_triplet("play_ground", ground, glit, gdim)
    # the braziers' pools: two steps up, for the inner ring of their light
    shifted(glit, np.ones((glit.h, glit.w), bool), STEP_UP).save(os.path.join(OUT, "play_ground_hot.png"))
    pyre(part="back").save(os.path.join(OUT, "pyre_back.png"))
    pyre(part="front").save(os.path.join(OUT, "pyre_front.png"))
    brazier(fire_side=1).save(os.path.join(OUT, "brazier.png"))
    brazier(fire_side=-1).save(os.path.join(OUT, "brazier_r.png"))
    title, tfire = title_scene()
    tlit, tdim = lit_twins(title, tfire, radius=(80, 130))
    save_triplet("title_scene", title, tlit, tdim)
    if preview:
        title.save(os.path.join(preview, "title_bake.png"), scale=2)
        strip.save(os.path.join(preview, "strip.png"), scale=3)
        lit.save(os.path.join(preview, "strip_lit.png"), scale=3)
        ground.save(os.path.join(preview, "ground.png"), scale=2)
        big = Canvas(80, 30)
        big.blit(pyre(part="back"), 3, 3)
        big.blit(pyre(part="front"), 3, 3)
        big.save(os.path.join(preview, "pyre.png"), scale=6)
    print("baked scenery to", OUT)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
