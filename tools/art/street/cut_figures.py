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

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/mockups/lowpoly"
OUT = os.path.join(os.path.dirname(__file__), "../../../game/art/street")

# name: (source, crop box l, t, r, b, tolerance)
CUTS = {
    "mamuthone": ("mamuthone_turnaround.png", (20, 70, 540, 985), 16),
    "issohadore": ("issohadore_turnaround.png", (80, 20, 490, 1000), 20),
}


def cut(src, box, tol):
    return cut_array(np.asarray(Image.open(os.path.join(SRC, src)).convert("RGB").crop(box)).astype(float), tol)


def cut_array(a, tol):
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
    alpha = ndimage.gaussian_filter(fg.astype(float), 0.8)
    alpha = np.clip((alpha - 0.15) / 0.7, 0, 1)
    ys, xs = np.where(alpha > 0.02)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([a, alpha * 255]).astype(np.uint8)[t:b, l:r]
    return Image.fromarray(rgba, "RGBA")


# The Mamuthone's dance: four moments of one stamp onto his left leg, side by side on one sheet
# (anticipation, impact, follow-through, settle). Split at the gaps between the figures, cut each
# out, and put all four on one canvas with the feet at the same place (bottom centre), so the
# game can swap between them without the figure sliding.
DANCE = ("mamuthone_dance_sheet_v2.png", [0, 408, 826, 1258, None], 18)


def feet_x(img):
    al = np.asarray(img)[..., 3] > 128
    ys, xs = np.where(al)
    low = ys > ys.max() - (ys.max() - ys.min()) * 0.08
    return float(np.mean(xs[low]))


def dance():
    src, cuts, tol = DANCE
    sheet = np.asarray(Image.open(os.path.join(SRC, src)).convert("RGB")).astype(float)
    cuts = [c if c is not None else sheet.shape[1] for c in cuts]
    poses = [cut_array(sheet[:, cuts[i]:cuts[i + 1]], tol) for i in range(4)]
    fx = [feet_x(p) for p in poses]
    half = int(max(max(f, p.size[0] - f) for f, p in zip(fx, poses))) + 2
    h = max(p.size[1] for p in poses)
    for i, p in enumerate(poses):
        canvas = Image.new("RGBA", (half * 2, h), (0, 0, 0, 0))
        canvas.paste(p, (int(round(half - fx[i])), h - p.size[1]))
        canvas.save(os.path.join(OUT, "mamuthone_dance_%d.png" % i))
        print("dance", i, canvas.size)


os.makedirs(OUT, exist_ok=True)
dance()
for name, (src, box, tol) in CUTS.items():
    img = cut(src, box, tol)
    img.save(os.path.join(OUT, name + ".png"))
    print(name, img.size)
Image.open(os.path.join(SRC, "street_tall_v2.png")).convert("RGB").save(os.path.join(OUT, "street.png"))
print("street copied")
