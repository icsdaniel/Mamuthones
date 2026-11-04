"""Shared steps for turning Daniele's ChatGPT pictures (2026-10, tools/art/sources/chatgpt/) into game art.

Every picture goes through the same steps:
  1. key: the flat magenta (#FF00FF) background, and the pink fringe it leaves on edges, becomes
     real alpha;
  2. grid: the picture is taken down to its own art-pixel grid (area average, so each art pixel is
     one even sample of its block) and the alpha cut hard at half;
  3. snap: every colour is snapped to the style palette (style_palette.png, the 61 colours of the
     ChatGPT style bible), nearest in Lab;
  4. save: blown back up by a whole factor with nearest (so the game's own shrinking to its screen
     cells starts from clean blocks) and written lossless.
"""
import os
import numpy as np
from PIL import Image
import cv2
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "../../.."))
GAME = os.path.join(ROOT, "game")
SRC = os.path.join(ROOT, "tools/art/sources/chatgpt")
PALETTE = ["#07060a", "#0b1a33", "#0e5a2c", "#120e0e", "#13284a", "#140c09", "#173c8a", "#1a0e0a",
    "#1a1420", "#1e1c30", "#23305a", "#24160f", "#251e1f", "#26b862", "#2c2840", "#2f78e0", "#33201a",
    "#3a3132", "#3c2618", "#3e3552", "#44176a", "#4a2c0e", "#4e3228", "#5a0e12", "#5a2e2a", "#5c3a22",
    "#6e6672", "#701a46", "#70452e", "#7a1c0a", "#80562f", "#8a2fd0", "#8a4430", "#8a5038", "#8a5a1c",
    "#9cc4ff", "#9cf0a8", "#a8161c", "#a85a26", "#a89ea6", "#c0683a", "#c48262", "#c8400c", "#c89030",
    "#c8a0ff", "#d8802e", "#e0242a", "#e0408c", "#e2d6ca", "#e8975a", "#ecb894", "#ecc055", "#f07018",
    "#f6c48a", "#fba832", "#fbf3e8", "#ff5a42", "#ffacd0", "#ffd86a", "#fff0a0", "#fff4cc"]
# colours reserved for the notes: never snapped to on figures, scenery or the HUD
RESERVED = {"#0e5a2c", "#26b862", "#9cf0a8", "#173c8a", "#2f78e0", "#9cc4ff", "#44176a", "#8a2fd0",
    "#c8a0ff", "#701a46", "#e0408c", "#ffacd0"}


def _rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def palette(reserved=True, extra=()):
    cols = [c for c in PALETTE if reserved or c not in RESERVED] + list(extra)
    return np.array([_rgb(c) for c in cols], np.uint8)


def src(name):
    return os.path.join(SRC, name)


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).copy()


