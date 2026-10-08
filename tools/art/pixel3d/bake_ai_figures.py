"""The Mamuthone and the Issohadore from Daniele's pixel-art pictures (made with an outside image AI;
the second set, 2026-10-08, cut by ai_cut.py into game/art/ai/), for PixelFigure:

    python3 tools/art/pixel3d/bake_ai_figures.py

The pictures are already pixel art on a grid of their own (about 7.5 px a cell for the Mamuthone,
5.7 for the Issohadore), so each is only taken down to the game's 172 cells tall, snapped back to
its own colours and turned to face the road (the Mamuthone stands on the right, the Issohadore on
the left). It stays one picture: PixelFigure bobs it as two slices of itself, split at its KNEE
row (picked by eye where the fleece and the trousers end over the shins, so the drop slides them
down over the legs).

Writes game/art/pixel/<figure>_whole.png.
"""
import os
import numpy as np
from PIL import Image
import pixelate as px
from bake_figures import shrink_rgba, H, OUT

K = 40
AI = os.path.join(px.GAME, "art/ai")
# where across its picture each figure stands on its spot (0 its left edge, 1 its right, before it
# is turned): these figures stride wide and reach out with rope and bells, so neither their feet
# nor their middle keeps them on screen; picked by eye on the play screen
ANCHOR = {"mamuthone": 0.35, "issohadore": 0.68}


def bake(name):
    a = np.asarray(Image.open(os.path.join(AI, name + ".png")).convert("RGBA")).copy()
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    ys, xs = np.nonzero(a[..., 3])
    top, bottom = ys.min(), ys.max() + 1
    k = H / float(bottom - top)
    cx = xs.min() + ANCHOR[name] * (xs.max() + 1 - xs.min())
    half = max(cx - xs.min(), xs.max() + 1 - cx) + 4.0 / k
    l, r = int(round(cx - half)), int(round(cx + half))
    pad = max(0, -l, r - a.shape[1])
    size = (int(round((r - l) * k)), H)
    s = shrink_rgba(np.pad(a, ((0, 0), (pad, pad), (0, 0)))[top:bottom, l + pad:r + pad], size)
    opaque = s[..., 3] > 0
    pal = px.kpalette(s[..., :3][opaque], K)
    idx = px.despeckle(px.nearest(s[..., :3], pal), opaque, pal)
    s[..., :3] = np.where(opaque[..., None], pal[idx], 0)
    # turned to face the road
    Image.fromarray(s[:, ::-1]).save(os.path.join(OUT, "%s_whole.png" % name))
    print(name, size)


if __name__ == "__main__":
    bake("mamuthone")
    bake("issohadore")
