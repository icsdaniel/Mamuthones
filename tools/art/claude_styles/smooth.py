"""Smooth motion for the lino style: the world stays pixel art, but notes, bell
bars, the rope and the Mamuthones' bob move in screen pixels, not art pixels.

Each moving thing is drawn once as a stable pixel-art sprite (its shape only
changes when its size steps up by a whole art pixel), scaled by whole numbers,
then placed at sub-art-pixel precision. Nothing is redrawn into the art grid as
it moves, so nothing crawls or shimmers.
"""
import math, os, subprocess, sys
import numpy as np
from PIL import Image
from pxkit import hexc, over
import scene, figure, lino, lino3
from scene import Scene, visible_notes
from lino import INK, CREAM, RED

C = lambda h: np.array(hexc(h), np.uint8)


def up(arr, S):
    return arr.repeat(S, 0).repeat(S, 1)


def paste(dst, src, x, y):
    over(dst, src, int(round(x)), int(round(y)))


# --- continuous bob -------------------------------------------------------------
# keyframes in ms from the beat: rest -> snap down -> low (bells land) -> return -> rest
KEYS = [(0, 0), (70, 1), (150, 2), (300, 3), (470, 0)]


def bob_offset(part, ms):
    vals = figure.BOB[part]
    ms = ms % 500.0
    for (t0, f0), (t1, f1) in zip(KEYS, KEYS[1:]):
        if t0 <= ms <= t1:
            u = (ms - t0) / (t1 - t0)
            u = u * u * (3 - 2 * u)          # smoothstep
            return vals[f0] + (vals[f1] - vals[f0]) * u
    return vals[0]


# --- sprites ------------------------------------------------------------------------
class Mini(Scene):
    def __init__(self, w, h):
        super().__init__({'size': (w, h)})


_sprites = {}


def note_sprite(kind, w):
    """A stamp note at a whole art-pixel width; cached, so its shape is fixed."""
    w = max(4, int(round(w)))
    key = ('n', kind, w)
    if key not in _sprites:
        h = int(w * 0.36 + w * 0.08) + 6
        m = Mini(w + 6, h)
        m.img[...] = 0
        lino.stamp(m, (w + 6) / 2, w * 0.18 + 2.5, w, kind)
        _sprites[key] = (m.img.copy(), (w + 6) / 2, w * 0.18 + 2.5)
    return _sprites[key]


