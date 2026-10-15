"""The player's look on the play screen's pixel Mamuthone (PixelFigure, cut by bake_ai_figures.py):

    python3 tools/art/pixel3d/bake_looks.py

Run it after bake_ai_figures.py. The finished picture wears dark brown sheepskin and natural leather;
this recolours its pixels region by region into the workshop's real choices (MaskSpec.FLEECES and
MaskSpec.STRAPS), keeping every pixel's place and light step, so the figure is the same drawing:

  fleece  "dark_brown" is the picture as painted; "black" maps its warm strands onto a black-wool
          ramp lit by the bonfire (shadows K0, the lit tips a warm grey-brown, never grey-blue).
  straps  "natural" is as painted; "dark" maps the leather (the chest strap the bells hang from and
          the gaiters, sos cambales, wound round the shins) onto a near-black leather ramp. The
          buckles' metal stays.

Writes game/art/pixel/looks/mamuthone_body_<fleece>_<straps>.png, mamuthone_head_<fleece>_<straps>.png
(the head piece has fleece at the collar and the strap's top), mamuthone_front_bells_<straps>.png
(the straps between the bells), mamuthone_face.png (the painted face: where
FigureLook stamps the carved mask, MaskPixels, at run time) and the numbers in
game/scripts/art/figure_look_cells.gd.

Regions are found by colour (the picture's warm ramp against its neutral cloth and the kerchief's
red) inside boxes picked by eye on the 172-px canvas (as the picture faces the road, before any
flip).
"""
import os
import colorsys
import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "../../.."))
SRC = os.path.join(ROOT, "game/art/pixel")
OUT = os.path.join(SRC, "looks")
GD = os.path.join(ROOT, "game/scripts/art/figure_look_cells.gd")

FLEECES = ["black", "dark_brown"]
STRAPS = ["natural", "dark"]

# The leather, (x0, y0, x1, y1) on the canvas, end exclusive: the chest strap between the buckles
# and the two gaiters.
LEATHER = [(39, 47, 52, 80), (18, 137, 46, 167), (80, 134, 109, 163)]
# Skin and the kerchief's tail stay as painted.
KEEP_BODY = [(2, 82, 19, 99), (55, 80, 79, 98)]
# On the head piece only the collar's strands are fleece (the hood is the kerchief).
HEAD_FLEECE = [(10, 30, 25, 50), (55, 30, 70, 50)]
# The strap running down from the kerchief (head piece) and between the front bells (their piece).
HEAD_LEATHER = [(41, 38, 53, 60)]
BELLS_LEATHER = [(36, 55, 62, 70)]
# The painted face (inside the kerchief), searched for low-saturation pixels.
FACE_BOX = (24, 9, 44, 42)
# The carving is laid on the painted 3/4 face (FigureLook.carve): MaskPixels is rendered at
# MASK_UNIT art px to the mask unit and read through the painted face's own landmarks, picked by eye
# on the head: the nose's ridge column (the mask's middle; the far side of the face, left of it, is
# narrower than the near side) and the rows of the crown, brow, eyes, nose tip, mouth, chin.
MASK_UNIT = 10.0
NOSE_X = 31.5
LANDMARKS = [(-1.34, 11.0), (-0.63, 18.5), (-0.34, 23.0), (0.7, 30.5), (1.13, 34.5), (1.56, 37.5), (1.9, 40.0)]

# Black sheepskin in the firelight, shadow to lit tip.
BLACK_WOOL = ["#0a080b", "#110e10", "#181415", "#211b1b", "#2b2322", "#372d2a", "#463931", "#574739"]
# Dark leather.
DARK_LEATHER = ["#0c0808", "#120c0a", "#1a110d", "#231711", "#2e1e15", "#3c271b"]


def hexes(cs):
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in cs], np.float32)


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def hsv(a):
    rgb = a[..., :3].astype(np.float32) / 255.0
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return s, mx


def box_mask(shape, boxes):
    m = np.zeros(shape[:2], bool)
    for x0, y0, x1, y1 in boxes:
        m[y0:y1, x0:x1] = True
    return m


def warm(a):
    s, v = hsv(a)
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (a[..., 3] > 0) & (s >= 0.3) & (r >= g) & (g >= b - 4)


def skin(a):
    s, v = hsv(a)
    return (a[..., 0] > 170) & (s < 0.58)


def ramp_map(a, m, ramp, lo, hi):
    """Pixels in m onto `ramp` by their light (luma between lo and hi spread over the ramp)."""
    out = a.copy()
    cols = hexes(ramp)
    L = luma(a[..., :3].astype(np.float32))
    t = np.clip((L - lo) / max(hi - lo, 1.0), 0.0, 1.0)
    idx = np.clip(np.round(t * (len(ramp) - 1)).astype(int), 0, len(ramp) - 1)
    out[..., :3] = np.where(m[..., None], cols[idx].astype(np.uint8), a[..., :3])
    return out


def light_range(a, m):
    L = luma(a[..., :3].astype(np.float32))[m]
    return float(np.percentile(L, 2)), float(np.percentile(L, 99))


