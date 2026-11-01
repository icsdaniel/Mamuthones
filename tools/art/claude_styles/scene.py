"""Play-screen mockup, drawn at native pixel size for each style.

Layout matches the game: portrait 9:20, HUD on top, a street running to a
vanishing point, three full-width lanes, hit rings, three step buttons.
Every part is drawn by code from scratch; nothing is traced or stretched.
"""
import math
import numpy as np
from pxkit import Layer, Style, BAYER4, hexc, over, text, text_w
import figure

C = lambda h: np.array(hexc(h), np.uint8)


class Scene:
    def __init__(self, cfg):
        self.cfg = cfg
        self.W, self.H = cfg['size']
        W, H = self.W, self.H
        self.img = np.zeros((H, W, 4), np.uint8)
        Y, X = np.mgrid[0:H, 0:W]
        self.X, self.Y = X + 0.5, Y + 0.5
        self.Yi, self.Xi = Y, X
        self.vpx, self.vpy = W / 2, H * 0.335
        self.hity = H * 0.79
        self.hw0, self.hw1 = W * 0.075, W * 0.50
        self.btn_top = H * 0.845

    # --- geometry ----------------------------------------------------------
    def t_of_y(self, y):
        return (y - self.vpy) / (self.hity - self.vpy)

    def halfw(self, y):
        return self.hw0 + (self.hw1 - self.hw0) * self.t_of_y(y)

    def y_of_depth(self, s):
        """s = 0 at the hit line, 1 at the horizon; perspective compressed."""
        t = (1 - s) / (1 + 2.6 * s)
        return self.vpy + t * (self.hity - self.vpy)

    def lane_x(self, lane, y, frac=0.5):
        hw = self.halfw(y)
        return self.vpx - hw + (lane + frac) * (2 * hw / 3)

    # --- painting helpers ----------------------------------------------------
    def fill(self, mask, col):
        self.img[mask] = C(col) if isinstance(col, str) else col

    def gradient(self, mask, stops, y0, y1, dither=True):
        """Vertical gradient between colour stops with ordered dithering."""
        t = np.clip((self.Y - y0) / max(1e-6, (y1 - y0)), 0, 0.9999)
        n = len(stops) - 1
        f = t * n
        if dither:
            f = f + (BAYER4[self.Yi % 4, self.Xi % 4] - 0.5) * 0.9
        idx = np.clip(np.round(f), 0, n).astype(int)
        for k, c in enumerate(stops):
            self.fill(mask & (idx == k), c)

    def put(self, x, y, col):
        x, y = int(x), int(y)
        if 0 <= x < self.W and 0 <= y < self.H:
            self.img[y, x] = C(col) if isinstance(col, str) else col

    def sprite(self, arr, x, y):
        over(self.img, arr, int(round(x)), int(round(y)))


