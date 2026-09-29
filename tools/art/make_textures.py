#!/usr/bin/env python3
"""Bake the shared woodcut textures for Mamuthones (paper, grain, hatch, chisel, fog, speckle, glow,
fleece). The UI kit is pixel art now: tools/art/pixel/ui_kit.py writes game/art/ui/.

Everything is procedural (numpy only) and tileable, so the pictures stay small and cheap on a phone:
the game repeats them instead of stretching large images.

    python3 tools/art/make_textures.py            # writes game/art/textures/

Palette (docs/design.md section 8): black #141110, bone #ede6da, red #c0392b, ember #e0a24a.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pngio import write_png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "game", "art", "textures")

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


def main():
    os.makedirs(TEX, exist_ok=True)
    out = {
        (TEX, "paper.png"): paper(),
        (TEX, "grain.png"): grain(),
        (TEX, "hatch.png"): hatch(),
        (TEX, "chisel.png"): chisel(),
        (TEX, "fog.png"): fog(),
        (TEX, "speckle.png"): speckle(),
        (TEX, "glow.png"): glow(),
        (TEX, "fleece.png"): fleece(),
    }
    for (folder, name), img in out.items():
        write_png(os.path.join(folder, name), img)
        print("wrote", os.path.relpath(os.path.join(folder, name), ROOT), img.shape)


if __name__ == "__main__":
    main()
