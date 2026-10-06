"""The play field in pixel art: the road's light table, the notes (drawn in road.py, at every size
they take), the hit line's slots, the bell bar and its badge, the step buttons and their footprints,
and the small HUD pieces:

    python3 tools/art/pixel/field.py        # bakes game/art/px/field/*.png + scripts/art/fire_cells.gd

Notes grow as they come down the road. Instead of scaling one picture (which would smear or drop its
1-px outline), each note is drawn at every size it takes, one art pixel apart, and the game picks
the size for the note's depth: the note slides smoothly while its pixels stay whole.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from palette import P  # noqa: E402
from px import Canvas  # noqa: E402
import road  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/field")

CELLS = []      # (name, (w, h), (ax, ay)) -> fire_cells.gd


def save(cv, name, anchor):
    cv.save(os.path.join(OUT, name + ".png"))
    CELLS.append((name, (cv.w, cv.h), anchor))


# ------------------------------------------------------------------------------------------ road light

# Rows: materials of the road; columns: light levels, cool (0) to hottest (7). The road shader picks
# a column by the light at each art pixel (fire, rails, the hit line, a pressed lane, the beat).
ROAD_LUT = [
    # 0 mortar between the setts
    ["K1", "SETT0", "SETT0", "STONE0", "STONE1", "STONE1", "STONE2", "STONE3"],
    # 1 sett, the common tone
    ["SETT1", "SETT1", "SETT2", "STONE1", "STONE2", "STONE2", "STONE3", "STONE4"],
    # 2 sett, the lighter tone (one step up)
    ["SETT1", "SETT2", "SETT2", "STONE2", "STONE2", "STONE3", "STONE3", "STONE4"],
    # 3 a worn sett (a few, near the kerbs)
    ["SETT0", "SETT1", "SETT1", "STONE1", "STONE1", "STONE2", "STONE2", "STONE3"],
    # 4 the kerb's gold inlay along the road's edges (by light: rest .. on the beat, a hit)
    ["GOLD2", "GOLD2", "GOLD3", "GOLD3", "GOLD4", "GOLD4", "GOLD5", "GOLD5"],
    # 5 the kerb stone either side of the inlay
    ["K0", "K1", "SETT0", "STONE0", "STONE1", "STONE1", "STONE2", "STONE2"],
    # 6 the curb outside the road
    ["K0", "K0", "K1", "K1", "STONE0", "STONE0", "STONE1", "STONE1"],
    # 7 a lane divider: a pale stone line, cool and quiet
    ["SETT3", "SETT4", "SETT4", "SETT5", "STONE3", "STONE4", "STONE4", "STONE5"],
    # 8 a beat line across the lanes
    ["SETT3", "SETT4", "SETT4", "SETT5", "STONE4", "STONE4", "STONE5", "STONE5"],
    # 9 the first beat of a bar
    ["SETT5", "BONE0", "BONE0", "BONE1", "BONE1", "BONE2", "BONE2", "BONE3"],
    # 10 the lit top of a sett (the fire is up the road)
    ["SETT2", "SETT2", "SETT3", "STONE2", "STONE3", "STONE3", "STONE4", "STONE5"],
]


def road_lut():
    cv = Canvas(len(ROAD_LUT[0]), len(ROAD_LUT))
    for j, row in enumerate(ROAD_LUT):
        for i, c in enumerate(row):
            cv.pset(i, j, c)
    cv.save(os.path.join(OUT, "road_lut.png"))


# ------------------------------------------------------------------------------------------ notes

# The notes, the hit line's slots and the bell bar are drawn in road.py.
NOTE_SIZES = range(5, 31)        # half-widths (art px) of the step plate, far to near
TARGET_SIZES = range(14, 31)     # half-widths of the hit line's slots (the step plate's near sizes)
BAR_HEIGHTS = range(5, 17)
BADGE_SIZES = range(5, 19)


BUTTON_STATES = ("idle", "cued", "pressed", "hit", "miss")
BUTTON_M = 6   # 9-slice margin


def button_src(state):
    """The step button's 9-slice source, 24 x 24 with 6-px margins: a navy panel with a faint weave,
    a gold frame inside a K0 outline, gold studs in the corners. The game builds each button to its
    size from this and lays the row of diamonds and the footprints on it."""
    S = 24
    cv = Canvas(S, S)
    fill = {"idle": ("NAVY1", "NAVY2"), "cued": ("NAVY2", "NAVY3"), "pressed": ("NAVY0", "NAVY1"),
            "hit": ("RED1", "RED2"), "miss": ("NAVY0", "NAVY0")}[state]
    frame = {"idle": ("GOLD2", "GOLD3", "GOLD4"), "cued": ("GOLD3", "GOLD4", "GOLD5"), "pressed": ("GOLD3", "GOLD4", "GOLD5"),
             "hit": ("FIRE4", "FIRE6", "FIRE7"), "miss": ("GOLD0", "GOLD1", "GOLD2")}[state]
    cv.rect(0, 0, S, S, "K0")
    cv.rect(1, 1, S - 2, S - 2, frame[1])
    cv.hline(1, S - 2, 1, frame[2])
    cv.vline(1, 1, S - 2, frame[2])
    cv.hline(1, S - 2, S - 2, frame[0])
    cv.vline(S - 2, 1, S - 2, frame[0])
    cv.rect(2, 2, S - 4, S - 4, "K0")
    cv.rect(3, 3, S - 6, S - 6, fill[0])
    # weave: faint horizontal threads every other row, broken in a twill
    for y in range(4, S - 3, 2):
        for x in range(3, S - 3):
            if (x + y // 2) % 4 != 0:
                cv.pset(x, y, fill[1])
    # inner hairline
    cv.hline(3, S - 4, 3, "K1" if state != "hit" else "RED0")
    # corner studs
    for (x, y) in ((4, 4), (S - 5, 4), (4, S - 5), (S - 5, S - 5)):
        cv.pset(x, y, frame[2])
    return cv


def diamond(col_hi, col):
    cv = Canvas(3, 3)
    cv.pset(1, 0, col_hi)
    cv.pset(0, 1, col)
    cv.pset(1, 1, col_hi)
    cv.pset(2, 1, col)
    cv.pset(1, 2, col)
    return cv


def stud(col_hi, col, core="RED3"):
    """A small studded diamond for the button's top band: gold, lit on its upper left, a red core,
    in a K0 outline (7 x 7 with the outline)."""
    cv = Canvas(7, 7)
    for y in range(1, 6):
        for x in range(1, 6):
            if abs(x - 3) + abs(y - 3) <= 2:
                cv.pset(x, y, col_hi if (x - 3) + (y - 3) < 0 else col)
    cv.pset(3, 3, core)
    cv.outline("K0")
    return cv


def foot(tone="idle", right=False):
    """A cream footprint (a sole with its tread), toes up: the left foot unless right."""
    W, H = 13, 24
    cv = Canvas(W, H)
    cols = {"idle": ("BONE3", "BONE2", "BONE4"), "bright": ("BONE4", "BONE3", "STAR1"),
            "hot": ("FIRE6", "FIRE5", "FIRE7"), "dim": ("BONE1", "BONE0", "BONE1")}[tone]
    # sole: a wide ball, a narrow waist, a round heel; the big toe side toward the middle
    cv.ellipse(6.5, 7.5, 5.2, 7.0, cols[0])
    cv.ellipse(6.2, 18.5, 4.0, 4.6, cols[0])
    cv.poly([(2.2, 9), (10.6, 9), (9.6, 16), (3.0, 16)], cols[0])
    # tread lines across
    for y in (4, 7, 10, 13, 17, 20):
        cv.hline(3, 9, y, cols[1])
    cv.pset(4, 2, cols[2])
    cv.pset(5, 1, cols[2])
    cv.pset(6, 1, cols[2])
    cv.outline("K0")
    if right:
        cv = cv.flipped()
    return cv


# ------------------------------------------------------------------------------------------ HUD pieces

def hud_bell(state="lit"):
    """A unison bell, mouth down: gold lit from the upper left (lit), glowing hot (hot, just earned),
    or a dark iron bell (dark)."""
    W, H = 11, 12
    cv = Canvas(W, H)
    ramp = {"lit": ["GOLD2", "GOLD3", "GOLD4", "GOLD5"], "hot": ["GOLD4", "GOLD5", "FIRE7", "FIRE7"],
            "dark": ["K1", "NAVY1", "NAVY2", "NAVY3"]}[state]
    body = cv.m_poly([(3.0, 3.0), (8.0, 3.0), (9.6, 9.5), (1.4, 9.5)]) | cv.m_ellipse(5.5, 3.6, 2.6, 2.2)
    xx, yy = cv.grid()
    v = 1.0 - ((xx + 0.5 - 2.0) / 9.0 * 0.8 + (yy + 0.5 - 1.0) / 10.0 * 0.4)
    cv.ramp_fill(body, ramp, np.clip(v, 0, 1) * 0.9 + 0.05, dither=False)
    cv.hline(1, 9, 9, ramp[0])          # the lip
    cv.hline(2, 8, 8, ramp[1])
    cv.rect(5, 0, 1, 2, ramp[1])        # the loop
    cv.pset(5, 10, ramp[0] if state != "dark" else "NAVY1")   # the clapper
    cv.outline("K0")
    return cv


def pip_flame(frame, tone="lit"):
    """A health pip: a small flame on its ember, three frames of flicker; red when health is low;
    'out' is the dead ember alone."""
    W, H = 9, 13
    cv = Canvas(W, H)
    cols = {"lit": ["FIRE3", "FIRE4", "FIRE6", "FIRE7"], "red": ["RED2", "RED3", "RED4", "FIRE5"],
            "bright": ["FIRE4", "FIRE5", "FIRE7", "FIRE7"]}.get(tone)
    cv.ellipse(4.5, 10.5, 3.2, 1.6, "LEATHER1" if tone != "out" else "STONE1")
    if tone == "out":
        cv.pset(4, 10, "FIRE1")
        cv.outline("K0")
        return cv
    sway = [0, 1, -1][frame % 3]
    tip = [1.0, 2.0, 1.5][frame % 3]
    outer = [(1.5, 10.0), (4.5 + sway * 0.6, tip), (7.5, 10.0), (4.5, 11.2)]
    cv.poly(outer, cols[0])
    cv.ellipse(4.5, 8.8, 3.0, 2.4, cols[0])
    cv.poly([(2.6, 9.6), (4.5 + sway * 0.5, tip + 2.5), (6.4, 9.6)], cols[1])
    cv.ellipse(4.5, 9.0, 2.0, 1.8, cols[1])
    cv.poly([(3.5, 9.6), (4.5 + sway * 0.3, tip + 4.5), (5.5, 9.6)], cols[2])
    cv.ellipse(4.5, 9.4, 1.0, 1.0, cols[3])
    cv.outline("K0")
    return cv


def pause_button(down=False):
    """The pause button: a navy disc in a gold ring, two cream bars."""
    W = H = 17
    cv = Canvas(W, H)
    c = W / 2
    cv.ellipse(c, c, 7.6, 7.6, "GOLD5" if down else "GOLD4")
    cv.ellipse(c, c + 0.4, 7.0, 7.0, "GOLD3" if not down else "GOLD4")
    cv.ellipse(c, c, 6.0, 6.0, "K0")
    cv.ellipse(c, c, 5.2, 5.2, "NAVY2" if down else "NAVY1")
    for x in (6, 9):
        cv.rect(x, 5, 2, 7, "BONE4" if down else "BONE3")
        cv.vline(x, 5, 11, "BONE4")
    cv.outline("K0")
    return cv


def main():
    os.makedirs(OUT, exist_ok=True)
    CELLS.clear()
    road_lut()
    for rx in NOTE_SIZES:
        for kind in ("step", "call", "heal", "stomp", "hold"):
            cv, a = road.plate(rx, kind)
            save(cv, f"note_{kind}_{rx}", a)
        cv, a = road.plate(rx, "end")
        save(cv, f"hold_end_{rx}", a)
    for rx in TARGET_SIZES:
        for st in ("idle", "beat", "lit", "miss"):
            cv, a = road.target(rx, st)
            save(cv, f"target_{st}_{rx}", a)
    for up in (True, False):
        way = "up" if up else "down"
        for r in BADGE_SIZES:
            cv, a = road.badge(r, up)
            save(cv, f"badge_{way}_{r}", a)
        for h in BAR_HEIGHTS:
            save(road.bar_tile(h, up), f"bar_{way}_{h}", (0, 0))
            save(road.bar_end(h, up), f"bar_end_{way}_{h}", (0, 0))
    for st in BUTTON_STATES:
        save(button_src(st), f"button_{st}", (BUTTON_M, BUTTON_M))
    save(diamond("GOLD4", "GOLD3"), "diamond", (1, 1))
    save(diamond("GOLD5", "GOLD4"), "diamond_bright", (1, 1))
    save(diamond("FIRE7", "FIRE6"), "diamond_hot", (1, 1))
    save(diamond("GOLD2", "GOLD1"), "diamond_dim", (1, 1))
    save(stud("GOLD4", "GOLD3"), "stud", (3, 3))
    save(stud("GOLD5", "GOLD4", "RED4"), "stud_bright", (3, 3))
    save(stud("FIRE7", "FIRE6", "FIRE4"), "stud_hot", (3, 3))
    save(stud("GOLD2", "GOLD1", "RED1"), "stud_dim", (3, 3))
    for tone in ("idle", "bright", "hot", "dim"):
        save(foot(tone), f"foot_l_{tone}", (6, 12))
        save(foot(tone, True), f"foot_r_{tone}", (6, 12))
    for st in ("lit", "hot", "dark"):
        save(hud_bell(st), f"hud_bell_{st}", (5, 6))
    for f in range(3):
        for tone in ("lit", "red", "bright"):
            save(pip_flame(f, tone), f"pip_{tone}_{f}", (4, 11))
    save(pip_flame(0, "out"), "pip_out", (4, 11))
    save(pause_button(False), "pause", (8, 8))
    save(pause_button(True), "pause_down", (8, 8))
    write_cells()
    print("baked field to", OUT, len(CELLS), "sprites")


def write_cells():
    lines = [f'\t"{n}": [Vector2({w}, {h}), Vector2({ax}, {ay})],' for (n, (w, h), (ax, ay)) in CELLS]
    gd = """class_name FireCells
extends RefCounted
## Generated by tools/art/pixel/field.py - do not edit; re-run it after changing the art.
## Every play-field sprite in res://art/px/field/: [size, anchor], in art pixels (1x). The anchor of a
## note, ring, target or badge is the centre of its face; of a 9-slice source, its margin.

const NOTE_MIN := %d
const NOTE_MAX := %d
const TARGET_MIN := %d
const TARGET_MAX := %d
const BAR_MIN := %d
const BAR_MAX := %d
const BADGE_MIN := %d
const BADGE_MAX := %d
const BUTTON_MARGIN := %d
const CELLS := {
%s
}
""" % (min(NOTE_SIZES), max(NOTE_SIZES), min(TARGET_SIZES), max(TARGET_SIZES), min(BAR_HEIGHTS), max(BAR_HEIGHTS), min(BADGE_SIZES), max(BADGE_SIZES), BUTTON_M, "\n".join(lines))
    with open(os.path.join(ROOT, "scripts/art/fire_cells.gd"), "w") as f:
        f.write(gd)


if __name__ == "__main__":
    main()
