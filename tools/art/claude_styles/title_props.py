"""Main screen proposals (Night style), built from the agreed contents:
Continue (names the stop) > Story, Songs > Settings gear; small Learn and Ranks; the logo and the
procession bobbing to the beat as atmosphere. No progress, no quit, no shop.

T1 Procession - the street as a picture band between logo and buttons.
T2 On the road - the play view itself; the three step buttons are Story, Continue, Songs.
T3 The Mamuthone - one big Mamuthone bobbing, bells ringing, buttons under him.
"""
import math, os, sys, subprocess
import numpy as np
from PIL import Image
import smooth, figure
from menus import Cv, tw, W, H, S, INK, CREAM, RED, TAN, BROWN, BELL, GEAR, PLAY, TROPHY, stars
from menus_night import note, dots, vdots, main_button, DIM

_orig_notes = smooth.visible_notes
STREET = dict(smooth.R38, health_demo=None, juice=False, misses=(),
              hud_fn=lambda s: None, buttons_fn=lambda s: None)


def street(t, rings=False):
    smooth.visible_notes = lambda t_: []
    try:
        cfg = dict(STREET) if rings else dict(STREET, rings_fn=lambda s: None)
        if not rings:
            import lino
            orig = lino.rings
            lino.rings = lambda s: None
        f = smooth.frame(cfg, t, 1)
    finally:
        smooth.visible_notes = _orig_notes
        if not rings:
            lino.rings = orig
    return f


def fade(c, y0, y1, down=True):
    for y in range(y0, y1):
        k = (y - y0) / (y1 - y0)
        k = k if down else 1 - k
        m = np.random.default_rng(y).random(W) > k
        c.a[y, m] = (20, 16, 20, 255)


def logo(c, y, sc=2):
    c.icon(BELL, 38, y, CREAM, 3); c.icon(['...#...'], 38, y + 21, RED, 3)
    c.icon(BELL, 76, y + 4, CREAM, 3); c.icon(['...#...'], 76, y + 25, RED, 3)
    for k, x in ((-1, 32), (1, 102)):
        for j in range(2):
            c.rect(x + k * j * 4, y + 6 + j * 3, 2, 8 - j * 2, RED)
    c.ctext('SONAZZOS', W / 2, y + 36, CREAM, sc)


def corners(c, y=281):
    c.icon(TROPHY, 9, y, TAN); c.text('RANKS', 17, y, TAN)
    c.icon(GEAR, W - 15, y - 1, TAN)


