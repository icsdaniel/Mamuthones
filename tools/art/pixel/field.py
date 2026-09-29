"""The play field in pixel art: the road's light table, the notes (at every size they are drawn),
the hit line's targets, the bell bar, the badge, hold rings, the stomp note, the step buttons and
their footprints, and the small HUD pieces:

    python3 tools/art/pixel/field.py        # bakes game/art/px/field/*.png + scripts/art/fire_cells.gd

Notes grow as they come down the road. Instead of scaling one picture (which would smear or drop its
1-px outline), each note is drawn at every size it takes, one art pixel apart, and the game picks
the size for the note's depth: the note slides smoothly while its pixels stay whole.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from palette import P  # noqa: E402
from px import Canvas  # noqa: E402

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
    # mortar between the setts
    ["K1", "SETT0", "SETT0", "STONE0", "STONE1", "STONE1", "STONE2", "FIRE1"],
    # sett, the common tone
    ["SETT1", "SETT2", "SETT2", "STONE1", "STONE2", "STONE3", "STONE4", "FIRE2"],
    # sett, the lighter tone (one step up)
    ["SETT2", "SETT3", "SETT3", "STONE2", "STONE3", "STONE4", "STONE5", "FIRE3"],
    # moss in the joints
    ["MOSS0", "MOSS0", "MOSS1", "MOSS1", "MOSS1", "MOSS2", "MOSS2", "MOSS2"],
    # the rail's core (by pulse: rest .. on the beat)
    ["FIRE4", "FIRE5", "FIRE5", "FIRE6", "FIRE6", "FIRE6", "FIRE7", "FIRE7"],
    # the rail's edge pixels
    ["FIRE2", "FIRE3", "FIRE3", "FIRE4", "FIRE4", "FIRE5", "FIRE5", "FIRE6"],
    # the curb outside the outer rails
    ["K0", "K0", "K1", "K1", "STONE0", "STONE0", "STONE1", "STONE1"],
]


def road_lut():
    cv = Canvas(len(ROAD_LUT[0]), len(ROAD_LUT))
    for j, row in enumerate(ROAD_LUT):
        for i, c in enumerate(row):
            cv.pset(i, j, c)
    cv.save(os.path.join(OUT, "road_lut.png"))


# ------------------------------------------------------------------------------------------ notes

NOTE_SIZES = range(5, 23)        # half-widths (art px) of the notes, far to near
TARGET_SIZES = range(16, 33, 2)  # half-widths of the hit line's targets


def ry_of(rx):
    return max(2, int(round(rx * 0.46)))


def disc(cv, cx, cy, rx, ry, depth, side, rim, face):
    """A coin lying on the road seen from above and in front: its side (depth px) under a face.
    side: colour of the edge; rim, face: lists of colours from the rim inward (bands)."""
    cv.ellipse(cx, cy + depth, rx, ry, side[0])
    cv.rect(cx - rx + 0.5, cy, 2 * rx - 1, depth, side[0])
    # the edge's lit upper band
    for k in range(depth):
        m = cv.m_ellipse(cx, cy + k, rx, ry) & ~cv.m_ellipse(cx, cy + k - 1, rx, ry)
        cv._put(m, side[1] if k < depth - 1 or depth == 1 else side[0])
    bands = rim + face
    n = len(bands)
    for i, col in enumerate(bands):
        k = 1.0 - i / n
        cv.ellipse(cx, cy - (1 - k) * ry * 0.18, rx * k, ry * k, col)


def note(rx, kind="step"):
    """A note at half-width rx: a glowing ember disc (step), in a dashed gold ring (call / off-beat),
    a gold disc with a flame (heal), or the stomp: a wider, heavier disc in a double gold rim with
    two thumb prints on its face."""
    ry = ry_of(rx)
    depth = max(1, int(round(rx * 0.16)))
    if kind == "stomp":
        return stomp(rx)
    pad = 4 if kind == "call" else 2
    ex = rx + (3 if kind == "call" else 0)
    W = 2 * ex + 2 * pad + 1
    H = 2 * ry + depth + 2 * pad + 6
    cv = Canvas(W, H)
    cx = W / 2
    cy = pad + ry + 2 + (1 if kind == "call" else 0)
    if kind == "heal":
        disc(cv, cx, cy, rx, ry, depth, ["GOLD1", "GOLD2"], ["GOLD3"], ["GOLD4", "BONE3", "BONE4"])
        # the flame on its face
        fh = max(2, int(round(ry * 1.2)))
        fw = max(1, rx * 0.22)
        cv.poly([(cx - fw, cy + ry * 0.35), (cx + fw, cy + ry * 0.35), (cx + fw * 0.4, cy - fh * 0.5), (cx, cy - fh)], "FIRE4")
        cv.poly([(cx - fw * 0.5, cy + ry * 0.35), (cx + fw * 0.5, cy + ry * 0.35), (cx, cy - fh * 0.3)], "FIRE6")
    else:
        disc(cv, cx, cy, rx, ry, depth, ["RED0", "RED1"], ["RED2", "RED3"], ["FIRE3", "FIRE4", "FIRE5", "FIRE6", "FIRE7"])
        # a hot glint on the rim toward the fire (upper edge)
        if rx >= 8:
            cv.hline(int(cx - rx * 0.4), int(cx + rx * 0.2), int(cy - ry + 1), "FIRE4")
    cv.outline("K0")
    if kind == "call":
        # the dashed gold ring of an off-beat step, clear of the disc by a pixel
        rr, rry = ex, ry + 3
        m = cv.m_ellipse(cx, cy + depth * 0.5, rr + 0.5, rry + 0.5) & ~cv.m_ellipse(cx, cy + depth * 0.5, rr - 0.5, rry - 0.5)
        xx, yy = cv.grid()
        ang = np.arctan2((yy + 0.5 - cy) / max(rry, 1), (xx + 0.5 - cx) / max(rr, 1))
        dash = (np.floor((ang + math.pi) / (math.tau / max(10, int(rx * 1.4)))) % 2) == 0
        free = ~cv.solid()
        cv._put(m & dash & free, "GOLD5")
    return cv, (int(cx), int(cy))


def _thumb(cv, tx, ty, tw, th, lean):
    """A thumb print: a bone oval leaning `lean` (x per y, tops toward the middle), a K0 edge and
    the whorl of its ridges."""
    xx, yy = cv.grid()
    X = xx + 0.5 - tx
    Y = yy + 0.5 - ty
    Xs = X - lean * Y
    m = (Xs / tw) ** 2 + (Y / th) ** 2 <= 1.0
    edge = (Xs / (tw + 1.0)) ** 2 + (Y / (th + 1.0)) ** 2 <= 1.0
    cv._put(edge & ~m, "K0")
    cv._put(m, "BONE3")
    cv._put(m & (Y < -th * 0.35) & (Xs * lean < 0), "BONE4")
    if tw >= 2.6:
        r = (Xs / tw) ** 2 + (Y / th) ** 2
        cv._put(m & (np.abs(r - 0.42) < 0.13) & (Y > -th * 0.55), "BONE2")
    if tw >= 4.0:
        cv._put(m & (r < 0.07), "BONE2")


def stomp(rx):
    """The two-thumb stomp: a heavy drum-head as wide as 1.7 notes and twice as thick, in a gold rim,
    with two thumb prints leaning in on its ember face - press with both thumbs at once."""
    ex = int(round(rx * 1.7))
    ry = ry_of(rx) + 1
    depth = max(2, int(round(rx * 0.3)))
    pad = 2
    W = 2 * ex + 2 * pad + 1
    H = 2 * ry + depth + 2 * pad + 4
    cv = Canvas(W, H)
    cx = W / 2
    cy = pad + ry + 2
    # the heavy edge, then a gold rim (two px across, one down), a K0 groove, the ember face
    cv.ellipse(cx, cy + depth, ex, ry, "GOLD1")
    cv.rect(cx - ex + 0.5, cy, 2 * ex - 1, depth, "GOLD1")
    for k in range(depth):
        m = cv.m_ellipse(cx, cy + k, ex, ry) & ~cv.m_ellipse(cx, cy + k - 1, ex, ry)
        cv._put(m, "GOLD2" if k < depth - 1 else "GOLD1")
    cv.ellipse(cx, cy, ex, ry, "GOLD3")
    top = cv.m_ellipse(cx, cy, ex, ry) & ~cv.m_ellipse(cx, cy + 1, ex, ry)
    cv._put(top, "GOLD5")
    xx, yy = cv.grid()
    cv._put(cv.m_ellipse(cx, cy, ex, ry) & ((yy + 0.5) < cy) & ~top, "GOLD4")
    fx, fy = ex - 2.2, ry - 1.2
    cv.ellipse(cx, cy + 0.3, fx + 1, fy + 0.8, "K0")
    cv.ellipse(cx, cy + 0.3, fx, fy, "RED2")
    cv.ellipse(cx, cy + 0.6, fx - 0.6, fy - 0.8, "RED3")
    cv.ellipse(cx, cy + 0.6, fx * 0.55, fy * 0.6, "FIRE3")
    cv.ellipse(cx, cy + 0.6, fx * 0.3, fy * 0.35, "FIRE4")
    # studs on the rim, like the buttons'
    for sx in (-1, 1):
        cv.pset(cx + sx * (ex - 1.0) - 0.5, cy - 0.5, "GOLD5")
    tw = max(1.6, rx * 0.34)
    th = max(2.2, ry * 0.78)
    for sx in (-1, 1):
        _thumb(cv, cx + sx * ex * 0.48, cy + 0.1, tw, th, -sx * 0.3)
    cv.outline("K0")
    return cv, (int(cx), int(cy))


def hold_ring(rx):
    """The end of a hold: a hollow gold ring lying on the road."""
    ry = ry_of(rx)
    W, H = 2 * rx + 5, 2 * ry + 6
    cv = Canvas(W, H)
    cx, cy = W / 2, H / 2 - 0.5
    cv.ellipse(cx, cy + 1, rx, ry, "GOLD2")
    cv.ellipse(cx, cy, rx, ry, "GOLD4")
    cv.ellipse(cx, cy - 0.5, rx - 1, ry - 1, "GOLD5")
    inner = cv.m_ellipse(cx, cy + 0.5, max(1, rx - 2.2), max(1, ry - 2))
    cv._put(inner, None)
    cv.outline("K0")
    cv._put(inner & ~cv.solid(), None)
    return cv, (int(cx), int(cy))


def target(rx, state="idle"):
    """A hit-line target: a heavy gold oval ring, hollow (the road shows through). States: idle,
    beat (brighter on the beat), lit (a lane pressed: the ring glows and its middle burns), miss
    (dulled for an instant)."""
    ry = max(4, int(round(rx * 0.4)))
    W, H = 2 * rx + 5, 2 * ry + 7
    cv = Canvas(W, H)
    cx, cy = W / 2, H / 2 - 0.5
    ramp = {"idle": ["GOLD1", "GOLD2", "GOLD3", "GOLD4", "GOLD5"],
            "beat": ["GOLD2", "GOLD3", "GOLD4", "GOLD5", "FIRE7"],
            "lit": ["FIRE2", "FIRE4", "FIRE5", "FIRE6", "FIRE7"],
            "miss": ["K1", "GOLD0", "GOLD1", "GOLD2", "GOLD2"]}[state]
    t = 3
    cv.ellipse(cx, cy + 1, rx, ry, ramp[0])            # underside shadow
    cv.ellipse(cx, cy, rx, ry, ramp[2])
    top = cv.m_ellipse(cx, cy, rx, ry) & ~cv.m_ellipse(cx, cy + 1, rx, ry)
    cv._put(top, ramp[4])
    xx, yy = cv.grid()
    upper = cv.m_ellipse(cx, cy, rx, ry) & ((yy + 0.5) < cy - ry * 0.35)
    cv._put(upper & ~cv.m_ellipse(cx, cy - 1, rx - 1, ry - 1), ramp[3])
    lower = cv.m_ellipse(cx, cy, rx, ry) & ((yy + 0.5) > cy + ry * 0.4)
    cv._put(lower & ~top, ramp[1])
    inner = cv.m_ellipse(cx, cy, rx - t, ry - t + 1)
    cv._put(inner, None)
    # the inner lip: a dark line inside the ring
    lip = cv.m_ellipse(cx, cy, rx - t + 1, ry - t + 2) & ~inner
    cv._put(lip & ((yy + 0.5) > cy), ramp[0])
    if state == "lit":
        cv.ellipse(cx, cy + 0.5, rx - t - 1, ry - t, "FIRE3")
        cv.ellipse(cx, cy + 0.5, (rx - t - 1) * 0.7, (ry - t) * 0.65, "FIRE5")
        cv.ellipse(cx, cy + 0.5, (rx - t - 1) * 0.35, (ry - t) * 0.35, "FIRE7")
    cv.outline("K0")
    if state != "lit":
        cv._put(inner & ~cv.m_ellipse(cx, cy, rx - t - 1, ry - t), "K0")
        hole = cv.m_ellipse(cx, cy, rx - t - 1, ry - t)
        cv._put(hole, None)
    return cv, (int(cx), int(cy))


def badge(r):
    """The bell bar's medallion: a red disc in a gold rim with a bone bell."""
    W = H = 2 * r + 5
    cv = Canvas(W, H)
    c = W / 2
    cv.ellipse(c, c, r, r, "GOLD4")
    cv.ellipse(c, c + 0.5, r - 0.6, r - 0.6, "GOLD3")
    cv.ellipse(c, c, r - 1.5, r - 1.5, "RED2")
    cv.ellipse(c, c - 0.5, r - 2, r - 2, "RED3")
    # the bell
    bw = max(2, r * 0.55)
    bh = max(3, r * 0.9)
    top = c - bh * 0.55
    cv.poly([(c - bw * 0.45, top + bh * 0.25), (c + bw * 0.45, top + bh * 0.25), (c + bw * 0.62, top + bh), (c - bw * 0.62, top + bh)], "BONE4")
    cv.ellipse(c, top + bh * 0.28, bw * 0.45, bh * 0.3, "BONE4")
    cv.hline(int(c - bw * 0.62), int(c + bw * 0.62), int(top + bh), "BONE3")
    cv.pset(c, top + bh + 1, "BONE3")
    cv.outline("K0")
    return cv, (int(c), int(c))


