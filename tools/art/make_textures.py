#!/usr/bin/env python3
"""Bake the woodcut textures and UI nine-patches for Mamuthones.

Everything is procedural (numpy only) and tileable, so the pictures stay small and cheap on a phone:
the game repeats them instead of stretching large images.

    python3 tools/art/make_textures.py            # writes game/art/textures/ and game/art/ui/

Palette (docs/design.md section 8): black #141110, bone #ede6da, red #c0392b, ember #e0a24a.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pngio import write_png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "game", "art", "textures")
UI = os.path.join(ROOT, "game", "art", "ui")

BLACK = np.array([20, 17, 16], float)
INK = np.array([12, 10, 9], float)
BONE = np.array([237, 230, 218], float)
RED = np.array([192, 57, 43], float)
EMBER = np.array([224, 162, 74], float)
WOOD = np.array([35, 29, 25], float)  # dark carved wood, a step up from black so bone lines sit on it


# ---------------------------------------------------------------- noise helpers

def fbm(h, w, beta=2.0, seed=0, fx=1.0, fy=1.0):
    """Periodic (tileable) fractal noise in 0..1. fx/fy > 1 stretch features along that axis."""
    rng = np.random.default_rng(seed)
    n = rng.standard_normal((h, w))
    ky = np.fft.fftfreq(h)[:, None] * h / fy
    kx = np.fft.fftfreq(w)[None, :] * w / fx
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1.0
    amp = 1.0 / k ** (beta / 2.0)
    amp[0, 0] = 0.0
    f = np.real(np.fft.ifft2(np.fft.fft2(n) * amp))
    f -= f.min()
    f /= max(f.max(), 1e-9)
    return f


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def blend(base, color, alpha):
    a = alpha[..., None]
    return base * (1 - a) + color * a


def stamp_strokes(h, w, count, length, width, angle, angle_jitter, seed, taper=True):
    """Alpha field of short gouge strokes (wrapped so the tile repeats)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    for _ in range(count):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        ln = length * rng.uniform(0.5, 1.3)
        wd = width * rng.uniform(0.6, 1.3)
        a = angle + rng.normal(0, angle_jitter)
        ca, sa = np.cos(a), np.sin(a)
        r = int(ln / 2 + wd + 2)
        ys = (np.arange(int(cy) - r, int(cy) + r + 1)) % h
        xs = (np.arange(int(cx) - r, int(cx) + r + 1)) % w
        yy, xx = np.meshgrid(np.arange(-r, r + 1) + (int(cy) - cy), np.arange(-r, r + 1) + (int(cx) - cx), indexing="ij")
        u = xx * ca + yy * sa
        v = -xx * sa + yy * ca
        t = np.clip(u / (ln / 2), -1, 1)
        half = wd / 2 * (np.sqrt(np.clip(1 - t * t, 0, 1)) if taper else 1.0)
        inside = smooth(0.5, -0.5, np.abs(v) - half) * smooth(0.5, -0.5, np.abs(u) - ln / 2)
        # A gouge cut is darker at its deep end: fade along its length.
        inside *= 0.55 + 0.45 * (t + 1) / 2
        sub = out[np.ix_(ys, xs)]
        out[np.ix_(ys, xs)] = np.maximum(sub, inside)
    return out


# ---------------------------------------------------------------- tileable textures

def paper(size=512):
    mott = fbm(size, size, 2.6, 1)
    fine = fbm(size, size, 0.6, 2)
    fibers = stamp_strokes(size, size, 900, 14, 1.0, 0.0, 1.6, 3)
    img = np.ones((size, size, 3)) * BONE
    img *= (0.93 + 0.07 * mott)[..., None]
    img *= (0.975 + 0.025 * fine)[..., None]
    img = blend(img, BONE * 0.8, fibers * 0.35)
    rng = np.random.default_rng(4)
    specks = (rng.random((size, size)) > 0.9993).astype(float)
    img = blend(img, BLACK, specks * 0.6)
    return img


