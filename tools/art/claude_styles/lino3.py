"""Round 3: back to round 1's W2 (135 x 300) and enhance it at that size.

R3A keeps W2's scene and swaps in carved stamp notes, notched rings, red bells
and zigzag buttons. R3B also expands the scene: a crowd along the walls,
smoke from the bonfire, and a carved HUD.
"""
import copy, math
import numpy as np
import woodcut, lino
from lino import INK, CREAM, RED, ellipse_mask, zigzag, foot, plate
from pxkit import Style, text, text_w

W2 = woodcut.R1['w2_lino_red']

FIG3 = Style({
    'fleece':      [INK, INK, INK, CREAM, RED],
    'mask':        [INK, INK, INK, CREAM],
    'scarf':       [INK, INK, '#c9bba0'],
    'leather':     [INK, RED, RED],
    'bronze':      [RED, RED, RED, RED, CREAM],
    'bronze_in':   [INK, INK],
    'velvet':      [INK, INK, INK],
    'boot':        [INK, INK, CREAM],
    'hand':        [INK, INK, CREAM],
    'hole':        [INK],
    'brass_small': [CREAM, CREAM, CREAM],
}, outline='black', ink=INK)


def buttons_small(s):
    """W2's own cream buttons, with a small red zigzag border carved round each."""
    import scene as sc_
    sc_.draw_buttons(s, W2)
    W, H = s.W, s.H
    top, bot = int(s.btn_top), int(H * 0.985)
    gap = max(1, round(W * 0.02))
    bw = (W - 4 * gap) / 3
    bt = W2['btn']
    for i in range(3):
        x0 = gap + i * (bw + gap); x1 = x0 + bw
        zigzag(s, int(x0 + bt), int(top + gap + bt), int(x1 - bt), int(bot - bt), RED, 2)


def hud_small(s):
    W, H = s.W, s.H
    y = int(H * 0.014)
    x0, x1 = int(W * 0.05), int(W * 0.95)
    prog = 0.42
    for x in range(x0, x1):
        k = (x - x0) % 4
        h = 1 if k in (1, 3) else (2 if k == 2 else 0)
        col = RED if (x - x0) / (x1 - x0) < prog else CREAM
        for yy in range(-h, h + 1):
            s.put(x, y + 2 + yy, col)
    sy = y + 8
    score = '14,094'
    tw = text_w(score, 1)
    plate(s, W - tw - 10 - 3, sy, tw + 10, 15)
    text(s.img, score, W - tw - 5 - 3, sy + 4, INK, None, 1)
    plate(s, 3, sy, text_w('2x', 1) + 10, 15, fill=RED, border=CREAM)
    text(s.img, '2x', 8, sy + 4, CREAM, None, 1)
    cy = sy + 20
    text(s.img, '32', int(W / 2 - text_w('32', 2) / 2), cy, CREAM, INK, 2)
    text(s.img, 'COMBO', int(W / 2 - text_w('COMBO', 1) / 2), cy + 16, RED, INK, 1)
    jw = 'PERFECT'
    tw3 = text_w(jw, 1)
    bx, byy = int(W / 2 - tw3 / 2) - 6, int(s.btn_top - 8)
    plate(s, bx, byy, tw3 + 12, 13, fill=CREAM, border=INK)
    text(s.img, jw, bx + 6, byy + 3, RED, None, 1)


def crowd_and_smoke(s, frame, nframes):
    """Onlookers along both walls near the fire, and smoke rising off it."""
    W, H = s.W, s.H
    r = np.random.default_rng(5)
    ph = frame / max(1, nframes) * 2 * math.pi
    people = []
    for side in (-1, 1):
        for z in np.arange(3.0, 9.0, 0.6):
            t = 1.0 / z
            y = s.vpy + t * (s.hity - s.vpy)
            x = s.vpx + side * (s.halfw(y) * 1.12 + 3 + r.random() * 4)
            people.append((t, x, y, r.random()))
    for (t, x, y, rnd) in sorted(people):
        h = 5 + 22 * t                       # height in px, by depth
        hr = max(1.0, h * 0.11)
        bw = max(1.5, h * 0.2)
        head_y = y - h + hr
        body = (np.abs(s.X - x) <= bw * (0.6 + 0.4 * (s.Y - head_y) / h)) & (s.Y > head_y + hr * 0.8) & (s.Y <= y)
        head = np.hypot(s.X - x, s.Y - head_y) <= hr
        fig = body | head
        nb = np.zeros_like(fig)
        nb[1:] |= fig[:-1]; nb[:-1] |= fig[1:]; nb[:, 1:] |= fig[:, :-1]; nb[:, :-1] |= fig[:, 1:]
        s.fill(nb & ~fig & (s.Y < y), CREAM)
        s.fill(fig, INK)
        if rnd < 0.35 and h > 10:            # a red shawl on some of the women
            s.fill(body & (s.Y < head_y + hr + h * 0.25), RED)
    # smoke: a dotted cream ribbon drifting up and left from the fire
    cx, by = s.vpx, s.vpy - H * 0.07
    for k in range(45):
        v = k / 45
        yy = by - v * H * 0.09
        xx = cx + v * W * 0.22 + 4 * math.sin(v * 9 - ph * 2) * (0.3 + v)
        if (k + frame) % 3 != 0:
            s.put(xx, yy, CREAM)
            if v > 0.4 and k % 2 == 0:
                s.put(xx + 1, yy, CREAM)


def make_a():
    c = copy.copy(W2)
    c = dict(c)
    c['name'] = 'r3a_w2_stamps'
    c['style'] = FIG3
    c['notes_fn'] = lino.notes
    c['rings_fn'] = lino.rings
    c['buttons_fn'] = buttons_small
    return c


def make_b():
    c = make_a()
    c['name'] = 'r3b_w2_expanded'
    c['hud_fn'] = hud_small
    c['extra_fn'] = crowd_and_smoke
    return c


R3 = {'w2_round1': W2, 'r3a_w2_stamps': make_a(), 'r3b_w2_expanded': make_b()}
