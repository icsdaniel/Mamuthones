"""Pixel art redrawn from Daniele's pictures rather than shrunk from them (Daniele, 2026-10-05: "use
the references as a rough starting point to then re create from scratch").

A picture is only used for three things: which material each cell is (red cloth, white linen,
fleece, brass...), the shape of each material, and roughly how lit it is. Every cell is then
painted fresh from that material's own short ramp (MATERIALS), in large clean clusters:

  1. material per cell by majority vote over the cell (no averaged in-between colours);
  2. light per cell from the picture's brightness, blurred so it forms big shapes, banded into the
     ramp's steps by share (most of a material in its middle steps, a little in its top step);
  3. clusters cleaned: a cell unlike its neighbours joins them, so no lone pixels;
  4. a hand-drawn texture on top where the material has one (fleece tufts, skirt pleats,
     twisted rope);
  5. a one-cell outline in the darkest step of the material beside it.

Every figure and the street use the same ramps, so the whole screen shares one palette.
"""
import numpy as np
import cv2
from scipy import ndimage


def hexes(*h):
    return np.array([[int(x[i:i + 2], 16) for i in (1, 3, 5)] for x in h], np.uint8)


# each ramp dark -> light; `share` is how much of the material sits in each step
MATERIALS = {
    "red":    (hexes("#4a0d12", "#8e161b", "#c81d22", "#ee3a2c", "#ff7656"), (0.08, 0.17, 0.42, 0.27, 0.06)),
    "linen":  (hexes("#5d5463", "#958a92", "#cdbfb6", "#efe3d6", "#fffaf0"), (0.06, 0.14, 0.3, 0.42, 0.08)),
    "skin":   (hexes("#6e3a2a", "#a8644a", "#d4987a", "#f0c4a2"), (0.12, 0.3, 0.42, 0.16)),
    "cloth":  (hexes("#0c0909", "#1b1515", "#2c2425", "#433839", "#5e5052"), (0.22, 0.3, 0.26, 0.16, 0.06)),
    "brass":  (hexes("#2a1606", "#5e3810", "#9a6420", "#cf9a3a", "#f2cf72"), (0.2, 0.2, 0.24, 0.24, 0.12)),
    "fleece": (hexes("#120806", "#25140f", "#3a2420", "#54352b", "#7a4a2c", "#b0662c", "#e39a4a"), (0.14, 0.2, 0.22, 0.18, 0.12, 0.09, 0.05)),
    "wood":   (hexes("#080504", "#140c09", "#22150f", "#342219"), (0.3, 0.35, 0.25, 0.1)),
    "night":  (hexes("#060b1a", "#0a1430", "#111d42", "#1c2650", "#2c2a58"), (0.2, 0.3, 0.25, 0.17, 0.08)),
    "stone":  (hexes("#100e1c", "#1b182c", "#28223a", "#3a2a44", "#55303e", "#763a36", "#9c4c36", "#c46a40", "#e49458", "#f6c27e"),
               (0.1, 0.12, 0.13, 0.12, 0.11, 0.11, 0.1, 0.09, 0.08, 0.04)),
    "flame":  (hexes("#8a1f0a", "#c8400c", "#ee6a16", "#fba030", "#fed46a", "#fff4c8"), (0.1, 0.15, 0.2, 0.25, 0.2, 0.1)),
    "leather": (hexes("#3a1a0c", "#7a3a16", "#b8601e", "#e08a34", "#f8b860"), (0.12, 0.26, 0.32, 0.22, 0.08)),
}
# how much the light is blurred per material: big soft cloth areas get big clusters, small detailed
# things (faces, bells, fleece tufts) keep their shapes
SOFT = {"red": 1.0, "cloth": 0.9, "stone": 1.0, "night": 1.4}
NAMES = list(MATERIALS)


def classify(rgb, alpha, rules):
    """Material index per pixel of a full-size picture (rules: list of (name, predicate(h, s, v)))."""
    hsv = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2HSV).astype(np.int32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    out = np.full(rgb.shape[:2], -1, np.int32)
    for name, pred in rules:
        m = (out < 0) & pred(h, s, v) & (alpha > 0)
        out[m] = NAMES.index(name)
    return out


def majority(mat, alpha, size):
    """Material per cell by area vote, and which cells are opaque."""
    w, h = size
    votes = np.stack([cv2.resize(((mat == i) & (alpha > 0)).astype(np.float32), size, interpolation=cv2.INTER_AREA)
                      for i in range(len(NAMES))], -1)
    al = cv2.resize((alpha > 0).astype(np.float32), size, interpolation=cv2.INTER_AREA)
    m = np.argmax(votes, -1)
    return np.where(al > 0.5, m, -1)


def light(rgb, alpha, size, blur=0.8):
    """Brightness per cell (Lab L, masked mean), blurred a little so it falls into big shapes."""
    L = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2LAB)[..., 0].astype(np.float32)
    a = (alpha > 0).astype(np.float32)
    num = cv2.resize(L * a, size, interpolation=cv2.INTER_AREA)
    den = cv2.resize(a, size, interpolation=cv2.INTER_AREA)
    num = cv2.GaussianBlur(num, (0, 0), blur)
    den = cv2.GaussianBlur(den, (0, 0), blur)
    return num / np.maximum(den, 1e-3)


def thresholds(mat, lit):
    """Per material, the brightness cut points that give each ramp step its share."""
    out = {}
    for i, name in enumerate(NAMES):
        v = lit[mat == i]
        if v.size < 4:
            continue
        share = np.cumsum(MATERIALS[name][1])[:-1]
        out[i] = np.quantile(v, share)
    return out


def band(mat, lit, cuts):
    step = np.zeros(mat.shape, np.int32)
    for i, c in cuts.items():
        m = mat == i
        step[m] = np.searchsorted(c, lit[m])
    return step


