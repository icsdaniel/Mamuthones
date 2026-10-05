"""The pixel look's palette and its lookup table.

    python3 tools/art/pixel3d/palette.py

The palette is drawn from Daniele's own pictures (the street and both figures, k-means in Lab), plus
the few colours the game itself needs to read (the notes' glazes, the bell straps, cream, ink). It is
written as game/art/pixel/palette.png (one row, darkest to lightest) and as the lookup PixelFilter
uses, game/art/pixel/palette_lut.png: 32 slices of 32 x 32 side by side (blue picks the slice, red
across, green down), each entry the palette colour nearest in Lab.
"""
import os
import numpy as np
from PIL import Image
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "../../../game")
ART = os.path.join(GAME, "art/street")
OUT = os.path.join(GAME, "art/pixel")
K = 30

# the colours the play screen needs whatever the pictures hold (notes, straps, ink, hud)
FIXED = [
    "#07060a", "#1a1420", "#fff6e0", "#f6ead0",                       # ink, deep shade, glint, cream
    "#9ccaff", "#2f78e0", "#163a94", "#5aa8ff",                       # step blue
    "#a8ffc8", "#26b862", "#0e6632",                                  # heal green
    "#ffe9a8", "#e8a820", "#7e5006",                                  # hold gold
    "#ff9c8c", "#e06a5c", "#d84848", "#c8282a", "#8e1a1e", "#5e0c10",  # bell up red
    "#a4b6ff", "#6c80e8", "#4e64d4", "#3450c0", "#24348a", "#141e5e",  # bell down indigo
    "#f2c46a", "#b0701e", "#4e2a0a",                                  # bronze
    "#ff9a32", "#ffd27a", "#ffd35a", "#7a2e06",                       # hud edge, gold ink
    "#8a2fd0", "#d070ff",                                             # top unison purple
    "#ff3b30", "#ffffff",
]


def lab(rgb):
    a = np.asarray(rgb, np.uint8).reshape(-1, 1, 3)
    return cv2.cvtColor(a, cv2.COLOR_RGB2LAB).reshape(-1, 3).astype(np.float32)


def samples():
    px = []
    st = np.asarray(Image.open(os.path.join(ART, "street.png")).convert("RGB")).reshape(-1, 3)
    px.append(st[::7])
    for name in ["mamuthone_bob_0", "issohadore_bob_0"]:
        a = np.asarray(Image.open(os.path.join(ART, name + ".png")).convert("RGBA")).reshape(-1, 4)
        a = a[a[:, 3] > 200][:, :3]
        px.append(a[::3])
    return np.concatenate(px)


def main():
    os.makedirs(OUT, exist_ok=True)
    s = samples()
    L = lab(s)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 60, 0.5)
    cv2.setRNGSeed(7)
    _, _, centers = cv2.kmeans(L, K, None, crit, 4, cv2.KMEANS_PP_CENTERS)
    rgb = cv2.cvtColor(np.clip(centers, 0, 255).astype(np.uint8).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)
    fixed = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in FIXED], np.uint8)
    pal = np.concatenate([rgb, fixed])
    # drop near duplicates
    keep = []
    pl = lab(pal)
    for i in range(len(pal)):
        if all(np.linalg.norm(pl[i] - pl[j]) > 6.0 for j in keep):
            keep.append(i)
    pal = pal[keep]
    order = np.argsort(lab(pal)[:, 0])
    pal = pal[order]
    Image.fromarray(pal.reshape(1, -1, 3)).save(os.path.join(OUT, "palette.png"))
    # the lookup
    q = (np.arange(32) * 255.0 / 31.0 + 0.5).astype(np.uint8)
    r, g, b = np.meshgrid(q, q, q, indexing="ij")
    cube = np.stack([r, g, b], -1).reshape(-1, 3)
    cl = lab(cube)
    pl = lab(pal)
    idx = np.argmin(((cl[:, None, :] - pl[None, :, :]) ** 2).sum(-1), axis=1)
    out = pal[idx].reshape(32, 32, 32, 3)  # r, g, b
    img = np.zeros((32, 1024, 3), np.uint8)
    for bi in range(32):
        img[:, bi * 32:(bi + 1) * 32] = out[:, :, bi].transpose(1, 0, 2)  # rows = g, cols = r
    Image.fromarray(img).save(os.path.join(OUT, "palette_lut.png"))
    print(len(pal), "colours")


if __name__ == "__main__":
    main()