def grain(size=512):
    """White streaks in alpha: wood grain running left to right, with two knots."""
    y, x = np.mgrid[0:size, 0:size].astype(float)
    warp = fbm(size, size, 3.0, 11, fx=4.0) * 30.0 + fbm(size, size, 1.6, 12, fx=6.0) * 5.0
    # Knots bend the lines around them (periodic distance keeps the tile seamless).
    for kx, ky, s in ((0.3, 0.35, 1.0), (0.78, 0.8, 0.7)):
        dx = (x - kx * size + size / 2) % size - size / 2
        dy = (y - ky * size + size / 2) % size - size / 2
        d = np.sqrt((dx / 2.2) ** 2 + dy ** 2)
        warp += s * 26.0 * np.exp(-d / 22.0) * np.sign(dy + 0.01)
    rings = (y + warp) * (24.0 / size) * 2 * np.pi
    line = np.abs(np.sin(rings))
    streak = smooth(0.82, 0.98, line) * 0.8
    fine = fbm(size, size, 1.2, 13, fx=10.0)
    streak += smooth(0.62, 0.9, fine) * 0.35
    streak *= 0.6 + 0.4 * fbm(size, size, 2.0, 14, fx=3.0)
    a = np.clip(streak, 0, 1)
    return np.dstack([np.full((size, size), 255.0), a * 255])


def hatch(size=256, spacing=8):
    """Diagonal ink hatching, white in alpha; lines break and swell like a hand-cut block."""
    y, x = np.mgrid[0:size, 0:size].astype(float)
    wob = (fbm(size, size, 2.4, 21) - 0.5) * 3.0
    phase = ((x + y + wob) % spacing) / spacing
    width = 0.22 + 0.16 * fbm(size, size, 2.0, 22)
    lines = smooth(width + 0.06, width - 0.06, np.abs(phase - 0.5) * 2 * 0.5)
    breaks = smooth(0.25, 0.35, fbm(size, size, 1.8, 23, fx=3.0))
    a = lines * breaks
    return np.dstack([np.full((size, size), 255.0), np.clip(a, 0, 1) * 255])


def chisel(size=256):
    """Gouge marks: mostly horizontal scoops, as left by clearing a woodblock."""
    a = stamp_strokes(size, size, 170, 34, 5.0, 0.15, 0.35, 31)
    a = np.maximum(a, stamp_strokes(size, size, 60, 18, 3.0, -0.6, 0.4, 32) * 0.8)
    return np.dstack([np.full((size, size), 255.0), np.clip(a, 0, 1) * 255])


def fog(size=256):
    f = fbm(size, size, 2.2, 41, fx=2.5)
    f2 = fbm(size, size, 1.4, 42, fx=1.5)
    v = np.clip(f * 0.8 + f2 * 0.3 - 0.1, 0, 1)
    return v * 255


