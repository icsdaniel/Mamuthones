"""Shared steps for turning Daniele's pictures into pixel art on the play screen's grid.

pixelate(rgb, size, ...) flattens the picture's texture into areas first (mean shift, so the cells
take clean colours instead of noise), shrinks it to `size` by area, then snaps every cell to the
palette (game/art/pixel/palette.png), nearest in Lab, with a light ordered dither only where the
picture is a smooth gradient (the sky), so flat areas stay flat.
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
