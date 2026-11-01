"""Tiny pixel-art kit: shaded shapes -> palette ramps -> outlines.

Everything is drawn at native pixel size, then scaled up by whole numbers only
(never stretched). Shapes carry a fake 3D normal so each style can light them
the same way and then quantise to its own ramps, hatching or dithering.
"""
import numpy as np
from PIL import Image

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hexc(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Layer:
    """A part buffer: material id, light value and an optional 'flat colour' override."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.mat = np.full((h, w), -1, dtype=np.int32)
        self.light = np.zeros((h, w), dtype=np.float32)
        Y, X = np.mgrid[0:h, 0:w]
        self.X = X + 0.5
        self.Y = Y + 0.5

    # --- shapes -----------------------------------------------------------
    def _apply(self, mask, mat, light):
        self.mat[mask] = mat
        self.light[mask] = light[mask] if np.ndim(light) else light

    def ellipse(self, cx, cy, rx, ry, mat, L=(-0.55, -0.6, 0.6), amb=0.18, mod=None, clip=None):
        dx = (self.X - cx) / rx
        dy = (self.Y - cy) / ry
        d = dx * dx + dy * dy
        m = d <= 1.0
        if clip is not None:
            m &= clip(self.X, self.Y)
        nz = np.sqrt(np.clip(1 - d, 0, 1))
        lt = shade(dx, dy, nz, L, amb)
        if mod is not None:
            lt = lt + mod(self.X, self.Y)
        self._apply(m, mat, lt)
        return m

    def poly(self, pts, mat, light=0.6, mod=None, grad=None):
        m = point_in_poly(self.X, self.Y, pts)
        lt = np.full(m.shape, light, dtype=np.float32)
        if grad is not None:
            lt = lt + grad(self.X, self.Y)
        if mod is not None:
            lt = lt + mod(self.X, self.Y)
        self._apply(m, mat, lt)
        return m

    def band(self, x0, y0, x1, y1, w, mat, light=0.6, mod=None):
        """Strap from (x0,y0) to (x1,y1), rounded across its width."""
        px, py = self.X - x0, self.Y - y0
        vx, vy = x1 - x0, y1 - y0
        ln = max(1e-6, (vx * vx + vy * vy) ** 0.5)
        ux, uy = vx / ln, vy / ln
        t = px * ux + py * uy
        s = px * -uy + py * ux
        m = (t >= 0) & (t <= ln) & (np.abs(s) <= w / 2)
        across = s / (w / 2)
        lt = light + 0.25 * (-across)  # upper-left edge catches light
        if mod is not None:
            lt = lt + mod(self.X, self.Y)
        self._apply(m, mat, lt.astype(np.float32))
        return m

    def rect(self, x0, y0, x1, y1, mat, light=0.6):
        m = (self.X >= x0) & (self.X < x1) & (self.Y >= y0) & (self.Y < y1)
        self._apply(m, mat, light)
        return m

    def mask_fill(self, m, mat, light):
        self._apply(m, mat, light if np.ndim(light) == 0 else light)

    def px(self, x, y, mat, light=0.5):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.mat[y, x] = mat
            self.light[y, x] = light


def shade(dx, dy, nz, L, amb):
    lx, ly, lz = L
    n = (lx * lx + ly * ly + lz * lz) ** 0.5
    lx, ly, lz = lx / n, ly / n, lz / n
    d = np.clip(dx * lx + dy * ly + nz * lz, 0, 1)
    return (amb + (1 - amb) * d).astype(np.float32)


def point_in_poly(X, Y, pts):
    inside = np.zeros(X.shape, dtype=bool)
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        cond = ((yi > Y) != (yj > Y))
        with np.errstate(divide='ignore', invalid='ignore'):
            xint = (xj - xi) * (Y - yi) / ((yj - yi) if yj != yi else 1e-9) + xi
        inside ^= cond & (X < xint)
        j = i
    return inside


class Style:
    """ramps: material -> list of entries dark->light. An entry is '#rrggbb',
    ('h', a, b) row hatching, ('v', a, b) column hatching or ('d', a, b) checker."""

    def __init__(self, ramps, outline='black', ink='#000000', dither=0.0, outline_mode='outer'):
        self.ramps = {k: [parse_entry(e) for e in v] for k, v in ramps.items()}
        self.names = list(ramps.keys())
        self.ids = {k: i for i, k in enumerate(self.names)}
        self.outline = outline  # 'black' | 'selective' | None
        self.ink = hexc(ink)
        self.dither = dither

    def m(self, name):
        return self.ids[name]

    def render(self, layer, outline=True, ox=0, oy=0):
        """Layer -> RGBA uint8 array. ox, oy shift the dither/hatch phase so a part
        keeps its texture when it moves."""
        h, w = layer.h, layer.w
        out = np.zeros((h, w, 4), dtype=np.uint8)
        Y, X = np.mgrid[0:h, 0:w]
        bay = BAYER4[(Y + oy) % 4, (X + ox) % 4]
        for name, mid in self.ids.items():
            sel = layer.mat == mid
            if not sel.any():
                continue
            ramp = self.ramps[name]
            n = len(ramp)
            lt = np.clip(layer.light, 0, 0.999)
            f = lt * n + (bay - 0.5) * self.dither
            idx = np.clip(np.floor(f), 0, n - 1).astype(int)
            for k, e in enumerate(ramp):
                s = sel & (idx == k)
                if not s.any():
                    continue
                kind, a, b = e
                if kind == 'c':
                    out[s] = a
                else:
                    if kind == 'h':
                        alt = ((Y + oy) % 2) == 0
                    elif kind == 'v':
                        alt = ((X + ox) % 2) == 0
                    elif kind == 'h3':
                        alt = ((Y + oy) % 3) == 0
                    else:
                        alt = ((X + Y + ox + oy) % 2) == 0
                    out[s & alt] = a
                    out[s & ~alt] = b
        if outline and self.outline:
            filled = layer.mat >= 0
            nb = np.zeros_like(filled)
            nb[1:, :] |= filled[:-1, :]
            nb[:-1, :] |= filled[1:, :]
            nb[:, 1:] |= filled[:, :-1]
            nb[:, :-1] |= filled[:, 1:]
            edge = nb & ~filled
            if self.outline == 'black':
                out[edge] = self.ink
            else:  # selective: darkest colour of the neighbouring material, darkened
                matn = np.full(layer.mat.shape, -1)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    sh = np.roll(np.roll(layer.mat, dy, 0), dx, 1)
                    matn = np.where((matn < 0) & (sh >= 0), sh, matn)
                for name, mid in self.ids.items():
                    s = edge & (matn == mid)
                    a = self.ramps[name][0][1]
                    out[s] = darken(a, 0.55)
        return out


def parse_entry(e):
    if isinstance(e, str):
        return ('c', np.array(hexc(e), np.uint8), None)
    k, a, b = e
    return (k, np.array(hexc(a), np.uint8), np.array(hexc(b), np.uint8))


def darken(c, f):
    return np.array([int(c[0] * f), int(c[1] * f), int(c[2] * f), 255], np.uint8)


def over(dst, src, x, y):
    """Alpha-over (binary alpha) of src array onto dst array at x, y."""
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    a = s[..., 3:4] > 0
    dst[y0:y1, x0:x1] = np.where(a, s, dst[y0:y1, x0:x1])


def to_img(arr, scale=1):
    im = Image.fromarray(arr, 'RGBA')
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im


# --- 5x7 pixel font ----------------------------------------------------------
FONT = {
    'A': ".###.#...##...##...#######...##...#", 'B': "####.#...#####.#...##...##...#####.",
    'C': ".###.#...##....#....#....#...#.###.", 'D': "####.#...##...##...##...##...#####.",
    'E': "######....####.#....#....#....#####", 'F': "######....####.#....#....#....#....",
    'G': ".###.#...##....#.####...##...#.####", 'H': "#...##...#######...##...##...##...#",
    'I': "#####..#....#....#....#....#..#####", 'K': "#...##..#.###..#..#.#...##...##...#",
    'L': "#....#....#....#....#....#....#####", 'M': "#...###.###.#.##...##...##...##...#",
    'N': "#...###..##.#.##..###...##...##...#", 'O': ".###.#...##...##...##...##...#.###.",
    'P': "####.#...##...#####.#....#....#....", 'R': "####.#...##...#####.#.#..#..#.#...#",
    'S': ".#####....#.....###.....#....#####.", 'T': "#####..#....#....#....#....#....#..",
    'U': "#...##...##...##...##...##...#.###.", 'X': "#...##...#.#.#..#...#.#.#...##...#",
    'Z': "#####....#...#...#...#...#....#####", 'Y': "#...##...#.#.#..#....#....#....#...",
    '0': ".###.#...##..###.#.###..##...#.###.", '1': "..#...##....#....#....#....#...###.",
    '2': ".###.#...#....#...#...#...#...#####", '3': "####.....#....#.###.....#....#####.",
    '4': "...#...##..#.#.#..#.#####...#....#.", '5': "######....####.....#....#....#####.",
    '6': ".###.#....#....####.#...##...#.###.", '7': "#####....#...#...#...#....#....#...",
    '8': ".###.#...##...#.###.#...##...#.###.", '9': ".###.#...##...#.####....#....#.###.",
    'x': "..........#...#.#.#...#...#.#.#...#", ',': '.'*25 + '..#..' + '.#...',
    ' ': "." * 35, '!': "..#....#....#....#....#.........#..",
}

FONT['X'] = "#...##...#.#.#..#...#.#.#...##...#"[:0] + "#...#" "#...#" ".#.#." "..#.." ".#.#." "#...#" "#...#"


def text(dst, s, x, y, col, shadow=None, scale=1, spacing=1):
    passes = []
    if shadow:
        passes.append((np.array(hexc(shadow), np.uint8), scale))
    passes.append((np.array(hexc(col), np.uint8), 0))
    for c, off in passes:
        cx = x
        for ch in s:
            g = FONT.get(ch, FONT[' ']).ljust(35, '.')
            for i in range(7):
                for j in range(5):
                    if g[i * 5 + j] == '#':
                        for a in range(scale):
                            for b in range(scale):
                                _put(dst, cx + j * scale + b + off, y + i * scale + a + off, c)
            cx += (5 + spacing) * scale
    return cx


def text_w(s, scale=1, spacing=1):
    return len(s) * (5 + spacing) * scale - spacing * scale


def _put(dst, x, y, c, keep=False):
    H, W = dst.shape[:2]
    if 0 <= x < W and 0 <= y < H:
        dst[y, x] = c
