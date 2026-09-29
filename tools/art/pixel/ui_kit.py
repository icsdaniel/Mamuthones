"""The pixel UI kit ("Bonfire Night"): every nine-patch, ornament and icon the game's Theme uses, drawn
from the one palette, after Daniele's menu reference (navy panels framed in old gold, red diamonds,
one red kilim banner for the main action).

    python3 tools/art/pixel/ui_kit.py            # writes game/art/ui/ and game/art/px/ui/
    python3 tools/art/pixel/ui_kit.py --preview out.png   # also a contact sheet of the kit

Two kinds of file:
  * game/art/ui/<name>.png - nine-patches and ornaments at 1x (one array cell = one art pixel). The
    Theme draws them with PixelBox (game/scripts/art/pixel_box.gd), which scales them x3 with nearest
    filtering, tiles the centres and places the ornaments. Margins are listed in NINE below and
    mirrored in WoodcutTheme.
  * game/art/ui/<name>.png for icons (toggles, check boxes, radio, slider grabber, option arrow) are
    saved already x3, because Godot draws theme icons at their pixel size.
  * game/art/px/ui/ - the shared menu backdrop (stone wall, 1x), torch frames and the torch glow.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from px import Canvas, BAYER4  # noqa: E402
from palette import P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
UI = os.path.join(ROOT, "art/ui")
PXUI = os.path.join(ROOT, "art/px/ui")

# Nine-patch margins in art pixels (left, top, right, bottom); WoodcutTheme uses the same numbers.
NINE = {}


def pattern(rows, key):
    """A tile from strings: each char maps through key (a dict char -> colour name or None)."""
    h, w = len(rows), len(rows[0])
    cv = Canvas(w, h)
    for y, r in enumerate(rows):
        assert len(r) == w, (rows, y)
        for x, ch in enumerate(r):
            col = key.get(ch)
            if col is not None:
                cv.pset(x, y, col)
    return cv


def tile_into(cv, tile, x0, y0, x1, y1, ox=0, oy=0):
    """Repeats a tile over [x0, x1) x [y0, y1) (only where the tile has pixels)."""
    for y in range(y0, y1):
        ty = (y - y0 + oy) % tile.h
        for x in range(x0, x1):
            tx = (x - x0 + ox) % tile.w
            if tile.a[ty, tx, 3]:
                cv.a[y, x] = tile.a[ty, tx]


def ring(cv, x0, y0, x1, y1, top, left, right, bottom, chamfer=False):
    """One-pixel rectangle outline over the inclusive box, each side its own colour."""
    cv.hline(x0, x1, y0, top)
    cv.hline(x0, x1, y1, bottom)
    cv.vline(x0, y0 + 1, y1 - 1, left)
    cv.vline(x1, y0 + 1, y1 - 1, right)
    if chamfer:
        for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            cv.pset(x, y, None)


# ------------------------------------------------------------------ patterns

# A faint woven lattice for the navy buttons: small lozenges in the next navy up, like the reference's
# dark kilim weave. "o" = motif, "." = ground.
WEAVE = [
    "...o....",
    "..o.o...",
    ".o...o..",
    "o.....o.",
    ".o...o..",
    "..o.o...",
    "...o....",
    "........",
]

# The red kilim field: stepped lozenges in dark red with a gold heart, on red.
KILIM = [
    "......dd......",
    ".....d..d.....",
    "....d.hh.d....",
    "...d.h..h.d...",
    "..d.h.gg.h.d..",
    ".d.h.g..g.h.d.",
    "d.h.g....g.h.d",
    ".d.h.g..g.h.d.",
    "..d.h.gg.h.d..",
    "...d.h..h.d...",
    "....d.hh.d....",
    ".....d..d.....",
]

# Kilim border band (top and bottom of the banner, inside the frame): small teeth.
KILIM_BAND = [
    "dddddddddddddd",
    "g..g..g..g..g.",
    ".gg.gg.gg.gg.g",
]


def weave_tile(ground, motif):
    return pattern(WEAVE, {".": ground, "o": motif})


def kilim_tile(ground, dark, hi, gold):
    """A 14 x 15 lattice of stepped lozenges: dark lattice lines, a lighter ring, a gold ring and heart.
    15 rows so a 32-art-pixel banner (96 px, the touch size) shows exactly one row of lozenges."""
    cv = Canvas(14, 15, ground)
    for y in range(15):
        for x in range(14):
            d = abs(x - 7) + abs(y - 7)
            col = {7: dark, 5: hi, 3: gold, 0: gold}.get(d)
            if col is not None:
                cv.pset(x, y, col)
    return cv


# ------------------------------------------------------------------ ornaments

def diamond(r, cols):
    """A lozenge of 'radius' r (size 2r+1): cols[d] is the colour at Manhattan distance d from the centre
    (None = transparent), with the outermost entry as its outline."""
    n = 2 * r + 1
    cv = Canvas(n, n)
    for y in range(n):
        for x in range(n):
            d = abs(x - r) + abs(y - r)
            if d <= r and cols[d] is not None:
                cv.pset(x, y, cols[d])
    return cv


def red_diamond(dim=False, lit=False):
    """The small red mark at both ends of every framed button: an outlined lozenge with a dot."""
    if dim:
        return diamond(3, ["BONE1", "NAVY0", "BONE0", "K0"])
    if lit:
        return diamond(3, ["GOLD5", "RED1", "RED4", "K0"])
    cv = diamond(3, ["RED4", "NAVY0", "RED3", "K0"])
    # light on the upper left facets of the ring
    for (x, y) in ((1, 3), (2, 2), (3, 1)):
        cv.pset(x, y, "RED4")
    return cv


def medallion(dim=False):
    """The gold kilim medallion at both ends of the red banner: concentric stepped lozenges."""
    if dim:
        cols = ["BONE2", "BONE1", "RED0", "RED0", "BONE1", "BONE0", "RED0", "BONE1", "K0"]
    else:
        cols = ["GOLD5", "GOLD4", "RED3", "RED2", "GOLD4", "GOLD3", "RED1", "GOLD4", "K0"]
    cv = diamond(8, cols)
    if not dim:
        # upper-left facets of the outer gold ring catch the light
        for i in range(1, 8):
            x, y = i, 8 - i
            if cv.get(x, y) == P["GOLD4"]:
                cv.pset(x, y, "GOLD5")
        # small gold teeth sticking out on the axis points, like the reference's kilim hooks
    return cv


def stud(bright=False):
    """A 5x5 corner rivet (K0 outline) that sits over the frame's corners."""
    cv = Canvas(5, 5)
    cv.rect(0, 0, 5, 5, "K0")
    cv.rect(1, 1, 3, 3, "GOLD4" if not bright else "GOLD5")
    cv.pset(1, 1, "GOLD5")
    cv.pset(3, 3, "GOLD2" if not bright else "GOLD3")
    cv.pset(2, 3, "GOLD3")
    cv.pset(3, 2, "GOLD3")
    return cv