# =============================================================================
def draw(cfg, frame=0, nframes=1, beat_phase=0.0, fig_frame=0, cache={}):
    s = Scene(cfg)
    W, H = s.W, s.H
    P = cfg['pal']
    st = cfg['style']

    # ---- sky ---------------------------------------------------------------
    sky = s.Y < s.vpy + 2
    s.gradient(sky, P['sky'], 0, s.vpy)
    if cfg.get('sky_lines'):  # woodcut: carved horizontal strokes, denser near the horizon
        for y in range(int(H * 0.08), int(s.vpy)):
            t = (y - H * 0.08) / (s.vpy - H * 0.08)
            if t > 0.35 and (y % max(2, int(7 - 5 * t))) == 0:
                rng = np.random.default_rng(y)
                x = rng.integers(-6, 2)
                while x < W:
                    ln = rng.integers(4, 14)
                    seg = (s.Yi == y) & (s.Xi >= x) & (s.Xi < x + ln)
                    s.fill(seg & sky, P['sky_line'])
                    x += ln + rng.integers(2, 6)
    rng = np.random.default_rng(7)
    for _ in range(int(W * H * cfg.get('stars', 0.0))):
        x, y = rng.integers(0, W), rng.integers(int(H * 0.08), int(s.vpy * 0.85))
        s.put(x, y, P['star'] if rng.random() < 0.7 else P['star2'])
        if cfg.get('cross_stars') and rng.random() < 0.3:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                s.put(x + dx, y + dy, P['star2'])
    if 'moon' in P:
        mx, my, mr = W * 0.22, H * 0.15, W * 0.06
        d = ((s.X - mx) ** 2 + (s.Y - my) ** 2) ** 0.5
        s.fill(d <= mr, P['moon'])
        if cfg.get('moon_cut'):
            d2 = ((s.X - mx - mr * 0.45) ** 2 + (s.Y - my + mr * 0.2) ** 2) ** 0.5
            s.fill((d <= mr) & (d2 <= mr * 0.85), P['sky'][0])
    if cfg.get('clouds'):
        for (cx, cy, r) in ((0.2, 0.13, 0.09), (0.3, 0.12, 0.07), (0.75, 0.18, 0.08), (0.84, 0.17, 0.06)):
            for k in range(5):
                ox = (k - 2) * r * 0.7 * W
                rr = r * W * (1 - abs(k - 2) * 0.22)
                d = ((s.X - cx * W - ox) / rr) ** 2 + ((s.Y - cy * H) / (rr * 0.6)) ** 2
                m = d <= 1
                s.fill(m & (s.Y > cy * H), P['cloud_sh'])
                s.fill(m & (s.Y <= cy * H + rr * 0.15), P['cloud'])

    # ---- mountains on the horizon --------------------------------------------
    xs = np.arange(W) / W
    for k, (amp, base, col, seed) in enumerate(cfg['ridges']):
        ridge = base * H - amp * H * (0.55 * np.sin(xs * 7.1 + seed) + 0.3 * np.sin(xs * 17.3 + seed * 2) + 0.15 * np.sin(xs * 41 + seed))
        m = (s.Y >= ridge[None, :]) & (s.Y < s.vpy + 2)
        s.fill(m, col)

    # ---- house walls on both sides ------------------------------------------------
    base_edge, top_edge = H * 0.70, H * cfg.get('roof_near', 0.14)
    F = cfg.get('street_floor')
    if F:  # a wide street: the walls start where the floor meets the screen edge
        t_edge = (s.vpx / F - s.hw0) / (s.hw1 - s.hw0)
        base_edge = s.vpy + t_edge * (s.hity - s.vpy)
    for side in (-1, 1):
        u = (s.X - s.vpx) * side / s.vpx  # 0 at VP, 1 at screen edge
        valid = u > 0.02
        uu = np.where(valid, u, 1)
        base_y = s.vpy + (base_edge - s.vpy) * uu
        top_y = (s.vpy - H * 0.02) + (top_edge - (s.vpy - H * 0.02)) * uu
        v = (base_y - s.Y) / np.maximum(1e-6, base_y - top_y)
        z = 1.0 / uu
        hz = z * 1.25 + (0.4 if side > 0 else 0.0)
        house = np.floor(hz)
        w = hz - house
        h0_, h1_ = cfg.get('house_h', (0.62, 0.38))
        hh = h0_ + h1_ * (np.sin(house * 3.7 + side) * 0.5 + 0.5)
        wall = valid & (v >= 0) & (v <= hh)
        lit = (np.sin(house * 5.3 + side * 2) > -0.2)
        # wall tone: lit by the fire toward the centre
        s.gradient(wall, P['wall'], 0, W * 0.5) if False else None
        shade_idx = np.clip((1 - u) * len(P['wall']) + (BAYER4[s.Yi % 4, s.Xi % 4] - 0.5) * 0.8, 0, len(P['wall']) - 1).astype(int)
        for k, c in enumerate(P['wall']):
            s.fill(wall & (shade_idx == k), c)
        # stone courses
        if cfg.get('courses'):
            course = (np.floor(v * 9 * hh) != np.floor((v + 1.0 / np.maximum(1, base_y - top_y)) * 9 * hh))
            s.fill(wall & course & ((s.Xi + np.floor(v * 9).astype(int)) % 3 == 0), P['wall_line'])
        # house seams
        seam = wall & ((w < 0.035) | (w > 0.965))
        s.fill(seam, P['seam'])
        # roof edge
        rk = cfg.get('roof_k', 1.0)
        roof = valid & (v > hh) & (v <= hh + (0.05 + 0.02 / uu) * rk)
        s.fill(roof, P['roof'])
        if cfg.get('roof_tiles'):          # curved Sardinian tiles: dark gaps in the red
            tiles = roof & ((s.Yi % 3 == 0) | ((s.Xi % 4 == 0) & (s.Yi % 3 == 1)))
            s.fill(tiles, P['roof_line'])
        if 'roof2' in P:
            s.fill(valid & (v > hh) & (v <= hh + 0.02), P['roof2'])
        # windows and doors
        win = wall & (w > 0.32) & (w < 0.58) & (v > 0.5) & (v < 0.5 + 0.22 * hh)
        door = wall & (w > 0.62) & (w < 0.86) & (v < 0.36)
        s.fill(win & lit, P['win_lit'])
        s.fill(win & ~lit, P['win_dark'])
        s.fill(door, P['door'])
        if 'shutter' in P:
            sh = wall & (((w > 0.24) & (w < 0.32)) | ((w > 0.58) & (w < 0.66))) & (v > 0.5) & (v < 0.5 + 0.22 * hh)
            s.fill(sh, P['shutter'])
        if 'win_frame' in P:
            fr = wall & (w > 0.30) & (w < 0.60) & (np.abs(v - 0.49) < 0.02)
            s.fill(fr, P['win_frame'])
        # sidewalk between wall base and road
        side_m = valid & (v < 0) & (s.Y < base_y + (H * 0.79 - base_y) * 1.0)
        s.fill(side_m, P['sidewalk'])

    # ---- road: cobbles in perspective -------------------------------------------
    t = s.t_of_y(s.Y)
    hw = s.hw0 + (s.hw1 - s.hw0) * t
    road = (s.Y >= s.vpy) & (np.abs(s.X - s.vpx) <= hw + 0.5) & (s.Y < s.btn_top)
    # wider kerb band outside lanes
    if F:
        floor = (s.Y >= s.vpy) & (np.abs(s.X - s.vpx) <= hw * F) & ~road & (s.Y < s.btn_top)
        s.fill(floor, P['floor'])
        # carved strokes across the street floor, tightening toward the horizon
        r_ = np.random.default_rng(31)
        for k in range(1, 40):
            tt_ = 1.0 / (1.0 + k * 0.45)
            y = int(s.vpy + tt_ * (s.hity - s.vpy) * 1.15)
            if y >= s.btn_top or tt_ < 0.12:
                continue
            hw_ = s.halfw(y)
            dash = max(2, int(hw_ * 0.14))
            for sd in (-1, 1):
                x = hw_ * 1.1 + (k % 2) * dash * 0.5
                while x < hw_ * F - 1:
                    ln = int(dash * (0.5 + 0.6 * r_.random()))
                    for j in range(ln):
                        if x + j < hw_ * F - 1:
                            s.put(s.vpx + sd * (x + j), y, P['floor_line'])
                    x += ln + max(2, int(dash * 0.7))
        # the floor's outer edge, where the houses stand
        for y in range(int(s.vpy), int(s.btn_top)):
            for sd in (-1, 1):
                s.put(s.vpx + sd * (s.halfw(y + 0.5) * F), y, P['floor_edge'])
    kerb = (s.Y >= s.vpy) & (np.abs(s.X - s.vpx) <= hw * (1.05 if F else 1.12) + 1) & ~road & (s.Y < s.btn_top)
    s.fill(kerb, P['kerb'])
    tt = np.maximum(t, 0.02)
    zz = 1.0 / tt
    rowf = zz * cfg.get('cobble_rows', 2.2)
    row = np.floor(rowf)
    lat = (s.X - s.vpx) / np.maximum(hw, 1) * cfg.get('cobble_cols', 4) + 0.5 * (row % 2)
    fr_r = rowf - row
    fr_c = lat - np.floor(lat)
    px_r = 1.0 / np.maximum(1e-3, (s.hity - s.vpy) * tt * tt / (zz * 0 + 1)) * cfg.get('cobble_rows', 2.2)
    mortar = (fr_r < np.clip(px_r * 1.0, 0, 0.45)) | (fr_c < np.clip(0.9 / np.maximum(hw, 1) * cfg.get('cobble_cols', 4), 0, 0.4))
    ci = np.clip((np.sin(row * 12.9 + np.floor(lat) * 4.1) * 0.5 + 0.5) * len(P['cobble']), 0, len(P['cobble']) - 0.01).astype(int)
    for k, c in enumerate(P['cobble']):
        s.fill(road & ~mortar & (ci == k), c)
    s.fill(road & mortar, P['mortar'])
    # darken the far end so the horizon recedes
    fog = road & (t < 0.18) & ((s.Xi + s.Yi) % 2 == 0)
    s.fill(fog, P['mortar'])

    # ---- bonfire / tower at the vanishing point ------------------------------------
    if cfg.get('fire'):
        draw_fire(s, cfg, frame, nframes)
    if cfg.get('tower'):
        draw_tower(s, cfg)

    # ---- lane lines ---------------------------------------------------------------
    for i in range(4):
        x_far = s.vpx - s.hw0 + i * (2 * s.hw0 / 3)
        x_near = s.vpx - s.hw1 + i * (2 * s.hw1 / 3)
        for y in range(int(s.vpy), int(s.btn_top)):
            tt_ = s.t_of_y(y + 0.5)
            x = x_far + (x_near - x_far) * tt_
            edge = i in (0, 3)
            core = P['lane_edge'] if edge else P['lane']
            s.put(x, y, core)
            if cfg.get('lane_glow') and tt_ > 0.15:
                s.put(x - 1, y, P['lane_glow'])
                s.put(x + 1, y, P['lane_glow'])
                if edge and cfg.get('wide_edge') and tt_ > 0.4:
                    s.put(x + (1 if i == 0 else -1) * 2, y, P['lane_glow2'])

    if cfg.get('extra_fn'):
        cfg['extra_fn'](s, frame, nframes)

    # ---- the Mamuthones: two rows, as in the procession -----------------------------
    figs = cfg['figures']
    for (fx, fy, fh, flip) in figs:
        key = (cfg['name'], fh)
        if key not in cache:
            f, parts = figure.build(st, fh, cfg.get('fig_opts'))
            cache[key] = (f, figure.render_parts(f, parts, st))
        f, rp = cache[key]
        arr = figure.compose(f, rp, fig_frame, C(cfg['keyline']) if cfg.get('keyline') else None)
        if flip:
            arr = arr[:, ::-1]
        s.sprite(arr, fx * W - f.W / 2, fy * H - f.CH)

    # ---- notes ---------------------------------------------------------------------
    if cfg.get('notes_fn'):
        cfg['notes_fn'](s, beat_phase)
        cfg['rings_fn'](s)
    else:
        draw_notes(s, cfg, beat_phase)

        # ---- hit rings -----------------------------------------------------------------
        for lane in range(3):
            cx = s.lane_x(lane, s.hity)
            rx = (2 * s.hw1 / 3) * 0.42
            ry = rx * cfg.get('note_flat', 0.36)
            d = ((s.X - cx) / rx) ** 2 + ((s.Y - s.hity) / ry) ** 2
            d2 = ((s.X - cx) / (rx - cfg['ring_w'])) ** 2 + ((s.Y - s.hity) / (ry - cfg['ring_w'] * 0.6)) ** 2
            ring = (d <= 1) & (d2 > 1)
            if lane in getattr(s, 'flash', ()):
                s.fill((d <= 1.5) & (d2 > 1) & ((s.Xi + s.Yi) % 2 == 0), P['ring_hi'])
                s.fill(ring, P['ring_hi'])
            s.fill(ring & (s.Y < s.hity), P['ring_hi'])
            s.fill(ring & (s.Y >= s.hity), P['ring'])
            if 'ring_in' in P:
                s.fill((d2 <= 1) & ((s.Xi + s.Yi) % 2 == 0), P['ring_in'])
        if cfg.get('ring_cord'):
            y = int(s.hity)
            for x in range(0, W):
                if not any(abs(x - s.lane_x(l, s.hity)) < (2 * s.hw1 / 3) * 0.42 for l in range(3)):
                    s.put(x, y, P['ring'])

    # ---- step buttons -----------------------------------------------------------------
    (cfg.get('buttons_fn') or (lambda s_: draw_buttons(s_, cfg)))(s)

    # ---- print grain: a few specks so flat ink and paper look printed --------------------
    if cfg.get('grain'):
        g = np.random.default_rng(11).random((H, W))
        for a, b, amt in cfg['grain']:
            ca, cb = C(a), C(b)
            hit = np.all(s.img == ca, axis=-1) & (g < amt)
            s.img[hit] = cb

    # ---- HUD ------------------------------------------------------------------------------
    (cfg.get('hud_fn') or (lambda s_: draw_hud(s_, cfg)))(s)
    return s.img