def flood(m, seed):
    """The 4-connected part of m holding seed (or the nearest set pixel to it)."""
    if not m[seed]:
        ys, xs = np.nonzero(m)
        k = np.argmin((ys - seed[0]) ** 2 + (xs - seed[1]) ** 2)
        seed = (ys[k], xs[k])
    out = np.zeros_like(m)
    todo = [seed]
    while todo:
        y, x = todo.pop()
        if y < 0 or x < 0 or y >= m.shape[0] or x >= m.shape[1] or out[y, x] or not m[y, x]:
            continue
        out[y, x] = True
        todo += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return out


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, "mamuthone_%s.png" % name)).convert("RGBA")).copy()


def save(a, name):
    Image.fromarray(a.astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    body = load("body")
    head = load("head")
    w_body = warm(body) & ~skin(body) & ~box_mask(body.shape, KEEP_BODY)
    s, v = hsv(body)
    metal = (v > 0.66) & (s > 0.55)          # the buckles' brass catches the fire
    leather = w_body & box_mask(body.shape, LEATHER) & ~metal
    fleece = w_body & ~box_mask(body.shape, LEATHER)
    w_head = warm(head) & ~skin(head)
    head_fleece = w_head & box_mask(head.shape, HEAD_FLEECE)
    hs_, hv_ = hsv(head)
    head_leather = w_head & box_mask(head.shape, HEAD_LEATHER) & ~((hv_ > 0.66) & (hs_ > 0.55))
    # the straps between the front bells: their leather, above the bells' bronze
    bells = load("front_bells")
    bs_, bv_ = hsv(bells)
    bells_leather = warm(bells) & box_mask(bells.shape, BELLS_LEATHER) & (bv_ < 0.5)
    f_lo, f_hi = light_range(body, fleece)
    l_lo, l_hi = light_range(body, leather)
    for fl in FLEECES:
        b = body if fl == "dark_brown" else ramp_map(body, fleece, BLACK_WOOL, f_lo, f_hi)
        for st in STRAPS:
            o = b if st == "natural" else ramp_map(b, leather, DARK_LEATHER, l_lo, l_hi)
            save(o, "mamuthone_body_%s_%s" % (fl, st))
        h = head if fl == "dark_brown" else ramp_map(head, head_fleece, BLACK_WOOL, f_lo, f_hi)
        for st in STRAPS:
            o = h if st == "natural" else ramp_map(h, head_leather, DARK_LEATHER, l_lo, l_hi)
            save(o, "mamuthone_head_%s_%s" % (fl, st))
    for st in STRAPS:
        o = bells if st == "natural" else ramp_map(bells, bells_leather, DARK_LEATHER, l_lo, l_hi)
        save(o, "mamuthone_front_bells_%s" % st)
    # the painted face: the low-saturation pixels joined to its middle, holes filled
    x0, y0, x1, y1 = FACE_BOX
    hs, hv = hsv(head)
    grey = (head[..., 3] > 0) & (hs < 0.3)
    face = np.zeros(grey.shape, bool)
    face[y0:y1, x0:x1] = grey[y0:y1, x0:x1]
    face = flood(face, ((y0 + y1) // 2, (x0 + x1) // 2))
    # rows filled across (the eyes' dark band breaks the grey into pieces)
    for y in range(face.shape[0]):
        xs = np.flatnonzero(face[y])
        if xs.size:
            face[y, xs.min():xs.max() + 1] = True
    fm = np.zeros(head.shape, np.uint8)
    fm[face] = (255, 255, 255, 255)
    Image.fromarray(fm, "RGBA").save(os.path.join(OUT, "mamuthone_face.png"), optimize=True)
    ys, xs = np.nonzero(face)
    marks = ", ".join("Vector2(%.2f, %.1f)" % m for m in LANDMARKS)
    swatch_fleece = (72, 92, 40, 44)
    swatch_straps = (76, 124, 40, 44)
    with open(GD, "w") as f:
        f.write('''class_name FigureLookCells
extends RefCounted
## Generated by tools/art/pixel3d/bake_looks.py - do not edit; re-run it after bake_ai_figures.py.
## Where the player's look goes on the play screen's pixel Mamuthone (PixelFigure), in art px of its
## 172-px canvas (as the picture faces the road).

const DIR := "res://art/pixel/looks/"
## The carving on the painted 3/4 face (mamuthone_face.png): MaskPixels at MASK_UNIT, its middle
## (u = 0) on the nose's column NOSE_X, its rows by LANDMARKS (mask v, face row y), piecewise.
const MASK_UNIT := %.1f
const NOSE_X := %.1f
const LANDMARKS: Array[Vector2] = [%s]
## The painted face's box.
const FACE := Rect2i(%d, %d, %d, %d)
## Crops of the figure that show a fleece and a strap swatch in the workshop.
const SWATCH_FLEECE := Rect2i(%d, %d, %d, %d)
const SWATCH_STRAPS := Rect2i(%d, %d, %d, %d)
''' % (MASK_UNIT, NOSE_X, marks, xs.min(), ys.min(), xs.max() + 1 - xs.min(), ys.max() + 1 - ys.min(),
            *swatch_fleece, *swatch_straps))
    print("fleece px", int(fleece.sum()), "leather px", int(leather.sum()), "head fleece", int(head_fleece.sum()),
          "face", int(face.sum()))


if __name__ == "__main__":
    main()
