"""Two-block lino: black, cream and vermilion only, carved like a linocut.

A fuller version of round 1's W2: twice the resolution, its own street,
notes, rings, buttons and HUD, all drawn as if gouged out of a block.
"""
import math
import numpy as np
from pxkit import Style, Layer, over, text, text_w, hexc
from scene import Scene, visible_notes, C
import figure

INK, CREAM, RED = '#141014', '#efe6d2', '#c8352a'
# print specks only: dust in the ink, ink missing from the paper
SPECK_INK, SPECK_CREAM = '#2c2222', '#ddd3bd'

FIG = Style({
    'fleece':      [INK, INK, INK, CREAM, RED],
    'mask':        [INK, INK, INK, CREAM],
    'scarf':       [INK, INK, ('h', CREAM, INK)],
    'leather':     [INK, RED, RED],
    'bronze':      [RED, RED, RED, RED, CREAM],
    'bronze_in':   [INK, INK],
    'velvet':      [INK, INK, ('v', CREAM, INK)],
    'boot':        [INK, INK, CREAM],
    'hand':        [INK, INK, CREAM],
    'hole':        [INK],
    'brass_small': [CREAM, CREAM, CREAM],
}, outline='black', ink=INK)

FIG_OPTS = dict(tuft_amp=0.95, carve=(0.7, 0.42, 1), fleece_clamp=0.55, rim=0.6,
                bell_cords=False, sym_face=True, face_lines=True)


def rng_(seed):
    return np.random.default_rng(seed)


# =============================================================================
def draw(cfg, frame=0, nframes=1, phase=0.0, fig_frame=0, cache={}):
    s = Scene(cfg)
    W, H = s.W, s.H
    ink, cream, red = C(INK), C(CREAM), C(RED)
    s.img[...] = ink

    sky(s, cfg)
    mountains(s)
    houses(s)
    road(s)
    bonfire(s, frame, nframes)
    lanes(s)

    # the procession: two rows of Mamuthones, the far ones smaller
    for (fx, fy, fh, flip) in cfg['figures']:
        key = ('lino', fh)
        if key not in cache:
            f, parts = figure.build(FIG, fh, FIG_OPTS)
            cache[key] = (f, figure.render_parts(f, parts, FIG))
        f, rp = cache[key]
        arr = figure.compose(f, rp, fig_frame, cream)
        if flip:
            arr = arr[:, ::-1]
        s.sprite(arr, fx * W - f.W / 2, fy * H - f.CH)

    notes(s, phase)
    rings(s)
    grain(s)          # print texture under the UI, so the UI stays crisp
    buttons(s)
    hud(s)
    return s.img


# --- sky ---------------------------------------------------------------------------
def sky(s, cfg):
    W, H = s.W, s.H
    top = int(H * 0.075)
    mx, my, mr = W * 0.25, H * 0.155, W * 0.075
    # gouged sky: long wavy strokes, denser toward the horizon, clear round the moon and HUD
    r = rng_(3)
    y = int(H * 0.19)
    while y < s.vpy:
        t = (y - H * 0.19) / (s.vpy - H * 0.19)
        x = r.integers(-20, 0)
        while x < W:
            ln = int(r.integers(14, 40))
            for k in range(ln):
                xx = x + k
                yy = y + 1.4 * math.sin(xx / 13.0 + y * 0.17)
                if math.hypot(xx - mx, yy - my) > mr * 2.3:
                    s.put(xx, yy, CREAM)
            x += ln + int(r.integers(4, 14))
        y += max(3, int(round(10 - 7 * t)))
    for rr in (mr * 1.45, mr * 1.8, mr * 2.15):  # carved halo rings
        for k in range(int(2 * math.pi * rr)):
            a_ = k / rr
            if int(k / 3) % 3 != 2:
                s.put(mx + math.cos(a_) * rr, my + math.sin(a_) * rr, CREAM)
    # stars: small carved crosses
    for _ in range(14):
        x, y = r.integers(4, W - 4), r.integers(top + 4, int(s.vpy * 0.62))
        if math.hypot(x - mx, y - my) < mr * 2.4 or (y < H * 0.2 and abs(x - W / 2) < W * 0.2):
            continue
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            s.put(x + dx, y + dy, CREAM)
    # the moon: cream, its lower half cut with black lines
    d = np.hypot(s.X - mx, s.Y - my)
    s.fill(d <= mr, CREAM)
    cut = (d <= mr) & (s.Y > my + mr * 0.15) & (((s.Yi - int(my)) % 3) == 0)
    s.fill(cut, INK)
    ring = (d > mr + 2) & (d <= mr + 3)
    s.fill(ring & ((s.Xi + s.Yi) % 3 != 0), CREAM)