# =============================================================================
def draw_fire(s, cfg, frame, nframes):
    P = cfg['pal']
    W, H = s.W, s.H
    fw = W * cfg.get('fire_w', 0.13)
    fh = H * cfg.get('fire_h', 0.09)
    cx, by = s.vpx, s.vpy + H * 0.012
    # glow on the road
    d = ((s.X - cx) / (fw * 2.2)) ** 2 + ((s.Y - by) / (fh * 0.9)) ** 2
    glow = (d < 1) & (s.Y > by - 1) & ((s.Xi + s.Yi) % 2 == 0) & (np.abs(s.X - s.vpx) <= s.halfw(s.Y) + 0.5)
    s.fill(glow, P['fire_glow'])
    ph = frame / max(1, nframes) * 2 * math.pi
    x0, x1 = int(cx - fw), int(cx + fw) + 1
    y0, y1 = int(by - fh * 1.25), int(by) + 1
    ramp = P['fire']
    for y in range(y0, y1):
        for x in range(x0, x1):
            u = (x + 0.5 - cx) / fw
            v = (by - (y + 0.5)) / fh  # 0 at base, 1 at top
            if v < 0:
                continue
            wob = 0.18 * math.sin(v * 7 - ph * 2 + u * 3) + 0.12 * math.sin(v * 13 + ph * 3)
            width = max(0.0, 1 - v) ** 0.8 * (0.85 + 0.25 * math.sin(u * 9 + ph * 2 + v * 5))
            val = width - abs(u + wob * v)
            # tongues
            val += 0.25 * math.sin(u * 11 + ph * 4) * v
            if val <= 0:
                continue
            k = min(len(ramp) - 1, int(val * len(ramp) * 1.6))
            s.put(x, y, ramp[k])
    # logs
    for k in (-1, 1):
        for i in range(int(fw * 1.5)):
            x = cx + k * (i - fw * 0.75) * 0.9
            y = by - 1 + (i - fw * 0.75) * 0.35 * k * 0.6
            s.put(x, y, P['log'])
            s.put(x, y + 1, P['log2'])
    # sparks
    rng = np.random.default_rng(frame + 3)
    for _ in range(cfg.get('sparks', 8)):
        x = cx + rng.normal(0, fw * 0.6)
        y = by - fh * (1.1 + rng.random() * 1.4)
        s.put(x, y, ramp[-1] if rng.random() < 0.5 else ramp[-2])


