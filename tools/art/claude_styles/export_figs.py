"""The Woodcut procession for the Godot game, as the review page draws it (round 38): every
Mamuthone at every height it reaches as the files walk toward the fire, at each moment of the heavy
step (crouch, a short lift while stepping, a hard landing on the beat), with the cream keyline.
The game places them each frame (StreetBackdrop), so the files walk and bob as designed.

  figs_N.png        atlas pages, S px per art px
  figs.json         {"S", "seeds", "poses": [t, ...], "heights": [lo, hi], "sil_h", "rows": {...},
                     "sprites": {"seed_h_pose": [page, x, y, w, h, ax, ay]}}  (ax, ay: the art px
                     point of the sprite at the figure's (x, y) foot point, in sprite px)
"""
import os, sys, json
import numpy as np
from PIL import Image
import figure
import smooth as sm
from scene import Scene

CFG = sm.R38
S = 2                                   # sprite px per art px: half-px steps in the bob
SEEDS = [0, 10, 20]                     # three Mamuthones, a little different each
# pose times, s since the beat (120 bpm): fine through the landing, coarser after
POSES = [i / 48 for i in range(10)] + [0.21 + i * (0.29 / 9) for i in range(9)]
PAGE = 2048


def heights():
    R = CFG['rows']
    lo = int(round(R['scale'] / R['zmax'])) - 1
    hi = int(round(R['scale'] * R['ratio'] / R['z0'])) + 1
    return lo, hi


def sprite(seed, h, tsec):
    bulk = 0.94 + 0.1 * ((seed * 37) % 10) / 10
    amp = 0.9 + 0.2 * ((seed * 53) % 10) / 10
    opts = dict(CFG.get('fig_opts') or {}, seed=seed, bulk=bulk)
    key = ('fig', h, seed)
    if key not in sm._sprites:
        f, parts = figure.build(CFG['style'], h, opts)
        sm._sprites[key] = (f, figure.render_parts(f, parts, CFG['style']))
    f, rp = sm._sprites[key]
    layer = np.zeros((f.CH * S + 4 * S, f.W * S + 2 * S, 4), np.uint8)
    for part in figure.PART_ORDER:
        dx, dy = sm.heavy_offsets(part, tsec, amp)
        # drawn for the right-hand file (bells swing out to the left, toward the road); the left
        # file is this mirrored
        sm.paste(layer, sm.up(rp[part], S), S - dx * h * S, dy * h * S)
    a = layer[..., 3] > 0
    if CFG['rows']['scale'] / h >= CFG['rows']['sil_z']:
        layer[a] = sm.C(sm.INK)                     # far files as flat black shapes
    nb = np.zeros_like(a)
    for k in range(1, S + 1):
        nb[k:] |= a[:-k]; nb[:-k] |= a[k:]; nb[:, k:] |= a[:, :-k]; nb[:, :-k] |= a[:, k:]
    layer[nb & ~a] = sm.C(CFG.get('keyline') or sm.CREAM)
    # anchor: the figure's (x, y) lands at sprite px ((f.W / 2) * S + S, f.CH * S)
    return layer, f.W / 2 * S + S, f.CH * S


def main(out):
    os.makedirs(out, exist_ok=True)
    lo, hi = heights()
    items = []
    for seed in SEEDS:
        for h in range(lo, hi + 1):
            for pi, t in enumerate(POSES):
                img, ax, ay = sprite(seed, h, t)
                al = img[..., 3] > 0
                ys, xs = np.nonzero(al)
                if len(xs) == 0:
                    continue
                x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
                items.append(('%d_%d_%d' % (seed, h, pi), img[y0:y1, x0:x1], ax - x0, ay - y0))
    # shelf packing, tallest first
    items.sort(key=lambda it: -it[1].shape[0])
    pages, sprites = [], {}
    page = np.zeros((PAGE, PAGE, 4), np.uint8); x = y = shelf = 0
    for key, img, ax, ay in items:
        hh, ww = img.shape[:2]
        if x + ww + 1 > PAGE:
            x, y, shelf = 0, y + shelf + 1, 0
        if y + hh + 1 > PAGE:
            pages.append(page); page = np.zeros((PAGE, PAGE, 4), np.uint8); x = y = shelf = 0
        page[y:y + hh, x:x + ww] = img
        sprites[key] = [len(pages), int(x), int(y), int(ww), int(hh), float(ax), float(ay)]
        x += ww + 1; shelf = max(shelf, hh)
    pages.append(page)
    for i, p in enumerate(pages):
        used = np.nonzero(p[..., 3].any(1))[0]
        p = p[:max(used.max() + 1, 1)] if len(used) else p[:1]
        Image.fromarray(p, 'RGBA').save(os.path.join(out, 'figs_%d.png' % i))
    R = dict(CFG['rows'])
    s = Scene(CFG)
    meta = dict(S=S, seeds=SEEDS, poses=POSES, heights=[lo, hi], rows=R,
                scene=dict(vpx=s.vpx, vpy=s.vpy, hity=s.hity, hw0=s.hw0, hw1=s.hw1, W=s.W),
                timing=dict(T_OFF=sm.T_OFF, T_BEAT=sm.T_BEAT), sprites=sprites)
    with open(os.path.join(out, 'figs.json'), 'w') as fh:
        json.dump(meta, fh)
    print(len(sprites), 'sprites on', len(pages), 'pages')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'out_game')
