"""The Mamuthone and the Issohadore redrawn as pixel art (repaint.py) instead of shrunk from Daniele's
pictures, cut into the same parts as bake_figures.py so PixelFigure bobs them exactly as before:

    python3 tools/art/pixel3d/redraw_figures.py

Writes game/art/pixel/<figure>_<part>.png (same sizes and canvas as bake_figures.py).
"""
import os
import numpy as np
from PIL import Image
import bake_figures as bf
import pixelate as px
import repaint as rp

ALL = lambda name: [(name, lambda h, s, v: np.ones_like(h, bool))]

LEATHER = ("leather", lambda h, s, v: (h >= 6) & (h <= 20) & (s > 165) & (v > 95))
MAMUTHONE = {
    "body": [LEATHER, ("fleece", lambda h, s, v: np.ones_like(h, bool))],
    "legs": [("fleece", lambda h, s, v: np.ones_like(h, bool))],
    "head": [("wood", lambda h, s, v: (v < 58)), ("fleece", lambda h, s, v: np.ones_like(h, bool))],
    "back_bells": ALL("brass"),
    "front_bells": ALL("brass"),
}
ISSO_BODY = [
    ("red", lambda h, s, v: ((h < 8) | (h > 168)) & (s > 140) & (v > 90)),
    ("linen", lambda h, s, v: (s < 80) & (v > 160)),
    ("skin", lambda h, s, v: (h >= 4) & (h <= 18) & (s >= 55) & (s <= 150) & (v > 135)),
    ("brass", lambda h, s, v: (h >= 10) & (h <= 30) & (s > 130) & (v > 110)),
    ("cloth", lambda h, s, v: np.ones_like(h, bool)),
]
ISSOHADORE = {"body": ISSO_BODY, "legs": ISSO_BODY, "head": ISSO_BODY, "rope": ALL("brass")}


def redraw(name, order, layers_fn, rules, rim_right, textures):
    a = np.asarray(Image.open(os.path.join(bf.SRC, name + "_bob_0.png")).convert("RGBA")).copy()
    a[..., 3] = np.where(a[..., 3] > 100, 255, 0)
    h, w = a.shape[:2]
    size = (int(round(w * bf.H / h)), bf.H)
    soft = a.copy()
    soft[..., :3] = px.smooth(a[..., :3], 9, 30, 7)
    layers = layers_fn(soft, None)
    # one set of cut points per material over the whole figure, so the parts match
    mats, lits = [], []
    for p in order:
        L = layers[p]
        mf = rp.classify(L[..., :3], L[..., 3], rules[p])
        mats.append(rp.majority(mf, L[..., 3], size))
        lits.append(rp.light(L[..., :3], L[..., 3], size, 0.35))
    cuts = rp.thresholds(np.concatenate(mats), np.concatenate(lits))
    union = np.zeros((bf.H, size[0]), bool)
    out = {}
    for p in order:
        tex = textures.get(p)
        rgba, mat, _ = rp.repaint_layer(layers[p], size, rules[p], cuts, tex, rim_right)
        out[p] = (rgba, mat)
        union |= mat >= 0
    for p in order:
        rgba, mat = out[p]
        ring, _ = rp.outline(mat)
        skip = (ring & union) if p in ("body", "legs") else None
        Image.fromarray(rp.ink_outline(rgba, mat, skip)).save(os.path.join(bf.OUT, "%s_%s.png" % (name, p)))
    print(name, size)


def main():
    H = bf.H
    redraw("mamuthone", ["legs", "body", "back_bells", "front_bells", "head"], bf.mamuthone_layers, MAMUTHONE,
           rim_right=False, textures={"body": {}, "legs": {}})
    redraw("issohadore", ["legs", "body", "rope", "head"], bf.issohadore_layers, ISSOHADORE,
           rim_right=True, textures={"body": {"pleats": (int(H * 0.40), int(H * 0.61))}, "rope": {"rope": (0, H)}})


if __name__ == "__main__":
    main()
