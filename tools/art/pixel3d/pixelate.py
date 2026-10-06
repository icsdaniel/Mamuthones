"""Shared steps for turning Daniele's pictures into pixel art on the play screen's grid.

The second pass (Daniele, 2026-10-05: "do a better job with the pixel artification") keeps each
picture's own look: an edge-keeping smooth (bilateral, not mean shift: that melted the flames and
the fleece), a shrink by area, a light sharpen on the grid, then a palette of the picture's OWN
colours (k-means in Lab: kpalette) instead of one shared palette, nearest colour in Lab, no dither,
lone stray cells merged into their neighbours (despeckle), and an outline in a dark shade of the
colour next to it (selout) rather than flat ink. The older shared palette (palette.png, snap) is
kept for PixelFilter, which only runs without the World viewport.
"""
import os
import numpy as np
from PIL import Image
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "../../../game")
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 - 0.47


def palette():
    return np.asarray(Image.open(os.path.join(GAME, "art/pixel/palette.png")).convert("RGB")).reshape(-1, 3)


def lab(rgb):
    a = np.asarray(rgb).astype(np.uint8)
    sh = a.shape
    return cv2.cvtColor(a.reshape(-1, 1, 3), cv2.COLOR_RGB2LAB).reshape(sh).astype(np.float32)


def snap(rgb, pal=None, dither=None, amount=10.0):
    """rgb (h, w, 3) uint8 -> nearest palette colours. dither: (h, w) weight 0..1 for ordered dither."""
    pal = palette() if pal is None else pal
    L = lab(rgb)
    if dither is not None:
        h, w = dither.shape
        t = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
        L = L.copy()
        L[..., 0] += t * amount * dither
    pl = lab(pal.reshape(-1, 1, 3)).reshape(-1, 3)
    d = ((L[..., None, :] - pl[None, None, :, :]) ** 2).sum(-1)
    return pal[np.argmin(d, -1)]


def flatten(rgb, sp=6, sr=18):
    return cv2.pyrMeanShiftFiltering(np.ascontiguousarray(rgb), sp, sr)


def shrink(rgb, size):
    return cv2.resize(rgb, size, interpolation=cv2.INTER_AREA)


def gradient_mask(small):
    """1 where the picture is a smooth, dark gradient (dither there), 0 on detail."""
    g = cv2.cvtColor(small, cv2.COLOR_RGB2GRAY).astype(np.float32)
    edges = cv2.Laplacian(g, cv2.CV_32F, ksize=3)
    m = (np.abs(edges) < 6.0).astype(np.float32)
    m = cv2.erode(m, np.ones((3, 3), np.uint8))
    return m


def outline(rgba, ink=(7, 6, 10)):
    """A one-cell dark outline round the opaque part of a sprite."""
    a = rgba[..., 3] > 127
    grown = cv2.dilate(a.astype(np.uint8), np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], np.uint8)) > 0
    ring = grown & ~a
    out = rgba.copy()
    out[..., 3] = np.where(a, 255, 0)
    out[ring] = (*ink, 255)
    return out


# ------------------------------------------------------------------ second pass


def rgb_of_lab(L):
    sh = L.shape
    return cv2.cvtColor(np.clip(L, 0, 255).astype(np.uint8).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(sh)


def kpalette(pixels, k, seed=7):
    """The picture's own k colours (k-means in Lab over `pixels`, any shape ending in 3)."""
    L = lab(np.asarray(pixels, np.uint8).reshape(-1, 1, 3)).reshape(-1, 3)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 80, 0.3)
    cv2.setRNGSeed(seed)
    _, _, c = cv2.kmeans(L.astype(np.float32), k, None, crit, 5, cv2.KMEANS_PP_CENTERS)
    return rgb_of_lab(c.reshape(-1, 3))


def nearest(rgb, pal):
    """Index of the palette colour nearest in Lab, per pixel."""
    L = lab(rgb)
    P = lab(pal.reshape(-1, 1, 3)).reshape(-1, 3)
    return np.argmin(((L[..., None, :] - P) ** 2).sum(-1), -1)


def smooth(rgb, d=7, sc=24, ss=5):
    """Edge-keeping smooth before the shrink: the texture goes, the shapes' edges stay."""
    return cv2.bilateralFilter(np.ascontiguousarray(rgb), d, sc, ss)


def sharpen(rgb, amount=0.7):
    f = rgb.astype(np.float32)
    return np.clip(f + (f - cv2.GaussianBlur(f, (0, 0), 0.8)) * amount, 0, 255).astype(np.uint8)


def despeckle(idx, mask, pal, passes=2, max_d=28.0):
    """A cell unlike all four neighbours, three of which agree on a close colour, takes theirs."""
    P = lab(pal.reshape(-1, 1, 3)).reshape(-1, 3)
    h, w = idx.shape
    for _ in range(passes):
        out = idx.copy()
        pad = np.pad(idx, 1, mode="edge")
        pm = np.pad(mask, 1)
        nb = [pad[0:h, 1:w + 1], pad[2:h + 2, 1:w + 1], pad[1:h + 1, 0:w], pad[1:h + 1, 2:w + 2]]
        nm = [pm[0:h, 1:w + 1], pm[2:h + 2, 1:w + 1], pm[1:h + 1, 0:w], pm[1:h + 1, 2:w + 2]]
        same = sum(((n == idx) & m) for n, m in zip(nb, nm))
        for y, x in zip(*np.nonzero((same == 0) & mask)):
            vals = [int(nb[k][y, x]) for k in range(4) if nm[k][y, x]]
            if len(vals) < 3:
                continue
            u, c = np.unique(vals, return_counts=True)
            j = u[np.argmax(c)]
            if c.max() >= 3 and np.linalg.norm(P[j] - P[idx[y, x]]) < max_d:
                out[y, x] = j
        idx = out
    return idx


def selout(rgba, keep=0.25, ink=(10, 7, 12)):
    """A one-cell outline round the opaque part, each cell a dark shade of the colour beside it."""
    a = rgba[..., 3] > 0
    ker = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], np.uint8)
    ring = (cv2.dilate(a.astype(np.uint8), ker) > 0) & ~a
    f = rgba[..., :3].astype(np.float32) * a[..., None]
    near = cv2.blur(f, (3, 3)) / np.maximum(cv2.blur(a.astype(np.float32), (3, 3))[..., None], 1e-3)
    out = rgba.copy()
    out[..., 3] = np.where(a, 255, 0)
    out[ring, :3] = (near * keep + np.array(ink, np.float32) * (1.0 - keep))[ring].astype(np.uint8)
    out[ring, 3] = 255
    return out
