"""Cut Daniele's outside-AI art sheets (2026-10-08) into clean sprites:

    python3 tools/art/pixel3d/ai_cut.py <dir with the sheets>

The image AI paints a light grey checkerboard where the background should be see-through, so the
background is everything light and grey joined to the sheet's edges (a real alpha channel is used
as is). What is left is split into its separate pieces, and each piece is cropped and written to
game/art/ai/<name>.png at the sheet's own size. The users scale them to the play screen's grid.
"""
import os
import sys
import numpy as np
from PIL import Image
import cv2
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "../../../game/art/ai")

# sheet -> names of its pieces, in reading order (top to bottom, then left to right)
SHEETS = {
    "1000145719.png": ["issohadore"],
    "1000145720.png": ["mamuthone"],
    "1000145727.png": ["bar_up", "bar_down", "bar_arrow", "bar_bell"],
    "1000145733.png": ["note_step", "note_offbeat", "note_call", "note_heal", "note_hold", "note_stomp"],
    "1000145736.png": ["rope", "knot"],
    "1000145739.png": ["ring_idle", "ring_gold", "ring_red"],
    "1000145740.png": ["hud_plate", "hud_pause", "hud_bar", "hud_stud"],
    "1000145745.png": None,   # the street: opaque, copied whole
    "1000145750.png": ["btn_idle", "btn_pressed", "foot"],
}


# sheets whose pieces have holes the checkerboard shows through (the rings)
HOLES = {"1000145739.png"}


def mask_of(rgba, holes=False):
    if (rgba[..., 3] < 128).mean() > 0.05:
        return rgba[..., 3] > 128
    rgb = rgba[..., :3]
    hsv = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2HSV)
    light = (rgb.min(-1) > 165) & (hsv[..., 1] < 40)
    lab, _ = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(edge))
    if holes:
        big = [i for i, n in enumerate(ndimage.sum(light, lab, range(1, lab.max() + 1)), 1) if n > 2000]
        fg &= ~np.isin(lab, big)
    # the checkerboard also shows through closed gaps (inside a coil of rope, under an arm): grey
    # patches with no colour at all, in two shades
    grey = (hsv[..., 1] <= 6) & (rgb.min(-1) > 185)
    gl, gk = ndimage.label(grey)
    for i, n in enumerate(ndimage.sum(grey, gl, range(1, gk + 1)), 1):
        if n < 800:
            continue
        v = hsv[..., 2][gl == i].astype(float)
        if (v < 224).mean() > 0.2 and (v > 230).mean() > 0.2:
            fg &= ~cv2.dilate((gl == i).astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    fg = cv2.morphologyEx(fg.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
    # light specks the checkerboard leaves on a piece's edge
    near = cv2.dilate((~fg).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
    return fg & ~(light & near)


def pieces(fg, n):
    lab, k = ndimage.label(cv2.dilate(fg.astype(np.uint8), np.ones((9, 9), np.uint8)))
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, k + 1))
    big = sorted(range(1, k + 1), key=lambda i: -sizes[i - 1])[:n]
    boxes = []
    for i in big:
        ys, xs = np.nonzero((lab == i) & fg)
        boxes.append((ys.min(), xs.min(), ys.max() + 1, xs.max() + 1, i))
    # reading order: rows by top (within a third of the tallest piece), then left to right
    tall = max(b[2] - b[0] for b in boxes)
    boxes.sort(key=lambda b: (round(b[0] / (tall * 0.6)), b[1]))
    return [(b[:4], lab == b[4]) for b in boxes]


def main(src, only=None):
    os.makedirs(OUT, exist_ok=True)
    for sheet, names in SHEETS.items():
        if only and sheet not in only:
            continue
        rgba = np.asarray(Image.open(os.path.join(src, sheet)).convert("RGBA")).copy()
        if names is None:
            Image.fromarray(rgba[..., :3]).save(os.path.join(OUT, "street.png"))
            continue
        fg = mask_of(rgba, sheet in HOLES)
        if len(names) == 1:
            l2, k = ndimage.label(fg)
            fg = l2 == (np.argmax(ndimage.sum(fg, l2, range(1, k + 1))) + 1)
            # fill only small holes: the big ones are the checkerboard seen through the figure
            holes = ndimage.binary_fill_holes(fg) & ~fg
            hl, hk = ndimage.label(holes)
            small = [i for i, n in enumerate(ndimage.sum(holes, hl, range(1, hk + 1)), 1) if n < 600]
            fg |= np.isin(hl, small)
        for name, ((t, l, b, r), m) in zip(names, pieces(fg, len(names))):
            out = rgba.copy()
            out[..., 3] = np.where(fg & m, 255, 0)
            out[out[..., 3] == 0, :3] = 0
            Image.fromarray(out[t:b, l:r]).save(os.path.join(OUT, name + ".png"))
            print(name, (r - l, b - t))




def silver(src, dst):
    """Expert's sixteenths have no picture of their own: the blue note in silver."""
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
    lum = (a[..., :3] @ np.array([0.3, 0.55, 0.15], np.float32)) / 255.0
    lum = np.clip((lum - 0.05) * 1.6, 0, 1) ** 0.8
    dark, light = np.array([70, 76, 96], np.float32), np.array([250, 252, 255], np.float32)
    out = a.copy()
    out[..., :3] = dark + (light - dark) * lum[..., None]
    Image.fromarray(out.astype(np.uint8)).save(dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
    silver(os.path.join(OUT, "note_step.png"), os.path.join(OUT, "note_six.png"))
