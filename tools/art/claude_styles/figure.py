"""The Mamuthone, drawn from scratch as separate parts so the game can bob them.

Coordinates are in figure units (1.0 = figure height), x centred. Each style
renders the same anatomy with its own ramps, outline and texture rules, at its
own native size. Parts share one canvas so offsets are simple.
"""
import math
import numpy as np
from pxkit import Layer, over

PART_ORDER = ['back_bells', 'legs', 'body', 'arms', 'head', 'front_bells']

# Bob: snap down, hold, settle back. Offsets in figure units (scaled to px per
# style, rounded). Bells lag a frame behind the body, the head a little less.
# Times follow the game's current bob (200/90/80/130 ms).
BOB_TIMES_MS = [200, 90, 80, 130]
BOB = {
    'back_bells':  [0.0, 0.010, 0.050, 0.030],
    'legs':        [0.0, 0.0, 0.0, 0.0],
    'body':        [0.0, 0.040, 0.042, 0.018],
    'arms':        [0.0, 0.040, 0.046, 0.020],
    'head':        [0.0, 0.030, 0.048, 0.022],
    'front_bells': [0.0, 0.015, 0.058, 0.026],
}


def tri(x):
    """Triangle wave 0..1..0 with period 1."""
    f = x - np.floor(x)
    return 1 - np.abs(2 * f - 1)