def dull_stud():
    cv = Canvas(5, 5)
    cv.rect(0, 0, 5, 5, "K0")
    cv.rect(1, 1, 3, 3, "GOLD1")
    cv.pset(1, 1, "GOLD2")
    return cv


# ------------------------------------------------------------------ nine-patches

def framed(tile, sides_outer, sides_inner, studs=None, shadow=True, inset="NAVY0", pressed=False):
    """A framed button nine-patch: K0 outline (chamfered), two gold rings, a K0 inner line, then the tiled
    fill. Returns (canvas, margins). With `pressed` the whole face sits one pixel lower (no shadow)."""
    m = 5
    tw, th = tile.w, tile.h
    w = m + tw + m
    h = m + th + m + 1   # + the shadow row
    cv = Canvas(w, h)
    dy = 1 if pressed else 0
    y_top, y_bot = dy, h - 2 + dy   # outline box rows
    ring(cv, 0, y_top, w - 1, y_bot, "K0", "K0", "K0", "K0", chamfer=True)
    ring(cv, 1, y_top + 1, w - 2, y_bot - 1, *sides_outer)
    ring(cv, 2, y_top + 2, w - 3, y_bot - 2, *sides_inner)
    ring(cv, 3, y_top + 3, w - 4, y_bot - 3, "K0", "K0", "K0", "K0")
    tile_into(cv, tile, 4, y_top + 4, w - 4, y_bot - 3, ox=tw - 1, oy=th - 1)
    if inset is not None:
        cv.hline(4, w - 5, y_top + 4, inset)
    if shadow and not pressed:
        cv.hline(1, w - 2, h - 1, "K0")
    if studs is not None:
        for (x, y) in ((0, y_top), (w - 5, y_top), (0, y_bot - 4), (w - 5, y_bot - 4)):
            cv.blit(studs, x, y)
    return cv, (m, m + dy, m, m + 1 - dy)


GOLD_OUT = ("GOLD4", "GOLD3", "GOLD3", "GOLD2")
GOLD_IN = ("GOLD3", "GOLD2", "GOLD2", "GOLD1")
LIT_OUT = ("GOLD5", "GOLD4", "GOLD4", "GOLD3")
LIT_IN = ("GOLD4", "GOLD3", "GOLD3", "GOLD2")
DULL_OUT = ("GOLD2", "GOLD1", "GOLD1", "GOLD1")
DULL_IN = ("GOLD1", "GOLD0", "GOLD0", "GOLD0")