def mountains(s):
    W, H = s.W, s.H
    xs = np.arange(W) / W
    ridge = H * 0.318 - H * 0.03 * (0.55 * np.sin(xs * 6.3 + 1.0) + 0.3 * np.sin(xs * 15.1 + 2.2) + 0.15 * np.sin(xs * 37 + 0.4))
    m = (s.Y >= ridge[None, :]) & (s.Y < s.vpy + 2)
    s.fill(m, INK)
    for x in range(W):
        s.put(x, ridge[x], CREAM)
        # a few slope strokes under the ridge line
        if x % 7 == 0:
            for k in range(2, 5):
                s.put(x + k * 0.5, ridge[x] + k, CREAM)


# --- houses ------------------------------------------------------------------------
def houses(s):
    W, H = s.W, s.H
    base_edge, top_edge = H * 0.70, H * 0.21
    for side in (-1, 1):
        u = (s.X - s.vpx) * side / s.vpx
        valid = u > 0.03
        uu = np.where(valid, u, 1)
        base_y = s.vpy + (base_edge - s.vpy) * uu
        top_y = (s.vpy - H * 0.02) + (top_edge - (s.vpy - H * 0.02)) * uu
        span = np.maximum(1e-6, base_y - top_y)
        v = (base_y - s.Y) / span
        z = 1.0 / uu
        hz = z * 1.25 + (0.45 if side > 0 else 0.0)
        house = np.floor(hz)
        w = hz - house
        hh = 0.6 + 0.4 * (np.sin(house * 3.7 + side) * 0.5 + 0.5)
        wall = valid & (v >= 0) & (v <= hh)
        s.fill(wall, CREAM)
        # stone courses: rows of blocks with staggered joints, carved in black
        rows = 7.0
        rv = v * rows
        row = np.floor(rv)
        jw = (w * 3.0 + 0.5 * (row % 2) + 0.23 * np.sin(row * 2.7 + house))
        px_v = 1.0 / span * rows          # one pixel in row units
        px_w = 1.25 * 3.0 / np.maximum(1e-3, s.vpx * uu * uu / 1.0) * 1.0
        hj = (rv - row) < np.maximum(px_v * 1.0, 0.0)
        vj = (jw - np.floor(jw)) < np.clip(px_w * 0.9, 0.02, 0.5)
        s.fill(wall & (hj | vj) & (uu > 0.12), INK)
        # shaded side: the right-hand walls face away from the fire, hatched
        if side > 0:
            s.fill(wall & (((s.Xi + s.Yi) % 4) == 0) & (uu > 0.08), INK)
        # house seams, roof eaves with a red tile row
        s.fill(wall & ((w < 0.04) | (w > 0.96)), INK)
        eave = valid & (v > hh) & (v <= hh + 0.04)
        s.fill(eave, INK)
        tiles = valid & (v > hh + 0.04) & (v <= hh + 0.075)
        s.fill(tiles & ((np.floor(w * 12) % 2) == 0), RED)
        s.fill(tiles & ((np.floor(w * 12) % 2) == 1), INK)
        # windows lit red inside, doors black with a red step
        win = wall & (w > 0.30) & (w < 0.58) & (v > 0.50) & (v < 0.50 + 0.22 * hh)
        lit = np.sin(house * 5.3 + side * 2) > -0.3
        s.fill(win, INK)
        s.fill(win & lit & (v < 0.50 + 0.12 * hh), RED)
        door = wall & (w > 0.64) & (w < 0.86) & (v < 0.36)
        s.fill(door, INK)
        s.fill(door & (v < 0.04), RED)
        # pavement in front: black with a cream kerb line
        side_m = valid & (v < 0) & (s.Y < s.hity + 2)
        s.fill(side_m, INK)


