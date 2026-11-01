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
from pxkit import hexc, over, BAYER4 as BAYER
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


# --- Rift of the NecroDancer bob (the game's reference: StreetBackdrop._bob, PixelFigure.pose) ---
BOB_HOLD, BOB_BACK = 0.03, 0.10   # s: down at once on the beat, held, back up by 0.1 s
HEAD_LAG = LOAD_LAG = 0.033       # s: head and bells come back a moment late
DROP = 0.05                       # of figure height, as in the clip
NOD = DROP * 3 / 8                # the head drops this much further
LOAD_OFF = DROP * 2 / 8           # bells can be this far off their straps
LOAD_OUT = DROP * 1 / 8           # and swing out toward the road this much while low


def rift(t):
    if t < 0:
        return 0.0
    x = min(1.0, max(0.0, (t - BOB_HOLD) / (BOB_BACK - BOB_HOLD)))
    return 1.0 - x * x * (3 - 2 * x)


def rift_offsets(part, t, amp=1.0):
    """(dx, dy) in figure heights, t = seconds since the last beat."""
    b = rift(t)
    body = b * DROP * amp
    if part == 'legs':
        return 0.0, 0.0                  # feet stay planted
    if part == 'head':
        h = max(b, rift(t - HEAD_LAG))
        return 0.0, max(body, h * (DROP + NOD) * amp)
    if part in ('back_bells', 'front_bells'):
        l = rift(t - LOAD_LAG)
        y = body + min(LOAD_OFF, max(-LOAD_OFF, l * DROP * amp - body))
        return max(b, l) * LOAD_OUT * amp, y
    return 0.0, body


# --- heavy hop (round 13): crouch, a short lift while stepping, a hard landing ON the beat ---
H_DROP, H_JUMP, H_CROUCH = 0.07, 0.035, 0.025
T_CROUCH, T_OFF, T_BEAT = 0.26, 0.34, 0.5     # s within a 120 bpm beat