def accent(pressed=False):
    """The red kilim banner: a heavier gold frame, a band of teeth top and bottom, the woven field."""
    if pressed:
        tile = kilim_tile("RED1", "RED0", "RED2", "GOLD2")
        band = pattern(KILIM_BAND, {"d": "RED0", "g": "GOLD2", ".": "RED1"})
    else:
        tile = kilim_tile("RED2", "RED1", "RED3", "GOLD3")
        band = pattern(KILIM_BAND, {"d": "RED1", "g": "GOLD3", ".": "RED2"})
    m = 5
    bh = band.h
    tw, th = tile.w, tile.h
    w = m + tw + m
    top = m + bh
    h = top + th + bh + m + 1
    cv = Canvas(w, h)
    dy = 1 if pressed else 0
    y_top, y_bot = dy, h - 2 + dy
    ring(cv, 0, y_top, w - 1, y_bot, "K0", "K0", "K0", "K0", chamfer=True)
    ring(cv, 1, y_top + 1, w - 2, y_bot - 1, *(LIT_OUT if pressed else ("GOLD5", "GOLD4", "GOLD4", "GOLD3")))
    ring(cv, 2, y_top + 2, w - 3, y_bot - 2, *(LIT_IN if pressed else GOLD_IN))
    ring(cv, 3, y_top + 3, w - 4, y_bot - 3, "K0", "K0", "K0", "K0")
    tile_into(cv, band, 4, y_top + 4, w - 4, y_top + 4 + bh)
    flipped = Canvas(band.w, band.h)
    flipped.a = band.a[::-1].copy()
    tile_into(cv, flipped, 4, y_bot - 3 - bh, w - 4, y_bot - 3)
    tile_into(cv, tile, 4, y_top + 4 + bh, w - 4, y_bot - 3 - bh, ox=tw // 2, oy=0)
    st = stud(bright=True)
    for (x, y) in ((0, y_top), (w - 5, y_top), (0, y_bot - 4), (w - 5, y_bot - 4)):
        cv.blit(st, x, y)
    return cv, (m, top + dy, m, bh + m + 1 - dy)


def board():
    """The dark board panel: NAVY0 with a double gold rule and small gold lozenges at the corners."""
    tile = Canvas(8, 8, "NAVY0")
    # the faintest twill so a big board is not a dead flat colour
    for i in range(8):
        if i % 4 == 0:
            tile.pset(i, (i * 3) % 8, "NAVY1")
    m = 7
    w = m + tile.w + m
    h = m + tile.h + m
    cv = Canvas(w, h)
    ring(cv, 0, 0, w - 1, h - 1, "K0", "K0", "K0", "K0", chamfer=True)
    ring(cv, 1, 1, w - 2, h - 2, "GOLD4", "GOLD3", "GOLD3", "GOLD2")
    ring(cv, 2, 2, w - 3, h - 3, "K0", "K0", "K0", "K0")
    ring(cv, 3, 3, w - 4, h - 4, "NAVY1", "NAVY1", "NAVY1", "NAVY1")
    ring(cv, 4, 4, w - 5, h - 5, "GOLD2", "GOLD2", "GOLD2", "GOLD1")
    tile_into(cv, tile, 5, 5, w - 5, h - 5)
    ring(cv, 5, 5, w - 6, h - 6, "NAVY0", "NAVY0", "NAVY0", "NAVY0")
    # corner lozenges on the outer rule
    lz = diamond(2, ["GOLD5", "GOLD4", "K0"])
    for (x, y) in ((-1, -1), (w - 4, -1), (-1, h - 4), (w - 4, h - 4)):
        cv.blit(lz, x, y)
    return cv, (m, m, m, m)


def parchment():
    """Paper cards: BONE3 parchment in a dark wood frame with gold nail heads."""
    tile = Canvas(24, 24, "BONE3")
    # a few fibres, placed by hand so the repeat does not show (no noise field)
    for (x, y, n, col) in ((2, 3, 2, "BONE4"), (15, 7, 3, "BONE2"), (7, 16, 2, "BONE4"), (19, 20, 2, "BONE2")):
        tile.hline(x, x + n - 1, y, col)
    m = 7
    w = m + tile.w + m
    h = m + tile.h + m
    cv = Canvas(w, h)
    ring(cv, 0, 0, w - 1, h - 1, "K0", "K0", "K0", "K0", chamfer=True)
    ring(cv, 1, 1, w - 2, h - 2, "WOOD4", "WOOD3", "WOOD3", "WOOD2")
    ring(cv, 2, 2, w - 3, h - 3, "WOOD3", "WOOD2", "WOOD2", "WOOD1")
    ring(cv, 3, 3, w - 4, h - 4, "WOOD2", "WOOD1", "WOOD1", "WOOD1")
    ring(cv, 4, 4, w - 5, h - 5, "K0", "K0", "K0", "K0")
    tile_into(cv, tile, 5, 5, w - 5, h - 5)
    # the paper darkens a little at its edge (1 px of BONE2 with a dithered second row)
    ring(cv, 5, 5, w - 6, h - 6, "BONE2", "BONE2", "BONE2", "BONE2")
    for x in range(6, w - 6, 2):
        cv.pset(x, 6, "BONE2")
        cv.pset(x + 1, h - 7, "BONE2")
    for y in range(6, h - 6, 2):
        cv.pset(6, y, "BONE2")
        cv.pset(w - 7, y + 1, "BONE2")
    # wood grain on the frame (tiles along the edges: keep it periodic in the tile span)
    for x in range(m, w - m):
        if (x - m) % 5 == 2:
            cv.pset(x, 2, "WOOD2")
        if (x - m) % 7 == 4:
            cv.pset(x, h - 4, "WOOD0")
    nail = Canvas(3, 3)
    nail.rect(0, 0, 3, 3, "K0")
    nail.pset(1, 1, "GOLD4")
    nail.pset(0, 0, None)
    nail.pset(2, 0, None)
    nail.pset(0, 2, None)
    nail.pset(2, 2, None)
    nail2 = Canvas(3, 3)
    nail2.rect(0, 0, 3, 3, "K0")
    nail2.rect(0, 0, 2, 2, "GOLD4")
    nail2.pset(0, 0, "GOLD5")
    for (x, y) in ((1, 1), (w - 4, 1), (1, h - 4), (w - 4, h - 4)):
        cv.blit(nail2, x, y)
    return cv, (m, m, m, m)


def quiet(pressed=False):
    """The quiet button (Back, secondary actions): a single thin gold rule on dark navy, no studs."""
    tile = Canvas(4, 4, "NAVY1" if pressed else "NAVY0")
    m = 3
    w = m + tile.w + m
    h = m + tile.h + m + 1
    cv = Canvas(w, h)
    dy = 1 if pressed else 0
    y_top, y_bot = dy, h - 2 + dy
    ring(cv, 0, y_top, w - 1, y_bot, "K0", "K0", "K0", "K0", chamfer=True)
    if pressed:
        ring(cv, 1, y_top + 1, w - 2, y_bot - 1, "GOLD5", "GOLD4", "GOLD4", "GOLD3")
    else:
        ring(cv, 1, y_top + 1, w - 2, y_bot - 1, "GOLD3", "GOLD2", "GOLD2", "GOLD1")
    ring(cv, 2, y_top + 2, w - 3, y_bot - 2, "K0", "K0", "K0", "K0")
    tile_into(cv, tile, 3, y_top + 3, w - 3, y_bot - 2)
    if not pressed:
        cv.hline(1, w - 2, h - 1, "K0")
    return cv, (m, m + dy, m, m + 1 - dy)


def field():
    """Text field: sunk navy well with a thin gold rim."""
    tile = Canvas(4, 4, "NAVY0")
    m = 4
    w = m + tile.w + m
    h = m + tile.h + m
    cv = Canvas(w, h)
    ring(cv, 0, 0, w - 1, h - 1, "K0", "K0", "K0", "K0", chamfer=True)
    ring(cv, 1, 1, w - 2, h - 2, "GOLD2", "GOLD2", "GOLD2", "GOLD3")
    ring(cv, 2, 2, w - 3, h - 3, "K0", "K0", "K0", "K0")
    tile_into(cv, tile, 3, 3, w - 3, h - 3)
    cv.hline(3, w - 4, 3, "K1")
    return cv, (m, m, m, m)


def focus_ring():
    m = 5
    w = h = m * 2 + 4
    cv = Canvas(w, h + 1)
    ring(cv, 0, 0, w - 1, h - 1, "GOLD5", "GOLD5", "GOLD5", "GOLD5", chamfer=True)
    return cv, (m, m, m, m + 1)


def groove(fill):
    """A slider / progress groove 5 px tall: K0 outline, a sunk NAVY track, or a lit fill."""
    w, h = 9, 5
    cv = Canvas(w, h)
    ring(cv, 0, 0, w - 1, h - 1, "K0", "K0", "K0", "K0", chamfer=True)
    if fill == "empty":
        cv.rect(1, 1, w - 2, 3, "NAVY0")
        cv.hline(1, w - 2, 1, "K1")
        cv.hline(1, w - 2, 3, "NAVY1")
    elif fill == "gold":
        cv.hline(1, w - 2, 1, "GOLD5")
        cv.hline(1, w - 2, 2, "GOLD4")
        cv.hline(1, w - 2, 3, "GOLD2")
    elif fill == "red":
        cv.hline(1, w - 2, 1, "RED4")
        cv.hline(1, w - 2, 2, "RED3")
        cv.hline(1, w - 2, 3, "RED2")
    return cv, (2, 2, 2, 2)


def scroll_grabber(hi=False):
    w, h = 4, 9
    cv = Canvas(w, h)
    ring(cv, 0, 0, w - 1, h - 1, "K0", "K0", "K0", "K0", chamfer=True)
    cv.rect(1, 1, 2, h - 2, "GOLD4" if hi else "GOLD3")
    cv.vline(2, 1, h - 2, "GOLD3" if hi else "GOLD2")
    cv.pset(1, 1, "GOLD5" if hi else "GOLD4")
    return cv, (2, 3, 2, 3)


def scroll_track():
    w, h = 4, 7
    cv = Canvas(w, h)
    cv.rect(1, 0, 2, h, "NAVY0")
    cv.vline(1, 0, h - 1, "K0")
    return cv, (1, 2, 1, 2)


def rule_line():
    """The separator's line: one gold pixel with a K0 shadow under it (tiles horizontally)."""
    cv = Canvas(4, 3)
    cv.hline(0, 3, 1, "GOLD3")
    cv.hline(0, 3, 2, "K0")
    cv.pset(1, 1, "GOLD4")
    return cv, (0, 1, 0, 1)


def rule_diamond():
    """The divider's centre: a gold lozenge with a red heart (the reference's centre ornament)."""
    cv = diamond(6, ["RED4", "RED3", "RED2", "GOLD1", "GOLD4", "GOLD3", "K0"])
    for i in range(1, 6):
        x, y = i, 6 - i
        if cv.get(x, y) in (P["GOLD3"], P["GOLD4"]):
            cv.pset(x, y, "GOLD5")
    return cv


def rule_end():
    """A small gold bead that ends a divider line, with a short tick."""
    cv = Canvas(5, 5)
    d = diamond(2, ["GOLD5", "GOLD3", "K0"])
    cv.blit(d, 0, 0)
    return cv


# ------------------------------------------------------------------ icons (saved x3)

def toggle(on, disabled=False):
    """A pill switch 26 x 14: the slot, and a bronze boss that slides to the right when on."""
    w, h = 26, 14
    cv = Canvas(w, h)
    slot = Canvas(w, h)
    body = slot.m_rect(3, 1, w - 6, h - 2) | slot.m_ellipse(6.5, 7, 5.5, 6) | slot.m_ellipse(w - 6.5, 7, 5.5, 6)
    cv._put(body, "K0")
    inner = cv.m_rect(4, 2, w - 8, h - 4) | cv.m_ellipse(6.5, 7, 4.5, 5) | cv.m_ellipse(w - 6.5, 7, 4.5, 5)
    rim = "GOLD1" if disabled else ("GOLD4" if on else "GOLD2")
    cv._put(inner, rim)
    well = cv.m_rect(5, 3, w - 10, h - 6) | cv.m_ellipse(6.5, 7, 3.5, 4) | cv.m_ellipse(w - 6.5, 7, 3.5, 4)
    if on:
        cv._put(well, "RED1" if disabled else "RED2")
        if not disabled:
            # a row of kilim teeth in the lit slot
            for x in range(7, w - 12, 3):
                cv.pset(x, 7, "RED3")
    else:
        cv._put(well, "NAVY0")
    cv.hline(6, w - 7, 3, "K1" if not on else ("RED0" if disabled else "RED1"))
    kx = w - 7 if on else 6
    knob = cv.m_ellipse(kx + 0.5, 7, 5.2, 5.6)
    cv._put(knob, "K0")
    if disabled:
        cv.shade_ellipse(kx + 0.5, 7, 4.2, 4.6, ["BONE0", "BONE1"], dither=False)
    elif on:
        cv.shade_ellipse(kx + 0.5, 7, 4.2, 4.6, ["GOLD2", "GOLD3", "GOLD4", "GOLD5"], dither=False)
    else:
        cv.shade_ellipse(kx + 0.5, 7, 4.2, 4.6, ["BONE0", "BONE1", "BONE2"], dither=False)
    # the boss's centre pin
    cv.pset(kx, 7, "K0" if not on else "GOLD2")
    return cv


def check(on, disabled=False):
    """A 12 x 12 square box in a gold rim; checked: a cream tick on red."""
    n = 12
    cv = Canvas(n, n)
    ring(cv, 0, 0, n - 1, n - 1, "K0", "K0", "K0", "K0", chamfer=True)
    rim = ("GOLD1", "GOLD1", "GOLD1", "GOLD0") if disabled else ("GOLD4", "GOLD3", "GOLD3", "GOLD2")
    ring(cv, 1, 1, n - 2, n - 2, *rim)
    ring(cv, 2, 2, n - 3, n - 3, "K0", "K0", "K0", "K0")
    cv.rect(3, 3, n - 6, n - 6, "NAVY0")
    if on:
        cv.rect(3, 3, n - 6, n - 6, "RED1" if disabled else "RED2")
        tick = "BONE1" if disabled else "BONE4"
        for (x, y) in ((3, 6), (4, 7), (5, 8), (6, 7), (7, 6), (8, 5), (8, 4)):
            cv.pset(x, y, tick)
        for (x, y) in ((4, 6), (5, 7), (6, 6), (7, 5), (7, 4)):
            cv.pset(x, y, tick)
    else:
        cv.hline(3, n - 4, 3, "K1")
    return cv


def radio(on):
    """A lozenge in a gold rim; selected: a red lozenge heart."""
    if on:
        return diamond(6, ["RED4", "RED3", "RED2", "K0", "GOLD4", "GOLD3", "K0"])
    return diamond(6, ["NAVY0", "NAVY0", "NAVY0", "K1", "GOLD3", "GOLD2", "K0"])


def grabber(kind):
    """The slider's knob: a gold lozenge with a red heart (13 x 13)."""
    if kind == "off":
        cv = diamond(6, ["BONE0", "BONE0", "K0", "BONE1", "BONE1", "BONE0", "K0"])
    elif kind == "hi":
        cv = diamond(6, ["RED4", "RED4", "K0", "GOLD5", "GOLD5", "GOLD4", "K0"])
    else:
        cv = diamond(6, ["RED4", "RED3", "K0", "GOLD4", "GOLD4", "GOLD3", "K0"])
        for i in range(1, 6):
            if cv.get(i, 6 - i) == P["GOLD3"]:
                cv.pset(i, 6 - i, "GOLD5")
    return cv


def arrow():
    """OptionButton arrow: a gold chevron pointing down, 9 x 7."""
    cv = Canvas(9, 7)
    for i in range(4):
        cv.hline(1 + i, 7 - i, 1 + i, "GOLD4")
    cv.hline(1, 7, 1, "GOLD5")
    cv.outline()
    return cv


def bell(size, earned):
    """A small bronze cowbell for scores and results: 'small' 9 x 10, 'big' 15 x 17 (with outline)."""
    if size == "small":
        w, h = 11, 12
        cv = Canvas(w, h)
        body = [(3, 3), (7, 3), (9, 9), (1, 9)]
        cv.poly(body, "GOLD3")
        cv.hline(1, 8, 9, "GOLD2")
        cv.rect(4, 1, 2, 2, "GOLD2")  # loop
        cv.pset(5, 10, "GOLD1")     # clapper
        cv.vline(3, 4, 8, "GOLD5")
        cv.vline(4, 3, 6, "GOLD4")
        cv.pset(2, 8, "GOLD4")
        cv.vline(7, 5, 8, "GOLD2")
        cv.pset(8, 8, "GOLD2")
    else:
        w, h = 17, 19
        cv = Canvas(w, h)
        body = [(5, 4), (11, 4), (15, 15), (1, 15)]
        cv.poly(body, "GOLD3")
        cv.rect(6, 2, 4, 1, "GOLD2")
        cv.rect(6, 1, 1, 2, "GOLD2")
        cv.rect(9, 1, 1, 2, "GOLD2")
        cv.rect(7, 1, 2, 1, "GOLD3")
        # light from the upper left, bronze shadow on the right, a lip at the mouth
        cv.poly([(5, 4), (8, 4), (5, 15), (2, 15)], "GOLD4")
        cv.poly([(6, 5), (7, 5), (4, 13), (3, 13)], "GOLD5")
        cv.poly([(10, 4), (11, 4), (15, 15), (12, 15)], "GOLD2")
        cv.hline(1, 15, 15, "GOLD2")
        cv.hline(2, 14, 16, "GOLD1")
        cv.rect(7, 16, 3, 2, "GOLD1")   # clapper
        cv.pset(8, 17, "GOLD2")
    if not earned:
        # the empty mark: just the silhouette's outline in dim bone, hollow inside
        s = cv.solid()
        cv.a[:] = 0
        cv._put(s, "BONE1")
        inner = s.copy()
        inner[1:, :] &= s[:-1, :]
        inner[:-1, :] &= s[1:, :]
        inner[:, 1:] &= s[:, :-1]
        inner[:, :-1] &= s[:, 1:]
        cv._put(inner, None)
        cv.outline()
        return cv
    cv.outline()
    return cv


# ------------------------------------------------------------------ backdrop (1x)

def backdrop(w=360, h=540, seed=11):
    """The stone the menu screens stand on: a wall of worn ashlar blocks, dark and cool at the top, warm
    from the torch and brazier light below; worn cobbles at the very bottom. Calm, low contrast, so
    panels and text on it read. Anchored bottom-centre on screen; wide enough for a 3:4 tablet."""
    rnd = np.random.default_rng(seed)
    cv = Canvas(w, h, "K0")
    floor_y = h - 44
    # light: 0 at the top, rising to the bottom, a little brighter at both sides (torches)
    yy, xx = np.mgrid[0:h, 0:w]
    v = np.clip((yy - h * 0.18) / (h * 0.82), 0, 1) ** 1.6
    side = np.clip(1.0 - np.minimum(xx, w - 1 - xx) / (w * 0.22), 0, 1)
    v = np.clip(v * 0.85 + side * v * 0.35, 0, 1)
    # block courses: rows of blocks with staggered joints; each block gets one tone + an upper-left lip
    y = 0
    row = 0
    tone = np.zeros((h, w))
    ids = np.full((h, w), -1)
    bid = 0
    while y < floor_y:
        bh = int(rnd.integers(11, 15))
        x = -int(rnd.integers(0, 24))
        while x < w:
            bw = int(rnd.integers(18, 36))
            y1 = min(y + bh, floor_y)
            x0, x1 = max(x, 0), min(x + bw, w)
            if x1 > x0:
                tone[y:y1, x0:x1] = rnd.uniform(-0.12, 0.12)
                ids[y:y1, x0:x1] = bid
                bid += 1
            x += bw
        y += bh
        row += 1
    # mortar = pixels where the block id changes to the right or below
    mortar = np.zeros((h, w), bool)
    mortar[:, :-1] |= ids[:, :-1] != ids[:, 1:]
    mortar[:-1, :] |= ids[:-1, :] != ids[1:, :]
    mortar[floor_y - 1:, :] = False
    lip = np.zeros((h, w), bool)   # the lit top edge of each block (light comes from below: bottom lip)
    lip[:-2, :] = mortar[1:-1, :] & ~mortar[:-2, :]
    val = np.clip(v + tone, 0, 1)
    # one dark warm stone ramp: near black up high, the torchlit browns low down
    wall = (yy < floor_y)
    cv.ramp_fill(wall, ["K1", "STONE0", "STONE1", "STONE2", "STONE3"], np.clip(val * 0.92 + 0.08, 0, 0.999))
    # worn: a few chips and cracks, darker, only on lit blocks
    for _ in range(90):
        cx, cy = int(rnd.integers(0, w)), int(rnd.integers(int(h * 0.3), floor_y))
        if mortar[cy, cx]:
            continue
        ln = int(rnd.integers(2, 5))
        for i in range(ln):
            px_, py_ = cx + i, cy + (i // 2)
            if 0 <= px_ < w and 0 <= py_ < floor_y and not mortar[py_, px_]:
                cv.pset(px_, py_, "STONE0" if val[py_, px_] > 0.4 else "K1")
    # mortar lines and lit lips
    cv._put(mortar & wall, "K0")
    lit_lip = lip & wall & (val > 0.45)
    cv._put(lit_lip & (val > 0.7), "STONE4")
    cv._put(lit_lip & (val <= 0.7), "STONE3")
    # the floor: worn flagstones, lit warm, a darker joint between each
    fy0 = floor_y
    cv.rect(0, fy0, w, h - fy0, "K0")
    cv.hline(0, w - 1, fy0, "STONE2")
    yrow = fy0 + 2
    r = 0
    while yrow < h:
        ch = 7 + r
        x = -int(rnd.integers(0, 16))
        while x < w:
            cw = int(rnd.integers(16, 28))
            lv = np.clip(0.5 + (yrow - fy0) / 70.0 + rnd.uniform(-0.12, 0.12), 0, 1)
            fill = "STONE2" if lv > 0.62 else "STONE1"
            top = "STONE4" if lv > 0.62 else "STONE3"
            cv.rect(x + 1, yrow, cw - 1, ch - 1, fill)
            cv.hline(x + 2, x + cw - 2, yrow, top)
            cv.pset(x + 1, yrow, None if False else "STONE1")
            cv.hline(x + 2, x + cw - 2, yrow + ch - 2, "STONE0" if fill == "STONE1" else "STONE1")
            x += cw
        yrow += ch
        r += 1
    return cv


def torch_frames(n=4):
    """A wall torch (iron bracket, pitch-soaked head) with n flame frames, 11 x 26 each."""
    frames = []
    shapes = [
        [(5, 3), (7, 6), (8, 9), (7, 11), (3, 11), (2, 9), (3, 6)],
        [(6, 2), (8, 6), (8, 9), (7, 11), (3, 11), (2, 8), (4, 5)],
        [(4, 3), (7, 5), (8, 8), (7, 11), (3, 11), (2, 9), (3, 5)],
        [(5, 1), (7, 5), (9, 9), (7, 11), (3, 11), (2, 8), (3, 4)],
    ]
    for i in range(n):
        cv = Canvas(11, 26)
        # bracket and shaft
        cv.rect(4, 13, 3, 11, "WOOD1")
        cv.vline(4, 13, 23, "WOOD2")
        cv.rect(3, 17, 5, 2, "SETT2")
        cv.rect(2, 22, 7, 2, "SETT2")
        cv.hline(2, 8, 22, "SETT4")
        # the torch head (bound pitch)
        cv.rect(3, 11, 5, 3, "FLEECE2")
        cv.hline(3, 7, 12, "LEATHER1")
        # flame
        pts = shapes[i % len(shapes)]
        cv.poly(pts, "FIRE3")
        inner = [(x * 0.6 + 5 * 0.4, y * 0.6 + 11 * 0.4 + 0.6) for (x, y) in pts]
        cv.poly(inner, "FIRE5")
        core = [(x * 0.3 + 5 * 0.7, y * 0.3 + 11 * 0.7 + 0.4) for (x, y) in pts]
        cv.poly(core, "FIRE6")
        cv.pset(5, 10, "FIRE7")
        # a spark above on some frames
        if i % 2 == 0:
            cv.pset(6 - i // 2, 0 + i // 2, "FIRE5")
        cv.outline()
        frames.append(cv)
    return frames


def torch_glow(r=40):
    """A banded warm glow (drawn additively behind each torch): three flat rings, darkest outside."""
    n = r * 2 + 1
    cv = Canvas(n, n)
    for rr, col in ((r, "GOLD0"), (int(r * 0.66), "GOLD1"), (int(r * 0.33), "FIRE2")):
        cv.ellipse(r + 0.5, r + 0.5, rr, rr, col)
    # dithered edge between bands so they are stepped but not harsh
    return cv


def title_glow(w=60, h=20):
    """A banded glow behind the main banner (drawn additively, pulsing on the beat)."""
    cv = Canvas(w, h)
    for f, col in ((1.0, "GOLD0"), (0.72, "FIRE1"), (0.45, "FIRE2")):
        cv.ellipse(w / 2, h / 2, w / 2 * f, h / 2 * f, col)
    return cv


# ------------------------------------------------------------------ output

def main():
    os.makedirs(UI, exist_ok=True)
    os.makedirs(PXUI, exist_ok=True)
    nine = {
        "button_normal": framed(weave_tile("NAVY1", "NAVY2"), GOLD_OUT, GOLD_IN, stud()),
        "button_hover": framed(weave_tile("NAVY2", "NAVY3"), LIT_OUT, GOLD_IN, stud(True)),
        "button_pressed": framed(weave_tile("RED1", "RED2"), LIT_OUT, LIT_IN, stud(True), inset="RED0", pressed=True),
        "button_selected": framed(weave_tile("RED1", "RED2"), LIT_OUT, LIT_IN, stud(True), inset="RED0"),
        "button_disabled": framed(weave_tile("NAVY0", "NAVY1"), DULL_OUT, DULL_IN, dull_stud(), inset="K1"),
        "button_focus": focus_ring(),
        "button_quiet": quiet(False),
        "button_quiet_pressed": quiet(True),
        "accent_normal": accent(False),
        "accent_pressed": accent(True),
        "panel_dark": board(),
        "panel_paper": parchment(),
        "field": field(),
        "groove": groove("empty"),
        "groove_gold": groove("gold"),
        "groove_red": groove("red"),
        "scroll_grabber": scroll_grabber(False),
        "scroll_grabber_hi": scroll_grabber(True),
        "scroll_track": scroll_track(),
        "rule": rule_line(),
    }
    for name, (cv, margins) in nine.items():
        cv.save(os.path.join(UI, name + ".png"))
        NINE[name] = margins
    ornaments = {
        "diamond_red": red_diamond(),
        "diamond_lit": red_diamond(lit=True),
        "diamond_dim": red_diamond(dim=True),
        "medallion": medallion(),
        "medallion_dim": medallion(dim=True),
        "rule_diamond": rule_diamond(),
        "rule_end": rule_end(),
        "bell_small": bell("small", True),
        "bell_small_empty": bell("small", False),
        "bell_big": bell("big", True),
        "bell_big_empty": bell("big", False),
    }
    for name, cv in ornaments.items():
        cv.save(os.path.join(UI, name + ".png"))
    icons = {
        "toggle_on": toggle(True),
        "toggle_off": toggle(False),
        "toggle_on_off": toggle(True, True),
        "toggle_off_off": toggle(False, True),
        "check_on": check(True),
        "check_off": check(False),
        "check_on_off": check(True, True),
        "check_off_off": check(False, True),
        "radio_on": radio(True),
        "radio_off": radio(False),
        "grabber": grabber("normal"),
        "grabber_hi": grabber("hi"),
        "grabber_off": grabber("off"),
        "arrow": arrow(),
    }
    for name, cv in icons.items():
        cv.save(os.path.join(UI, name + ".png"), scale=3)
    backdrop().save(os.path.join(PXUI, "backdrop.png"))
    for i, fr in enumerate(torch_frames()):
        fr.save(os.path.join(PXUI, "torch_%d.png" % i))
    torch_glow().save(os.path.join(PXUI, "torch_glow.png"))
    title_glow().save(os.path.join(PXUI, "banner_glow.png"))
    for name, m in NINE.items():
        print("%-18s margins %s" % (name, m))
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], nine, ornaments, icons)


# ------------------------------------------------------------------ preview (for the artist only)

def ninepatch(cv, margins, w, h):
    """Python stand-in for PixelBox: tiles the edges and centre to a w x h art-pixel box."""
    l, t, r, b = margins
    src = cv.a
    H, W = src.shape[:2]
    out = np.zeros((h, w, 4), np.uint8)

    def span(n, a, bb, total):
        mid = total - a - bb
        idx = list(range(a)) + [a + (i % mid) for i in range(n - a - bb)] + list(range(total - bb, total))
        return idx

    xs = span(w, l, r, W)
    ys = span(h, t, b, H)
    out[:] = src[np.ix_(ys, xs)]
    c = Canvas(w, h)
    c.a = out
    return c


def preview(path, nine, orn, icons):
    from PIL import Image
    sheet = Canvas(240, 300, "K0")
    bd = backdrop()
    sheet.blit(bd, -60, 300 - 540)

    def btn(name, x, y, w, h, left, right):
        cv, m = nine[name]
        c = ninepatch(cv, m, w, h)
        sheet.blit(c, x, y)
        if left is not None:
            o = orn[left]
            yy = y + (h - 1 - o.h) // 2 + (1 if name.endswith("pressed") else 0)
            sheet.blit(o, x + 6, yy)
            sheet.blit(o, x + w - 6 - o.w, yy)

    btn("accent_normal", 8, 8, 224, 36, "medallion", None)
    btn("accent_pressed", 8, 48, 224, 36, "medallion", None)
    for i, n in enumerate(["button_normal", "button_hover", "button_pressed", "button_selected", "button_disabled"]):
        btn(n, 8 + (i % 2) * 114, 90 + (i // 2) * 34, 110, 32, "diamond_dim" if n == "button_disabled" else ("diamond_lit" if n in ("button_pressed", "button_selected") else "diamond_red"), None)
    cv, m = nine["panel_dark"]
    sheet.blit(ninepatch(cv, m, 110, 60), 8, 196)
    cv, m = nine["panel_paper"]
    sheet.blit(ninepatch(cv, m, 110, 60), 122, 196)
    cv, m = nine["rule"]
    sheet.blit(ninepatch(cv, m, 200, 3), 20, 270)
    rd = orn["rule_diamond"]
    sheet.blit(rd, 120 - rd.w // 2, 271 - rd.h // 2)
    sheet.blit(orn["rule_end"], 18, 269)
    sheet.blit(orn["rule_end"], 218, 269)
    x = 8
    for n in ["bell_small", "bell_small_empty", "bell_big", "bell_big_empty"]:
        sheet.blit(orn[n], x, 280)
        x += orn[n].w + 3
    im = sheet.image(3)
    # icons are already x3: paste them in a column on the right
    ic = Image.new("RGBA", (330, im.height), (7, 6, 14, 255))
    y = 10
    x = 10
    for n, cv in icons.items():
        i3 = cv.image(3)
        if x + i3.width > 320:
            x = 10
            y += 90
        ic.paste(i3, (x, y), i3)
        x += i3.width + 10
    # groove samples
    for j, n in enumerate(["groove", "groove_gold", "groove_red", "field"]):
        cv, m = nine[n]
        c = ninepatch(cv, m, 90, cv.h if n != "field" else 14)
        ci = c.image(3)
        ic.paste(ci, (10, 420 + j * 60), ci)
    full = Image.new("RGBA", (im.width + ic.width, im.height))
    full.paste(im, (0, 0))
    full.paste(ic, (im.width, 0))
    full.save(path)
    print("preview", path)


if __name__ == "__main__":
    main()