# --- road ----------------------------------------------------------------------------
def road(s):
    W, H = s.W, s.H
    t = s.t_of_y(s.Y)
    hw = s.hw0 + (s.hw1 - s.hw0) * t
    rd = (s.Y >= s.vpy) & (np.abs(s.X - s.vpx) <= hw + 0.5) & (s.Y < s.btn_top)
    s.fill(rd, INK)
    # carved strokes across the road: rows of dashes that tighten toward the horizon
    r = rng_(21)
    zrow = 0.0
    k = 0
    while True:
        k += 1
        zrow = 1.0 + k * 0.42
        tt = 1.0 / zrow
        y = s.vpy + tt * (s.hity - s.vpy) * 1.18
        if y < s.vpy + (s.hity - s.vpy) * 0.2:
            break
        if y >= s.btn_top:
            continue
        hwy = s.halfw(y)
        dash = max(2, int(hwy * 0.16))
        x = s.vpx - hwy + 2 + (k % 2) * dash * 0.6
        while x < s.vpx + hwy - 2:
            ln = int(dash * (0.6 + 0.6 * r.random()))
            for j in range(ln):
                if x + j < s.vpx + hwy - 2:
                    s.put(x + j, y, CREAM)
                    if tt > 0.55:
                        s.put(x + j, y + 1, CREAM)
            x += ln + max(2, int(dash * 0.5))
    # kerb: a red line and a cream line outside each road edge
    for side in (-1, 1):
        for y in range(int(s.vpy), int(s.btn_top)):
            x = s.vpx + side * (s.halfw(y + 0.5) + 1.5)
            s.put(x, y, RED)
            s.put(x + side, y, RED)
            s.put(x + side * 2, y, CREAM)


# --- bonfire ---------------------------------------------------------------------------
def bonfire(s, frame, nframes):
    W, H = s.W, s.H
    cx, by = s.vpx, s.vpy + H * 0.014
    fw, fh = W * 0.13, H * 0.12
    ph = frame / max(1, nframes) * 2 * math.pi * 4
    # tongues: (x offset, height, lean) - outer ones lean out, curl at the tip
    tongues = [(-0.62, 0.50, -0.5), (-0.32, 0.80, -0.25), (0.0, 1.0, 0.1), (0.30, 0.78, 0.3), (0.60, 0.48, 0.5)]
    for layer in ('red', 'cream'):
        for i, (tx, th, lean) in enumerate(tongues):
            hgt = fh * th * (0.92 + 0.1 * math.sin(ph * 0.5 + i * 2.1))
            if layer == 'cream':
                hgt *= 0.55
            base = fw * (0.36 if layer == 'red' else 0.16)
            for y in range(int(by - hgt), int(by) + 1):
                v = (by - y) / hgt
                half = base * max(0.0, 1 - v) ** 0.75 * (1 + 0.18 * math.sin(v * 9 + ph + i))
                xc = cx + tx * fw + (lean + 0.25 * math.sin(ph * 0.5 + i)) * fw * 0.6 * v * v
                for x in range(int(xc - half - 1), int(xc + half + 2)):
                    if abs(x + 0.5 - xc) <= half:
                        s.put(x, y, RED if layer == 'red' else CREAM)
    # gouges: thin black curves cut up through the flames
    for k in (-0.45, -0.15, 0.15, 0.45):
        for y in range(int(by - fh * 0.5), int(by - 2)):
            v = (by - y) / (fh * 0.5)
            x = cx + k * fw + 1.5 * v * math.sin(ph * 0.5 + k * 6)
            px = s.img[int(y), int(x)]
            if not np.all(px == C(INK)):
                s.put(x, y, INK)
    # logs crossed under the fire
    for side in (-1, 1):
        for i in range(int(fw * 1.8)):
            x = cx + side * (i - fw * 0.9)
            y = by + 1 + (i - fw * 0.9) * 0.2 * side
            s.put(x, y, CREAM); s.put(x, y + 1, CREAM); s.put(x, y + 2, INK)
    r = rng_(frame % 9 + 1)
    for _ in range(10):
        s.put(cx + r.normal(0, fw * 0.6), by - fh * (1.1 + r.random() * 1.1), CREAM if r.random() < 0.5 else RED)