def draw_tower(s, cfg):
    P = cfg['pal']
    W, H = s.W, s.H
    tw, th = W * 0.08, H * 0.13
    x0, x1 = s.vpx - tw / 2, s.vpx + tw / 2
    yb = s.vpy + 1
    m = (s.X >= x0) & (s.X < x1) & (s.Y >= yb - th) & (s.Y < yb)
    s.fill(m, P['tower'])
    s.fill(m & (s.X < x0 + tw * 0.35), P['tower_sh'])
    # belfry opening
    o = (np.abs(s.X - s.vpx) < tw * 0.18) & (s.Y > yb - th * 0.86) & (s.Y < yb - th * 0.68)
    s.fill(o, P['tower_open'])
    # little bell
    s.fill((np.abs(s.X - s.vpx) < tw * 0.1) & (s.Y > yb - th * 0.78) & (s.Y < yb - th * 0.70), P['tower_bell'])
    # pyramid cap
    cap = (s.Y < yb - th) & (s.Y > yb - th * 1.35) & (np.abs(s.X - s.vpx) < (tw / 2 + 1) * (s.Y - (yb - th * 1.35)) / (th * 0.35))
    s.fill(cap, P['roof'])
    s.fill(cap & (s.X > s.vpx), P['roof2'] if 'roof2' in P else P['roof'])


