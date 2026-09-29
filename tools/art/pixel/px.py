"""A tiny pixel-art canvas: every sprite, backdrop, frame and icon of the game's pixel look is drawn
with this, at its true pixel size (1 art pixel = 1 array cell), from the palette in palette.py.

    from px import Canvas
    cv = Canvas(64, 80)
    cv.ellipse(32, 40, 20, 26, "FLEECE2")
    cv.outline()                    # K0 outline round everything drawn
    cv.save("out.png")              # 1x; the game scales it up with nearest filtering

Colours are palette names ("GOLD3") or RGB tuples already in the palette; `None` erases.
All shapes are hard-edged: no anti-aliasing, ever. Dithering is ordered (Bayer 4x4) and only where
asked for.
"""
import math
import os
import random

import numpy as np
from PIL import Image

from palette import P, ALL

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def rgb(col):
    if col is None:
        return None
    if isinstance(col, str):
        return P[col]
    return tuple(col)


class Canvas:
    def __init__(self, w, h, fill=None):
        self.w, self.h = int(w), int(h)
        self.a = np.zeros((self.h, self.w, 4), np.uint8)
        if fill is not None:
            self.a[:, :, :3] = rgb(fill)
            self.a[:, :, 3] = 255

    # ------------------------------------------------------------ basics
    def _put(self, mask, col):
        """Paints col wherever the boolean mask is set (None erases)."""
        col = rgb(col)
        if col is None:
            self.a[mask] = 0
        else:
            self.a[mask, :3] = col
            self.a[mask, 3] = 255

    def grid(self):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return xx, yy

    def pset(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            c = rgb(col)
            if c is None:
                self.a[y, x] = 0
            else:
                self.a[y, x, :3] = c
                self.a[y, x, 3] = 255

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h and self.a[y, x, 3]:
            return tuple(int(v) for v in self.a[y, x, :3])
        return None

    def solid(self):
        return self.a[:, :, 3] > 0

    def rect(self, x, y, w, h, col):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            m = np.zeros((self.h, self.w), bool)
            m[y0:y1, x0:x1] = True
            self._put(m, col)

    def hline(self, x0, x1, y, col):
        self.rect(min(x0, x1), y, abs(x1 - x0) + 1, 1, col)

    def vline(self, x, y0, y1, col):
        self.rect(x, min(y0, y1), 1, abs(y1 - y0) + 1, col)

    # ------------------------------------------------------------ masks
    def m_ellipse(self, cx, cy, rx, ry):
        xx, yy = self.grid()
        return ((xx + 0.5 - cx) / max(rx, 0.01)) ** 2 + ((yy + 0.5 - cy) / max(ry, 0.01)) ** 2 <= 1.0

    def m_poly(self, pts):
        """Pixels whose centres fall inside the polygon (even-odd)."""
        xx, yy = self.grid()
        px, py = xx + 0.5, yy + 0.5
        inside = np.zeros((self.h, self.w), bool)
        n = len(pts)
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            if y0 == y1:
                continue
            cond = ((y0 <= py) & (py < y1)) | ((y1 <= py) & (py < y0))
            xint = x0 + (py - y0) * (x1 - x0) / (y1 - y0)
            inside ^= cond & (px < xint)
        return inside

    def m_rect(self, x, y, w, h):
        m = np.zeros((self.h, self.w), bool)
        m[max(0, int(y)):max(0, int(y + h)), max(0, int(x)):max(0, int(x + w))] = True
        return m

    def ellipse(self, cx, cy, rx, ry, col):
        self._put(self.m_ellipse(cx, cy, rx, ry), col)

    def poly(self, pts, col):
        self._put(self.m_poly(pts), col)

    def line(self, x0, y0, x1, y1, col, w=1):
        """Bresenham line, w px thick (square brush)."""
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            if w == 1:
                self.pset(x0, y0, col)
            else:
                self.rect(x0 - (w - 1) // 2, y0 - (w - 1) // 2, w, w, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def polyline(self, pts, col, w=1):
        for i in range(len(pts) - 1):
            self.line(*pts[i], *pts[i + 1], col, w)

    def curve(self, pts, col, w=1, steps=None):
        """Catmull-Rom through pts, rasterised as short lines."""
        if len(pts) < 2:
            return
        P_ = [pts[0]] + list(pts) + [pts[-1]]
        out = []
        for i in range(1, len(P_) - 2):
            p0, p1, p2, p3 = P_[i - 1], P_[i], P_[i + 1], P_[i + 2]
            n = steps or max(2, int(math.hypot(p2[0] - p1[0], p2[1] - p1[1])))
            for s in range(n):
                t = s / n
                t2, t3 = t * t, t * t * t
                x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
                y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
                out.append((round(x), round(y)))
        out.append((round(pts[-1][0]), round(pts[-1][1])))
        dedup = [out[0]]
        for p in out[1:]:
            if p != dedup[-1]:
                dedup.append(p)
        self.polyline(dedup, col, w)
        return dedup

    # ------------------------------------------------------------ fills with light
    def dither(self, mask, col_a, col_b, level, ox=0, oy=0):
        """Inside mask, col_b where the Bayer threshold is under `level` (0..1, scalar or array), else col_a."""
        xx, yy = self.grid()
        th = BAYER4[(yy + oy) % 4, (xx + ox) % 4]
        lv = level if np.isscalar(level) else level
        pick = th < lv
        if col_a is not None:
            self._put(mask & ~pick, col_a)
        self._put(mask & pick, col_b)

    def ramp_fill(self, mask, cols, value, dither=True):
        """Fills mask with a ramp of colours by `value` (array 0..1, same shape as the canvas): the ramp
        is banded, and each band edge is softened with one Bayer step when dither is set."""
        n = len(cols)
        v = np.clip(value, 0, 0.9999) * n
        idx = np.floor(v).astype(int)
        if dither:
            xx, yy = self.grid()
            frac = v - idx
            th = BAYER4[yy % 4, xx % 4]
            # only the outer quarter of each band dithers into the next one
            up = (frac > 0.75) & (th < (frac - 0.75) * 4 * 0.5)
            idx = np.clip(idx + up, 0, n - 1)
        for i, col in enumerate(cols):
            self._put(mask & (idx == i), col)

    def shade_ellipse(self, cx, cy, rx, ry, cols, light=(-0.6, -0.7), mask=None, dither=True):
        """A lit ellipsoid: cols dark..light, lit from `light` (a direction in the picture plane)."""
        xx, yy = self.grid()
        nx = (xx + 0.5 - cx) / max(rx, 0.01)
        ny = (yy + 0.5 - cy) / max(ry, 0.01)
        m = nx * nx + ny * ny <= 1.0
        if mask is not None:
            m &= mask
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
        lx, ly = light
        lz = math.sqrt(max(0.0, 1 - lx * lx - ly * ly))
        d = np.clip(nx * lx + ny * ly + nz * lz, 0, 1)
        self.ramp_fill(m, cols, d, dither)
        return m

    # ------------------------------------------------------------ post passes
    def outline(self, col="K0", diagonal=False, inner_gap=None):
        """Draws col on every empty pixel that touches a drawn one (4-neighbours; 8 with diagonal)."""
        s = self.solid()
        n = np.zeros_like(s)
        n[1:, :] |= s[:-1, :]
        n[:-1, :] |= s[1:, :]
        n[:, 1:] |= s[:, :-1]
        n[:, :-1] |= s[:, 1:]
        if diagonal:
            n[1:, 1:] |= s[:-1, :-1]
            n[1:, :-1] |= s[:-1, 1:]
            n[:-1, 1:] |= s[1:, :-1]
            n[:-1, :-1] |= s[1:, 1:]
        self._put(n & ~s, col)

    def rim(self, side, col, where=None, depth=1):
        """Recolours the outermost `depth` drawn pixels on one side ('l','r','t','b') - the fire's rim light."""
        s = self.solid()
        edge = np.zeros_like(s)
        shift = {"l": (0, 1), "r": (0, -1), "t": (1, 0), "b": (-1, 0)}[side]
        cur = s.copy()
        for _ in range(depth):
            nb = np.zeros_like(s)
            dy, dx = shift
            # a pixel is on the `side` edge if its neighbour toward that side is empty
            if side == "l":
                nb[:, 1:] = cur[:, :-1]
            elif side == "r":
                nb[:, :-1] = cur[:, 1:]
            elif side == "t":
                nb[1:, :] = cur[:-1, :]
            else:
                nb[:-1, :] = cur[1:, :]
            e = cur & ~nb
            edge |= e
            cur = cur & ~e
        if where is not None:
            edge &= where
        # never recolour the outline itself
        edge &= ~self.is_color("K0")
        self._put(edge, col)

    def is_color(self, col):
        c = rgb(col)
        return (self.a[:, :, 3] > 0) & np.all(self.a[:, :, :3] == np.array(c, np.uint8), axis=2)

    def recolor(self, src, dst, mask=None):
        m = self.is_color(src)
        if mask is not None:
            m &= mask
        self._put(m, dst)

    def speckle(self, mask, cols, density, seed=0):
        """Scatters single pixels of random cols over mask (texture: fleece tufts, stone grit)."""
        rnd = np.random.default_rng(seed)
        r = rnd.random((self.h, self.w))
        m = mask & (r < density)
        pick = rnd.integers(0, len(cols), (self.h, self.w))
        for i, col in enumerate(cols):
            self._put(m & (pick == i), col)

    def clean_orphans(self, mask=None):
        """Removes lone pixels whose 4 neighbours all share one other colour (replaces them with it)."""
        a = self.a
        out = a.copy()
        for y in range(1, self.h - 1):
            for x in range(1, self.w - 1):
                if mask is not None and not mask[y, x]:
                    continue
                if not a[y, x, 3]:
                    continue
                nb = [tuple(a[y + dy, x + dx]) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))]
                if nb[0] == nb[1] == nb[2] == nb[3] and nb[0] != tuple(a[y, x]) and nb[0][3]:
                    out[y, x] = nb[0]
        self.a = out

    # ------------------------------------------------------------ composition
    def blit(self, other, x, y, flip=False, mask_col=None):
        src = other.a[:, ::-1] if flip else other.a
        h, w = src.shape[:2]
        x, y = int(x), int(y)
        sx0, sy0 = max(0, -x), max(0, -y)
        dx0, dy0 = max(0, x), max(0, y)
        ww, hh = min(w - sx0, self.w - dx0), min(h - sy0, self.h - dy0)
        if ww <= 0 or hh <= 0:
            return
        s = src[sy0:sy0 + hh, sx0:sx0 + ww]
        d = self.a[dy0:dy0 + hh, dx0:dx0 + ww]
        m = s[:, :, 3] > 0
        d[m] = s[m]

    def flipped(self):
        c = Canvas(self.w, self.h)
        c.a = self.a[:, ::-1].copy()
        return c

    def copy(self):
        c = Canvas(self.w, self.h)
        c.a = self.a.copy()
        return c

    def bbox(self):
        ys, xs = np.nonzero(self.a[:, :, 3])
        if len(xs) == 0:
            return (0, 0, 0, 0)
        return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)

    # ------------------------------------------------------------ output
    def image(self, scale=1):
        im = Image.fromarray(self.a, "RGBA")
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return im

    def save(self, path, scale=1, check=True):
        if check:
            bad = check_palette(self.a)
            if bad:
                raise ValueError(f"{path}: {len(bad)} off-palette colours, e.g. {bad[:4]}")
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        self.image(scale).save(path)


_ALLSET = set(ALL)


def check_palette(a):
    m = a[:, :, 3] > 0
    cols = {tuple(int(v) for v in c) for c in np.unique(a[m][:, :3], axis=0)} if m.any() else set()
    return sorted(cols - _ALLSET)


def rng(seed):
    return random.Random(seed)