class Fig:
    def __init__(self, style, H, pad_top=None):
        self.st = style
        self.H = H
        self.W = int(round(H * 0.86)) | 1
        self.pad = pad_top if pad_top is not None else max(2, H // 16)
        self.CH = H + self.pad + 1

    def P(self, x, y):
        return self.W / 2 + x * self.H, self.pad + y * self.H

    def S(self, v):
        return v * self.H

    def layer(self):
        return Layer(self.W, self.CH)


def _hash(a, b):
    v = np.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return v - np.floor(v)


def fleece_mod(fig, amp=0.32, cell=None):
    tw = cell or max(2.0, fig.H / 15.0)
    th = tw * 1.8

    def mod(X, Y):
        col = np.floor(X / tw)
        jit = _hash(col, 3.1)
        yy = Y / th + jit
        row = np.floor(yy)
        j2 = _hash(col, row)
        u = X / tw - col
        v = yy - row
        half = 0.62 * (1.0 - 0.85 * v)  # lock narrows to its tip
        inside = np.abs(u - 0.45) < half
        lit = amp * (0.5 - 0.6 * v) + 0.12 * (j2 - 0.5) - 0.15 * (u - 0.45)
        return np.where(inside, lit, -amp * 0.8)
    return mod


def spiky_ellipse_mask(fig, L, cx, cy, rx, ry, n_spikes, depth, lower_only=True):
    X, Y = L.X, L.Y
    dx = (X - cx) / rx
    dy = (Y - cy) / ry
    rho = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    sp = tri(ang / (2 * math.pi) * n_spikes) * depth
    if lower_only:
        sp = sp * np.clip(dy * 1.6 + 0.4, 0, 1)
    m = rho <= 1 + sp
    nz = np.sqrt(np.clip(1 - np.minimum(rho, 1) ** 2, 0, 1))
    return m, dx / np.maximum(rho, 1e-6) * np.minimum(rho, 1), dy / np.maximum(rho, 1e-6) * np.minimum(rho, 1), nz


def shaggy(f, L, cx, cy, rx, ry, n, depth, droop=0.6, seed=1, top_flat=0.0):
    """Polygon blob whose outline breaks into hanging locks of fleece."""
    pts = []
    rng = np.random.default_rng(seed)
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        if i % 2 == 0:
            k = 1.0
            pts.append((cx + rx * ca * k, cy + ry * sa * k))
        else:
            low = max(0.0, sa) ** 0.7  # long locks at the hem, short at the top
            d = depth * (0.35 + 0.65 * low) * (0.7 + 0.6 * rng.random())
            if sa < -0.3:
                d *= top_flat
            tx = cx + rx * ca * (1 + d * (1 - droop * low))
            ty = cy + ry * sa + d * ry * (0.4 + droop * low)
            pts.append((tx, ty))
    from pxkit import point_in_poly
    m = point_in_poly(L.X, L.Y, pts)
    dx = (L.X - cx) / rx
    dy = (L.Y - cy) / ry
    rho = np.minimum(np.sqrt(dx * dx + dy * dy), 1.0)
    nz = np.sqrt(np.clip(1 - rho * rho, 0, 1))
    return m, np.clip(dx, -1, 1), np.clip(dy, -1, 1), nz


def fleece_fill(f, L, m, base, mat, seed=0, amp=0.75):
    """Fill with a dark base, then stamp hanging locks top to bottom like shingles."""
    H = f.H
    lw = max(2, int(round(H / 20)))      # lock width in px
    lh = max(4, int(round(H / 7)))      # lock length in px
    base = np.asarray(base, np.float32)
    L.mat[m] = mat
    L.light[m] = (base * 0.7 - amp * 0.35)[m]
    rng = np.random.default_rng(seed)
    yy, xx = np.where(m)
    if len(yy) == 0:
        return
    n = int(len(yy) / (lw * lh * 0.35)) + 1
    pick = rng.integers(0, len(yy), n)
    cents = sorted(zip(yy[pick] - lh * 0.3, xx[pick]), key=lambda p: p[0])
    for (jy, cxp) in cents:
        ln = lh * (0.7 + 0.6 * rng.random())
        for v in range(int(ln)):
            t = v / ln
            half = (lw / 2) * (1 - t) + 0.25
            py = int(jy + v)
            for u in range(int(cxp - lw), int(cxp + lw) + 1):
                if abs(u + 0.5 - cxp) <= half and 0 <= py < L.h and 0 <= u < L.w and m[py, u]:
                    L.light[py, u] = base[py, u] * 0.8 + amp * (0.35 - 0.8 * t) - 0.04 * (u + 0.5 - cxp)
    L.light[m] = np.clip(L.light[m] * 0.85, 0, 0.78)


def rim(L, dirx, diry, amt):
    """Brighten pixels whose neighbour toward the light is empty."""
    filled = L.mat >= 0
    sh = np.roll(np.roll(filled, diry, 0), dirx, 1)
    edge = filled & ~sh
    L.light[edge] += amt


def shade_n(nx, ny, nz, Lv=(-0.55, -0.6, 0.6), amb=0.16):
    lx, ly, lz = Lv
    n = (lx * lx + ly * ly + lz * lz) ** 0.5
    return (amb + (1 - amb) * np.clip((nx * lx + ny * ly + nz * lz) / n, 0, 1)).astype(np.float32)


def build(style, H, opts=None):
    """Return dict part -> Layer for the rest pose."""
    o = dict(tuft=None, tuft_amp=0.75, spikes=20, spike_depth=0.30, front_bells=3,
             back_bells=4, light=(-0.55, -0.6, 0.6))
    o.update(opts or {})
    f = Fig(style, H)
    st = style
    M = st.m
    Lv = o['light']
    parts = {}

    # --- back bells: big sonazzos riding high on the shoulders, mouths out ---
    BL = []
    bells = [(-0.235, 0.275, 0.083), (0.235, 0.275, 0.083), (-0.13, 0.205, 0.072), (0.13, 0.205, 0.072), (-0.17, 0.12, 0.062), (0.17, 0.12, 0.062)]
    if o['back_bells'] == 6:
        bells = [(-0.27, 0.33, 0.07), (0.27, 0.33, 0.07)] + bells
    for (bx, by, br) in bells:
        L = f.layer(); BL.append(L)
        cx, cy = f.P(bx, by)
        r = f.S(br)
        L.ellipse(cx, cy, r * 1.05, r, M('bronze'), L=Lv, amb=0.22)
        # open mouth faces outwards and up
        side = 1 if bx > 0 else -1
        mx, my = cx + side * r * 0.32, cy - r * 0.18
        L.ellipse(mx, my, r * 0.55, r * 0.5, M('bronze_in'), L=(-side * 0.6, 0.6, 0.5), amb=0.05)
    parts['back_bells'] = BL[4:] + BL[2:4] + BL[:2]

    # --- legs: dark velvet trousers, heavy boots ---
    L = f.layer()
    for sx in (-1, 1):
        x0, y0 = f.P(sx * 0.115 - 0.055, 0.74)
        x1, y1 = f.P(sx * 0.115 + 0.055, 0.95)
        L.rect(x0, y0, x1, y1, M('velvet'), light=0.45 - 0.15 * sx)
        cx, cy = f.P(sx * 0.125, 0.965)
        L.ellipse(cx, cy, f.S(0.082), f.S(0.042), M('boot'), L=Lv)
        L.rect(x0 - 0.5, cy - f.S(0.04), x1 + 0.5, cy, M('boot'), light=0.35 - 0.1 * sx)
    parts['legs'] = L

    # --- body: the mastruca (black sheepskin), straps across ---
    L = f.layer()
    fm = fleece_mod(f, o['tuft_amp'], o['tuft'])
    # main mass: hangs to the knees in long locks
    cx, cy = f.P(0, 0.50)
    m, nx, ny, nz = shaggy(f, L, cx, cy, f.S(0.285), f.S(0.235), 15, 0.32, seed=3, top_flat=0.3)
    fleece_fill(f, L, m, shade_n(nx, ny, nz, Lv), M('fleece'), seed=1, amp=o['tuft_amp'])
    cx, cy = f.P(0, 0.375)
    m, nx, ny, nz = shaggy(f, L, cx, cy, f.S(0.30), f.S(0.11), 13, 0.35, seed=5, top_flat=0.4)
    fleece_fill(f, L, m, shade_n(nx, ny, nz, Lv), M('fleece'), seed=2, amp=o['tuft_amp'])
    # leather straps crossing the chest, buckle at the cross
    w = max(1.6, f.S(0.034))
    a = f.P(-0.20, 0.33); b = f.P(0.17, 0.62)
    L.band(a[0], a[1], b[0], b[1], w, M('leather'), light=0.62)
    a = f.P(0.20, 0.33); b = f.P(-0.17, 0.62)
    L.band(a[0], a[1], b[0], b[1], w, M('leather'), light=0.5)
    bx, by = f.P(0, 0.475)
    s = max(1.0, f.S(0.022))
    L.rect(bx - s, by - s, bx + s, by + s, M('brass_small'), light=0.85)
    parts['body'] = L

    # --- arms: fleece sleeves, dark hands hanging by the sides ---
    L = f.layer()
    for sx in (-1, 1):
        hx, hy = f.P(sx * 0.315, 0.715)
        L.ellipse(hx, hy, f.S(0.038), f.S(0.042), M('hand'), L=Lv)
    for sx in (-1, 1):
        cx, cy = f.P(sx * 0.31, 0.52)
        m, nx, ny, nz = shaggy(f, L, cx, cy, f.S(0.07), f.S(0.17), 7, 0.45, seed=7 + sx, top_flat=0.2)
        fleece_fill(f, L, m, shade_n(nx, ny, nz, Lv) - 0.05, M('fleece'), seed=4 + sx, amp=o['tuft_amp'])
    parts['arms'] = L

    # --- head: scarf (muncadore) wrapped round the wooden mask (visera) ---
    L = f.layer()
    cx, cy = f.P(0, 0.195)
    L.ellipse(cx, cy, f.S(0.125), f.S(0.135), M('scarf'), L=Lv)
    # scarf knot / drape under the chin
    pts = [f.P(-0.10, 0.26), f.P(0.10, 0.26), f.P(0.0, 0.37)]
    L.poly(pts, M('scarf'), light=0.4)
    # the mask: long, dark, carved wood
    mx, my = f.P(0, 0.205)
    L.ellipse(mx, my, f.S(0.074), f.S(0.10), M('mask'), L=Lv, amb=0.1)
    rimm = (L.mat == M('mask'))
    L.light[rimm] *= 0.55
    hs = H / 48.0  # feature scale
    k = max(1, int(round(hs)))  # feature stroke in px
    # brow ridge: lit on the fire side
    by = my - f.S(0.03)
    for dx in np.arange(-f.S(0.055), f.S(0.055) + 0.01, 1.0):
        for t in range(k):
            L.px(mx + dx, by - 1 - t + abs(dx) * 0.12, M('mask'), 0.99 if dx <= 0 else 0.72)
    # eyes: dark holes under the brow
    ey = by + k
    for sx in (-1, 1):
        ex = mx + sx * f.S(0.03)
        for a in range(k):
            for b in range(k + (1 if H >= 70 else 0)):
                L.px(ex + sx * b - (k - 1) / 2, ey + a, M('hole'), 0.0)
    # long nose: lit ridge with a shadow side
    nlen = int(max(2, f.S(0.045)))
    for t in range(nlen):
        for a in range(k):
            L.px(mx - 0.5 - a, ey + 1 + t, M('mask'), 0.99)
        L.px(mx + 0.5 + (k - 1), ey + 1 + t, M('mask'), 0.05)
    # cheekbones catch the fire
    for sx in (-1, 1):
        for a in range(k):
            L.px(mx + sx * f.S(0.045), ey + max(2, f.S(0.03)) + a, M('mask'), 0.97 if sx < 0 else 0.7)
    # mouth: a hard, small slit
    my2 = my + f.S(0.055)
    for dx in range(-max(1, int(f.S(0.02))), max(1, int(f.S(0.02))) + 1):
        for a in range(max(1, k - 1)):
            L.px(mx + dx, my2 + a, M('hole'), 0.0)
    parts['head'] = L

    # --- front bells: small sonaggias in a row on the belt ---
    FB = []
    n = o['front_bells']
    xs = np.linspace(-0.095, 0.095, n)
    for i, bx in enumerate(xs):
        L = f.layer(); FB.append(L)
        top = 0.585 + 0.025 * (i % 2 == 0)
        x0, y0 = f.P(bx, top)
        cx0, cy0 = f.P(0, 0.48)
        L.band(cx0, cy0, x0, y0 + 1, max(1.0, f.S(0.016)), M('leather'), light=0.45)
        wt, wb, hh = f.S(0.022), f.S(0.042), f.S(0.095)
        pts = [(x0 - wt, y0), (x0 + wt, y0), (x0 + wb * 0.85, y0 + hh * 0.6),
               (x0 + wb, y0 + hh), (x0 - wb, y0 + hh), (x0 - wb * 0.85, y0 + hh * 0.6)]
        L.poly(pts, M('bronze'), light=0.5, grad=lambda X, Y, x0=x0, wb=wb: -0.5 * (X - x0) / (wb + 1e-6) + 0.08)
        L.ellipse(x0, y0 + hh, wb * 0.95, max(0.9, f.S(0.014)), M('bronze_in'), L=(0, 1, 0.2), amb=0.05)
        rim(L, -1, 0, 0.2)
    parts['front_bells'] = FB
    # warm rim from the bonfire on the outer silhouette only
    union = np.zeros((f.CH, f.W), bool)
    for k in ('body', 'arms', 'head'):
        union |= parts[k].mat >= 0
    left_empty = ~np.roll(union, 1, 1)
    for k in ('body', 'arms'):
        Lk = parts[k]
        e = (Lk.mat >= 0) & left_empty
        Lk.light[e] += o.get('rim', 0.6)
    return f, parts


def render_parts(fig, parts, style):
    out = {}
    for k, v in parts.items():
        if isinstance(v, list):
            arr = np.zeros((fig.CH, fig.W, 4), np.uint8)
            for lay in v:
                over(arr, style.render(lay), 0, 0)
            out[k] = arr
        else:
            out[k] = style.render(v)
    return out


def compose(fig, rendered, frame=0, extra=None):
    out = np.zeros((fig.CH, fig.W, 4), np.uint8)
    for k in PART_ORDER:
        dy = int(round(BOB[k][frame] * fig.H))
        over(out, rendered[k], 0, dy)
    return out