def disc(s, cfg, cx, cy, w, kind):
    """A note: a flat disc with a thickness band, shaded through the style."""
    st = cfg['note_style']
    flat = cfg.get('note_flat', 0.36)
    h = max(2, w * flat)
    th = max(1, round(w * 0.09))
    Wl, Hl = int(w) + 4, int(h + th) + 4
    L = Layer(Wl, Hl)
    ox, oy = Wl / 2, (h / 2) + 2
    # side band
    L.ellipse(ox, oy + th, w / 2, h / 2, st.m(kind + '_side'), L=(0, 0.2, 1), amb=0.4)
    L.rect(ox - w / 2, oy, ox + w / 2, oy + th, st.m(kind + '_side'), light=0.45)
    L.ellipse(ox, oy, w / 2, h / 2, st.m(kind), L=(-0.5, -0.9, 0.6), amb=0.3)
    # emblem: a small bright mark in the centre (a bell-mouth ring)
    if w >= 9:
        L.ellipse(ox, oy, w * 0.22, h * 0.22, st.m(kind + '_side'), L=(0.5, 0.9, 0.6), amb=0.2)
        L.ellipse(ox - w * 0.03, oy - h * 0.04, w * 0.12, h * 0.12, st.m(kind), L=(-0.5, -0.9, 0.6), amb=0.6)
    arr = st.render(L)
    s.sprite(arr, cx - Wl / 2, cy - oy)