def clean(mat, step, passes=1):
    """A cell whose step (or material) none of its four neighbours share takes the most common one."""
    h, w = mat.shape
    key = np.where(mat >= 0, mat * 16 + step, -1)
    for _ in range(passes):
        pad = np.pad(key, 1, constant_values=-1)
        nb = np.stack([pad[0:h, 1:w + 1], pad[2:h + 2, 1:w + 1], pad[1:h + 1, 0:w], pad[1:h + 1, 2:w + 2],
                       pad[0:h, 0:w], pad[0:h, 2:w + 2], pad[2:h + 2, 0:w], pad[2:h + 2, 2:w + 2]], -1)
        same4 = (nb[..., :4] == key[..., None]).sum(-1)
        out = key.copy()
        for y, x in zip(*np.nonzero((same4 == 0) & (key >= 0))):
            vals = nb[y, x][nb[y, x] >= 0]
            if vals.size < 3:
                continue
            u, c = np.unique(vals, return_counts=True)
            out[y, x] = u[np.argmax(c)]
        key = out
    return np.where(key >= 0, key // 16, -1), np.where(key >= 0, key % 16, 0)


def paint(mat, step):
    h, w = mat.shape
    out = np.zeros((h, w, 4), np.uint8)
    for i, name in enumerate(NAMES):
        m = mat == i
        if m.any():
            ramp = MATERIALS[name][0]
            out[m, :3] = ramp[np.clip(step[m], 0, len(ramp) - 1)]
            out[m, 3] = 255
    return out


def outline(mat, keep_inside=None):
    """Outline ring cells and the material each takes its darkest step from."""
    a = mat >= 0
    ker = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], np.uint8)
    ring = (cv2.dilate(a.astype(np.uint8), ker) > 0) & ~a
    # nearest material: grow the material map by one cell
    grown = mat.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        sh = np.roll(np.roll(mat, dy, 0), dx, 1)
        grown = np.where((grown < 0) & (sh >= 0), sh, grown)
    return ring, grown


def texture(mat, step, kind_rows, mirror=False):
    """Hand-made textures, drawn as cell patterns over the shading.

    fleece: shaggy tufts, a short dark V every few cells, staggered row to row;
    cloth rows given in kind_rows['pleats'] (y0, y1): a dark pleat line every third column;
    brass rows in kind_rows['rope'] (y0, y1): a twist, every third diagonal a step darker."""
    h, w = mat.shape
    step = step.copy()
    fl = NAMES.index("fleece")
    ys, xs = np.mgrid[0:h, 0:w]
    tuft = ((ys % 5 == 0) & (((xs + (ys // 5) * 2) % 4) == 0))
    for y, x in zip(*np.nonzero(tuft & (mat == fl) & bool(kind_rows.get("tufts")))):
        for dy, dx in ((0, 0), (-1, -1), (-1, 1), (-2, -1), (-2, 1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and mat[yy, xx] == fl and step[yy, xx] > 0:
                step[yy, xx] -= 1
        if y + 1 < h and mat[y + 1, x] == fl and step[y + 1, x] < 6:
            step[y + 1, x] += 1           # the tuft's lit tip just under its dark crease
    if "pleats" in kind_rows:
        y0, y1 = kind_rows["pleats"]
        cl = NAMES.index("cloth")
        m = (mat == cl) & (ys >= y0) & (ys < y1)
        step[m & (xs % 3 == 0)] = np.maximum(step[m & (xs % 3 == 0)] - 1, 0)
        step[m & (xs % 3 == 1)] = np.minimum(step[m & (xs % 3 == 1)] + 1, 4)
    if "rope" in kind_rows:
        y0, y1 = kind_rows["rope"]
        br = NAMES.index("brass")
        m = (mat == br) & (ys >= y0) & (ys < y1) & (((xs + ys) % 3) == 0)
        step[m] = np.maximum(step[m] - 1, 0)
    return step


def repaint_layer(rgba, size, rules, cuts=None, textures=None, rim_right=None):
    """One picture (RGBA, full size) -> RGBA at `size` in the material ramps. Returns (rgba, mat,
    lit) so callers can share cut points (cuts) between the parts of one figure."""
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    mat_full = classify(rgb, alpha, rules)
    mat = majority(mat_full, alpha, size)
    sharp, soft = light(rgb, alpha, size, 0.35), light(rgb, alpha, size, 1.0)
    lit = sharp.copy()
    for name in SOFT:
        m = mat == NAMES.index(name)
        lit[m] = soft[m]
    if cuts is None:
        cuts = thresholds(mat, lit)
    step = band(mat, lit, cuts)
    # the fire side catches a little more light: one step up on the outermost cell of each row
    if rim_right is not None:
        for y in range(mat.shape[0]):
            xs = np.nonzero(mat[y] >= 0)[0]
            if xs.size:
                x = xs[-1] if rim_right else xs[0]
                if NAMES[mat[y, x]] == "brass":
                    continue
                n = len(MATERIALS[NAMES[mat[y, x]]][0])
                step[y, x] = min(step[y, x] + 2, n - 1)
    mat, step = clean(mat, step)
    if textures is not None:
        step = texture(mat, step, textures)
    out = paint(mat, step)
    return out, mat, cuts


def ink_outline(rgba, mat, skip=None):
    """A one-cell outline round the opaque part in the darkest step of the material beside it."""
    ring, grown = outline(mat)
    if skip is not None:
        ring &= ~skip
    out = rgba.copy()
    for i, name in enumerate(NAMES):
        m = ring & (grown == i)
        out[m, :3] = MATERIALS[name][0][0] // 2
        out[m, 3] = 255
    return out