def t1(t):
    c = Cv(INK); stars(c)
    try:
        c.paste(street(t)[56:190], 0, 74)
    except Exception as e:
        print(e)
    fade(c, 74, 92)
    fade(c, 176, 196, down=False)
    c.rect(0, 196, W, 104, INK); stars(c, 7); c.rect(0, 0, W, 74, INK); stars(c, 3)
    logo(c, 12)
    main_button(c, 'CONTINUE', 205, 128, 'STOP 4 - CARNIVAL')
    c.ctext('STORY', 36, 244, CREAM); c.ctext('SONGS', W - 36, 244, CREAM)
    vdots(c, W // 2, 240, 254, BROWN)
    c.ctext('LEARN TO PLAY', W / 2, 262, DIM)
    dots(c, 8, W - 8, 274, BROWN)
    corners(c)
    return c


def t2(t):
    c = Cv(INK)
    try:
        f = street(t, rings=True)
        c.paste(f[:258], 0, 0)
    except Exception as e:
        print(e)
    c.rect(0, 0, W, 66, INK); stars(c, 3)
    fade(c, 66, 80)
    logo(c, 16)
    c.icon(TROPHY, 6, 6, TAN); c.text('RANKS', 14, 6, TAN); c.icon(GEAR, W - 13, 5, TAN)
    c.ctext('LEARN', W - 18, 50, DIM) if False else None
    # the stop the middle step leads to, floating over the road like the combo
    c.rect(18, 196, W - 36, 11, INK)
    c.ctext('STOP 4 - CARNIVAL', W / 2, 198, CREAM)
    # three step buttons, like the play screen's, with words in place of feet
    by = 262
    labels = [('STORY', False), ('PLAY', True), ('SONGS', False)]
    bw = (W - 8) // 3
    c.rect(0, by - 6, W, H - by + 6, INK)
    for i, (lab, main) in enumerate(labels):
        x = 2 + i * (bw + 2)
        c.rect(x, by, bw, 30, RED if main else CREAM)
        for k in range(x + 1, x + bw - 1, 3):          # carved zigzag rim like the game buttons
            c.put(k, by + 1, INK if not main else CREAM)
            c.put(k + 1, by + 28, INK if not main else CREAM)
        if main:
            c.icon(PLAY, x + bw / 2 - 14, by + 12, CREAM)
            c.text(lab, x + bw / 2 - 7, by + 12, CREAM)
        else:
            c.ctext(lab, x + bw / 2, by + 12, INK)
    c.ctext('LEARN TO PLAY', W / 2, H - 6, DIM) if False else None
    c.rect(0, 293, W, 7, INK)
    c.text('LEARN', W - 46, 6, TAN)
    return c


_fig = {}


def big_figure(tsec, Hf=118):
    if Hf not in _fig:
        cfg = smooth.R5
        f, parts = figure.build(cfg['style'], Hf, dict(cfg['fig_opts'], seed=0))
        _fig[Hf] = (f, figure.render_parts(f, parts, cfg['style']))
    f, rp = _fig[Hf]
    lay = np.zeros((f.CH + 16, f.W + 16, 4), np.uint8)
    for part in figure.PART_ORDER:
        dx, dy = smooth.heavy_offsets(part, tsec)
        smooth.paste(lay, rp[part], 8 + dx * Hf, 8 + dy * Hf)
    a = lay[..., 3] > 0
    nb = np.zeros_like(a)
    nb[1:] |= a[:-1]; nb[:-1] |= a[1:]; nb[:, 1:] |= a[:, :-1]; nb[:, :-1] |= a[:, 1:]
    lay[nb & ~a] = (239, 230, 210, 255)
    return lay


def t3(t):
    c = Cv(INK); stars(c)
    tsec = (t % 1.0) * 0.5
    # fire glow behind him, pulsing on the beat
    p = smooth.rift(tsec) if hasattr(smooth, 'rift') else 0
    cy = 150
    for r_, col in ((50 + 3 * p, '#2a1416'), (38 + 3 * p, '#3a1618')):
        c.oval(W / 2, cy + 40, r_, r_ * 0.9, col)
    # the street floor
    c.rect(0, 196, W, 4, BROWN)
    for x in range(0, W, 3):
        c.put(x, 201, BROWN)
    fig = big_figure(tsec)
    h, w_ = fig.shape[:2]
    x0, y0 = int(W / 2 - w_ / 2), 198 - h + 6
    sub = c.a[y0:y0 + h, x0:x0 + w_]
    m = fig[..., 3] > 0
    sub[m] = fig[m]
    logo(c, 10)
    main_button(c, 'CONTINUE', 211, 128, 'STOP 4 - CARNIVAL')
    c.ctext('STORY', 36, 248, CREAM); c.ctext('SONGS', W - 36, 248, CREAM)
    vdots(c, W // 2, 244, 258, BROWN)
    c.ctext('LEARN TO PLAY', W / 2, 265, DIM)
    dots(c, 8, W - 8, 275, BROWN)
    corners(c, 283)
    return c


def render(out, beats=4, fps=30):
    os.makedirs(out, exist_ok=True)
    for name, fn in (('t1', t1), ('t2', t2), ('t3', t3)):
        tmp = f'{out}/.{name}'
        os.makedirs(tmp, exist_ok=True)
        n = int(beats * 0.5 * fps)
        for i in range(n):
            t = i / n * beats
            c = fn(t)
            im = Image.fromarray(c.a[..., :3]).resize((W * S, H * S), Image.NEAREST)
            im.save(f'{tmp}/{i:04d}.png')
            if abs(t - 0.1) < 0.5 / fps * 2 and not os.path.exists(f'{out}/title_{name}.png'):
                im.save(f'{out}/title_{name}.png')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', f'{tmp}/%04d.png',
                        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', f'{out}/title_{name}.mp4'], check=True)
        for f_ in os.listdir(tmp):
            os.remove(os.path.join(tmp, f_))
        os.rmdir(tmp)


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[2] == 'still':
        os.makedirs(sys.argv[1], exist_ok=True)
        for name, fn in (('t1', t1), ('t2', t2), ('t3', t3)):
            Image.fromarray(fn(0.1).a[..., :3]).resize((W * S, H * S), Image.NEAREST).save(f'{sys.argv[1]}/title_{name}.png')
    else:
        render(sys.argv[1])