def _ss(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def heavy_parts(t):
    """Body drop after landing, crouch before take-off, lift while airborne (fractions of height)."""
    land = 1.0 if t < 0.03 else 1.0 - _ss((t - 0.03) / 0.13)
    crouch = _ss((t - T_CROUCH) / (T_OFF - T_CROUCH - 0.02)) * (1 - _ss((t - T_OFF + 0.02) / 0.05))
    s_ = (t - T_OFF) / (T_BEAT - T_OFF)
    lift = 4 * s_ * (1 - s_) if 0 <= s_ <= 1 else 0.0
    return land, crouch, lift


def heavy_offsets(part, t, amp=1.0):
    """(dx, dy) in figure heights; dy > 0 is down. t = seconds since the beat (landing)."""
    t %= T_BEAT
    land, crouch, lift = heavy_parts(t)
    body = (land * H_DROP + crouch * H_CROUCH) * amp - lift * H_JUMP * amp
    if part == 'legs':
        return 0.0, -lift * H_JUMP * amp           # planted, except in the air
    if part == 'head':
        l2, _, _ = heavy_parts((t - 0.033) % T_BEAT)
        return 0.0, body + l2 * H_DROP * 0.4 * amp + lift * H_JUMP * 0.3 * amp
    if part in ('back_bells', 'front_bells'):
        l3, _, _ = heavy_parts((t - 0.05) % T_BEAT)
        reb = 0.012 * math.sin(max(0.0, t - 0.05) * 40) * math.exp(-max(0.0, t - 0.05) * 14) if t > 0.05 else 0.0
        dy = body + l3 * H_DROP * 0.35 * amp + lift * H_JUMP * 0.5 * amp + reb * amp
        return (max(land, l3) * LOAD_OUT * 2) * amp, dy
    if part == 'arms':
        l4, _, _ = heavy_parts((t - 0.02) % T_BEAT)
        return 0.0, body + l4 * H_DROP * 0.15 * amp
    return 0.0, body


def ring_marks(out, fg, tsec, S):
    """Short cream strokes flying off the bells for a moment after each landing."""
    if tsec > 0.14 or fg.get('z', 9) > 4.5:
        return
    k = 1 - tsec / 0.14
    h = fg['h']
    cream = C(CREAM)
    by = fg['y'] - h * 0.42
    for side in (-1, 1):
        bx = fg['x'] + side * h * 0.43
        for j, ang in enumerate((-0.5, 0.0, 0.5)):
            r0 = h * (0.06 + 0.1 * (1 - k))
            ln = max(2.0, h * 0.07 * k)
            for q in np.arange(0, ln, 1.0 / S):
                x = (bx + side * (r0 + q) * math.cos(ang)) * S
                y = (by + (r0 + q) * math.sin(ang)) * S
                xi, yi = int(x), int(y)
                if 0 <= yi < out.shape[0] - S and 0 <= xi < out.shape[1] - S:
                    out[yi:yi + S, xi:xi + S] = cream


def procession_walk(s, cfg, t):
    """The files walk toward the fire: one step on each bob, taken in the drop.
    Rows are evenly spaced in log depth; a new Mamuthone walks in past the
    screen edge at the front, and the far ones shrink into the dark."""
    R = cfg['rows']
    z0, ratio, step = R['z0'], R['ratio'], R['step']        # step = rows per beat
    beat = math.floor(t)
    if R.get('hop'):                                         # the step is taken in the air
        u = _ss(((t - beat) * 0.5 - T_OFF) / (T_BEAT - T_OFF))
    else:
        u = _ss(((t - beat) * 0.5) / 0.12)                   # the step, inside the drop
    pos = (beat + u) * step                                  # rows walked so far
    out = []
    W, H = s.W, s.H
    n = R['n']
    for side in (-1, 1):
        for j in range(n + 2):
            r = j - (pos % 1.0)                              # row index, moving away
            ident = j + math.floor(pos)                      # who this is
            z = z0 * ratio ** r
            z_out = z0 / ratio                               # one place in front: off screen
            if z > R['zmax'] or z < z_out:
                continue
            tt = 1.0 / z
            y = s.vpy + tt * (s.hity - s.vpy)
            h = int(round(R['scale'] * tt))
            w = h * 0.86
            x = s.vpx + side * (s.halfw(y) * R.get('out', 1.05) + w * 0.36)
            fit = s.vpx - w * 0.5 - 1                        # whole figure on screen
            if z >= z0:
                x = s.vpx + side * min(abs(x - s.vpx), fit)
            else:                                            # walk out past the side, no jump
                k = (math.log(z0) - math.log(z)) / math.log(ratio)   # 0 at the front place, 1 gone
                d0 = min(abs(s.vpx + s.halfw(y) * R.get('out', 1.05) + w * 0.36 - s.vpx), fit)
                x = s.vpx + side * (d0 + (s.vpx + w * 0.6 - d0) * k)
            seed = (ident * 7 + (side > 0) * 3) % 29
            out.append(dict(x=x, y=y, h=h, flip=side < 0, seed=seed, side=side, z=z,
                            bulk=0.94 + 0.1 * ((seed * 37) % 10) / 10, amp=0.9 + 0.2 * ((seed * 53) % 10) / 10))
    return sorted(out, key=lambda f: f['y'])


def procession(s, cfg, t=0.0):
    if cfg['rows'].get('walk'):
        return procession_walk(s, cfg, t)
    """Two files of Mamuthones along the road, far to near, each a little different."""
    out = []
    W, H = s.W, s.H
    k = cfg['rows']['scale']
    for side in (-1, 1):
        for i, z in enumerate(cfg['rows']['z']):
            t = 1.0 / z
            y = s.vpy + t * (s.hity - s.vpy)
            h = int(round(k * t))
            w = h * 0.86
            x = s.vpx + side * (s.halfw(y) * cfg['rows'].get('out', 1.05) + w * 0.36)
            if cfg['rows'].get('fit'):          # keep the whole figure on screen
                x = s.vpx + side * min(abs(x - s.vpx), s.vpx - w * 0.5 - 1)
            seed = i * 7 + (side > 0) * 3
            out.append(dict(x=x, y=y, h=h, flip=side < 0, seed=seed, side=side, z=z,
                            bulk=0.94 + 0.1 * ((seed * 37) % 10) / 10, amp=0.9 + 0.2 * ((seed * 53) % 10) / 10))
    return sorted(out, key=lambda f: f['y'])


# --- the bonfire grows with the combo: 1x to 4x ----------------------------------------
FIRE = {1: (0.085, 0.055), 2: (0.115, 0.085), 3: (0.14, 0.13), 4: (0.11, 0.0)}  # (width, height) of W, H


def level_at(cfg, t):
    """Combo level, seconds since it last went up (or None) and seconds since the beat."""
    spb = 0.5
    per = cfg['levels']                  # beats per level in the demo
    cyc = t % (4 * per)
    lv = int(cyc // per) + 1
    since = (cyc - (lv - 1) * per) * spb if lv > 1 else None
    return lv, since, (t % 1.0) * spb


def pulse(t):
    """The fire's beat: up at once, held, settled by 0.2 s (Rift's shape, a little slower)."""
    x = min(1.0, max(0.0, (t - 0.03) / 0.17))
    return 1.0 - x * x * (3 - 2 * x)


def level_fire(s, cfg, lv, since_up, beat_sec, frame_i, nframes):
    W, H = s.W, s.H
    P = cfg['pal']
    p = pulse(beat_sec)
    burst = 0.0 if since_up is None else max(0.0, 1.0 - since_up / 0.35)
    burst = burst * burst                # quick in, soft out
    fw, fh = FIRE[lv]
    by = s.vpy + H * 0.012
    if lv == 4:                          # high into the sky, round the combo
        fh = (by - H * 0.045) / H
    fh *= 1.0 + 0.16 * p + (0.2 if lv < 4 else 0.04) * burst
    fw *= 1.0 + 0.08 * p + 0.12 * burst
    # a level-up warms the street round the fire: a soft red glow, no white flash
    if burst > 0:
        R = (0.1 + (1 - burst) * 0.22) * H
        d = np.hypot(s.X - s.vpx, (s.Y - by) * 0.9)
        val = np.clip(1 - d / R, 0, 1) * burst
        th = BAYER[s.Yi % 4, s.Xi % 4]
        ink, red = C('#141014'), C('#c8352a')
        is_ink = np.all(s.img[..., :3] == ink[:3], axis=-1)
        s.img[is_ink & (val > 0.35 + th * 0.6)] = red
    if cfg.get('fire_style'):
        import fires
        box = (s.vpx, H * 0.115, W * 0.2, H * 0.06) if lv == 4 else None
        fn = fires.STYLES[cfg['fire_style']]
        kw = dict(beat_no=int(frame_i // 30)) if cfg['fire_style'] == 'pile' else {}
        fn(s, lv, beat_sec, since_up, frame_i / 60.0, box, **kw)
        return
    fcx, fcy = s.vpx, by
    cw = W * fw
    chh = H * fh
    # the combo's box: flames part round it at 4x
    box = None
    if lv == 4:
        box = (s.vpx, H * 0.115, W * 0.2, H * 0.06)
    ph = frame_i / max(1, nframes) * 2 * math.pi * 6
    ramp = P['fire']
    y0, y1 = int(by - chh * 1.15), int(by) + 1
    if lv == 4:
        y0 = int(H * 0.025)              # the tip stays under the progress bar
    for y in range(max(0, y0), y1):
        v = (by - (y + 0.5)) / chh
        if v < 0:
            continue
        reach = cw * 1.4 + (box[2] * 1.3 if box else 0)
        for x in range(int(fcx - reach), int(fcx + reach) + 1):
            u = (x + 0.5 - fcx) / cw
            if box is not None:          # the column splits in two and climbs round the text
                bx, byy, bw, bh = box
                sp = bw * 1.05 * max(0.0, 1 - ((y - byy) / (bh * 1.9)) ** 2)
                dd = abs(x + 0.5 - fcx) - sp
                u = (dd if dd > 0 else -dd * 2.5) / cw
            wob = 0.18 * math.sin(v * 7 - ph * 2 + u * 3) + 0.12 * math.sin(v * 13 + ph * 3)
            width = max(0.0, 1 - v) ** (0.8 if lv < 4 else 0.5) * (0.85 + 0.25 * math.sin(u * 9 + ph * 2 + v * 5))
            val = width - abs(u + wob * v)
            val += (0.25 if lv < 4 else 0.42) * math.sin(u * 11 + ph * 4 - v * 3) * v
            if box is not None:
                bx, byy, bw, bh = box
                e = ((x - bx) / bw) ** 2 + ((y - byy) / bh) ** 2
                if e < 1.0:
                    continue             # the text sits in a clear hole
                if e < 2.0:              # flames lick round its edge
                    val += 0.22 * (2.0 - e)
            if lv == 4:                  # ragged tongues and black cuts, like the small fire's
                val += 0.22 * math.sin(x * 0.9 + y * 0.35 - ph * 3) + 0.12 * math.sin(x * 2.3 - y * 0.6 + ph * 5) - 0.1
            if val <= 0:
                continue
            k = min(len(ramp) - 1, int(val * len(ramp) * (1.6 if lv < 4 else 1.15)))
            s.put(x, y, ramp[k])
    for k in (-1, 1):                    # logs
        for i in range(int(W * 0.12 * 1.5)):
            x = fcx + k * (i - W * 0.09) * 0.9
            y = by - 1 + (i - W * 0.09) * 0.21 * k
            s.put(x, y, P['log']); s.put(x, y + 1, P['log2'])
    r = np.random.default_rng(frame_i + 3)
    for _ in range(4 + 4 * lv + int(10 * burst)):
        s.put(fcx + r.normal(0, cw * 0.7), by - chh * (0.9 + r.random() * 0.6), ramp[-1] if r.random() < 0.5 else ramp[-2])


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
    if cfg.get('levels'):
        lv, since_up, beat_sec = level_at(cfg, t)
        base_cfg.update(fire=False, combo_text='', combo_word=False, no_mult=True,
                        extra_fn=lambda s_, f_, n_: level_fire(s_, cfg, lv, since_up, beat_sec, f_, n_))
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
    tsec = (t % 1.0) * 0.5                  # seconds since the beat at 120 bpm
    figs = procession(s, cfg, t) if cfg.get('rows') else [
        dict(x=fx * W, y=fy * H, h=fh, flip=flip, seed=0, side=(-1 if flip else 1), bulk=1.0, amp=1.0)
        for (fx, fy, fh, flip) in cfg['figures']]
    for fg in figs:
        fh = fg['h']
        opts = dict(cfg.get('fig_opts') or {}, seed=fg['seed'], bulk=fg['bulk'])
        key = ('fig', fh, fg['seed'])
        if key not in _sprites:
            f, parts = figure.build(cfg['style'], fh, opts)
            _sprites[key] = (f, figure.render_parts(f, parts, cfg['style']))
        f, rp = _sprites[key]
        layer = np.zeros((f.CH * S + 4 * S, f.W * S + 2 * S, 4), np.uint8)
        toward = -fg['side']                # bells swing out toward the road
        for part in figure.PART_ORDER:
            dx, dy = (heavy_offsets if cfg.get('heavy') else rift_offsets)(part, tsec, fg['amp'])
            paste(layer, up(rp[part], S), S + dx * fh * S * (toward if not fg['flip'] else -toward), dy * fh * S)
        if fg['flip']:
            layer = layer[:, ::-1]
        a = layer[..., 3] > 0
        sil = cfg['rows'].get('sil_z') if cfg.get('rows') else None
        if sil and fg.get('z', 0) >= sil:   # far files as flat black shapes
            layer[a] = C(INK)
        nb = np.zeros_like(a)
        for k in range(1, S + 1):
            nb[k:] |= a[:-k]; nb[:-k] |= a[k:]; nb[:, k:] |= a[:, :-k]; nb[:, :-k] |= a[:, k:]
        layer[nb & ~a] = C(cfg.get('keyline') or CREAM)
        paste(out, layer, (fg['x'] - f.W / 2) * S - S, (fg['y'] - f.CH) * S)
        if cfg.get('heavy'):
            ring_marks(out, fg, tsec, S)

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

    if cfg.get('levels'):
        draw_combo(out, s, lv, since_up, beat_sec, fire_i, S)
    out[:hud_rows] = np.where(top_keep[..., 3:4] > 0, top_keep, out[:hud_rows]) if False else out[:hud_rows]
    # the judgement plate and buttons always sit above the notes
    out[btn_rows:] = bot_keep
    return out


def _dilate(m, r):
    o = m.copy()
    for _ in range(r):
        n = o.copy()
        n[1:] |= o[:-1]; n[:-1] |= o[1:]; n[:, 1:] |= o[:, :-1]; n[:, :-1] |= o[:, 1:]
        o = n
    return o


def combo_sprite(lv, flick):
    """The combo number and word, in art pixels. At 4x the number burns:
    a red rim, a dithered red glow and small tongues licking off its top."""
    from pxkit import text, text_w
    num = f'{lv}x'
    M = 6
    w = max(text_w(num, 3), text_w('COMBO', 1)) + 2 * M + 3
    h = 21 + 3 + 2 + 7 + 1 + 2 * M
    img = np.zeros((h, w, 4), np.uint8)
    nx = (w - text_w(num, 3)) // 2
    hot = lv == 4
    text(img, num, nx, M, CREAM, RED if hot else INK, 3)
    text(img, 'COMBO', (w - text_w('COMBO', 1)) // 2, M + 21 + 3 + 2, CREAM if hot else '#c9bba0', INK, 1)
    if hot:
        a = img[..., 3] > 0
        num_m = a.copy(); num_m[M + 24:] = False
        r1 = _dilate(num_m, 1) & ~a
        r3 = _dilate(num_m, 3) & ~_dilate(num_m, 1) & ~a
        Y, X = np.mgrid[0:h, 0:w]
        th = BAYER[Y % 4, X % 4]
        img[r1] = C(RED)
        img[r3 & (th > 0.84 + 0.08 * math.sin(flick))] = C(RED)
        # tongues of flame off the top of each stroke
        for x in range(w):
            col = np.nonzero(num_m[:, x])[0]
            if not len(col):
                continue
            top = col[0]
            L = 1.6 + 2.2 * math.sin(x * 1.37 + flick * 2.1) + 1.2 * math.sin(x * 0.53 - flick * 3.3)
            for k in range(1, int(max(0, L)) + 1):
                yy = top - k
                if 0 <= yy < h and not a[yy, x]:
                    img[yy, x] = C(CREAM) if (k == 1 and L > 3.2) else C(RED)
    return img


def draw_combo(out, s, lv, since_up, beat_sec, frame_i, S):
    """The combo pulses on the beat with the Mamuthones' Rift shape, and pops on a level-up."""
    spr = combo_sprite(lv, frame_i * 0.21)
    k = 1.0 + 0.12 * rift(beat_sec)
    if since_up is not None and since_up < 0.3:
        u = since_up / 0.3
        k += 0.3 * (1 - u) ** 2
    h, w = spr.shape[:2]
    nw, nh = max(1, int(round(w * S * k))), max(1, int(round(h * S * k)))
    big = np.array(Image.fromarray(spr).resize((nw, nh), Image.NEAREST))
    cx, cy = s.W / 2 * S, (24 + 10.5) * S       # pulse round the number's centre
    ny = (6 + 10.5) / h                          # the number's centre within the sprite
    paste(out, big, cx - nw / 2, cy - nh * ny)


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


R5 = dict(lino3.R3['r3a_w2_stamps'], name='r5_rows',
          rows=dict(scale=100, z=[1.75, 3.0, 5.0, 8.0]))
# round 6: buildings pushed up and back, a wide street floor for the files to stand on
R6 = dict(R5, name='r6_street', street_floor=2.0,
          pal=dict(R5['pal'], floor='#141014', floor_line='#4a3c38', floor_edge='#c9bba0'),
          rows=dict(scale=100, z=[1.75, 3.0, 5.0, 8.0], out=1.25))

R7 = dict(R6, name='r7_fire', levels=4, combo_scale=3, combo_word=True)
R8 = dict(R7, name='r8_polish')
R9 = {k: dict(R8, name='r9_' + k, fire_style=k) for k in ('tongues', 'gouges', 'pile')}
R10 = dict(R8, name='r10_pile', fire_style='pile')

if __name__ == '__main__':
    cfg = {'r5': R5, 'r6': R6, 'r7': R7, 'r8': R8}.get(sys.argv[1]) or lino3.R3[sys.argv[1]]
    render(cfg, sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 3)


def closeup(path, H=96, S=5, fps=60, beats=4, slow=1.0, bpm=120, heavy=False):
    """One Mamuthone, big, on the lino night ink, to judge the bob."""
    cfg = R5
    f, parts = figure.build(cfg['style'], H, dict(cfg['fig_opts'], seed=0))
    rp = figure.render_parts(f, parts, cfg['style'])
    spb = 60.0 / bpm
    n = int(round(beats * spb * fps * slow))
    tmp = os.environ.get('FRAMES_DIR', path + '.frames')
    os.makedirs(tmp, exist_ok=True)
    for i in range(n):
        tsec = (i / fps / slow) % spb
        layer = np.zeros((f.CH * S + 8 * S, f.W * S + 8 * S, 4), np.uint8)
        layer[...] = C(INK)
        fig = np.zeros_like(layer)
        for part in figure.PART_ORDER:
            dx, dy = (heavy_offsets if heavy else rift_offsets)(part, tsec)
            paste(fig, up(rp[part], S), 4 * S + dx * H * S, 4 * S + dy * H * S)
        a = fig[..., 3] > 0
        nb = np.zeros_like(a)
        for k in range(1, S + 1):
            nb[k:] |= a[:-k]; nb[:-k] |= a[k:]; nb[:, k:] |= a[:, :-k]; nb[:, :-k] |= a[:, k:]
        fig[nb & ~a] = C(CREAM)
        out = np.where(fig[..., 3:4] > 0, fig, layer)
        # a beat light under him: red for the 100 ms the bob lasts
        if tsec < BOB_BACK:
            out[-3 * S:, :] = C(RED)
        h, w = out.shape[:2]
        out = out[:h - h % 2, :w - w % 2]
        Image.fromarray(out[..., :3]).save(f'{tmp}/{i:04d}.png')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', f'{tmp}/%04d.png',
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '14', path], check=True)
    for f_ in os.listdir(tmp):
        os.remove(os.path.join(tmp, f_))


# round 11: same log pile at every level; options for the Mamuthones and the buildings
R10b = dict(R10, name='r11_base')
_rows_a = dict(scale=90, z=[2.4, 3.4, 5.0, 8.0], out=1.1, fit=True)
R11_M = {
    'm_a': dict(R10b, rows=_rows_a),
    'm_b': dict(R10b, rows=dict(scale=84, z=[2.3, 2.9, 3.7, 4.8, 6.3, 8.5], out=1.12, fit=True)),
    'm_c': dict(R10b, rows=dict(_rows_a, sil_z=4.0)),
}
_night = dict(R10b['pal'], wall=['#141014'] * 3, wall_line='#3a2c2c', seam='#c9bba0', roof='#c9bba0',
              win_lit='#c8352a', win_dark='#3a2c2c', door='#3a2c2c')
_stone = dict(R10b['pal'], wall=['#c9bba0', '#efe6d2', '#efe6d2'], roof='#c8352a', roof_line='#141014',
              shutter='#c8352a', win_dark='#141014', win_lit='#141014', door='#141014')
R11_B = {
    'b_a': R11_M['m_a'],
    'b_b': dict(R11_M['m_a'], pal=_night),
    'b_c': dict(R11_M['m_a'], pal=_stone, house_h=(0.45, 0.25), roof_k=1.7, roof_tiles=True),
}

# round 12: today's houses and four-a-side files, back rows black, walking a step per bob
R12 = dict(R10b, name='r12_walk', rows=dict(walk=True, scale=90, z0=2.4, ratio=1.42, step=1 / 3,
                                            n=5, zmax=11.0, out=1.1, sil_z=4.0))

# round 13: a heavy hop that rings the bells on the beat
R13 = dict(R12, name='r13_hop', heavy=True, rows=dict(R12['rows'], hop=True))
R14 = dict(R13, name='r14_exit')
R15 = dict(R14, name='r15_square', wall_u0=0.3)