# ------------------------------------------------------------------------------------------ bar, buttons

def bar_src(h):
    """A slice of the bell bar, h px tall, 8 px wide (the game tiles it across the road): a gold
    plank, lit on top, K0 outline top and bottom."""
    cv = Canvas(8, h + 2)
    cv.rect(0, 1, 8, h, "GOLD3")
    cv.hline(0, 7, 1, "GOLD5")
    if h >= 5:
        cv.hline(0, 7, 2, "GOLD4")
    cv.hline(0, 7, h - 1, "GOLD2")
    if h >= 8:
        cv.hline(0, 7, h - 2, "GOLD2")
        for x in range(8):
            if x % 4 == 1:
                cv.pset(x, h // 2 + 1, "GOLD2")
    cv.hline(0, 7, 0, "K0")
    cv.hline(0, 7, h + 1, "K0")
    return cv


def bar_end(h, up):
    """The bar's end cap with its chevron (pointing up to raise the bells, down to lower them)."""
    W = max(6, h + 2)
    cv = Canvas(W, h + 2)
    cv.rect(0, 1, W - 1, h, "GOLD3")
    cv.hline(0, W - 2, 1, "GOLD5")
    cv.hline(0, W - 2, h - 1, "GOLD2")
    cv.vline(0, 0, h + 1, "K0")
    cv.hline(0, W - 1, 0, "K0")
    cv.hline(0, W - 1, h + 1, "K0")
    # chevron
    cx = W / 2
    cy = (h + 2) / 2
    s = max(1.5, h * 0.28)
    d = -1 if up else 1
    pts = [(cx - s * 1.4, cy - d * s * 0.6), (cx, cy + d * s * 0.7), (cx + s * 1.4, cy - d * s * 0.6)]
    cv.polyline([(round(x), round(y)) for x, y in pts], "K0", w=1 if h < 9 else 2)
    return cv


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


def main(preview=None):
    os.makedirs(OUT, exist_ok=True)
    CELLS.clear()
    road_lut()
    for rx in NOTE_SIZES:
        for kind in ("step", "call", "heal", "stomp"):
            cv, a = note(rx, kind)
            save(cv, f"note_{kind}_{rx}", a)
        cv, a = hold_ring(rx)
        save(cv, f"hold_ring_{rx}", a)
    for rx in TARGET_SIZES:
        for st in ("idle", "beat", "lit", "miss"):
            cv, a = target(rx, st)
            save(cv, f"target_{st}_{rx}", a)
    for r in range(4, 14):
        cv, a = badge(r)
        save(cv, f"badge_{r}", a)
    for h in range(5, 15):
        save(bar_src(h), f"bar_{h}", (0, 0))
        save(bar_end(h, True), f"bar_end_up_{h}", (0, 0))
        save(bar_end(h, False), f"bar_end_down_{h}", (0, 0))
    for st in BUTTON_STATES:
        save(button_src(st), f"button_{st}", (BUTTON_M, BUTTON_M))
    save(diamond("GOLD4", "GOLD3"), "diamond", (1, 1))
    save(diamond("GOLD5", "GOLD4"), "diamond_bright", (1, 1))
    save(diamond("FIRE7", "FIRE6"), "diamond_hot", (1, 1))
    save(diamond("GOLD2", "GOLD1"), "diamond_dim", (1, 1))
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
    if preview:
        sheet = Canvas(260, 150, "NAVY0")
        x = 2
        for rx in (6, 10, 14, 20):
            for k, kind in enumerate(("step", "call", "heal", "stomp")):
                cv, _ = note(rx, kind)
                sheet.blit(cv, x, 2 + k * 22)
            x += 2 * rx + 12
        cv, _ = target(24, "idle")
        sheet.blit(cv, 2, 92)
        cv, _ = target(24, "lit")
        sheet.blit(cv, 56, 92)
        cv, _ = badge(9)
        sheet.blit(cv, 110, 92)
        sheet.blit(foot("idle"), 140, 92)
        sheet.blit(foot("idle", True), 156, 92)
        sheet.blit(button_src("idle"), 175, 92)
        sheet.blit(button_src("hit"), 202, 92)
        cv, _ = hold_ring(14)
        sheet.blit(cv, 2, 120)
        x = 40
        for st in ("lit", "hot", "dark"):
            sheet.blit(hud_bell(st), x, 120)
            x += 13
        for f in range(3):
            for tone in ("lit", "red"):
                sheet.blit(pip_flame(f, tone), x, 120)
                x += 10
        sheet.blit(pip_flame(0, "out"), x, 120)
        sheet.blit(pause_button(), x + 12, 120)
        sheet.save(os.path.join(preview, "field_sheet.png"), scale=4)
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
const TARGET_STEP := 2
const BUTTON_MARGIN := %d
const CELLS := {
%s
}
""" % (min(NOTE_SIZES), max(NOTE_SIZES), min(TARGET_SIZES), max(TARGET_SIZES), BUTTON_M, "\n".join(lines))
    with open(os.path.join(ROOT, "scripts/art/fire_cells.gd"), "w") as f:
        f.write(gd)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
