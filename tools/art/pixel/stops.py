"""The seven story stops as pixel-art scenes of Mamoiada (docs/design.md section 5, docs/art-style.md):

    python3 tools/art/pixel/stops.py            # writes game/art/px/stops/ and game/scripts/art/stop_cells.gd
    python3 tools/art/pixel/stops.py --preview DIR   # also big previews of every card and world

Each stop is one "world" (W x H art pixels) drawn in layers, so Godot can animate it:
    stop_<n>_bg.png     sky, mountains, houses, the back crowd, the street, the fires' logs
    (fires)             animated flames drawn between bg and mid (fire_<kind>_<frame>.png, shared)
    stop_<n>_mid.png    what stands in front of the flames but behind the row (crowd against the fire)
    (figures)           the row, drawn live from FigureSprites (and the dim/half variants baked here)
    stop_<n>_front.png  the foreground (near crowd, braziers' iron) over the row
and one still, stop_<n>.png (the card: the world cropped to CARD with its figures composed in), which
is what StopArt.card() returns.

The characters come from figures.py (the lead's shared drawing): the card composes them from there and
the dim (back line) and half (far) variants are derived from them here, so after figures.py changes,
re-run bake_figures.py and then this script.
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import figures  # noqa: E402
import stop_scenery as S  # noqa: E402
from px import Canvas  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/stops")
W, H = 320, 184
CARD = (212, 148)          # the card picture's size (art px); 3x on the base screen = 636 x 444

FIRE_KINDS = {             # flame sprite sizes and how many frames loop
    "big": (60, 110, 8),
    "mid": (28, 46, 8),
    "small": (12, 18, 6),
    "tiny": (7, 10, 6),
}


class World:
    def __init__(self, n, name, sky_kind, lit="EMBER"):
        self.n = n
        self.name = name
        self.sky = sky_kind
        self.bg = Canvas(W, H)
        self.mid = Canvas(W, H)
        self.front = Canvas(W, H)
        self.fires = []        # {"x", "y" (flame base centre), "kind"}
        self.glows = []        # {"x", "y", "rx", "ry"}  additive, stepped
        self.smoke = []        # {"x", "y"} smoke sources
        self.card = (0, 0)     # top-left of the card crop
        self.cast = []         # the card's figures: {"sprite", "x", "y", "flip", "var"}
        self.row = {}          # how the procession stands here (ProcessionScene)
        self.ground = 172      # the row's feet
        self.sparks = True
        self.fog = None

    def fire(self, x, y, kind):
        self.fires.append({"x": int(x), "y": int(y), "kind": kind})

    def glow(self, x, y, rx, ry):
        self.glows.append({"x": int(x), "y": int(y), "rx": int(rx), "ry": int(ry)})

    def figure(self, sprite, x, y, flip=False, var=""):
        self.cast.append({"sprite": sprite, "x": int(x), "y": int(y), "flip": bool(flip), "var": var})


# ------------------------------------------------------------------------------------------ figures

_fig_cache = {}


def fig(sprite, var=""):
    """A figure canvas from figures.py by sprite name (as FigureSprites names them), plus a variant:
    "" as drawn, "dim" one ramp step darker (the back line), "half" half size, "halfdim" both,
    "sil" a dark silhouette with its fire rim (against a bright sky)."""
    key = (sprite, var)
    if key in _fig_cache:
        return _fig_cache[key]
    big = sprite.startswith("big_")
    base = sprite[4:] if big else sprite
    size = "big" if big else "field"
    if base.startswith("mamuthone_"):
        rest = base[len("mamuthone_"):]
        pose = rest.split("_")[-1]
        fleece = rest[: -len(pose) - 1]
        cv = figures.mamuthone(pose, fleece=fleece, size=size)
    else:
        pose = base.split("_")[-1]
        cv = figures.issohadore(pose, size=size)
    fx, fy = figures.FEET[size]
    if var in ("half", "halfdim"):
        cv = S.half(cv)
        fx, fy = fx // 2, fy // 2
    if var in ("dim", "halfdim"):
        cv = S.dim(cv, 1)
    if var == "sil":
        cv = S.silhouette(cv, "K1", rim="FIRE2")
    _fig_cache[key] = (cv, fx, fy)
    return _fig_cache[key]


def place(dst, sprite, x, y, flip=False, var=""):
    cv, fx, fy = fig(sprite, var)
    src = cv.flipped() if flip else cv
    ax = (cv.w - 1 - fx) if flip else fx
    dst.blit(src, x - ax, y - fy)


# ------------------------------------------------------------------------------------------ helpers

def night_sky(cv, horizon, seed, moon_at=None, warm_x=None, bands=("NIGHT0", "NIGHT1", "NIGHT2", "NIGHT3"), stars=110):
    S.sky(cv, 0, horizon, bands=bands, seed=seed, stars=stars, clouds=3,
          warm=(warm_x, 70, "NIGHT4") if warm_x is not None else None)
    if moon_at:
        S.moon(cv, *moon_at)


def hills(cv, seed, far_base, near_base, bottom):
    far = S.ridge(W, far_base, 12, seed, rough=0.8, peaks=3)
    S.mountains(cv, far, fill="HILL1", rim="NIGHT3", dark="HILL0", seed=seed, bottom=bottom)
    near = S.ridge(W, near_base, 8, seed + 7, rough=1.0, peaks=4)
    S.mountains(cv, near, fill="HILL0", rim="HILL2", dark="K1", seed=seed + 1, trees=40, bottom=bottom)


def street_row(cv, L, x0, x1, base, seed, hmin=20, hmax=34, far=False, lit=0.8, plaster_every=3, gaps=0):
    """A row of houses along a street, touching or with small gaps."""
    r = np.random.default_rng(seed)
    x = x0
    i = 0
    while x < x1:
        w = int(r.integers(16, 30)) if not far else int(r.integers(10, 18))
        h = int(r.integers(hmin, hmax))
        S.house(cv, L, x, base + int(r.integers(0, 2)), w, h, roof=int(3 + r.integers(0, 4)) if not far else 3,
                seed=seed * 31 + i, far=far, lit=lit, plaster=(i % plaster_every == 1), chimney=r.random() < 0.3,
                gable=r.random() < 0.35)
        x += w + (int(r.integers(0, gaps + 1)) if gaps else 0)
        i += 1


# ------------------------------------------------------------------------------------------ stop 2

def stop2():
    """Sant'Antonio's Fires, 16 January: the great bonfire in the street at night, the houses and the
    crowd round it, the Mamuthones out for the first time in the year."""
    wd = World(2, "Sant'Antonio's Fires", "night")
    G = wd.ground = 172
    fx, fy = 162, 150
    L = S.Light(W, H, ambient=0.16)
    L.add(fx, fy - 26, 200, 1.25, flat=0.75)
    L.add(fx, fy - 10, 70, 0.45)
    bg = wd.bg
    torches = [(40, 124), (122, 128), (206, 128), (292, 122), (96, 110), (226, 110)]
    for (tx, ty) in torches:
        L.add(tx, ty, 34, 0.45)
    night_sky(bg, 122, seed=21, moon_at=(270, 24, 5), warm_x=fx)
    hills(bg, 2, 100, 112, 150)
    # the village climbs the slopes either side of the square; the church tower on the right
    street_row(bg, L, -4, 110, 114, seed=22, hmin=14, hmax=22, far=True)
    street_row(bg, L, 206, 330, 114, seed=23, hmin=14, hmax=22, far=True)
    S.bell_tower(bg, L, 246, 116, w=12, h=54)
    street_row(bg, L, -8, 118, 132, seed=24, hmin=18, hmax=28)
    street_row(bg, L, 206, 330, 132, seed=25, hmin=18, hmax=28)
    # the houses closing the back of the square, full in the fire's light
    S.house(bg, L, 108, 138, 26, 24, roof=5, seed=91, gable=True)
    S.house(bg, L, 134, 138, 22, 20, roof=4, seed=92, plaster=True)
    S.house(bg, L, 176, 138, 24, 22, roof=5, seed=93)
    S.house(bg, L, 200, 138, 22, 26, roof=4, seed=94, gable=True, plaster=True)
    street_row(bg, L, -10, 74, 156, seed=26, hmin=30, hmax=42)
    street_row(bg, L, 254, 330, 156, seed=27, hmin=30, hmax=42)
    # the square
    S.cobbles(bg, L, 138, 156, x0=70, x1=256, seed=28, persp=1.18)
    S.cobbles(bg, L, 156, H, seed=29, persp=1.2)
    for (tx, ty) in torches:
        S.torch_post(bg, tx, ty + 8, 9)
        wd.fire(tx, ty, "tiny")
    # onlookers round the back of the fire and down the sides
    S.crowd(bg, L, 104, 224, 142, size=0.6, seed=30, fire_x=fx, density=1.2)
    S.crowd(bg, L, 70, 124, 150, size=0.8, seed=31, fire_x=fx)
    S.crowd(bg, L, 202, 258, 150, size=0.8, seed=32, fire_x=fx)
    S.crowd(bg, L, -4, 60, 164, size=1.0, seed=33, fire_x=fx, faces=0.5)
    S.crowd(bg, L, 266, 330, 164, size=1.0, seed=34, fire_x=fx, faces=0.5)
    wd.fire(fx, fy, "big")
    S.logs(wd.mid, fx, fy + 2, 46, 20, seed=35)
    wd.glow(fx, fy - 32, 96, 72)
    wd.smoke.append({"x": fx, "y": fy - 76})
    # braziers at the edges of the crowd
    for bx in (60, 266):
        S.brazier(wd.front, bx, G + 10)
        wd.fire(bx + 0.5, G - 1, "small")
        wd.glow(bx, G - 6, 18, 12)
    # the card: two Mamuthones flank the fire, the row behind, an Issohadore throws the rope
    wd.card = (54, 30)
    wd.figure("mamuthone_black_stand", 118, 152, False, "halfdim")
    wd.figure("mamuthone_black_stand", 136, 153, False, "halfdim")
    wd.figure("mamuthone_dark_brown_stand", 196, 152, True, "halfdim")
    wd.figure("mamuthone_black_stand", 88, G + 6)
    wd.figure("issohadore_throw", 212, G + 2, True)
    wd.figure("mamuthone_black_land", 246, G + 8, True)
    wd.row = {"x": 0.44, "ground": G + 6, "front": 3, "back": 3, "isso": 2, "far": True}
    return wd


# ------------------------------------------------------------------------------------------ stop 1

def stop1():
    """The Workshop, the night before: a carver's room lit by the hearth and an oil lamp. A mask being
    finished on the bench, gouges and shavings, masks and bells on the wall, a sheepskin hanging ready;
    through the window the village sleeps under the stars. Your Mamuthone stands dressed by the window."""
    wd = World(1, "The Workshop", "interior")
    G = wd.ground = 174
    wd.sparks = False
    hx, hy = 86, 152          # hearth fire
    lx, ly = 208, 134         # the oil lamp's flame
    L = S.Light(W, H, ambient=0.14)
    L.add(hx, hy - 14, 170, 0.95, flat=0.9)
    L.add(lx, ly, 100, 0.5)
    bg = wd.bg
    xx, yy = bg.grid()
    lm = L.map()
    # the back wall: rough stone below, lime plaster above, a heavy beam and ceiling joists
    wall = bg.m_rect(0, 0, W, 158)
    course = yy // 4
    alb = np.where((yy % 4 == 3) | ((xx + course * 5) % 9 == 0), -0.1, np.sin(course * 3.1 + (xx + course * 5) // 9 * 1.7) * 0.04)
    S.lit_fill(bg, wall & (yy >= 100), "inwall", lm, alb)
    plaster_alb = np.where(np.sin(xx * 0.31 + yy * 0.17) + np.sin(xx * 0.07 - yy * 0.41) > 1.3, -0.07, 0.0)
    S.lit_fill(bg, wall & (yy < 100), "inplaster", lm * 0.8, plaster_alb)
    beam = bg.m_rect(0, 96, W, 5)
    S.lit_fill(bg, beam, "plank", lm, np.where(yy == 96, 0.1, np.where(yy == 100, -0.12, 0.0)))
    top = bg.m_rect(0, 0, W, 9)
    S.lit_fill(bg, top, "plank", lm * 0.7, np.where(yy == 8, -0.15, 0.0))
    for jx in range(8, W, 34):
        j = bg.m_rect(jx, 0, 6, 13)
        S.lit_fill(bg, j, "plank", lm * 0.8, np.where(xx == jx, 0.08, np.where(xx == jx + 5, -0.12, 0.0)))
    # the window: the sleeping village under the stars
    wx0, wy0, ww, wh = 234, 24, 44, 50
    view = Canvas(W, H)
    S.sky(view, 0, wy0 + wh, seed=12, stars=60, clouds=1)
    ridge = S.ridge(W, wy0 + 30, 5, 13)
    S.mountains(view, ridge, fill="HILL1", rim="NIGHT3", dark="HILL0", seed=13)
    Lv = S.Light(W, H, ambient=0.2)
    street_row(view, Lv, wx0 - 4, wx0 + ww + 4, wy0 + wh + 1, seed=14, hmin=10, hmax=15, far=True)
    win = bg.m_rect(wx0, wy0, ww, wh)
    bg.a[win] = view.a[win]
    for (x0, y0, w0, h0, al) in ((wx0 - 3, wy0 - 3, ww + 6, 3, 0.05), (wx0 - 3, wy0 + wh, ww + 6, 4, 0.12),
                                 (wx0 - 3, wy0, 3, wh, 0.0), (wx0 + ww, wy0, 3, wh, -0.05),
                                 (wx0 + ww // 2 - 1, wy0, 2, wh, 0.0), (wx0, wy0 + wh // 2 - 1, ww, 2, 0.0)):
        S.lit_fill(bg, bg.m_rect(x0, y0, w0, h0), "plank", lm, al)
    # the hearth: a stone arch, soot above it, the fire in it
    arch = bg.m_rect(54, 114, 64, 44) | bg.m_ellipse(86, 114, 32, 12)
    S.lit_fill(bg, arch, "inwall", lm, np.where((yy % 3 == 2) | ((xx + (yy // 3) * 4) % 8 == 0), -0.1, 0.05))
    hole = bg.m_rect(62, 120, 48, 38) | bg.m_ellipse(86, 120, 24, 9)
    bg._put(hole, "K0")
    bg._put(hole & (yy > 144), "STONE0")
    soot = bg.m_ellipse(86, 98, 30, 22) & ~arch & wall & (yy < 96)
    bg._put(soot & (BAYER(bg) < 0.5), "STONE1")
    S.logs(bg, hx, hy + 3, 26, 10, seed=15)
    wd.fire(hx, hy, "mid")
    wd.glow(hx, hy - 16, 64, 46)
    bg.vline(86, 114, 128, "K1")
    # the sheepskin (mastruca) hung on a peg beside the hearth, its strap of bells over it
    skin = bg.m_poly([(124, 104), (144, 104), (150, 156), (118, 156)]) | bg.m_ellipse(134, 105, 11, 5)
    S.fleece_patch(bg, skin, seed=16, lit=skin & (xx < 128))
    bg.line(122, 112, 146, 136, "LEATHER1", w=2)
    bg.line(122, 111, 146, 135, "LEATHER2")
    for t in (0.2, 0.45, 0.7, 0.92):
        S.cowbell(bg, 122 + 24 * t, 113 + 24 * t, 5, 6, lit_side=-1)
    bg.pset(134, 99, "SETT4")
    # the shelf of masks: a plank on pegs, masks hanging on nails below it, bells on it
    shelf = bg.m_rect(152, 58, 76, 3)
    S.lit_fill(bg, shelf, "plank", lm, np.where(yy == 58, 0.12, -0.02))
    for px_ in (156, 222):
        bg.rect(px_, 61, 2, 4, "WOOD1")
    for i, mx in enumerate((162, 178, 194, 210)):
        bg.pset(mx, 65, "SETT4")
        S.small_mask(bg, mx, 66, 1.0 + (0.2 if i % 2 else 0), lit_side=-1)
    for (bx, bw, bh) in ((160, 7, 8), (172, 9, 10), (186, 6, 7), (202, 8, 9), (216, 10, 11)):
        S.cowbell(bg, bx, 58 - bh, bw, bh, lit_side=-1)
    # the floor: worn flagstones
    S.cobbles(bg, L, 158, H, seed=17, persp=1.35, ramp="infloor")
    # the bench in front, with the work on it
    fr = wd.front
    top_y = 148
    S.lit_fill(fr, fr.m_rect(124, top_y, 104, 5), "plank", lm, np.where(yy == top_y, 0.15, np.where(yy == top_y + 4, -0.15, 0.0)))
    for lgx in (130, 218):
        S.lit_fill(fr, fr.m_rect(lgx, top_y + 5, 5, H - top_y - 5), "plank", lm * 0.8, -0.05)
    S.lit_fill(fr, fr.m_rect(130, 170, 92, 3), "plank", lm * 0.6, -0.05)
    # the mask on its block, half carved: pale fresh cuts on the dark wood
    blk = fr.m_rect(146, 138, 22, 10)
    S.lit_fill(fr, blk, "plank", lm, np.where(yy == 138, 0.12, 0.0))
    S.small_mask(fr, 157, 119, 1.7, lit_side=-1)
    for (cx_, cy_) in ((152, 129), (160, 131), (155, 134)):
        fr.pset(cx_, cy_, "BONE2")
        fr.pset(cx_ + 1, cy_, "ROPE2")
    # gouges laid out, handles and blades
    for gx in (172, 180, 188):
        fr.line(gx, top_y - 1, gx + 8, top_y - 4, "LEATHER2")
        fr.line(gx + 8, top_y - 4, gx + 11, top_y - 5, "SETT4")
    r = np.random.default_rng(18)
    for i in range(14):
        sx = int(130 + r.random() * 60)
        fr.pset(sx, top_y - 1, "ROPE2" if i % 2 else "ROPE1")
        fr.pset(sx + 1, top_y - 2, "ROPE2")
    for i in range(12):
        fr.pset(int(120 + r.random() * 110), int(176 + r.random() * 6), "ROPE1")
    # the oil lamp: a brass lamp on the bench, its small flame animated
    fr.rect(lx - 3, top_y - 5, 7, 5, "GOLD2")
    fr.hline(lx - 3, lx + 3, top_y - 5, "GOLD4")
    fr.rect(lx + 2, top_y - 4, 1, 3, "GOLD3")
    fr.pset(lx - 4, top_y - 3, "GOLD2")
    fr.pset(lx, top_y - 6, "K1")
    wd.fire(lx, top_y - 7, "tiny")
    wd.glow(lx, top_y - 12, 36, 28)
    # your Mamuthone, dressed and ready by the window, facing the fire
    wd.card = (54, 30)
    wd.figure("mamuthone_black_stand", 246, G, True)
    wd.row = {"x": 0.77, "ground": G, "front": 1, "back": 0, "isso": 0, "far": False, "flip": True}
    return wd


def BAYER(cv):
    xx, yy = cv.grid()
    return S.BAYER4[yy % 4, xx % 4]


# ------------------------------------------------------------------------------------------ stop 3

def stop3():
    """Around the Bonfires, 17 January: a street climbing the hill, a fire at every corner and people
    gathered round each; the procession passing from one fire to the next."""
    wd = World(3, "Around the Bonfires", "night")
    G = wd.ground = 174
    f1 = (84, 158)
    f2 = (214, 124)
    f3 = (290, 98)
    L = S.Light(W, H, ambient=0.14)
    L.add(f1[0], f1[1] - 16, 150, 1.1, flat=0.85)
    L.add(f2[0], f2[1] - 10, 90, 0.9)
    L.add(f3[0], f3[1] - 6, 50, 0.7)
    bg = wd.bg
    night_sky(bg, 110, seed=31, moon_at=(44, 22, 4))
    hills(bg, 4, 92, 102, 124)
    # distant fires dotting the hillside
    for (dx, dy) in ((120, 104), (160, 98), (32, 106)):
        bg.rect(dx, dy, 2, 2, "FIRE5")
        bg.pset(dx, dy - 1, "FIRE3")
    # the road first: a band of setts rising to the right; the houses stand over it
    S.cobbles(bg, L, 96, H, seed=33, persp=1.12)
    xx, yy = bg.grid()
    for i, (x0, b, h) in enumerate(((-6, 150, 40), (24, 146, 34), (150, 132, 30), (176, 126, 30), (238, 112, 28), (262, 106, 26), (288, 100, 24))):
        S.house(bg, L, x0, b, 28 if i < 2 else 26, h, roof=5, seed=300 + i, gable=i % 2 == 0, plaster=i % 3 == 1, chimney=i % 2 == 1)
    for i, (x0, b, h) in enumerate(((52, 138, 22), (80, 136, 24), (108, 134, 26))):
        S.house(bg, L, x0, b, 28, h, roof=5, seed=320 + i, gable=i == 1)
    # onlookers round each fire
    S.crowd(bg, L, 196, 240, 126, size=0.55, seed=34, fire_x=f2[0], density=1.1)
    S.crowd(bg, L, 278, 306, 100, size=0.4, seed=35, fire_x=f3[0], density=1.1)
    S.crowd(bg, L, 20, 130, 158, size=0.9, seed=36, fire_x=f1[0], faces=0.5)
    wd.fire(f2[0], f2[1], "mid")
    S.logs(wd.mid, f2[0], f2[1] + 2, 20, 8, seed=37)
    wd.fire(f3[0], f3[1], "small")
    wd.fire(f1[0], f1[1], "big")
    S.logs(wd.mid, f1[0], f1[1] + 2, 40, 16, seed=38)
    wd.glow(f1[0], f1[1] - 30, 80, 60)
    wd.glow(f2[0], f2[1] - 14, 40, 30)
    wd.smoke.append({"x": f1[0], "y": f1[1] - 80})
    S.crowd(wd.front, L, -6, 40, H + 2, size=1.2, seed=39, fire_x=f1[0], faces=0.6)
    # the card: the row walking left down the street past the near fire
    wd.card = (44, 30)
    wd.figure("mamuthone_black_stand", 242, 130, True, "halfdim")
    wd.figure("mamuthone_black_stand", 226, 134, True, "halfdim")
    wd.figure("issohadore_stand", 260, 128, True, "half")
    wd.figure("mamuthone_black_air", 150, G - 4, True)
    wd.figure("mamuthone_dark_brown_land", 196, G, True)
    wd.figure("issohadore_stand", 240, G + 4, True)
    wd.row = {"x": 0.56, "ground": G + 2, "front": 2, "back": 3, "isso": 1, "flip": True, "far": True}
    return wd


# ------------------------------------------------------------------------------------------ stop 4

def stop4():
    """Carnival Sunday: a cold, bright winter afternoon in the stone streets; the whole procession in its
    two rows between the houses, the Issohadores round them, people at the doors and on the balconies."""
    wd = World(4, "Carnival Sunday", "day")
    G = wd.ground = 174
    wd.sparks = False
    L = S.Light(W, H, ambient=0.62)
    L.add(-80, 40, 460, 0.28)
    bg = wd.bg
    S.sky_day(bg, 0, 108, seed=41)
    # low winter sun behind the hills on the left
    S.moon(bg, 40, 92, 7, halo=True)
    far = S.ridge(W, 96, 10, 42)
    S.mountains(bg, far, fill="NIGHT5", rim="STAR0", dark="NIGHT4", seed=42, bottom=150)
    near = S.ridge(W, 106, 7, 43)
    S.mountains(bg, near, fill="NIGHT4", rim="NIGHT5", dark="NIGHT3", seed=43, trees=30, tree_col="HILL1", bottom=150)
    # the street: houses both sides in the sun, a shadowed side on the right
    xx, yy = bg.grid()
    shade = np.where(xx > 200, 0.62, 1.0)
    Ls = S.Light(W, H, ambient=0.0)
    Ls._map = L.map() * shade
    street_row(bg, Ls, -6, 120, 126, seed=44, hmin=18, hmax=26, lit=0.95)
    street_row(bg, Ls, 196, 330, 126, seed=45, hmin=18, hmax=26, lit=0.95)
    S.bell_tower(bg, Ls, 150, 124, w=12, h=46, lit=0.95, belfry_lit=False)
    S.house(bg, Ls, 120, 128, 28, 22, roof=5, seed=46, gable=True, plaster=True)
    S.house(bg, Ls, 166, 128, 30, 24, roof=5, seed=47, balcony=True)
    street_row(bg, Ls, -10, 70, 150, seed=48, hmin=36, hmax=48, lit=0.95)
    street_row(bg, Ls, 258, 330, 150, seed=49, hmin=36, hmax=48, lit=0.95)
    for bx in (6, 30, 270, 296):
        S.house(bg, Ls, bx, 150, 0, 0, roof=0, seed=50) if False else None
    S.cobbles(bg, Ls, 128, H, seed=50, persp=1.16)
    # cast shadow of the right houses across the street
    sh = bg.m_poly([(200, 128), (330, 128), (330, H), (250, H)])
    Ld = S.Light(W, H, ambient=0.0)
    Ld._map = L.map() * 0.6
    S.cobbles(bg, Ld, 128, H, x0=0, seed=50, persp=1.16) if False else None
    bg.a[sh & (BAYER(bg) < 0.5) & (yy > 128)] = bg.a[sh & (BAYER(bg) < 0.5) & (yy > 128)]
    # people at the doors and along the walls
    S.crowd(bg, L, 70, 124, 132, size=0.7, seed=51, fire_x=None, lit=1.2)
    S.crowd(bg, L, 196, 258, 132, size=0.7, seed=52, fire_x=None, lit=1.2)
    S.crowd(bg, L, -6, 58, 158, size=1.0, seed=53, fire_x=None, lit=1.2)
    S.crowd(bg, L, 268, 330, 158, size=1.0, seed=54, fire_x=None, lit=1.2)
    wd.card = (54, 30)
    wd.figure("mamuthone_black_stand", 130, 140, False, "halfdim")
    wd.figure("mamuthone_black_stand", 146, 141, False, "halfdim")
    wd.figure("mamuthone_black_stand", 162, 140, False, "halfdim")
    wd.figure("mamuthone_black_stand", 150, 150, False, "half")
    wd.figure("mamuthone_black_stand", 168, 151, False, "half")
    wd.figure("issohadore_stand", 190, 150, False, "half")
    wd.figure("mamuthone_black_land", 96, G + 2)
    wd.figure("mamuthone_dark_brown_air", 146, G - 2)
    wd.figure("mamuthone_black_crouch", 196, G + 3)
    wd.figure("issohadore_stand", 244, G + 6)
    wd.row = {"x": 0.5, "ground": G + 4, "front": 3, "back": 3, "isso": 2, "far": True, "day": True}
    return wd


# ------------------------------------------------------------------------------------------ stop 5

def stop5():
    """The Rope: carnival dusk in a narrow lane, torches lit, the crowd close on both sides; an
    Issohadore throws the soha over someone in the crowd while the rows pass behind."""
    wd = World(5, "The Rope", "dusk")
    G = wd.ground = 176
    L = S.Light(W, H, ambient=0.3)
    torches = [(58, 118), (150, 112), (254, 116)]
    for (tx, ty) in torches:
        L.add(tx, ty, 90, 0.75)
    bg = wd.bg
    S.sky_blue_hour(bg, 0, 100, seed=51)
    hills(bg, 6, 88, 98, 120)
    # the lane: tall houses both sides almost closing over it, a glimpse of the street beyond
    street_row(bg, L, 96, 230, 118, seed=55, hmin=14, hmax=20, far=True)
    S.house(bg, L, -8, 150, 44, 64, roof=6, seed=56, balcony=True)
    S.house(bg, L, 36, 146, 32, 54, roof=5, seed=57, plaster=True)
    S.house(bg, L, 68, 138, 30, 40, roof=5, seed=58, gable=True)
    S.house(bg, L, 222, 138, 30, 40, roof=5, seed=59)
    S.house(bg, L, 252, 146, 34, 56, roof=5, seed=60, plaster=True, balcony=True)
    S.house(bg, L, 286, 150, 40, 64, roof=6, seed=61)
    S.cobbles(bg, L, 118, H, seed=62, persp=1.15)
    for (tx, ty) in torches:
        S.torch_post(bg, tx, ty + 9, 10)
        wd.fire(tx, ty, "tiny")
        wd.glow(tx, ty - 3, 22, 18)
    # the crowd pressing in on both sides of the lane
    S.crowd(bg, L, 96, 230, 124, size=0.55, seed=63, fire_x=150, density=1.2)
    S.crowd(bg, L, 40, 120, 146, size=0.85, seed=64, fire_x=150)
    S.crowd(bg, L, 200, 290, 146, size=0.85, seed=65, fire_x=150)
    S.crowd(wd.front, L, -8, 70, H + 3, size=1.3, seed=66, fire_x=150, faces=0.7)
    wd.card = (54, 30)
    wd.figure("mamuthone_black_stand", 116, 128, False, "halfdim")
    wd.figure("mamuthone_black_stand", 132, 129, False, "halfdim")
    wd.figure("mamuthone_dark_brown_stand", 148, 128, False, "halfdim")
    wd.figure("mamuthone_black_air", 104, G - 8)
    wd.figure("issohadore_throw", 196, G, False)
    # someone in the crowd about to be caught by the soha: the rope flies from the Issohadore's loop
    # over to him and drops round his shoulders
    ol = Canvas(26, 32)
    Lo = S.Light(26, 32, ambient=0.35)
    Lo.add(26, 12, 30, 0.8)
    S.crowd(ol, Lo, 10, 13, 29, size=1.6, seed=5, fire_x=40, faces=1.0, kerchiefs=0.0, jitter=0)
    ol.outline("K0")
    wd.mid.blit(ol, 240 - 12, G + 1 - 30)
    arc = [(207, 103), (216, 92), (228, 94), (237, 112), (240, 152)]
    pts = []
    for i in range(len(arc) - 1):
        p0 = arc[max(0, i - 1)]
        p1, p2 = arc[i], arc[i + 1]
        p3 = arc[min(len(arc) - 1, i + 2)]
        for k in range(4):
            t = k / 4
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            pts.append((round(x), round(y)))
    # the noose round his shoulders
    for k in range(13):
        a = math.pi * 2 * k / 12 - math.pi / 2
        pts.append((round(240 + 7 * math.cos(a)), round(161 + 3 * math.sin(a))))
    wd.rope = pts
    wd.row = {"x": 0.3, "ground": G - 30, "front": 2, "back": 2, "isso": 2, "far": True,
              "isso_at": [0.62, G], "onlooker": [0.84, G - 2]}
    return wd


# ------------------------------------------------------------------------------------------ stop 6

def stop6():
    """The Piazza: the square before the church at night, the crowd at its thickest all round, braziers
    burning, the two rows in the middle ringing together."""
    wd = World(6, "The Piazza", "night")
    G = wd.ground = 174
    L = S.Light(W, H, ambient=0.18)
    braz = [(40, 160), (120, 146), (204, 146), (282, 160)]
    for (bx, by) in braz:
        L.add(bx, by - 8, 80, 0.8)
    L.add(160, 150, 150, 0.45, flat=0.6)
    bg = wd.bg
    night_sky(bg, 104, seed=61, moon_at=(56, 20, 5))
    hills(bg, 8, 88, 98, 128)
    street_row(bg, L, -6, 110, 122, seed=66, hmin=14, hmax=22, far=True)
    street_row(bg, L, 214, 330, 122, seed=67, hmin=14, hmax=22, far=True)
    # the church: its front and its bell tower close the square
    S.church(bg, L, 126, 136, w=48, h=32)
    S.bell_tower(bg, L, 178, 136, w=14, h=66)
    street_row(bg, L, -8, 124, 140, seed=68, hmin=22, hmax=32, balcony=None) if False else street_row(bg, L, -8, 124, 140, seed=68, hmin=22, hmax=32)
    street_row(bg, L, 196, 330, 140, seed=69, hmin=22, hmax=32)
    S.cobbles(bg, L, 136, H, seed=70, persp=1.14)
    # the crowd, thickest here: rows of heads round the square
    S.crowd(bg, L, 100, 226, 140, size=0.55, seed=71, fire_x=160, density=1.3)
    S.crowd(bg, L, 0, 110, 146, size=0.7, seed=72, fire_x=160, density=1.2)
    S.crowd(bg, L, 210, 330, 146, size=0.7, seed=73, fire_x=160, density=1.2)
    S.crowd(bg, L, -6, 90, 156, size=0.9, seed=74, fire_x=160)
    S.crowd(bg, L, 230, 330, 156, size=0.9, seed=75, fire_x=160)
    for (bx, by) in braz:
        S.brazier(bg if by < 150 else wd.front, bx, by + 10)
        wd.fire(bx + 0.5, by - 1, "small")
        wd.glow(bx, by - 6, 20, 14)
    S.crowd(wd.front, L, -8, 60, H + 3, size=1.25, seed=76, fire_x=160, faces=0.6)
    S.crowd(wd.front, L, 262, 330, H + 3, size=1.25, seed=77, fire_x=160, faces=0.6)
    wd.card = (54, 30)
    for i, x in enumerate((110, 128, 146, 164, 182)):
        wd.figure("mamuthone_black_stand" if i % 2 else "mamuthone_black_land", x, 150 + (i % 2), False, "half")
    wd.figure("issohadore_stand", 200, 152, False, "half")
    wd.figure("mamuthone_black_land", 104, G)
    wd.figure("mamuthone_dark_brown_land", 148, G + 1)
    wd.figure("mamuthone_black_land", 192, G)
    wd.figure("issohadore_throw", 236, G + 4)
    wd.row = {"x": 0.5, "ground": G + 2, "front": 3, "back": 3, "isso": 2, "far": True}
    return wd


# ------------------------------------------------------------------------------------------ stop 7

def stop7():
    """Shrove Tuesday: the last procession walks out of the village at dusk under a red sky, dark against
    the last light, fog on the road; after it the masks are put away until January."""
    wd = World(7, "Shrove Tuesday", "dusk")
    G = wd.ground = 172
    L = S.Light(W, H, ambient=0.08)
    L.add(250, 104, 150, 0.35, flat=0.6)
    L.add(26, 150, 70, 0.8)
    L.add(118, 140, 130, 1.0)
    bg = wd.bg
    S.sky_dusk(bg, 0, 118, seed=71)
    # the sun just gone: a hot line on the horizon
    far = S.ridge(W, 106, 10, 72)
    S.mountains(bg, far, fill="RED0", rim="FIRE3", dark="K1", seed=72, bottom=150)
    near = S.ridge(W, 116, 6, 73)
    S.mountains(bg, near, fill="K1", rim="RED1", dark="K0", seed=73, trees=30, tree_col="K0", bottom=150)
    # the village behind, dark, a few windows lit
    street_row(bg, L, -8, 110, 136, seed=74, hmin=18, hmax=30)
    S.bell_tower(bg, L, 60, 132, w=12, h=48, lit=0.6)
    # the road out, toward the light
    S.cobbles(bg, L, 132, H, seed=75, persp=1.16)
    xx, yy = bg.grid()
    # the last bonfire left burning at the edge of the village
    wd.fire(26, 150, "mid")
    S.logs(wd.mid, 26, 152, 20, 8, seed=76)
    wd.glow(26, 136, 40, 30)
    S.crowd(bg, L, -6, 70, 150, size=0.8, seed=77, fire_x=26)
    # the last great fire, on the road out: the row passes it one last time
    wd.fire(118, 160, "big")
    S.logs(wd.mid, 118, 162, 34, 12, seed=79)
    wd.glow(118, 120, 80, 60)
    wd.smoke.append({"x": 118, "y": 70})
    S.crowd(bg, L, 84, 160, 148, size=0.7, seed=80, fire_x=118)
    S.fog(bg, 124, 156, col="RED0", amount=0.4, seed=78)
    wd.fog = {"y0": 140, "y1": H, "col": "RED1"}
    wd.card = (80, 30)
    wd.figure("mamuthone_black_stand", 244, 146, False, "halfdim")
    wd.figure("mamuthone_black_stand", 258, 145, False, "halfdim")
    wd.figure("issohadore_stand", 276, 144, False, "half")
    wd.figure("mamuthone_black_air", 166, G - 4, True)
    wd.figure("mamuthone_black_land", 204, G, True)
    wd.figure("issohadore_stand", 240, G + 2, True)
    wd.row = {"x": 0.58, "ground": G + 2, "front": 3, "back": 2, "isso": 1, "far": True, "flip": True}
    return wd


# ------------------------------------------------------------------------------------------ output

def draw_rope(cv, pts):
    """The soha in flight: natural hemp, two tones, a K0 edge underneath, through pts (a Catmull-Rom)."""
    line = cv.curve(pts, "K0", w=2)
    shifted = [(x, y - 1) for (x, y) in pts]
    cv.curve(shifted, "ROPE1", w=1)
    top = [(x, y - 2) for (x, y) in pts]
    lp = cv.curve(top, "ROPE2", w=1)
    return line


def compose(wd, frame=0, cast=True):
    """The world with its flames at `frame`, the cast composed in (the card's scene)."""
    full = Canvas(W, H)
    full.blit(wd.bg, 0, 0)
    for f in wd.fires:
        fw, fh, n = FIRE_KINDS[f["kind"]]
        fl = fire_frame(f["kind"], frame % n)
        full.blit(fl, f["x"] - fw // 2, f["y"] - fh + 1)
    full.blit(wd.mid, 0, 0)
    if cast:
        for c in sorted(wd.cast, key=lambda c: (c["var"] not in ("half", "halfdim"), c["y"])):
            place(full, c["sprite"], c["x"], c["y"], c["flip"], c["var"])
        if getattr(wd, "rope", None):
            draw_rope(full, wd.rope)
    full.blit(wd.front, 0, 0)
    return full


def compose_card(wd, frame=0):
    full = compose(wd, frame)
    x0, y0 = wd.card
    out = Canvas(*CARD)
    out.a = full.a[y0:y0 + CARD[1], x0:x0 + CARD[0]].copy()
    return out, full


_fire_cache = {}


def fire_frame(kind, i, flare=False):
    key = (kind, i, flare)
    if key not in _fire_cache:
        fw, fh, n = FIRE_KINDS[kind]
        seed = {"big": 1, "mid": 2, "small": 3, "tiny": 4}[kind]
        _fire_cache[key] = S.flame(fw, fh, i / n, seed=seed, tongues=5 if kind == "big" else (4 if kind == "mid" else 2),
                                   flare=1.0 if flare else 0.0)
    return _fire_cache[key]


STOPS = {1: stop1, 2: stop2, 3: stop3, 4: stop4, 5: stop5, 6: stop6, 7: stop7}

FIG_BASE = ["mamuthone_%s_%s" % (f, p) for f in ("black", "dark_brown") for p in figures.MAM_POSES] + \
    ["issohadore_%s" % p for p in figures.ISS_POSES]
FIG_VARS = ("dim", "half", "halfdim", "ghost")


def ghost(cv):
    """Your best run's ghost: the figure's shape as a pale dithered veil (palette only, no alpha)."""
    out = Canvas(cv.w, cv.h)
    m = cv.solid()
    xx, yy = out.grid()
    edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    out._put(m & ((xx + yy) % 2 == 0), "NIGHT4")
    out._put(edge, "NIGHT5")
    return out


def gd_color(name):
    from palette import P
    r, g, b = P[name] if isinstance(name, str) else name
    return 'Color("#%02x%02x%02x")' % (r, g, b)


def export(worlds):
    """Writes every layer, the shared flame/glow/smoke sprites, the figure variants and stop_cells.gd."""
    os.makedirs(os.path.join(OUT, "figs"), exist_ok=True)
    lines = []
    glows = {}
    for n, wd in sorted(worlds.items()):
        card, _ = compose_card(wd)
        card.save(os.path.join(OUT, "stop_%d.png" % n))
        layers = []
        for lname in ("bg", "mid", "front"):
            cv = getattr(wd, lname)
            if lname == "bg" or cv.solid().any():
                cv.save(os.path.join(OUT, "stop_%d_%s.png" % (n, lname)))
                layers.append(lname)
            elif os.path.exists(os.path.join(OUT, "stop_%d_%s.png" % (n, lname))):
                os.remove(os.path.join(OUT, "stop_%d_%s.png" % (n, lname)))
        top = tuple(int(v) for v in wd.bg.a[0, W // 2, :3])
        gl = []
        for g in wd.glows:
            gname = "glow_%dx%d" % (g["rx"], g["ry"])
            glows[gname] = (g["rx"], g["ry"])
            gl.append('[%d, %d, "%s"]' % (g["x"], g["y"], gname))
        fires = ", ".join('[%d, %d, "%s"]' % (f["x"], f["y"], f["kind"]) for f in wd.fires)
        smoke = ", ".join("[%d, %d]" % (sm["x"], sm["y"]) for sm in wd.smoke)
        cast = ", ".join('["%s", %d, %d, %s, "%s"]' % (c["sprite"], c["x"], c["y"], "true" if c["flip"] else "false", c["var"]) for c in wd.cast)
        rope = ", ".join("Vector2(%d, %d)" % (x, y) for (x, y) in getattr(wd, "rope", []) or [])
        row = []
        for k, v in wd.row.items():
            if isinstance(v, bool):
                row.append('"%s": %s' % (k, "true" if v else "false"))
            elif isinstance(v, (int, float)):
                row.append('"%s": %s' % (k, v))
            elif isinstance(v, str):
                row.append('"%s": "%s"' % (k, v))
            else:
                row.append('"%s": [%s]' % (k, ", ".join(str(x) for x in v)))
        lines.append('\t%d: {"name": "%s", "sky": "%s", "ground": %d, "card": Vector2i(%d, %d), "top": %s, "sparks": %s,\n'
                     '\t\t"layers": [%s], "fires": [%s],\n\t\t"glows": [%s], "smoke": [%s],\n\t\t"cast": [%s],\n'
                     '\t\t"rope": [%s], "row": {%s}},' % (
                         n, wd.name.replace('"', ''), wd.sky, wd.ground, wd.card[0], wd.card[1], gd_color(top),
                         "true" if wd.sparks else "false", ", ".join('"%s"' % l for l in layers), fires, ", ".join(gl), smoke, cast,
                         rope, ", ".join(row)))
    # flames: every frame, plus one flare frame per kind (the beat)
    fire_lines = []
    for kind, (fw, fh, nfr) in FIRE_KINDS.items():
        for i in range(nfr):
            fire_frame(kind, i).save(os.path.join(OUT, "fire_%s_%d.png" % (kind, i)))
        for i in range(2):
            S.flame(fw, fh, i / 2.0, seed={"big": 1, "mid": 2, "small": 3, "tiny": 4}[kind],
                    tongues=5 if kind == "big" else (4 if kind == "mid" else 2), flare=1.0).save(
                os.path.join(OUT, "fire_%s_flare%d.png" % (kind, i)))
        fire_lines.append('\t"%s": [Vector2i(%d, %d), %d],' % (kind, fw, fh, nfr))
    for gname, (rx, ry) in glows.items():
        S.glow_sprite(rx, ry, "FIRE5", bands=4).save(os.path.join(OUT, gname + ".png"))
    for i in range(3):
        S.smoke_puff(5 + i * 2, seed=i).save(os.path.join(OUT, "smoke_%d.png" % i))
    # figure variants derived from figures.py (the back line, far figures, the ghost)
    fig_lines = []
    for base in FIG_BASE:
        for var in FIG_VARS:
            if var == "ghost":
                cv0, fx, fy = fig(base, "")
                cv = ghost(cv0)
            else:
                cv, fx, fy = fig(base, var)
            name = "%s_%s" % (var, base)
            cv.save(os.path.join(OUT, "figs", name + ".png"))
            fig_lines.append('\t"%s": [Vector2i(%d, %d), Vector2i(%d, %d)],' % (name, cv.w, cv.h, fx, fy))
    # an onlooker for the rope to catch (the Rope stop's procession)
    ol = Canvas(26, 32)
    Lo = S.Light(26, 32, ambient=0.35)
    Lo.add(26, 12, 30, 0.8)
    S.crowd(ol, Lo, 10, 13, 29, size=1.6, seed=5, fire_x=40, faces=1.0, kerchiefs=0.0, jitter=0)
    ol.outline("K0")
    ol.save(os.path.join(OUT, "figs", "onlooker.png"))
    fig_lines.append('\t"onlooker": [Vector2i(%d, %d), Vector2i(%d, %d)],' % (ol.w, ol.h, 12, 30))
    gd = """class_name StopCells
extends RefCounted
## Generated by tools/art/pixel/stops.py - do not edit; re-run it (after bake_figures.py when the
## figures change). The seven story worlds in art pixels: layers res://art/px/stops/stop_<n>_<layer>.png
## (bg behind the flames, mid in front of them, front over the row), their fires, glows, smoke, the
## card's cast and crop, and how the procession stands there (row).

const DIR := "res://art/px/stops/"
const WORLD := Vector2i(%d, %d)
const CARD := Vector2i(%d, %d)
## Flame sprites: fire_<kind>_<frame>.png (and fire_<kind>_flare0/1.png for the beat): [size, frames].
const FIRES := {
%s
}
## Figure variants derived from figures.py: figs/<var>_<sprite>.png: [cell size, feet].
const FIGS := {
%s
}
const STOPS := {
%s
}
""" % (W, H, CARD[0], CARD[1], "\n".join(fire_lines), "\n".join(fig_lines), "\n".join(lines))
    with open(os.path.join(ROOT, "scripts/art/stop_cells.gd"), "w") as f:
        f.write(gd)


def main():
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(preview, exist_ok=True)
    only = [int(a) for a in sys.argv[1:] if a.isdigit()]
    os.makedirs(OUT, exist_ok=True)
    worlds = {}
    for n, fn in sorted(STOPS.items()):
        wd = fn()
        worlds[n] = wd
        if preview and (not only or n in only):
            card, full = compose_card(wd)
            card.save(os.path.join(preview, "card_%d.png" % n), scale=4)
            full.save(os.path.join(preview, "world_%d.png" % n), scale=3)
    if "--no-export" not in sys.argv:
        export(worlds)
    print("stops done")


if __name__ == "__main__":
    main()
