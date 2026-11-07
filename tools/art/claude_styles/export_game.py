"""Export the Woodcut look (smooth.R38, the play screen Daniele approved) as pictures for the
Godot game: the still street, the files of Mamuthones bobbing, and the bonfire at each unison level.

    python3 export_game.py <game>/art/woodcut

Writes:
  street.png          135x300, the street with its houses, floor, road and lane lines (no fire,
                      figures, notes, HUD or buttons). The game lays its lanes on these lines:
                      geometry.json gives them.
  files_NN.png        540x1200 (4x), the two files of Mamuthones beside the road, NN = frame of
                      the bob (FILE_FPS frames a second after the beat; the last is at rest).
  fire_L.png          a strip of FIRE_FRAMES frames of the bonfire at unison level L (1-4), each
                      frame fire_box wide, in 135x300 px, one frame per 1/FIRE_FPS s after the beat.
  geometry.json       the street's lines and where the fire and frames sit, in 135x300 px.
"""
import json, math, os, sys
import numpy as np
from PIL import Image

import scene, figure, fires
import smooth as sm
from scene import Scene

CFG = sm.R38
S = 4                       # the files are drawn 4x so the bob moves in fine steps
FILE_FPS = 60
FILE_FRAMES = 16            # 0 .. 0.25 s after the beat; the last frame is the rest pose
FIRE_FPS = 30
FIRE_FRAMES = 15            # 0 .. 0.5 s after the beat (a beat at 120 bpm); held at the last


class FullRoad(Scene):
    """The scene's geometry with the road running to the bottom (the game draws its own buttons)."""
    def __init__(self, cfg):
        super().__init__(cfg)
        self.btn_top = self.H


def street():
    cfg = dict(CFG, figures=[], notes_fn=lambda s, p: None, rings_fn=lambda s: None,
               buttons_fn=lambda s: None, hud_fn=lambda s: None, fire=False, extra_fn=None,
               combo_text='', combo_word=False, no_mult=True, grain=CFG.get('grain'))
    orig = scene.Scene
    scene.Scene = FullRoad
    try:
        img = scene.draw(cfg, 0, 1, 0.0, 0)
    finally:
        scene.Scene = orig
    return img


def files(tsec):
    s = Scene(CFG)
    W, H = s.W, s.H
    out = np.zeros((H * S, W * S, 4), np.uint8)
    figs = sm.procession_walk(s, CFG, 0.0)
    for fg in figs:
        fh = fg['h']
        opts = dict(CFG.get('fig_opts') or {}, seed=fg['seed'], bulk=fg['bulk'])
        key = ('fig', fh, fg['seed'])
        if key not in sm._sprites:
            f, parts = figure.build(CFG['style'], fh, opts)
            sm._sprites[key] = (f, figure.render_parts(f, parts, CFG['style']))
        f, rp = sm._sprites[key]
        layer = np.zeros((f.CH * S + 4 * S, f.W * S + 2 * S, 4), np.uint8)
        toward = -fg['side']
        for part in figure.PART_ORDER:
            dx, dy = sm.heavy_offsets(part, tsec, fg['amp'])
            sm.paste(layer, sm.up(rp[part], S), S + dx * fh * S * (toward if not fg['flip'] else -toward), dy * fh * S)
        if fg['flip']:
            layer = layer[:, ::-1]
        a = layer[..., 3] > 0
        sil = CFG['rows'].get('sil_z')
        if sil and fg.get('z', 0) >= sil:
            layer[a] = sm.C(sm.INK)
        nb = np.zeros_like(a)
        for k in range(1, S + 1):
            nb[k:] |= a[:-k]; nb[:-k] |= a[k:]; nb[:, k:] |= a[:, :-k]; nb[:, :-k] |= a[:, k:]
        layer[nb & ~a] = sm.C(CFG.get('keyline') or sm.CREAM)
        sm.paste(out, layer, (fg['x'] - f.W / 2) * S - S, (fg['y'] - f.CH) * S)
        sm.ring_marks(out, fg, tsec, S)
    return out


def fire(lv, tsec):
    s = Scene(CFG)
    fires.pile(s, lv, tsec, None, tsec, None, beat_no=0)
    return s.img


def main(out):
    os.makedirs(out, exist_ok=True)
    s = Scene(CFG)
    W, H = s.W, s.H
    Image.fromarray(street(), 'RGBA').save(os.path.join(out, 'street.png'))
    # the files of Mamuthones: every figure at every height and moment of the step, placed by the
    # game each frame so they walk toward the fire as on the review page (export_figs.py)
    import export_figs
    export_figs.main(out)
    # one box holds the fire at every level and frame
    frames = {lv: [fire(lv, i / FIRE_FPS) for i in range(FIRE_FRAMES)] for lv in (1, 2, 3, 4)}
    al = np.zeros((H, W), bool)
    for fs in frames.values():
        for f in fs:
            al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    for lv, fs in frames.items():
        strip = np.concatenate([f[y0:y1, x0:x1] for f in fs], axis=1)
        Image.fromarray(strip, 'RGBA').save(os.path.join(out, 'fire_%d.png' % lv))
    hw = lambda y: s.halfw(y)
    # the lines x = a + b * y (135x300 px), left edge, the two dividers, right edge
    b = (s.hw1 - s.hw0) / (s.hity - s.vpy)
    a0 = s.hw0 - b * s.vpy                # halfw = a0 + b * y
    rails = [[s.vpx - a0, -b], [s.vpx - a0 / 3, -b / 3], [s.vpx + a0 / 3, b / 3], [s.vpx + a0, b]]
    geo = dict(size=[W, H], files_scale=S, rails=rails, vanish_y=s.vpy - s.hw0 / b, far_y=s.vpy,
               fire_box=[int(x0), int(y0), int(x1 - x0), int(y1 - y0)], fire_frames=FIRE_FRAMES,
               fire_fps=FIRE_FPS, file_frames=FILE_FRAMES, file_fps=FILE_FPS,
               fire_base=[s.vpx, s.vpy + H * 0.012], hit_y=s.hity)
    with open(os.path.join(out, 'geometry.json'), 'w') as fh:
        json.dump(geo, fh, indent=1)
    print(json.dumps(geo))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'out_game')
