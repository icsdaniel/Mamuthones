"""The player's own look, laid over the shared Mamuthone figures (figures.py): the dark straps, the
extra bells of the heavier bell sets and where the carved mask sits, for every pose at both sizes.

    python3 tools/art/pixel/workshop.py        (then `godot --headless --path game --import`)

Writes game/art/px/workshop/ (strap overlays, bell sprites) and game/scripts/art/look_cells.gd, which
LookArt reads. Nothing here copies the figures' pixels: the overlays are found in a fresh render of
figures.mamuthone(), so re-run this after figures.py changes (after bake_figures.py).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import figures  # noqa: E402
from palette import P  # noqa: E402
from px import Canvas  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/workshop")

# natural strap leather -> dark strap leather
DARK = {"LEATHER1": "K1", "LEATHER2": "LEATHER0", "LEATHER3": "LEATHER1"}
BELL_SIZES = ("xs", "s", "m", "l", "xl")


def find_mask(cv, rows):
    """Top-left of the mask stamp `rows` in cv (the figure's carved mask), or None."""
    a = cv.a
    h, w = len(rows), len(rows[0])
    want = []
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch not in ". ":
                want.append((i, j, P[figures.MASK_CMAP[ch]]))
    for y in range(cv.h - h):
        for x in range(cv.w - w):
            ok = True
            for (i, j, col) in want[:12]:
                if tuple(a[y + j, x + i, :3]) != col or a[y + j, x + i, 3] == 0:
                    ok = False
                    break
            if ok and all(tuple(a[y + j, x + i, :3]) == col for (i, j, col) in want):
                return x, y
    return None


def strap_overlay(cv):
    """The strap pixels of a figure render, recoloured dark: (Canvas, (x0, y0)) cropped to them."""
    a = cv.a
    out = Canvas(cv.w, cv.h)
    hit = False
    for name, dark in DARK.items():
        r, g, b = P[name]
        m = (a[:, :, 0] == r) & (a[:, :, 1] == g) & (a[:, :, 2] == b) & (a[:, :, 3] > 0)
        if m.any():
            out._put(m, dark)
            hit = True
    if not hit:
        return None, (0, 0)
    x0, y0, x1, y1 = out.bbox()
    crop = Canvas(x1 - x0, y1 - y0)
    crop.a[:, :, :] = out.a[y0:y1, x0:x1, :]
    return crop, (x0, y0)


def extra_bells(size):
    """Extra bells of the heavier sets, as (bell size, hang x, hang y, layer) relative to the yoke
    (where the chest straps meet). 'belt' bells hang from a second strap across the chest; 'back'
    bells show behind the far shoulder (drawn behind the figure)."""
    k = 1.0 if size == "field" else 1.6
    s_small, s_mid, s_big = ("xs", "s", "m") if size == "field" else ("s", "m", "l")
    belt_y = 9 * k

    def belt(u):
        return (u * k, belt_y + abs(u) * 0.12 * k)
    village = [(s_mid, *belt(-8), "front"), (s_mid, *belt(0), "front"), (s_mid, *belt(8), "front")]
    full = [(s_small, *belt(-12), "front"), (s_mid, *belt(-6), "front"), (s_big, *belt(0), "front"),
            (s_mid, *belt(6), "front"), (s_small, *belt(12), "front"),
            (s_big, 11 * k, -13 * k, "back"), (s_big, 15.5 * k, -6 * k, "back"), (s_big, 17.5 * k, 2 * k, "back")]
    return {"light": [], "village": village, "full": full}, [(-14 * k, belt_y + 1.2 * k), (14 * k, belt_y + 1.2 * k)]


def main():
    os.makedirs(OUT, exist_ok=True)
    mask_rects, straps, yokes = [], [], []
    for size in ("field", "big"):
        fx, fy = figures.FEET[size]
        rows = figures.MASK_BIG if size == "big" else figures.MASK_FIELD
        for pose in figures.MAM_POSES:
            cv = figures.mamuthone(pose, "black", size)
            key = f"{size}_{pose}"
            at = find_mask(cv, rows)
            if at is None:
                raise SystemExit(f"mask stamp not found in {key}")
            mx, my = at
            mask_rects.append(f'\t"{key}": Rect2i({mx - fx}, {my - fy}, {len(rows[0])}, {len(rows)}),')
            # the yoke, where the chest straps meet: a fixed offset from the mask in figures.py's layout
            yx = mx + (6 if size == "big" else 3.5)
            yy = my + (30.4 if size == "big" else 19)
            yokes.append(f'\t"{key}": Vector2({yx - fx:.1f}, {yy - fy:.1f}),')
            ov, (ox, oy) = strap_overlay(cv)
            if ov is not None:
                ov.save(os.path.join(OUT, f"straps_dark_{key}.png"))
                straps.append(f'\t"{key}": Vector2i({ox - fx}, {oy - fy}),')
    hangs = []
    for sz in BELL_SIZES:
        b, (hx, hy) = figures.bell(sz)
        b.save(os.path.join(OUT, f"bell_{sz}.png"))
        hangs.append(f'\t"{sz}": Vector2i({hx}, {hy}),')
    bells, belts = [], []
    for size in ("field", "big"):
        sets, belt = extra_bells(size)
        parts = []
        for bs, lst in sets.items():
            items = ", ".join(f'["{a}", Vector2({x:.1f}, {y:.1f}), "{layer}"]' for (a, x, y, layer) in lst)
            parts.append(f'"{bs}": [{items}]')
        bells.append(f'\t"{size}": {{{", ".join(parts)}}},')
        belts.append(f'\t"{size}": [Vector2({belt[0][0]:.1f}, {belt[0][1]:.1f}), Vector2({belt[1][0]:.1f}, {belt[1][1]:.1f})],')
    gd = f'''class_name LookCells
extends RefCounted
## Generated by tools/art/pixel/workshop.py - do not edit; re-run it after figures.py changes.
## Where the player's own look goes on the shared Mamuthone figures, per "<size>_<pose>", in art
## pixels relative to the figure's feet (facing right).

const DIR := "res://art/px/workshop/"
## The carved mask's stamp in the figure (the player's mask is drawn over it).
const MASK := {{
{chr(10).join(mask_rects)}
}}
## Where the chest straps meet.
const YOKE := {{
{chr(10).join(yokes)}
}}
## Top-left of straps_dark_<key>.png (the straps recoloured dark leather).
const STRAPS := {{
{chr(10).join(straps)}
}}
## Bell sprites bell_<size>.png: the point each hangs from.
const BELL_HANG := {{
{chr(10).join(hangs)}
}}
## Extra bells per bell set: [bell size, hang point relative to the yoke, "front" | "back"].
const BELLS := {{
{chr(10).join(bells)}
}}
## The second chest strap the belt bells hang from, relative to the yoke.
const BELT := {{
{chr(10).join(belts)}
}}
'''
    with open(os.path.join(ROOT, "scripts/art/look_cells.gd"), "w") as f:
        f.write(gd)
    print("look overlays written to", OUT)


if __name__ == "__main__":
    main()