def bar_sprite(up_, w, th):
    """A bell bar: one chevron per lane, drawn once per width."""
    w, th = max(8, int(round(w))), max(3, int(round(th)))
    key = ('b', up_, w, th)
    if key not in _sprites:
        m = Mini(w + 2, th + 2)
        m.img[...] = 0
        m.fill(np.ones((th + 2, w + 2), bool), INK)
        m.fill((m.X >= 1) & (m.X < w + 1) & (m.Y >= 1) & (m.Y < th + 1), RED if up_ else CREAM)
        col = CREAM if up_ else INK
        a = max(1, th // 2 - 1)
        cy = (th + 2) / 2
        for lane in range(3):
            cx = 1 + (lane + 0.5) * w / 3
            for k in range(-a, a + 1):
                yy = cy + (abs(k) - a / 2) * (1 if up_ else -1)
                m.put(cx + k, yy, col)
        _sprites[key] = (m.img.copy(), (w + 2) / 2, (th + 2) / 2)
    return _sprites[key]


# --- one frame -----------------------------------------------------------------------
def frame(cfg, t, S, nframes_fire=240, fire_i=0):
    """t = time in beats."""
    notes_now = visible_notes(t)
    flash = set()
    for (d, kind, lane, dt) in notes_now:
        if kind == 'bell' and abs(d) < 0.03:
            flash.update((0, 1, 2))
        elif kind == 'note_h' and d <= 0 < dt:
            flash.add(lane)
        elif kind != 'bell' and abs(d) < 0.03:
            flash.add(lane)

    def rings(s):
        s.flash = flash
        lino.rings(s)

    base_cfg = dict(cfg, figures=[], notes_fn=lambda s, p: None, rings_fn=rings)
    base = scene.draw(base_cfg, fire_i, nframes_fire, t, 0)
    s = Scene(cfg)                       # geometry only
    W, H = s.W, s.H
    out = up(base, S)
    # keep the HUD and buttons on top: remember them and paste back at the end
    hud_rows = int(H * 0.2) * S
    btn_rows = int(s.btn_top - 9) * S
    top_keep = out[:hud_rows].copy()
    bot_keep = out[btn_rows:].copy()

    # Mamuthones, each part moving smoothly in screen pixels, with one keyline
    ms = (t % 1.0) * 500.0
    for (fx, fy, fh, flip) in cfg['figures']:
        key = ('fig', fh)
        if key not in _sprites:
            f, parts = figure.build(cfg['style'], fh, cfg.get('fig_opts'))
            _sprites[key] = (f, figure.render_parts(f, parts, cfg['style']))
        f, rp = _sprites[key]
        layer = np.zeros((f.CH * S + 4 * S, f.W * S, 4), np.uint8)
        for part in figure.PART_ORDER:
            arr = up(rp[part], S)
            dy = bob_offset(part, ms) * fh * S
            paste(layer, arr, 0, dy)
        if flip:
            layer = layer[:, ::-1]
        a = layer[..., 3] > 0
        nb = np.zeros_like(a)
        for k in range(1, S + 1):
            nb[k:] |= a[:-k]; nb[:-k] |= a[k:]; nb[:, k:] |= a[:, :-k]; nb[:, :-k] |= a[:, k:]
        layer[nb & ~a] = C(cfg.get('keyline') or CREAM)
        paste(out, layer, (fx * W - f.W / 2) * S, (fy * H - f.CH) * S)

    # notes, bars and ropes, far to near
    lw = lambda y: 2 * s.halfw(y) / 3
    for (d, kind, lane, dt) in sorted(notes_now, key=lambda n: -n[0]):
        if kind == 'bell':
            if d < -0.01:
                continue
            y = s.y_of_depth(max(0, d))
            spr, ox, oy = bar_sprite(lane == 'up', 2 * s.halfw(y) - 2, max(3, lw(y) * 0.2))
            sc = (2 * s.halfw(y) - 2) / max(1, spr.shape[1] - 2)
            paste(out, up(spr, S), (s.vpx - ox) * S, (y - oy) * S)
            continue
        if kind == 'note_h':
            draw_rope(out, s, lane, d, dt, S)
            if dt <= 0.8:
                yt = s.y_of_depth(min(0.8, dt))
                spr, ox, oy = note_sprite('h', lw(yt) * 0.45)
                paste(out, up(spr, S), (s.lane_x(lane, yt) - ox) * S, (yt - oy) * S)
            y0 = s.y_of_depth(max(0, d))
            spr, ox, oy = note_sprite('h', lw(y0) * 0.8)
            paste(out, up(spr, S), (s.lane_x(lane, y0) - ox) * S, (y0 - oy) * S)
            continue
        if d < -0.015:
            continue
        y = s.y_of_depth(max(-0.01, d))
        k = {'note_q': 'q', 'note_e': 'e', 'note_o': 'o'}[kind]
        spr, ox, oy = note_sprite(k, lw(y) * 0.8)
        paste(out, up(spr, S), (s.lane_x(lane, y) - ox) * S, (y - oy) * S)

    out[:hud_rows] = np.where(top_keep[..., 3:4] > 0, top_keep, out[:hud_rows]) if False else out[:hud_rows]
    # the judgement plate and buttons always sit above the notes
    out[btn_rows:] = bot_keep
    return out


def draw_rope(out, s, lane, d, dt, S):
    """The hold rope, in screen pixels; its twist moves with the rope."""
    y0 = s.y_of_depth(max(0, d)) * S
    y1 = s.y_of_depth(min(0.8, dt)) * S
    shift = (s.y_of_depth(d) if d >= 0 else 0) * S
    ink, cream, red = C(INK), C(CREAM), C(RED)
    for ys in range(int(y1), int(y0) + 1):
        ya = ys / S
        cx = s.lane_x(lane, ya) * S
        rw = 2 * s.halfw(ya) / 3 * 0.13 * S
        x0, x1 = int(cx - rw - S), int(cx + rw + S)
        for xs in range(max(0, x0), min(out.shape[1], x1 + 1)):
            u = (xs - cx) / max(rw, 1)
            if abs(u) > 1:
                out[ys, xs] = ink
            else:
                tw = int((xs + ys - (0 if d < 0 else 0)) // (2 * S)) % 2
                out[ys, xs] = red if tw else cream


def render(cfg, path_mp4, path_gif, S=3, fps=60, beats=8, bpm=120):
    n = int(round(beats * 60 / bpm * fps))
    tmp = os.environ.get('FRAMES_DIR', path_mp4 + '.frames')
    os.makedirs(tmp, exist_ok=True)
    gif = []
    for i in range(n):
        t = i / n * beats
        img = frame(cfg, t, S, n, i)
        Image.fromarray(img[..., :3]).save(f'{tmp}/{i:04d}.png')
        if i % 2 == 0:
            gif.append(Image.fromarray(img[..., :3]).quantize(colors=16, dither=Image.NONE))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', f'{tmp}/%04d.png',
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'slow', path_mp4], check=True)
    gif[0].save(path_gif, save_all=True, append_images=gif[1:], duration=int(2000 / fps), loop=0)
    for f_ in os.listdir(tmp):
        os.remove(os.path.join(tmp, f_))
    os.rmdir(tmp)


if __name__ == '__main__':
    cfg = lino3.R3[sys.argv[1]]
    render(cfg, sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 3)
