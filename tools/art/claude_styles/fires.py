"""Round 9: three bonfire drafts in the lino inks, each with a clear beat bob.

Every style takes the same inputs: combo level 1-4, seconds since the beat,
seconds since a level-up, the frame time, and at 4x the combo's box to wrap.
The bob is the Mamuthones' Rift shape: up at once on the beat, held 0.03 s,
settled by 0.2 s. Outer flames lag 0.033 s behind the middle, like the head
and bells lag the body.
"""
import math
import numpy as np
from lino import INK, CREAM, RED

LAG = 0.033
HEIGHT = {1: 0.055, 2: 0.08, 3: 0.11}     # rest height, of H; 4x reaches the HUD
LEAP = {1: 0.32, 2: 0.3, 3: 0.26, 4: 0.1}  # extra height on the beat


def bob(t):
    if t < 0:
        t += 0.5                          # the lag wraps into the previous beat
    x = min(1.0, max(0.0, (t - 0.03) / 0.17))
    return 1.0 - x * x * (3 - 2 * x)


def _dil(m):
    n = m.copy()
    n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]
    return n


def _split(s, y, box, side):
    """At 4x the flames bow outward round the combo text."""
    if box is None:
        return 0.0
    bx, byy, bw, bh = box
    return side * bw * 1.12 * np.clip(1 - ((y - byy) / (bh * 1.8)) ** 2, 0, 1)


def _hole(s, box):
    if box is None:
        return np.ones_like(s.X, bool)
    bx, byy, bw, bh = box
    return ((s.X - bx) / bw) ** 2 + ((s.Y - byy) / bh) ** 2 >= 1.0


def _tongue(s, cx, by, h, w, sway, ph, side=0, box=None):
    v = (by - s.Y) / h
    centre = cx + sway * np.sin(v * 4.2 - ph) * v * w * 0.7 + _split(s, s.Y, box, side)
    half = w * np.clip(1 - v, 0, 1) ** 0.85 * np.clip((v + 0.06) * 3.5, 0, 1)
    m = (v >= 0) & (v <= 1) & (np.abs(s.X - centre) <= half)
    return m, centre, half, v


def _heights(s, lv, beat_sec, box):
    H = s.H
    by = s.vpy + H * 0.012
    if lv == 4:
        top = H * 0.065
        h = by - top
    else:
        h = H * HEIGHT[lv]
    return by, h


# --- A: carved tongues ---------------------------------------------------------
def tongues(s, lv, beat_sec, since_up, tt, box):
    """Separate leaf-shaped tongues, each outlined in black like a lino cut,
    red with a cream heart and one gouged line."""
    W, H = s.W, s.H
    by, h0 = _heights(s, lv, beat_sec, box)
    cx = s.vpx
    n = 3 if lv == 1 else (5 if lv < 4 else 6)
    spread = W * (0.045 + 0.012 * lv) * (1.4 if lv == 4 else 1)
    hole = _hole(s, box)
    order = sorted(range(n), key=lambda i: -abs(i - (n - 1) / 2))   # outer first
    for i in order:
        off = (i - (n - 1) / 2) / max(1, (n - 1) / 2)              # -1 .. 1
        lag = LAG * abs(off)
        p = bob(beat_sec - lag)
        hh = h0 * (1 - 0.38 * abs(off) ** 1.5) * (1 + LEAP[lv] * p)
        if lv == 4 and abs(off) > 0.5:
            hh = h0 * (1 + LEAP[lv] * p)  # the two outer tongues climb all the way
            ww_k = 0.72
        else:
            ww_k = 1.0
        ww = W * (0.028 + 0.006 * lv) * (1 - 0.15 * p) * (1.15 if abs(off) < 0.4 else 1) * ww_k
        side = (1 if off > 0 else -1) if box is not None else 0
        if box is not None and abs(off) < 0.5:
            hh = min(hh, by - box[1] - box[3] * 0.9)   # middle tongues stop under the text
        m, c, half, v = _tongue(s, cx + off * spread, by, hh, ww, 0.9, tt * 7 + i * 1.9, side, box)
        m &= hole
        s.fill(_dil(m) & ~m & hole, INK)
        s.fill(m, RED)
        core = m & (np.abs(s.X - c) <= half * 0.3) & (v < 0.55 - 0.1 * abs(off))
        s.fill(core, CREAM)
        gouge = m & (np.abs(s.X - (c + half * 0.55 * (1 if i % 2 else -1))) < 0.5) & (v > 0.18) & (v < 0.7)
        s.fill(gouge, INK)
    _logs(s, cx, by)


