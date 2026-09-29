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
    im = Image.open(os.path.join(SRC, src)).convert("RGB").crop(box)
    a = np.asarray(im).astype(float)
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


os.makedirs(OUT, exist_ok=True)
for name, (src, box, tol) in CUTS.items():
    img = cut(src, box, tol)
    img.save(os.path.join(OUT, name + ".png"))
    print(name, img.size)
Image.open(os.path.join(SRC, "street_tall_v2.png")).convert("RGB").save(os.path.join(OUT, "street.png"))
print("street copied")