def fleece(size=256, count=1500, seed=91):
    """Curly sheepskin: dense small open curls, white in alpha (tint and lay over a dark fill)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for _ in range(count):
        cx, cy = rng.uniform(0, size), rng.uniform(0, size)
        rad = rng.uniform(2.5, 4.8)
        wd = rng.uniform(0.9, 1.5)
        start = rng.uniform(0, 2 * np.pi)
        span = rng.uniform(3.4, 5.0)
        r = int(rad + wd + 2)
        ys = (np.arange(int(cy) - r, int(cy) + r + 1)) % size
        xs = (np.arange(int(cx) - r, int(cx) + r + 1)) % size
        yy, xx = np.meshgrid(np.arange(-r, r + 1) + (int(cy) - cy), np.arange(-r, r + 1) + (int(cx) - cx), indexing="ij")
        d = np.sqrt(xx * xx + (yy * 1.25) ** 2)
        ang = (np.arctan2(yy, xx) - start) % (2 * np.pi)
        ring = smooth(wd * 0.5 + 0.6, wd * 0.5 - 0.4, np.abs(d - rad)) * (ang < span)
        ring *= 0.45 + 0.55 * (ang / span)
        sub = out[np.ix_(ys, xs)]
        out[np.ix_(ys, xs)] = np.maximum(sub, ring)
    return np.dstack([np.full((size, size), 255.0), np.clip(out, 0, 1) * 255])


def glow(size=128):
    """Soft radial falloff with a little grain, for fire glow drawn as one textured quad."""
    y, x = np.mgrid[0:size, 0:size].astype(float) + 0.5
    r = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** 1.8
    a *= 0.85 + 0.15 * fbm(size, size, 1.0, 61)
    a *= smooth(1.0, 0.94, r)
    return np.dstack([np.full((size, size), 255.0), np.clip(a, 0, 1) * 255])


def speckle(size=256):
    """Paper showing through a solid black print (bone specks in alpha)."""
    rng = np.random.default_rng(51)
    base = fbm(size, size, 0.4, 52)
    blotch = fbm(size, size, 2.2, 53)
    a = smooth(0.78, 0.9, base * 0.7 + blotch * 0.45)
    a = np.maximum(a, (rng.random((size, size)) > 0.996) * 0.8)
    return np.dstack([np.full((size, size), 255.0), np.clip(a, 0, 1) * 255])


# ---------------------------------------------------------------- nine-patches

class Patch:
    """Coordinates for a tileable nine-patch: margin M, centre Cw x Ch (periodic in both axes)."""

    def __init__(self, m, cw, ch, seed):
        self.m, self.cw, self.ch = m, cw, ch
        self.w, self.h = cw + 2 * m, ch + 2 * m
        self.y, self.x = np.mgrid[0:self.h, 0:self.w].astype(float)
        self.u = ((self.x - m) % cw).astype(int)
        self.v = ((self.y - m) % ch).astype(int)
        self.seed = seed

    def noise(self, beta=1.6, k=0, fx=1.0):
        f = fbm(self.ch, self.cw, beta, self.seed * 97 + k, fx=fx)
        return f[self.v, self.u]

    def sd_box(self, inset, radius):
        """Signed distance to a rounded box inset from the texture edge (negative inside)."""
        hx, hy = self.w / 2 - inset, self.h / 2 - inset
        px = np.abs(self.x + 0.5 - self.w / 2) - (hx - radius)
        py = np.abs(self.y + 0.5 - self.h / 2) - (hy - radius)
        out = np.sqrt(np.maximum(px, 0) ** 2 + np.maximum(py, 0) ** 2)
        return out + np.minimum(np.maximum(px, py), 0) - radius

    def grain(self, k=5, lines=None):
        lines = lines or max(2, self.ch // 9)
        warp = self.noise(3.0, k, fx=3.0) * 1.5
        r = np.abs(np.sin((self.v / self.ch * lines + warp) * np.pi))
        return smooth(0.8, 0.98, r)


def rgba(rgb, a):
    return np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255])


def button(fill, line, seed, line_alpha=1.0, gaps=0.25, fill_grain=0.12, rim=True, dark_grain=False):
    p = Patch(22, 96, 40, seed)
    rough = (p.noise(1.4, 1) - 0.5) * 3.2
    sd = p.sd_box(3, 10) + rough
    body = smooth(0.7, -0.7, sd)
    g = p.grain()
    col = np.ones(sd.shape + (3,)) * fill
    if dark_grain:
        col = blend(col, INK, g * fill_grain * 3)
    else:
        col = blend(col, BONE, g * fill_grain)
    chis = smooth(0.72, 0.85, p.noise(0.9, 2)) * 0.5
    col = blend(col, INK, chis * (sd < -3))
    # Carved bone line inset from the edge, broken by chisel nicks.
    lsd = sd + 8.0 + (p.noise(1.8, 3) - 0.5) * 1.6
    lw = 1.5 + 0.7 * p.noise(2.0, 4)
    lm = smooth(lw + 0.7, lw - 0.7, np.abs(lsd))
    nick = smooth(gaps - 0.03, gaps + 0.03, p.noise(1.2, 6, fx=2.0))
    col = blend(col, line, lm * nick * line_alpha)
    if rim:
        edge = smooth(-2.6, -1.2, sd) * body
        col = blend(col, INK, edge)
    return rgba(col, body)


def focus_ring(seed):
    p = Patch(22, 96, 40, seed)
    sd = p.sd_box(1, 12) + (p.noise(1.4, 1) - 0.5) * 2.4
    ring = smooth(2.2, 1.2, np.abs(sd))
    return rgba(np.ones(sd.shape + (3,)) * EMBER, ring)


def panel_dark(seed=60):
    p = Patch(28, 128, 128, seed)
    sd = p.sd_box(2, 6) + (p.noise(1.3, 1) - 0.5) * 3.0
    body = smooth(0.7, -0.7, sd)
    col = np.ones(sd.shape + (3,)) * np.array([27, 22, 19], float)
    col = blend(col, BONE, p.grain(5, 12) * 0.05)
    col = blend(col, INK, smooth(0.7, 0.85, p.noise(0.8, 2)) * 0.5)
    for off, w, a in ((7.0, 1.6, 0.85), (12.0, 0.8, 0.45)):
        lsd = sd + off + (p.noise(1.8, 3 + int(off)) - 0.5) * 1.4
        lm = smooth(w + 0.7, w - 0.7, np.abs(lsd))
        nick = smooth(0.18, 0.24, p.noise(1.2, 9 + int(off), fx=2.0))
        col = blend(col, BONE, lm * nick * a)
    col = blend(col, INK, smooth(-2.5, -1.0, sd))
    return rgba(col, body)


def panel_paper(seed=70):
    p = Patch(28, 128, 128, seed)
    sd = p.sd_box(3, 4) + (p.noise(1.2, 1) - 0.5) * 4.0
    body = smooth(0.7, -0.7, sd)
    col = np.ones(sd.shape + (3,)) * BONE
    col *= (0.94 + 0.06 * p.noise(2.4, 2))[..., None]
    col = blend(col, BONE * 0.82, smooth(0.66, 0.9, p.noise(0.7, 3)) * 0.4)
    # Ink border: thick outer rule with a thin inner rule, like a printed card frame.
    ink = smooth(-4.5, -3.3, sd)
    inner = sd + 10.0 + (p.noise(1.8, 4) - 0.5) * 1.4
    ink = np.maximum(ink, smooth(1.6, 0.8, np.abs(inner)) * 0.9)
    # Edge darkening (old paper).
    col = blend(col, np.array([150, 120, 90], float), smooth(-26, -4, sd) * 0.25)
    col = blend(col, INK, ink)
    return rgba(col, body)


def groove(fill, seed, edge=BONE, edge_a=0.8, ch=8, m=8):
    """Slider/progress track: a gouged channel with rough bone lips."""
    p = Patch(m, 64, ch, seed)
    sd = p.sd_box(1, m - 1) + (p.noise(1.4, 1) - 0.5) * 1.8
    body = smooth(0.7, -0.7, sd)
    col = np.ones(sd.shape + (3,)) * fill
    col = blend(col, INK if fill.mean() > 60 else BONE, p.grain(5, 2) * 0.15)
    lip = smooth(1.4, 0.4, np.abs(sd + 1.2))
    col = blend(col, edge, lip * edge_a)
    return rgba(col, body)


def line_patch(color, seed, thick=2.2):
    p = Patch(8, 64, 4, seed)
    wob = (p.noise(1.8, 1) - 0.5) * 1.6
    d = np.abs(p.y + 0.5 - p.h / 2 + wob)
    a = smooth(thick + 0.6, thick - 0.6, d)
    a *= smooth(0.12, 0.2, p.noise(1.1, 2, fx=2.0))
    return rgba(np.ones(d.shape + (3,)) * color, a)


def scroll_grabber(color, seed):
    p = Patch(6, 6, 48, seed)
    sd = p.sd_box(1, 5) + (p.noise(1.4, 1) - 0.5) * 1.2
    body = smooth(0.7, -0.7, sd)
    col = np.ones(sd.shape + (3,)) * color
    col = blend(col, INK, smooth(-1.8, -0.8, sd))
    return rgba(col, body)


def field(y, x, cx, cy):
    return np.sqrt((x - cx) ** 2 + (y - cy) ** 2)


def icon_grabber(fill, ring, size=44, seed=90):
    y, x = np.mgrid[0:size, 0:size].astype(float) + 0.5
    c = size / 2
    rough = (fbm(size, size, 1.4, seed) - 0.5) * 2.0
    # Diamond (a lozenge cut with four gouge strokes).
    d = (np.abs(x - c) + np.abs(y - c)) + rough
    body = smooth(c - 1.0, c - 2.2, d)
    col = np.ones((size, size, 3)) * INK
    col = blend(col, ring, smooth(c - 4.0, c - 5.2, d))
    col = blend(col, fill, smooth(c - 8.5, c - 9.7, d))
    col = blend(col, INK, smooth(3.6, 2.4, field(y, x, c, c)))
    return rgba(col, body)


def icon_toggle(on, disabled=False, w=88, h=48, seed=100):
    y, x = np.mgrid[0:h, 0:w].astype(float) + 0.5
    r = h / 2 - 3
    px = np.abs(x - w / 2) - (w / 2 - 3 - r)
    d = np.sqrt(np.maximum(px, 0) ** 2 + (y - h / 2) ** 2) - r + (fbm(h, w, 1.4, seed) - 0.5) * 2.0
    body = smooth(0.7, -0.7, d)
    fill = RED if on else WOOD
    line = BONE
    if disabled:
        fill = fill * 0.5 + WOOD * 0.5
        line = BONE * 0.45
    col = np.ones((h, w, 3)) * fill
    col = blend(col, line, smooth(1.8, 0.8, np.abs(d + 4.0)))
    col = blend(col, INK, smooth(-2.0, -0.8, d))
    kx = w - 3 - r if on else 3 + r
    kd = field(y, x, kx, h / 2) - (r - 6) + (fbm(h, w, 1.4, seed + 1) - 0.5) * 1.6
    col = blend(col, INK, smooth(1.8, 0.6, kd))
    col = blend(col, line if not on else BONE, smooth(0.6, -0.6, kd + 2.0))
    # Carved dimple on the knob.
    col = blend(col, INK, smooth(2.6, 1.4, field(y, x, kx, h / 2)) * 0.8)
    return rgba(col, np.maximum(body, smooth(0.6, -0.6, kd)))


def icon_check(on, disabled=False, size=44, radio=False, seed=110):
    y, x = np.mgrid[0:size, 0:size].astype(float) + 0.5
    c = size / 2
    rough = (fbm(size, size, 1.4, seed) - 0.5) * 1.8
    if radio:
        d = field(y, x, c, c) - (c - 4) + rough
    else:
        q = np.maximum(np.abs(x - c), np.abs(y - c))
        d = q - (c - 4) + rough
    line = BONE * (0.45 if disabled else 1.0)
    col = np.ones((size, size, 3)) * WOOD
    body = smooth(0.7, -0.7, d)
    col = blend(col, line, smooth(1.9, 0.9, np.abs(d + 3.5)))
    col = blend(col, INK, smooth(-1.6, -0.6, d))
    if on:
        if radio:
            m = smooth(0.6, -0.6, field(y, x, c, c) - (c - 13) + rough)
        else:
            # A carved tick: two tapered gouges.
            def seg(ax, ay, bx, by, w0, w1):
                vx, vy = bx - ax, by - ay
                t = np.clip(((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
                dd = np.sqrt((x - ax - vx * t) ** 2 + (y - ay - vy * t) ** 2)
                return smooth(0.6, -0.6, dd - (w0 + (w1 - w0) * t))
            m = np.maximum(seg(11, 22, 19, 31, 2.0, 4.0), seg(19, 31, 34, 11, 4.0, 1.6))
        col = blend(col, RED if not disabled else RED * 0.5, m)
    return rgba(col, body)


def arrow_icon(color, size=32, seed=120):
    """Down chevron for option buttons."""
    y, x = np.mgrid[0:size, 0:size].astype(float) + 0.5
    c = size / 2
    d = np.abs(np.abs(x - c) - (y - c + 6) * 1.0) / 1.4 - 2.4 + (fbm(size, size, 1.4, seed) - 0.5) * 1.2
    m = smooth(0.6, -0.6, d) * (y > c - 7) * (y < c + 7)
    return rgba(np.ones((size, size, 3)) * color, m)


def main():
    os.makedirs(TEX, exist_ok=True)
    os.makedirs(UI, exist_ok=True)
    out = {
        (TEX, "paper.png"): paper(),
        (TEX, "grain.png"): grain(),
        (TEX, "hatch.png"): hatch(),
        (TEX, "chisel.png"): chisel(),
        (TEX, "fog.png"): fog(),
        (TEX, "speckle.png"): speckle(),
        (TEX, "glow.png"): glow(),
        (TEX, "fleece.png"): fleece(),
        (UI, "button_normal.png"): button(WOOD, BONE, 1),
        (UI, "button_hover.png"): button(WOOD * 1.25, BONE, 1, fill_grain=0.16),
        (UI, "button_pressed.png"): button(RED, BONE, 1, dark_grain=True),
        (UI, "button_disabled.png"): button(np.array([26, 22, 20], float), BONE * 0.5, 1, line_alpha=0.6, gaps=0.45),
        (UI, "button_focus.png"): focus_ring(2),
        (UI, "accent_normal.png"): button(RED, BONE, 3, dark_grain=True),
        (UI, "accent_pressed.png"): button(RED * 0.72, EMBER, 3, dark_grain=True),
        (UI, "panel_dark.png"): panel_dark(),
        (UI, "panel_paper.png"): panel_paper(),
        (UI, "groove.png"): groove(INK, 80),
        (UI, "groove_red.png"): groove(RED, 81, edge=BONE, edge_a=0.5),
        (UI, "groove_ember.png"): groove(EMBER, 82, edge=BONE, edge_a=0.4),
        (UI, "field.png"): groove(np.array([14, 12, 11], float), 83, ch=40, m=12),
        (UI, "rule.png"): line_patch(BONE, 84),
        (UI, "rule_ink.png"): line_patch(INK, 85),
        (UI, "scroll_grabber.png"): scroll_grabber(BONE * 0.8, 86),
        (UI, "scroll_grabber_hi.png"): scroll_grabber(EMBER, 86),
        (UI, "grabber.png"): icon_grabber(RED, BONE),
        (UI, "grabber_hi.png"): icon_grabber(EMBER, BONE),
        (UI, "grabber_off.png"): icon_grabber(WOOD, BONE * 0.45),
        (UI, "toggle_on.png"): icon_toggle(True),
        (UI, "toggle_off.png"): icon_toggle(False),
        (UI, "toggle_on_off.png"): icon_toggle(True, True),
        (UI, "toggle_off_off.png"): icon_toggle(False, True),
        (UI, "check_on.png"): icon_check(True),
        (UI, "check_off.png"): icon_check(False),
        (UI, "check_on_off.png"): icon_check(True, True),
        (UI, "check_off_off.png"): icon_check(False, True),
        (UI, "radio_on.png"): icon_check(True, radio=True),
        (UI, "radio_off.png"): icon_check(False, radio=True),
        (UI, "arrow.png"): arrow_icon(BONE),
    }
    for (folder, name), img in out.items():
        write_png(os.path.join(folder, name), img)
        print("wrote", os.path.relpath(os.path.join(folder, name), ROOT), img.shape)


if __name__ == "__main__":
    main()
