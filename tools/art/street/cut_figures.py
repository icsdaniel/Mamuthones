"""Cuts the Mamuthone and the Issohadore out of Daniele's turnaround pictures (front views) as sprites
with a soft alpha edge, and copies the empty street picture in as the play screen's background.

    python3 tools/art/street/cut_figures.py <folder with the reference pictures>

Background removal: pixels close to the picture's own backdrop colour that connect to the picture's
border become transparent; the edge is feathered by a pixel. Writes game/art/street/*.png.
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage
import cv2

SRC = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "/mnt/project-files/mockups/lowpoly"
OUT = os.path.join(os.path.dirname(__file__), "../../../game/art/street")

# name: (source, crop box l, t, r, b, tolerance)
CUTS = {
    "mamuthone": ("mamuthone_turnaround.png", (20, 70, 540, 985), 16),
    "issohadore": ("issohadore_turnaround.png", (80, 20, 490, 1000), 20),
}


def cut(src, box, tol):
    return cut_array(np.asarray(Image.open(os.path.join(SRC, src)).convert("RGB").crop(box)).astype(float), tol)


def cut_array(a, tol, clear_holes=False):
    # the backdrop's colour, smoothly varying: a heavy blur of the border rows and columns
    border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    near = d < tol
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    back = np.isin(lab, list(edge))
    fg = ~back
    # refine with a graph cut: the colour test alone loses dark boots against a dark backdrop
    gm = np.full(near.shape, cv2.GC_PR_BGD, np.uint8)
    gm[fg] = cv2.GC_PR_FGD
    gm[d > tol * 3] = cv2.GC_FGD
    gm[:6] = gm[-6:] = cv2.GC_BGD
    gm[:, :6] = gm[:, -6:] = cv2.GC_BGD
    # the legs run down the middle to the feet: likely figure, never certain
    h, w = near.shape
    legs = np.zeros_like(near)
    legs[int(h * 0.72):h - 8, int(w * 0.18):int(w * 0.82)] = True
    gm[legs & (gm == cv2.GC_PR_BGD) & (d > tol * 0.45)] = cv2.GC_PR_FGD
    bgm = np.zeros((1, 65), np.float64)
    fgm = np.zeros((1, 65), np.float64)
    cv2.grabCut(a.astype(np.uint8)[:, :, ::-1].copy(), gm, None, bgm, fgm, 6, cv2.GC_INIT_WITH_MASK)
    fg = (gm == cv2.GC_FGD) | (gm == cv2.GC_PR_FGD)
    fg = ndimage.binary_opening(fg, iterations=1)
    # keep the biggest piece (the figure)
    lab2, n2 = ndimage.label(fg)
    if n2 > 1:
        sizes = ndimage.sum(fg, lab2, range(1, n2 + 1))
        fg = lab2 == (1 + int(np.argmax(sizes)))
    fg = ndimage.binary_fill_holes(fg)
    if clear_holes:
        # backdrop seen through a loop (the Issohadore's rope): clear patches of backdrop colour
        # inside the figure, bigger than a few pixels
        lab3, n3 = ndimage.label(fg & near)
        if n3:
            sizes = ndimage.sum(np.ones_like(near), lab3, range(1, n3 + 1))
            fg &= ~np.isin(lab3, 1 + np.where(sizes > 40)[0])
    alpha = ndimage.gaussian_filter(fg.astype(float), 0.8)
    alpha = np.clip((alpha - 0.15) / 0.7, 0, 1)
    ys, xs = np.where(alpha > 0.02)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([a, alpha * 255]).astype(np.uint8)[t:b, l:r]
    return Image.fromarray(rgba, "RGBA")


def feet_x(img):
    al = np.asarray(img)[..., 3] > 128
    ys, xs = np.where(al)
    low = ys > ys.max() - (ys.max() - ys.min()) * 0.08
    return float(np.mean(xs[low]))


# The figures' bob (Daniele, 2026-09-30). A sheet is three poses of one figure side by side, one
# camera, feet in the same spot, on a plain backdrop, in the order standing, the drop on the beat,
# halfway back up. To replace a figure's pictures, save a new sheet over <figure>_bob_sheet.png in
# the reference folder and run this script with --bob: it finds the three poses by itself, cuts
# them out, lines their feet up on one canvas and writes game/art/street/<figure>_bob_0/1/2.png
# (0 rest, 1 drop, 2 halfway). The game's timing is in StreetBackdrop and doesn't change.
#
# REST picks which of the sheet's poses the figure stands in between beats. The Issohadore's sheet
# holds the rope overhead in its standing pose, so the rope jumped up every beat; Daniele chose to
# keep him resting with it at his hip (the halfway pose). Set it back to 0 for a sheet whose
# standing pose sits close to the other two.
BOBS = {
    "mamuthone": {"tol": 18, "rest": 0},
    "issohadore": {"tol": 18, "rest": 2, "clear_holes": True},
}


def split3(sheet, tol=30):
    """The columns that split a sheet into its three poses: the middle of the widest runs of
    empty backdrop, or, where two poses touch, the emptiest column near a third of the width."""
    bg = np.median(np.concatenate([sheet[:5].reshape(-1, 3), sheet[-5:].reshape(-1, 3)]), axis=0)
    ink = (np.sqrt(((sheet - bg) ** 2).sum(-1)) > tol).sum(0)
    w = len(ink)
    cuts = []
    for k in (1, 2):
        lo, hi = int(w * (k / 3 - 0.1)), int(w * (k / 3 + 0.1))
        low = ink[lo:hi].min()
        xs = np.where(ink[lo:hi] == low)[0] + lo
        # the middle of the longest run at that minimum
        runs = np.split(xs, np.where(np.diff(xs) > 1)[0] + 1)
        run = max(runs, key=len)
        cuts.append(int(run[len(run) // 2]))
    return [0] + cuts + [w]


def bob(name):
    cfg = BOBS[name]
    sheet = np.asarray(Image.open(os.path.join(SRC, name + "_bob_sheet.png")).convert("RGB")).astype(float)
    cuts = split3(sheet)
    poses = [cut_array(sheet[:, cuts[i]:cuts[i + 1]], cfg["tol"], cfg.get("clear_holes", False)) for i in range(3)]
    fx = [feet_x(p) for p in poses]
    half = int(max(max(f, p.size[0] - f) for f, p in zip(fx, poses))) + 2
    h = max(p.size[1] for p in poses)
    order = [cfg["rest"], 1, 2]
    for i, k in enumerate(order):
        p = poses[k]
        canvas = Image.new("RGBA", (half * 2, h), (0, 0, 0, 0))
        canvas.paste(p, (int(round(half - fx[k])), h - p.size[1]))
        canvas.save(os.path.join(OUT, "%s_bob_%d.png" % (name, i)))
        print(name, "bob", i, "from sheet pose", k, "split at", cuts[1:3], canvas.size)


os.makedirs(OUT, exist_ok=True)
for name in BOBS:
    if os.path.exists(os.path.join(SRC, name + "_bob_sheet.png")):
        bob(name)
if "--bob" in sys.argv:
    sys.exit()
for name, (src, box, tol) in CUTS.items():
    img = cut(src, box, tol)
    img.save(os.path.join(OUT, name + ".png"))
    print(name, img.size)
Image.open(os.path.join(SRC, "street_tall_v3.png")).convert("RGB").save(os.path.join(OUT, "street.png"))
print("street copied")
