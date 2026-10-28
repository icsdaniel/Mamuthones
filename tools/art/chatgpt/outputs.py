"""The animated pieces Daniele had ChatGPT draw frame by frame (the zip's output/ folder; the frames
used are kept in tools/art/sources/chatgpt/<set>/):

    python3 tools/art/chatgpt/outputs.py

fire-screen-style/  -> game/art/ai/fire/{loop_<n>x_<i>, up_<n>_<i>, logs}.png: the bonfire's four
                       tiers (loops 1x-4x), the three upward transitions and the stationary logs, all
                       on the one 320 px canvas (80 art px), never trimmed, so their anchor
                       (animation.json: logs baseline at its bottom middle) holds for every frame
mamuthone-bob-test/ -> game/art/ai/fig/mamuthone_bob_<i>.png and issohadore_bob_<i>.png: the four
issohadore-bob-test/   poses of the bob (0 up, 1 going down, 2 down, 3 coming back), 172 art px tall
                       like the figures they replace, feet on the canvas's bottom middle
phone-restart/      -> game/art/px/setup/phone_<i>.png (see setup.py)

Each frame: magenta fringe keyed off, stray specks dropped, put on the art grid and written 1:1 (the
game draws them one texel per cell). The fire is snapped to the style palette without the notes'
colours; the figures keep their own colours.
"""
import os
import json
import numpy as np
from scipy import ndimage
import common as c

FIRE = os.path.join(c.SRC, "fire-screen-style")
FIG = c.SRC


def clean(rgba, min_frac=0.01):
    """Keyed, and only the pieces worth keeping (specks of the old canvas edge dropped)."""
    k = c.keyed(rgba, loose=True)
    on = k[..., 3] > 0
    lab, n = ndimage.label(on)
    if n > 1:
        sizes = ndimage.sum(on, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= min_frac * sizes.max()]
        k[~np.isin(lab, keep), 3] = 0
    return k


def fire():
    pal = c.palette(reserved=False)
    out = os.path.join(c.GAME, "art/ai/fire")
    f = 4.0
    sets = [("loop_%dx" % n, "loop_%dx" % n) for n in (1, 2, 3, 4)] + \
        [("transition_%dx_to_%dx" % (n, n + 1), "up_%d" % n) for n in (1, 2, 3)]
    for d, name in sets:
        for i in range(4):
            a = c.load(os.path.join(FIRE, d, "frame_%d.png" % i))
            # sparks are single art px: keep every piece of the flame, drop nothing but magenta
            g = c.snap(c.grid(c.keyed(a, loose=True), f), pal)
            c.save(seat(g), os.path.join(out, "%s_%d.png" % (name, i)))
    g = c.snap(c.grid(clean(c.load(os.path.join(FIRE, "logs.png"))), f), pal)
    c.save(seat(g, False), os.path.join(out, "logs.png"))


TOP = 24          # art px added over the canvas: some frames are drawn too high and cut at its top
BASE = 70         # the flame's root row on the 80 px canvas (animation.json flame_root 282 / 4)


def seat(g, flame=True):
    """The frame on a canvas TOP px taller, its flame's root put back on BASE: a few of the drawn
    frames float up to 20 px over the logs (loop_1x 2, loop_2x 2, loop_3x 0/1/3, the 2x-3x rise)."""
    out = np.zeros((g.shape[0] + TOP, g.shape[1], 4), np.uint8)
    out[TOP:] = g
    if flame:
        rows = (out[..., 3] > 0).sum(1)
        body = np.nonzero(rows >= 4)[0]
        if body.size:
            d = BASE + TOP - (body.max())
            if d > 0:
                out = np.roll(out, d, 0)
                out[:d] = 0
    return out


def figures():
    out = os.path.join(c.GAME, "art/ai/fig")
    H = 172
    for fig in ("mamuthone", "issohadore"):
        frames = [clean(c.load(os.path.join(FIG, "%s-bob" % fig, "frame_%d.png" % i)), 0.05) for i in range(4)]
        # one scale for all four (the up pose's height is the figure's), feet on a shared floor
        ys = [np.nonzero(fr[..., 3] > 0)[0] for fr in frames]
        top, floor = ys[0].min(), max(y.max() for y in ys) + 1
        f = (floor - top) / float(H)
        xs = np.concatenate([np.nonzero(fr[..., 3] > 0)[1] for fr in frames])
        l, r = xs.min(), xs.max() + 1
        cx = 0.5 * (l + r)
        half = 0.5 * (r - l) + 2 * f
        l0, r0 = int(cx - half), int(cx + half)
        t0 = int(min(y.min() for y in ys) - 2 * f)
        for i, fr in enumerate(frames):
            pad = np.zeros((floor - t0, r0 - l0, 4), np.uint8)
            sl, sr = max(l0, 0), min(r0, fr.shape[1])
            pad[:, sl - l0:sr - l0] = fr[t0:floor, sl:sr]
            # their own colours, only shrunk (Daniele, 2026-10-28: snapped to the style palette they came
            # out recoloured, orange and red specks through the fleece)
            g = c.grid(pad, f)
            c.save(g, os.path.join(out, "%s_bob_%d.png" % (fig, i)))


if __name__ == "__main__":
    fire()
    figures()