# --- lanes and notes -----------------------------------------------------------------------
def lanes(s):
    for i in (1, 2):
        x_far = s.vpx - s.hw0 + i * (2 * s.hw0 / 3)
        x_near = s.vpx - s.hw1 + i * (2 * s.hw1 / 3)
        for y in range(int(s.vpy + 4), int(s.btn_top)):
            tt = s.t_of_y(y + 0.5)
            x = x_far + (x_near - x_far) * tt
            # carved dashes near the horizon, a solid line close up
            if tt > 0.35 or (y // 3) % 2 == 0:
                s.put(x, y, CREAM)
                if tt > 0.6:
                    s.put(x + 1, y, CREAM)


def lane_w(s, y):
    return 2 * s.halfw(y) / 3


def ellipse_mask(s, cx, cy, rx, ry):
    return ((s.X - cx) / rx) ** 2 + ((s.Y - cy) / ry) ** 2 <= 1


def stamp(s, cx, cy, w, kind):
    """A note, cut as a flat stamp. Each kind differs in colour AND pattern."""
    rx = w / 2
    ry = max(1.5, rx * 0.36)
    th = max(1, round(w * 0.08))
    outer = ellipse_mask(s, cx, cy + th, rx + 1, ry + 1) | ellipse_mask(s, cx, cy, rx + 1, ry + 1)
    s.fill(outer, INK if kind != 'o' else CREAM)
    side = ellipse_mask(s, cx, cy + th, rx, ry)
    top = ellipse_mask(s, cx, cy, rx, ry)
    if kind == 'q':      # on the beat: cream disc, red rosette
        s.fill(side, RED)
        s.fill(top, CREAM)
        if w >= 10:
            for k in range(6):
                a = k * math.pi / 3
                px, py = cx + math.cos(a) * rx * 0.48, cy + math.sin(a) * ry * 0.48
                s.fill(ellipse_mask(s, px, py, max(1, rx * 0.16), max(0.8, ry * 0.2)), RED)
        s.fill(ellipse_mask(s, cx, cy, max(1, rx * 0.2), max(0.8, ry * 0.25)), RED)
    elif kind == 'e':    # half beat: red disc, cream ring cut in
        s.fill(side, INK)
        s.fill(top, RED)
        ring = ellipse_mask(s, cx, cy, rx * 0.62, ry * 0.62) & ~ellipse_mask(s, cx, cy, rx * 0.62 - 1.2, ry * 0.62 - 1)
        s.fill(ring, CREAM)
    elif kind == 'o':    # off-beat: black disc with cream stripes
        s.fill(side, CREAM)
        s.fill(top, INK)
        s.fill(top & (((s.Xi - int(cx)) % 3) == 0) & ~ellipse_mask(s, cx, cy, rx * 0.35, ry * 0.4), CREAM)
    elif kind == 'h':    # hold: red disc, cream rope knot
        s.fill(side, INK)
        s.fill(top, RED)
        s.fill(ellipse_mask(s, cx, cy, rx * 0.4, ry * 0.45), CREAM)
        s.fill(ellipse_mask(s, cx, cy, rx * 0.18, ry * 0.2), RED)


def notes(s, phase):
    kinds = {'note_q': 'q', 'note_e': 'e', 'note_o': 'o', 'note_h': 'h'}
    s.flash = set()
    for (d, kind, lane, dt) in sorted(visible_notes(phase), key=lambda n: -n[0]):
        if kind == 'bell':
            if d < -0.01:
                continue
            if abs(d) < 0.03:
                s.flash.update((0, 1, 2))
            y = s.y_of_depth(max(0, d))
            hw = s.halfw(y)
            th = max(3, lane_w(s, y) * 0.2)
            up = lane == 'up'
            m = (np.abs(s.X - s.vpx) <= hw - 1) & (np.abs(s.Y - y) <= th / 2)
            s.fill((np.abs(s.X - s.vpx) <= hw) & (np.abs(s.Y - y) <= th / 2 + 1), INK)
            s.fill(m, RED if up else CREAM)
            # chevrons: up = cream on red, down = black on cream
            col = CREAM if up else INK
            a = max(1, int(th * 0.35))
            step = max(6, int(lane_w(s, y) * 0.3))
            for x0 in np.arange(s.vpx - hw + step / 2, s.vpx + hw - 2, step):
                for k in range(-a, a + 1):
                    yy = y + (abs(k) - a / 2) * (1 if up else -1)
                    s.put(x0 + k, yy, col)
                    s.put(x0 + k, yy + (1 if up else -1), col)
            continue
        if kind == 'note_h':
            y0, y1 = s.y_of_depth(max(0, d)), s.y_of_depth(min(0.8, dt))
            for y in range(int(y1), int(y0) + 1):
                cx = s.lane_x(lane, y + 0.5)
                rw = lane_w(s, y) * 0.13
                for x in range(int(cx - rw - 1), int(cx + rw) + 2):
                    u = (x + 0.5 - cx) / max(rw, 0.5)
                    if abs(u) > 1.0:
                        s.put(x, y, INK)
                    else:
                        twist = int((x + y) // max(2, int(rw))) % 2
                        s.put(x, y, RED if twist else CREAM)
            if dt <= 0.8:
                stamp(s, s.lane_x(lane, y1), y1, lane_w(s, y1) * 0.45, 'h')
            if d <= 0 < dt:
                s.flash.add(lane)
            stamp(s, s.lane_x(lane, y0), y0, lane_w(s, y0) * 0.8, 'h')
            continue
        if d < -0.015:
            continue
        if abs(d) < 0.03:
            s.flash.add(lane)
        y = s.y_of_depth(max(-0.01, d))
        stamp(s, s.lane_x(lane, y), y, lane_w(s, y) * 0.8, kinds[kind])


def rings(s):
    for lane in range(3):
        cx = s.lane_x(lane, s.hity)
        rx = lane_w(s, s.hity) * 0.43
        ry = rx * 0.36
        o = ellipse_mask(s, cx, s.hity, rx, ry)
        i = ellipse_mask(s, cx, s.hity, rx - 2.2, ry - 1.4)
        ring = o & ~i
        # carved notches round the ring
        ang = np.arctan2((s.Y - s.hity) / ry, (s.X - cx) / rx)
        notch = (np.floor(ang / (2 * math.pi) * 20) % 2 == 0) & (np.abs(np.sin(ang * 10)) < 0.25)
        if lane in s.flash:
            s.fill(ellipse_mask(s, cx, s.hity, rx + 3, ry + 2) & ~o, RED)
            s.fill(i, RED)
        s.fill(ring, CREAM)
        s.fill(ring & notch, INK)


def grain(s):
    g = rng_(11).random((s.H, s.W))
    ink, cream = C(INK), C(CREAM)
    a = np.all(s.img == ink, axis=-1) & (g < 0.035)
    b = np.all(s.img == cream, axis=-1) & (g > 0.955)
    s.img[a] = C(SPECK_INK)
    s.img[b] = C(SPECK_CREAM)


# --- buttons and HUD ---------------------------------------------------------------------
def zigzag(s, x0, y0, x1, y1, col, size):
    """Sardinian carved border: a row of triangles along each edge."""
    for x in range(int(x0), int(x1)):
        k = (x - x0) % (2 * size)
        h = size - abs(k - size)
        for yy in range(int(h)):
            s.put(x, y0 + yy, col)
            s.put(x, y1 - 1 - yy, col)
    for y in range(int(y0), int(y1)):
        k = (y - y0) % (2 * size)
        h = size - abs(k - size)
        for xx in range(int(h)):
            s.put(x0 + xx, y, col)
            s.put(x1 - 1 - xx, y, col)


def buttons(s):
    W, H = s.W, s.H
    top, bot = int(s.btn_top), int(H * 0.985)
    s.fill(s.Y >= s.btn_top - 1, INK)
    gap = max(2, round(W * 0.022))
    bw = (W - 4 * gap) / 3
    for i in range(3):
        x0 = int(gap + i * (bw + gap)); x1 = int(x0 + bw)
        y0 = top + gap
        m = (s.X >= x0) & (s.X < x1) & (s.Y >= y0) & (s.Y < bot)
        s.fill(m, CREAM)
        zigzag(s, x0 + 2, y0 + 2, x1 - 2, bot - 2, RED, 3)
        # inner frame line
        fr = (s.X >= x0 + 6) & (s.X < x1 - 6) & (s.Y >= y0 + 6) & (s.Y < bot - 6)
        fr2 = (s.X >= x0 + 7) & (s.X < x1 - 7) & (s.Y >= y0 + 7) & (s.Y < bot - 7)
        s.fill(fr & ~fr2, INK)
        cx, cy = (x0 + x1) / 2, (y0 + bot) / 2
        fs = (bot - top) * 0.62
        if i == 1:
            foot(s, cx - fs * 0.26, cy, fs, True)
            foot(s, cx + fs * 0.26, cy, fs, False)
        else:
            foot(s, cx, cy, fs, i == 0)


def foot(s, cx, cy, size, mirror):
    sx = -1 if mirror else 1
    rx, ry = size * 0.17, size * 0.26
    ball = ellipse_mask(s, cx + sx * size * 0.02, cy - size * 0.03, rx, ry)
    heel = ellipse_mask(s, cx - sx * size * 0.02, cy + size * 0.27, rx * 0.8, ry * 0.45)
    arch = (np.abs(s.X - cx) < rx * 0.75) & (s.Y > cy) & (s.Y < cy + size * 0.27)
    sole = ball | heel | arch
    s.fill(sole, INK)
    cut = ellipse_mask(s, cx - sx * rx * 1.25, cy + size * 0.12, rx * 0.65, ry * 0.45)
    s.fill(sole & cut, CREAM)
    # a carved line down the sole
    for k in range(int(size * 0.35)):
        s.put(cx + sx * rx * 0.25, cy - size * 0.12 + k, CREAM)
    for (tx, ty, tr) in [(-0.12, -0.36, 0.075), (-0.035, -0.40, 0.055), (0.04, -0.39, 0.05), (0.10, -0.35, 0.045), (0.15, -0.29, 0.04)]:
        s.fill(np.hypot(s.X - cx - sx * tx * size, s.Y - cy - ty * size) <= max(0.8, tr * size), INK)


def plate(s, x, y, w, h, fill=CREAM, border=RED):
    m = (s.X >= x) & (s.X < x + w) & (s.Y >= y) & (s.Y < y + h)
    s.fill(m, INK)
    s.fill((s.X >= x + 1) & (s.X < x + w - 1) & (s.Y >= y + 1) & (s.Y < y + h - 1), border)
    s.fill((s.X >= x + 3) & (s.X < x + w - 3) & (s.Y >= y + 3) & (s.Y < y + h - 3), fill)


def hud(s):
    W, H = s.W, s.H
    sc = 2
    # progress: a carved rope of diamonds, red up to where the song is
    y = int(H * 0.014)
    x0, x1 = int(W * 0.05), int(W * 0.95)
    prog = 0.42
    for x in range(x0, x1):
        k = (x - x0) % 6
        h = 2 - abs(k - 3) * 0.7
        col = RED if (x - x0) / (x1 - x0) < prog else CREAM
        for yy in range(-int(h), int(h) + 1):
            s.put(x, y + 3 + yy, col)
        s.put(x, y + 3, col)
    s.fill((s.Y >= y) & (s.Y < y + 7) & (np.abs(s.X - (x0 + prog * (x1 - x0))) < 1), CREAM)
    sy = y + 11
    score = '14,094'
    tw = text_w(score, sc)
    ph = 7 * sc + 10
    px0 = W - tw - 14 - 4
    plate(s, px0, sy, tw + 14, ph)
    text(s.img, score, px0 + 7, sy + 5, INK, None, sc)
    mult = '2x'
    tw2 = text_w(mult, sc)
    plate(s, 4, sy, tw2 + 14, ph, fill=RED, border=CREAM)
    text(s.img, mult, 4 + 7, sy + 5, CREAM, None, sc)
    cy = sy + ph + 6
    combo = '32'
    text(s.img, combo, int(W / 2 - text_w(combo, sc) / 2), cy, CREAM, INK, sc)
    text(s.img, 'COMBO', int(W / 2 - text_w('COMBO', 1) / 2), cy + 7 * sc + 3, RED, INK, 1)
    # judgement on a cream banner with cut ends, straddling the button bar
    jw = 'PERFECT'
    js = 2
    tw3 = text_w(jw, js)
    bx, byy = int(W / 2 - tw3 / 2) - 8, int(s.btn_top - 7 * js / 2 - 5)
    bwid, bh = tw3 + 16, 7 * js + 8
    plate(s, bx, byy, bwid, bh, fill=CREAM, border=INK)
    for k in range(int(bh / 2)):
        s.put(bx - 1 - (bh / 2 - k) * 0.6, byy + k, INK)
    text(s.img, jw, bx + 8, byy + 4, RED, None, js)


CFG = dict(name='lino_r2', size=(180, 400), scale=6, draw=draw,
           figures=[(0.12, 0.52, 66, True), (0.86, 0.585, 96, False)])
