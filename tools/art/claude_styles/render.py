import sys, numpy as np
from PIL import Image
from pxkit import to_img
import scene, styles


def bob_frame(t_in_beat_ms):
    # rest 200, then on the beat: down 90, low 80, return 130 (game timings)
    t = t_in_beat_ms
    if t < 90: return 1
    if t < 170: return 2
    if t < 300: return 3
    return 0


def still(cfg, phase=0.6, fig_frame=0):
    return cfg.get('draw', scene.draw)(cfg, 0, 1, phase, fig_frame)


def gif(cfg, path, scale, fps=20, bpm=120, beats=8):
    frames = []
    per_beat = int(round(fps * 60 / bpm))
    n = per_beat * beats
    for i in range(n):
        phase = i / per_beat
        ms = (i % per_beat) / per_beat * 60000 / bpm
        img = cfg.get('draw', scene.draw)(cfg, i, n, phase, bob_frame(ms))
        frames.append(to_img(img, scale).convert('RGB').quantize(colors=128, dither=Image.NONE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)


if __name__ == '__main__':
    cfg = getattr(styles, sys.argv[1])
    out = sys.argv[2]
    img = still(cfg, float(sys.argv[3]) if len(sys.argv) > 3 else 0.6)
    to_img(img, cfg['scale']).save(out)
    to_img(img, 1).save(out.replace('.png', '_1x.png'))