PATTERN = [  # (beat, kind, lane or tilt, hold length in beats) - loops every 8 beats
    (0.0, 'note_q', 1, 0), (0.5, 'note_e', 0, 0), (1.0, 'note_q', 2, 0), (2.0, 'bell', 'up', 0),
    (3.0, 'note_h', 0, 1.5), (4.5, 'note_o', 2, 0), (5.0, 'note_q', 1, 0), (6.0, 'bell', 'down', 0),
    (7.0, 'note_q', 0, 0), (7.5, 'note_e', 2, 0),
]
LOOP = 8
SP = 0.118  # depth per beat


def visible_notes(phase):
    out = []
    for rep in range(-1, 3):
        for (bt, kind, lane, ln) in PATTERN:
            d = (bt + rep * LOOP - phase) * SP
            dt = (bt + ln + rep * LOOP - phase) * SP
            if dt >= -0.02 and d <= 0.8:
                out.append((d, kind, lane, dt))
    return out


def draw_notes(s, cfg, phase):
    P = cfg['pal']
    lane_w = lambda y: 2 * s.halfw(y) / 3
    notes = sorted(visible_notes(phase), key=lambda n: -n[0])
    s.flash = set()
    for (d, kind, lane, dt) in notes:
        if kind == 'bell':
            if d < -0.01:
                continue
            if abs(d) < 0.03:
                s.flash.update((0, 1, 2))
            y = s.y_of_depth(max(0, d))
            hw = s.halfw(y)
            th = max(2, lane_w(y) * 0.16)
            up = lane == 'up'
            col, hi = (P['bell_up'], P['bell_up_hi']) if up else (P['bell_dn'], P['bell_dn_hi'])
            m = (np.abs(s.X - s.vpx) <= hw - 1) & (s.Y >= y - th / 2) & (s.Y < y + th / 2)
            s.fill(m, col)
            s.fill(m & (s.Y < y - th / 2 + max(1, th * 0.3)), hi)
            edge = (np.abs(s.X - s.vpx) <= hw) & ((np.abs(s.Y - (y - th / 2 - 0.5)) < 0.5) | (np.abs(s.Y - (y + th / 2 + 0.5)) < 0.5))
            s.fill(edge, P['note_ink'])
            for ln_ in range(3):
                ax = s.lane_x(ln_, y)
                a = max(1, int(th * 0.5))
                for k in range(a + 1):
                    yy = y - a / 2 + k if up else y + a / 2 - k
                    for dx in range(-k, k + 1):
                        s.put(ax + dx, yy, P['bell_arrow'])
            continue
        if kind == 'note_h':
            hd, tl = d, dt
            y0, y1 = s.y_of_depth(max(0, hd)), s.y_of_depth(min(1, tl))
            for y in range(int(y1), int(y0) + 1):
                cx = s.lane_x(lane, y + 0.5)
                rw = lane_w(y) * cfg.get('rope_w', 0.16)
                for x in range(int(cx - rw), int(cx + rw) + 1):
                    u = (x + 0.5 - cx) / max(rw, 0.5)
                    tw = int((x + y * 1.0) // max(1, int(rw * 0.9))) % 2
                    c = P['rope'][1 + tw] if abs(u) < 0.6 else P['rope'][0]
                    if u < -0.3 and tw == 0:
                        c = P['rope'][2]
                    s.put(x, y, c)
            if tl <= 1:
                disc(s, cfg, s.lane_x(lane, y1), y1, lane_w(y1) * 0.5, 'note_h')
            if hd <= 0 < tl:
                s.flash.add(lane)
            disc(s, cfg, s.lane_x(lane, y0), y0, lane_w(y0) * 0.8, 'note_h')
            continue
        if d < -0.015:
            continue
        if abs(d) < 0.03:
            s.flash.add(lane)
        y = s.y_of_depth(max(-0.01, d))
        disc(s, cfg, s.lane_x(lane, y), y, lane_w(y) * 0.8, kind)


def foot(Lw, Lh, two=False):
    """Bare footprint mask (the step buttons)."""
    L = Layer(Lw, Lh)
    return L


def draw_buttons(s, cfg):
    P = cfg['pal']
    W, H = s.W, s.H
    top, bot = int(s.btn_top), int(H * 0.985)
    s.fill(s.Y >= s.btn_top - 1, P['panel_bg'])
    gap = max(1, round(W * 0.02))
    bw = (W - 4 * gap) / 3
    for i in range(3):
        x0 = gap + i * (bw + gap)
        x1 = x0 + bw
        m = (s.X >= x0) & (s.X < x1) & (s.Y >= top + gap) & (s.Y < bot)
        bt = cfg['btn']
        s.fill(m, P['btn'][1])
        inner = (s.X >= x0 + bt) & (s.X < x1 - bt) & (s.Y >= top + gap + bt) & (s.Y < bot - bt)
        # bevel
        s.fill(m & ~inner & ((s.Y < top + gap + bt) | (s.X < x0 + bt)), P['btn'][2])
        s.fill(m & ~inner & ((s.Y >= bot - bt) | (s.X >= x1 - bt)), P['btn'][0])
        s.fill(inner, P['btn_face'][0])
        if cfg.get('btn_planks'):
            pl = inner & ((s.Yi - top) % max(3, int((bot - top) / 4)) == 0)
            s.fill(pl, P['btn_face'][1])
        if cfg.get('btn_dither'):
            dd = inner & ((s.Xi + s.Yi) % 2 == 0) & (s.Y > (top + bot) / 2 + (bot - top) * 0.2)
            s.fill(dd, P['btn_face'][1])
        outline = m & ~((s.X >= x0 + 1) & (s.X < x1 - 1) & (s.Y >= top + gap + 1) & (s.Y < bot - 1))
        s.fill(outline, P['btn_ink'])
        # rivets
        if cfg.get('rivets'):
            for (rx, ry) in ((x0 + bt + 1, top + gap + bt + 1), (x1 - bt - 2, top + gap + bt + 1),
                             (x0 + bt + 1, bot - bt - 2), (x1 - bt - 2, bot - bt - 2)):
                s.put(rx, ry, P['rivet'])
        # feet
        cx, cy = (x0 + x1) / 2, (top + gap + bot) / 2
        fs = (bot - top) * 0.55
        if i == 1:
            draw_foot(s, cfg, cx - fs * 0.24, cy, fs, mirror=True)
            draw_foot(s, cfg, cx + fs * 0.24, cy, fs, mirror=False)
        else:
            draw_foot(s, cfg, cx, cy, fs, mirror=(i == 0))


def draw_foot(s, cfg, cx, cy, size, mirror):
    P = cfg['pal']
    sx = -1 if mirror else 1
    # sole: big ellipse (ball) + smaller heel, toes as dots in an arc
    pts = []
    rx, ry = size * 0.17, size * 0.26
    ball = ((s.X - cx - sx * size * 0.02) / rx) ** 2 + ((s.Y - cy + size * 0.03) / ry) ** 2 <= 1
    heel = ((s.X - cx + sx * size * 0.02) / (rx * 0.8)) ** 2 + ((s.Y - cy - size * 0.27) / (ry * 0.45)) ** 2 <= 1
    arch = (np.abs(s.X - cx) < rx * 0.75) & (s.Y > cy) & (s.Y < cy + size * 0.27)
    sole = ball | heel | arch
    s.fill(sole, P['foot'])
    # arch cut on the inner side
    cut = ((s.X - cx + sx * rx * 1.25) / (rx * 0.65)) ** 2 + ((s.Y - cy - size * 0.12) / (ry * 0.45)) ** 2 <= 1
    s.fill(sole & cut, P['btn_face'][0])
    toes = [(-0.12, -0.36, 0.075), (-0.035, -0.40, 0.055), (0.04, -0.39, 0.05), (0.10, -0.35, 0.045), (0.15, -0.29, 0.04)]
    for (tx, ty, tr) in toes:
        r = max(0.7, tr * size)
        d = ((s.X - cx - sx * tx * size) ** 2 + (s.Y - cy - ty * size) ** 2) ** 0.5
        s.fill(d <= r, P['foot'])


def draw_hud(s, cfg):
    P = cfg['pal']
    W, H = s.W, s.H
    sc = cfg.get('font_scale', 1)
    # progress bar
    y = max(2, int(H * 0.012))
    bh = max(2, int(H * 0.008))
    x0, x1 = int(W * 0.06), int(W * 0.94)
    s.fill((s.X >= x0 - 1) & (s.X < x1 + 1) & (s.Y >= y - 1) & (s.Y < y + bh + 1), P['hud_ink'])
    s.fill((s.X >= x0) & (s.X < x1) & (s.Y >= y) & (s.Y < y + bh), P['hud_track'])
    s.fill((s.X >= x0) & (s.X < x0 + (x1 - x0) * 0.42) & (s.Y >= y) & (s.Y < y + bh), P['hud_fill'])
    # score plate on the right
    sy = y + bh + max(2, int(H * 0.01))
    score = '14,094'
    tw = text_w(score, sc)
    pw, ph = tw + 6 * sc, 7 * sc + 6 * sc
    px0 = W - pw - max(2, int(W * 0.03))
    plate(s, cfg, px0, sy, pw, ph)
    text(s.img, score, px0 + 3 * sc, sy + 3 * sc, P['hud_text'], P['hud_text_sh'], sc)
    # multiplier badge on the left
    mult = '2x'
    if cfg.get('no_mult'):
        mult = None
    if mult:
        tw2 = text_w(mult, sc)
        plate(s, cfg, max(2, int(W * 0.03)), sy, tw2 + 6 * sc, ph)
        text(s.img, mult, max(2, int(W * 0.03)) + 3 * sc, sy + 3 * sc, P['hud_mult'], P['hud_text_sh'], sc)
    # combo
    combo = cfg.get('combo_text', '32')
    cs = cfg.get('combo_scale', sc)
    cy = sy + ph + max(2, int(H * 0.01))
    text(s.img, combo, int(W / 2 - text_w(combo, cs) / 2), cy, P.get('combo', P['hud_text']), P.get('combo_sh', P['hud_text_sh']), cs)
    if cfg.get('combo_word', True) and sc >= 1:
        cw = 'COMBO'
        text(s.img, cw, int(W / 2 - text_w(cw, 1) / 2), cy + 7 * cs + 2, P['hud_text2'], P.get('combo_sh', P['hud_text_sh']), 1)
    # judgement above the hit line
    jw = 'PERFECT'
    js = cfg.get('judge_scale', sc)
    jx = int(W / 2 - text_w(jw, js) / 2)
    jy = int(s.btn_top - 7 * js * 0.5 - 2 * js)
    plate(s, cfg, jx - 3 * js, jy - 2 * js, text_w(jw, js) + 6 * js, 7 * js + 4 * js, judge=True)
    text(s.img, jw, jx, jy, P['judge'], P['hud_text_sh'], js)


def plate(s, cfg, x, y, w, h, judge=False):
    P = cfg['pal']
    m = (s.X >= x) & (s.X < x + w) & (s.Y >= y) & (s.Y < y + h)
    inner = (s.X >= x + 1) & (s.X < x + w - 1) & (s.Y >= y + 1) & (s.Y < y + h - 1)
    s.fill(m, P['hud_ink'])
    s.fill(inner, P['plate'])
    b = cfg.get('plate_border', 1)
    if b:
        rim_ = inner & ~((s.X >= x + 1 + b) & (s.X < x + w - 1 - b) & (s.Y >= y + 1 + b) & (s.Y < y + h - 1 - b))
        s.fill(rim_ & ((s.Y < y + 1 + b) | (s.X < x + 1 + b)), P['plate_hi'])
        s.fill(rim_ & ((s.Y >= y + h - 1 - b) | (s.X >= x + w - 1 - b)), P['plate_lo'])