def magenta(rgba, loose=False):
    """The magenta background (and its soft fringe where it touches a piece) as a mask."""
    rgb = np.ascontiguousarray(rgba[..., :3])
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.int32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    core = (np.abs(h - 150) <= 8) & (s > 150) & (v > 150)
    # the fringe: magenta-tinted pixels touching the background
    fringe = (np.abs(h - 150) <= 14) & (s > 70) & (v > 90)
    if loose:
        fringe |= (np.abs(h - 150) <= 18) & (s > 50)
    near = cv2.dilate(core.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    lab, _ = ndimage.label(fringe & near | core)
    keep = np.unique(lab[core])
    bg = np.isin(lab, keep[keep > 0])
    return bg | (rgba[..., 3] < 128)


def keyed(rgba, loose=False):
    out = rgba.copy()
    bg = magenta(rgba, loose)
    out[..., 3] = np.where(bg, 0, 255)
    out[bg, :3] = 0
    return out


def block_size(rgba, lo=3, hi=16):
    """Guess the art pixel's size in source px: the run length between colour changes that best
    explains the picture's edges (a comb at that period lines up with most of them)."""
    a = rgba[..., :3].astype(np.int32)
    dx = (np.abs(np.diff(a, axis=1)).sum(-1) > 40).sum(0).astype(np.float64)
    dy = (np.abs(np.diff(a, axis=0)).sum(-1) > 40).sum(1).astype(np.float64)
    best, score = None, -1
    for p10 in range(lo * 10, hi * 10 + 1):
        p = p10 / 10.0
        sc = 0.0
        for d in (dx, dy):
            idx = np.arange(d.size)
            ph = np.exp(2j * np.pi * idx / p)
            sc += abs((d * ph).sum()) / (d.sum() + 1e-9)
        if sc > score:
            best, score = p, sc
    return best


def grid(rgba, f, size=None):
    """Down to the art grid: f source px an art px (or straight to size=(w, h))."""
    h, w = rgba.shape[:2]
    if size is None:
        size = (max(1, round(w / f)), max(1, round(h / f)))
    a = rgba.astype(np.float32)
    al = a[..., 3:4] / 255.0
    pre = np.concatenate([a[..., :3] * al, al * 255.0], -1)
    small = cv2.resize(pre, size, interpolation=cv2.INTER_AREA)
    alpha = small[..., 3:4] / 255.0
    rgb = np.where(alpha > 0.01, small[..., :3] / np.maximum(alpha, 1e-6), 0)
    out = np.concatenate([np.clip(rgb, 0, 255), np.where(alpha > 0.5, 255.0, 0.0)], -1)
    return out.astype(np.uint8)


def snap(rgba, pal=None):
    """Every colour to its nearest palette colour (Lab distance)."""
    if pal is None:
        pal = palette()
    lab_p = cv2.cvtColor(pal[None].astype(np.uint8), cv2.COLOR_RGB2LAB)[0].astype(np.float32)
    rgb = np.ascontiguousarray(rgba[..., :3])
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32).reshape(-1, 3)
    out = np.empty((lab.shape[0],), np.int64)
    for i in range(0, lab.shape[0], 65536):
        d = ((lab[i:i + 65536, None, :] - lab_p[None]) ** 2).sum(-1)
        out[i:i + 65536] = d.argmin(1)
    res = rgba.copy()
    res[..., :3] = pal[out].reshape(rgb.shape)
    res[res[..., 3] == 0, :3] = 0
    return res


def up(rgba, k):
    return np.repeat(np.repeat(rgba, k, 0), k, 1)


def crop_alpha(rgba, pad=0):
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = np.zeros((b - t + 2 * pad, r - l + 2 * pad, 4), np.uint8)
    out[pad:pad + b - t, pad:pad + r - l] = rgba[t:b, l:r]
    return out


def pieces(fg, n, gap=9):
    """The n biggest separate pieces of mask fg, in reading order: [(box (t, l, b, r), mask)]."""
    lab, k = ndimage.label(cv2.dilate(fg.astype(np.uint8), np.ones((gap, gap), np.uint8)))
    sizes = ndimage.sum(fg, lab, range(1, k + 1))
    big = sorted(range(1, k + 1), key=lambda i: -sizes[i - 1])[:n]
    boxes = []
    for i in big:
        ys, xs = np.nonzero((lab == i) & fg)
        boxes.append((ys.min(), xs.min(), ys.max() + 1, xs.max() + 1, i))
    tall = max(b[2] - b[0] for b in boxes)
    boxes.sort(key=lambda b: (round(b[0] / (tall * 0.6)), b[1]))
    return [(b[:4], lab == b[4]) for b in boxes]


def save(rgba, path, k=1):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.fromarray(up(rgba, k) if k > 1 else rgba)
    if path.endswith(".webp"):
        img.save(path, lossless=True, quality=100, method=6, exact=True)
    else:
        img.save(path, optimize=True)
    print(os.path.relpath(path, ROOT), img.size)