# --- B: rising gouge lines -----------------------------------------------------
def gouges(s, lv, beat_sec, since_up, tt, box):
    """One flame shape cut through with curved black gouges that rise all the
    time, like a lino block carved in strokes. Cream in the heart."""
    W, H = s.W, s.H
    by, h0 = _heights(s, lv, beat_sec, box)
    cx = s.vpx
    p = bob(beat_sec)
    hole = _hole(s, box)
    hh = h0 * (1 + LEAP[lv] * p)
    ww = W * (0.07 + 0.016 * lv) * (1 - 0.1 * p) * (0.75 if lv == 4 else 1)
    parts = []
    if box is None:
        parts.append(_tongue(s, cx, by, hh, ww, 0.6, tt * 6, 0, None))
        for k in (-1, 1):                 # two small side tongues, lagging
            ps = bob(beat_sec - LAG)
            parts.append(_tongue(s, cx + k * ww * 0.75, by, hh * 0.55 * (1 + 0.1 * ps), ww * 0.45, 1.0, tt * 8 + k, 0, None))
    else:
        for k in (-1, 1):
            parts.append(_tongue(s, cx + k * ww * 0.25, by, hh, ww * 0.62, 0.6, tt * 6 + k, k, box))
    m = np.zeros_like(s.X, bool)
    for (mm, c, half, v) in parts:
        m |= mm
    m &= hole
    s.fill(_dil(m) & ~m & hole, INK)
    u = np.full(s.X.shape, 9.0)
    for (pm, pc, ph_, pv) in parts:      # 0 on each flame's spine, 1 at its edge
        uu = np.abs(s.X - pc) / np.maximum(ph_, 0.5)
        u = np.where(pm & (uu < u), uu, u)
    vv = (by - s.Y) / hh
    rings = ((u * 3.0 - tt * 2.2) % 1.0) < 0.3
    s.fill(m, RED)
    s.fill(m & (u < 0.3) & (vv < 0.6), CREAM)
    s.fill(m & rings & (u > 0.22) & (vv > 0.06), INK)
    _logs(s, cx, by)


# --- C: Sant'Antonio log pile with sparks --------------------------------------
def pile(s, lv, beat_sec, since_up, tt, box, beat_no=0):
    """The fogarone: a cone of crossed logs with flames out of the top and
    through the gaps. Each beat throws a handful of sparks up."""
    W, H = s.W, s.H
    box = None                            # round 10: no wrapping, a big natural fire
    by, h0 = _heights(s, min(lv, 3), beat_sec, box)
    leap = LEAP[lv]
    if lv == 4:
        h0, leap = H * 0.145, 0.24        # tips lick up behind the combo on the beat
    cx = s.vpx
    hole = _hole(s, box)
    ph_ = H * 0.045                       # the log cone is the same at every level
    pw = W * 0.095
    p = bob(beat_sec)
    # flames behind the logs, then the logs, then flames in the gaps
    n = {1: 3, 2: 3, 3: 5, 4: 7}[lv]
    for i in sorted(range(n), key=lambda i: -abs(i - (n - 1) / 2)):
        off = (i - (n - 1) / 2) / max(1, (n - 1) / 2)
        pp = bob(beat_sec - LAG * abs(off))
        hh = (h0 * (1 - 0.3 * abs(off) ** 1.5)) * (1 + leap * pp) * (1 + 0.06 * math.sin(tt * 9 + i * 2.1))
        side = (1 if off > 0 else -1) if box is not None else 0
        if box is not None and abs(off) < 0.6:
            hh = min(hh, by - box[1] - box[3] * 0.9)
        m, c, half, v = _tongue(s, cx + off * pw * (0.55 if lv < 4 else 0.75), by - ph_ * 0.3, hh, W * (0.03 + 0.005 * lv) * (1.15 if lv == 4 else 1), 0.8, tt * 7 + i * 2.3, side, box)
        m &= hole
        s.fill(_dil(m) & ~m & hole, INK)
        s.fill(m, RED)
        s.fill(m & (np.abs(s.X - c) <= half * 0.4) & (v < 0.5), CREAM)
    # the cone of logs: leaning poles meeting near the top
    apex = by - ph_
    for k in (-2, 2, -1, 1, 0):
        x0 = cx + k * pw / 2.1
        for j in range(int(ph_ * 1.05) + 1):
            u = j / ph_
            x = x0 + (cx + k * 0.8 - x0) * u
            y = by - j
            col = CREAM if (j // 4) % 3 else '#c9bba0'
            s.put(x - 1, y, INK); s.put(x, y, col); s.put(x + 1, y, col); s.put(x + 2, y, INK)
    # glowing gaps between the poles, flickering
    r = np.random.default_rng(int(tt * 20))
    for _ in range(6 + 3 * lv):
        u = r.random() * 0.7
        x = cx + (r.random() - 0.5) * pw * 1.6 * (1 - u)
        s.put(x, by - u * ph_, RED if r.random() < 0.7 else CREAM)
    # sparks thrown up on each beat, rising and fading over the beat
    r = np.random.default_rng(beat_no * 7 + 1)
    for k in range(4 + 2 * lv):
        sx = cx + (r.random() - 0.5) * pw * 1.4
        vy = H * (0.08 + 0.06 * r.random()) * (1 + 0.3 * (lv - 1))
        drift = (r.random() - 0.5) * W * 0.08
        t = beat_sec
        if t > 0.42 * (0.6 + 0.4 * r.random()):
            continue
        y = apex - h0 * 0.5 - vy * t * 2.2 + H * 0.05 * t * t
        x = sx + drift * t * 2 + math.sin(t * 9 + k) * 1.5
        s.put(x, y, CREAM if t < 0.15 else RED)


def _logs(s, cx, by):
    W = s.W
    for k in (-1, 1):
        for i in range(int(W * 0.12 * 1.5)):
            x = cx + k * (i - W * 0.09) * 0.9
            y = by - 1 + (i - W * 0.09) * 0.21 * k
            s.put(x, y, '#c9bba0'); s.put(x, y + 1, INK)


STYLES = {'tongues': tongues, 'gouges': gouges, 'pile': pile}
