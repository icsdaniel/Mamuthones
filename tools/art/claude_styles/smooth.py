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


def clean_note(kind, w):
    """Round 26 notes: the same stamps, with bold, simple marks that read at any size."""
    w = max(4, int(round(w)))
    key = ('cn', kind, w)
    if key not in _sprites:
        h = int(w * 0.36 + w * 0.08) + 6
        m = Mini(w + 6, h)
        m.img[...] = 0
        cx, cy = (w + 6) / 2, w * 0.18 + 2.5
        rx = w / 2
        ry = max(1.5, rx * 0.36)
        th = max(1, round(w * 0.08))
        E = lambda a, b, yy=cy: lino.ellipse_mask(m, cx, yy, a, b)
        outer = E(rx + 1, ry + 1, cy + th) | E(rx + 1, ry + 1)
        m.fill(outer, INK if kind != 'o' else CREAM)
        side, top = E(rx, ry, cy + th), E(rx, ry)
        if kind == 'q':                     # on the beat: cream face, one bold red dot
            m.fill(side, RED); m.fill(top, CREAM)
            m.fill(E(max(1.2, rx * 0.34), max(0.9, ry * 0.4)), RED)
        elif kind == 'e':                   # half beat: red face, one cream ring
            m.fill(side, INK); m.fill(top, RED)
            r_o, r_i = rx * 0.6, max(0.5, rx * 0.6 - max(1.3, rx * 0.16))
            m.fill(E(r_o, r_o * 0.36 + 0.3) & ~E(r_i, r_i * 0.36), CREAM)
        elif kind == 'o':                   # off-beat: black face, three bold cream bars
            m.fill(side, CREAM); m.fill(top, INK)
            bw_ = max(1, round(rx * 0.16))
            for k in (-1, 0, 1):
                m.fill(top & (np.abs(m.X - (cx + k * rx * 0.45)) < bw_ * 0.5 + 0.01) & E(rx - 1, ry - 0.6), CREAM)
        elif kind == 'h':                   # hold: red face, cream knot
            m.fill(side, INK); m.fill(top, RED)
            m.fill(E(rx * 0.42, ry * 0.5), CREAM)
            m.fill(E(max(0.8, rx * 0.16), max(0.6, ry * 0.2)), RED)
        _sprites[key] = (m.img.copy(), cx, cy)
    return _sprites[key]


def clean_bar(up_, w):
    """Round 26 bell bars: thicker, with one bold chevron per lane."""
    w = max(8, int(round(w)))
    th = max(4, int(round(w * 0.1)))
    key = ('cb', up_, w)
    if key not in _sprites:
        m = Mini(w + 2, th + 2)
        m.img[...] = 0
        m.fill(np.ones((th + 2, w + 2), bool), INK)
        m.fill((m.X >= 1) & (m.X < w + 1) & (m.Y >= 1) & (m.Y < th + 1), RED if up_ else CREAM)
        col = CREAM if up_ else INK
        a = max(1, int(th * 0.75))
        cy = (th + 2) / 2
        sw = 2 if th >= 6 else 1
        for lane in range(3):
            cx = 1 + (lane + 0.5) * w / 3
            for k in range(-a, a + 1):
                for q in range(sw):
                    yy = cy + (abs(k) * 0.55 - a * 0.28) * (1 if up_ else -1) + q * (1 if up_ else -1)
                    m.put(cx + k, yy, col)
        _sprites[key] = (m.img.copy(), (w + 2) / 2, (th + 2) / 2)
    return _sprites[key]


# --- round 27: three readability options ----------------------------------------------
def _outline(m, mask, col, n=1):
    g = mask.copy()
    for _ in range(n):
        h = g.copy(); h[1:] |= g[:-1]; h[:-1] |= g[1:]; h[:, 1:] |= g[:, :-1]; h[:, :-1] |= g[:, 1:]
        g = h
    m.fill(g & ~mask, col)


def flat_bold(kind, w):
    """A: flat stamps, rounder and bigger, each ringed in cream so it pops off the black road."""
    w = max(6, int(round(w)))
    key = ('fa', kind, w)
    if key not in _sprites:
        rx = w / 2; ry = max(2, rx * 0.5); th = max(1, round(w * 0.1))
        m = Mini(w + 8, int(2 * ry + th) + 8)
        m.img[...] = 0
        cx, cy = (w + 8) / 2, ry + 4
        E = lambda a, b, yy=cy: lino.ellipse_mask(m, cx, yy, a, b)
        body = E(rx, ry, cy + th) | E(rx, ry)
        _outline(m, body, INK, 1)
        ring = np.zeros_like(body); g = body.copy()
        g2 = g.copy(); g2[1:] |= g[:-1]; g2[:-1] |= g[1:]; g2[:, 1:] |= g[:, :-1]; g2[:, :-1] |= g[:, 1:]
        g3 = g2.copy(); g3[1:] |= g2[:-1]; g3[:-1] |= g2[1:]; g3[:, 1:] |= g2[:, :-1]; g3[:, :-1] |= g2[:, 1:]
        m.fill(g3 & ~g2, CREAM if kind != 'q' else RED)
        side, top = E(rx, ry, cy + th), E(rx, ry)
        face, edge, mark = {'q': (CREAM, RED, RED), 'e': (RED, INK, CREAM), 'o': (INK, CREAM, CREAM), 'h': (RED, INK, CREAM)}[kind]
        m.fill(side, edge); m.fill(top, face)
        if kind == 'q':
            m.fill(E(rx * 0.38, ry * 0.42), mark)
        elif kind == 'e':
            m.fill(E(rx * 0.55, ry * 0.58) & ~E(max(0.5, rx * 0.55 - max(1.5, rx * 0.2)), max(0.4, ry * 0.58 - max(1.2, ry * 0.25))), mark)
        elif kind == 'o':
            m.fill(top & (np.abs(m.X - cx) < max(1, rx * 0.5)) & (np.abs(m.Y - cy) < max(0.6, ry * 0.22)), mark)
        else:
            m.fill(E(rx * 0.42, ry * 0.5), mark)
        _sprites[key] = (m.img.copy(), cx, cy)
    return _sprites[key]


def token(kind, w, shaped=False):
    """B/C: notes as upright tokens standing on the lane, facing the player.
    B: round medallions with one bold mark. C: a different silhouette for each kind."""
    w = max(6, int(round(w)))
    key = ('tk', kind, w, shaped)
    if key not in _sprites:
        D = w
        m = Mini(D + 6, D + 6 + max(2, D // 6))
        m.img[...] = 0
        cx, cy = (D + 6) / 2, D / 2 + 3
        r = D / 2
        dx, dy = m.X - cx, m.Y - cy
        if not shaped or kind in ('q', 'h'):
            shape = np.hypot(dx, dy) <= r
        elif kind == 'e':
            shape = (np.abs(dx) + np.abs(dy)) <= r * 1.15
        else:                                    # off-beat: a smaller square
            shape = (np.abs(dx) <= r * 0.68) & (np.abs(dy) <= r * 0.68)
        sh = lino.ellipse_mask(m, cx, D + 3 + max(1, D // 12), r * 0.75, max(1, D * 0.08))
        m.fill(sh & ~shape, INK)                 # a shadow on the road
        _outline(m, shape, INK, 1)
        inner = shape.copy()
        for _ in range(max(1, D // 12)):
            g = inner; h = g.copy(); h[1:] &= g[:-1]; h[:-1] &= g[1:]; h[:, 1:] &= g[:, :-1]; h[:, :-1] &= g[:, 1:]; inner = h
        face, rim, mark = {'q': (CREAM, RED, RED), 'e': (RED, CREAM, CREAM), 'o': (INK, CREAM, CREAM), 'h': (RED, CREAM, CREAM)}[kind]
        if shaped and kind == 'o':
            face, rim = CREAM, INK               # a solid cream square reads on the black road
        m.fill(shape, rim); m.fill(inner, face)
        if shaped and kind == 'o':
            m.fill((np.abs(dx) <= r * 0.25) & (np.abs(dy) <= r * 0.25), RED)
        if kind == 'q':
            m.fill(np.hypot(dx, dy) <= r * 0.3, mark)
        elif kind == 'e' and not shaped:
            m.fill((np.hypot(dx, dy) <= r * 0.48) & (np.hypot(dx, dy) > r * 0.48 - max(1.5, r * 0.18)), mark)
        elif kind == 'o' and not shaped:
            m.fill((np.abs(dx) <= r * 0.42) & (np.abs(dy) <= max(0.7, r * 0.13)), mark)
        elif kind == 'h':
            m.fill(np.hypot(dx, dy) <= r * 0.36, mark); m.fill(np.hypot(dx, dy) <= r * 0.14, RED)
        _sprites[key] = (m.img.copy(), cx, D + 3)
    return _sprites[key]


def plank(up_, w, upright=False):
    """Bell bars. Flat (A): a thick bar with big filled arrows. Upright (B/C): a plank standing across
    the road, its arrows big enough to read far away."""
    w = max(10, int(round(w)))
    th = max(5, int(round(w * (0.12 if upright else 0.11))))
    key = ('pl', up_, w, upright)
    if key not in _sprites:
        m = Mini(w + 4, th + 4)
        m.img[...] = 0
        body = (m.X >= 2) & (m.X < w + 2) & (m.Y >= 2) & (m.Y < th + 2)
        _outline(m, body, INK, 1)
        m.fill(body, RED if up_ else CREAM)
        col = CREAM if up_ else INK
        a = th * 0.42
        for lane in range(3):
            cx = 2 + (lane + 0.5) * w / 3
            cy = 2 + th / 2
            v = (m.Y - cy) * (1 if up_ else -1)
            tri = (v >= -a) & (v <= a) & (np.abs(m.X - cx) <= (v + a) * 0.9)
            m.fill(tri & body, col)
        _sprites[key] = (m.img.copy(), (w + 4) / 2, (th + 4) / 2 if not upright else th + 2)
    return _sprites[key]


# --- round 28 (option D): notes and bars drawn at screen resolution -----------------------
HI_MIPS = [int(round(14 * 1.16 ** i)) for i in range(20)]


def _ring_of(mask, n):
    g = mask.copy()
    for _ in range(n):
        h = g.copy(); h[1:] |= g[:-1]; h[:-1] |= g[1:]; h[:, 1:] |= g[:, :-1]; h[:, :-1] |= g[:, 1:]
        g = h
    return g


def _shrink(mask, n):
    g = mask.copy()
    for _ in range(n):
        h = g.copy(); h[1:] &= g[:-1]; h[:-1] &= g[1:]; h[:, 1:] &= g[:, :-1]; h[:, :-1] &= g[:, 1:]
        g = h
    return g


def token_hi(kind, D):
    """An upright token drawn in screen pixels: a shape per kind, a carved rim, a bold mark."""
    D = max(10, int(D))
    key = ('thi', kind, D)
    if key not in _sprites:
        t = max(2, D // 14)                       # black outline
        rim = max(2, D // 9)
        pad = 2 * t + 2
        sh_h = max(2, D // 8)
        m = Mini(D + 2 * pad, D + 2 * pad + sh_h)
        m.img[...] = 0
        cx, cy = (D + 2 * pad) / 2, pad + D / 2
        r = D / 2
        dx, dy = m.X - cx, m.Y - cy
        if kind in ('q', 'h'):
            shape = np.hypot(dx, dy) <= r
        elif kind == 'e':
            shape = (np.abs(dx) + np.abs(dy)) <= r * 1.12
        else:
            shape = (np.abs(dx) <= r * 0.7) & (np.abs(dy) <= r * 0.7)
        base = pad + D
        sh = (((m.X - cx) / (r * 0.8)) ** 2 + ((m.Y - (base + sh_h * 0.3)) / (sh_h * 0.7)) ** 2) <= 1
        m.fill(sh & ~shape, INK)
        m.fill(_ring_of(shape, t) & ~shape, INK)
        inner = _shrink(shape, rim)
        face, rimc, mark = {'q': (CREAM, RED, RED), 'e': (RED, CREAM, CREAM), 'o': (CREAM, INK, RED), 'h': (RED, CREAM, CREAM)}[kind]
        m.fill(shape, rimc)
        m.fill(inner, face)
        ang = np.arctan2(dy, dx)
        if D >= 22:                               # carved notches round the rim, like the hit rings
            notch = shape & ~inner & (np.abs(np.sin(ang * 8)) < 0.16)
            m.fill(notch, INK)
        if kind == 'q':
            m.fill(np.hypot(dx, dy) <= r * 0.28, mark)
            if D >= 30:
                m.fill((np.hypot(dx, dy) <= r * 0.5) & (np.hypot(dx, dy) > r * 0.5 - max(1, D // 22)), mark)
        elif kind == 'e':
            m.fill(_shrink(inner, max(2, D // 8)) & ~_shrink(inner, max(2, D // 8) + max(2, D // 14)), mark)
        elif kind == 'o':
            m.fill((np.abs(dx) <= r * 0.22) & (np.abs(dy) <= r * 0.22), mark)
        else:
            m.fill(np.hypot(dx, dy) <= r * 0.36, mark); m.fill(np.hypot(dx, dy) <= r * 0.15, RED)
        if D >= 26:                               # a cut highlight, top left
            hl = inner & (np.hypot(dx + r * 0.42, dy + r * 0.42) <= r * 0.12)
            m.fill(hl, CREAM if face != CREAM else '#c9bba0')
        _sprites[key] = (m.img.copy(), cx, base)
    return _sprites[key]


def plank_hi(up_, w):
    """A bell plank in screen pixels: standing across the road, big outlined arrows."""
    w = max(30, int(w))
    th = max(12, int(round(w * 0.12)))
    key = ('phi', up_, w)
    if key not in _sprites:
        t = max(2, w // 120)
        pad = t + 2
        m = Mini(w + 2 * pad, th + 2 * pad)
        m.img[...] = 0
        body = (m.X >= pad) & (m.X < w + pad) & (m.Y >= pad) & (m.Y < th + pad)
        m.fill(_ring_of(body, t) & ~body, INK)
        m.fill(body, RED if up_ else CREAM)
        edge = body & ~_shrink(body, max(2, th // 8))
        m.fill(edge, CREAM if up_ else RED)
        col = CREAM if up_ else INK
        a = th * 0.36
        for lane in range(3):
            cx = pad + (lane + 0.5) * w / 3
            cy = pad + th / 2
            v = (m.Y - cy) * (1 if up_ else -1)
            tri = (v >= -a) & (v <= a) & (np.abs(m.X - cx) <= (v + a) * 1.0)
            m.fill(_ring_of(tri, max(1, t)) & ~tri & body & ~edge, INK if up_ else CREAM)
            m.fill(tri, col)
        _sprites[key] = (m.img.copy(), (w + 2 * pad) / 2, th + pad)
    return _sprites[key]


def place_hi(dst, fn, wpx, x, y):
    """Screen-pixel placement: the next drawn size up, scaled down by at most ~14%."""
    wpx = max(HI_MIPS[0], wpx)
    m = next((v for v in HI_MIPS if v >= wpx), HI_MIPS[-1])
    px = HI_PX
    spr, ox, oy = fn(max(6, int(round(m / px))))
    spr, ox, oy = up(spr, px) if px > 1 else spr, ox * px, oy * px
    k = wpx / m
    nw, nh = max(1, int(round(spr.shape[1] * k))), max(1, int(round(spr.shape[0] * k)))
    key = (hash(spr.tobytes()), spr.shape, nw)
    if key not in _scaled:
        _scaled[key] = np.array(Image.fromarray(spr).resize((nw, nh), Image.NEAREST))
    paste(dst, _scaled[key], x - ox * k, y - oy * k)


HI_PX = 1          # round 30: screen pixels per note pixel (2 = a touch chunkier than full res)


# --- round 29: the standard stamps and bars, redrawn at screen resolution -------------------
def stamp_hi(kind, W):
    """lino.stamp's design (same colours and marks) drawn in screen pixels, with outlines that scale."""
    W = max(12, int(W))
    key = ('shi', kind, W)
    if key not in _sprites:
        t = max(2, W // 30)
        rx = W / 2; ry = rx * 0.36; th = max(2, round(W * 0.08))
        pad = t + 2
        m = Mini(W + 2 * pad, int(2 * ry + th) + 2 * pad + 1)
        m.img[...] = 0
        cx, cy = (W + 2 * pad) / 2, pad + ry
        E = lambda a, b, yy=cy: (((m.X - cx) / max(a, 0.5)) ** 2 + ((m.Y - yy) / max(b, 0.5)) ** 2) <= 1
        body = E(rx, ry, cy + th) | E(rx, ry)
        m.fill(_ring_of(body, t) & ~body, INK if kind != 'o' else CREAM)
        side, top = E(rx, ry, cy + th) & ~E(rx, ry), E(rx, ry)
        if kind == 'q':
            m.fill(side, RED); m.fill(top, CREAM)
            for k in range(6):
                a = k * math.pi / 3
                px_, py_ = cx + math.cos(a) * rx * 0.5, cy + math.sin(a) * ry * 0.5
                m.fill((((m.X - px_) / (rx * 0.17)) ** 2 + ((m.Y - py_) / (ry * 0.22)) ** 2) <= 1, RED)
            m.fill(E(rx * 0.2, ry * 0.25), RED)
        elif kind == 'e':
            m.fill(side, INK); m.fill(top, RED)
            rw = max(t, W * 0.06)
            m.fill(E(rx * 0.62, ry * 0.62) & ~E(rx * 0.62 - rw, ry * 0.62 - rw * 0.6), CREAM)
        elif kind == 'o':
            m.fill(side, CREAM); m.fill(top, INK)
            sw = max(t, W // 20)
            stripes = (((m.Xi - int(cx)) % (3 * sw)) < sw) & ~E(rx * 0.35, ry * 0.4)
            m.fill(top & stripes & E(rx - t, ry - t * 0.6), CREAM)
        elif kind == 'h':
            m.fill(side, INK); m.fill(top, RED)
            m.fill(E(rx * 0.4, ry * 0.45), CREAM)
            m.fill(E(rx * 0.18, ry * 0.2), RED)
        _sprites[key] = (m.img.copy(), cx, cy)
    return _sprites[key]


def sign_hi(kind, W):
    """Round 30: the heart and the stomp in the high-res stamp set - stamp_hi's body with the
    heart or the two feet standing upright on the face, outlines that scale."""
    W = max(12, int(W))
    key = ('sghi', kind, W)
    if key not in _sprites:
        t = max(2, W // 30)
        rx = W / 2; ry = rx * 0.36; th = max(2, round(W * 0.08))
        hh = int(round(W * (0.62 if kind == 'heart' else 0.66)))
        pad = t + 2
        top_room = hh + 2 * t + 2
        m = Mini(W + 2 * pad, int(2 * ry + th) + 2 * pad + 1 + top_room)
        m.img[...] = 0
        cx, cy = (W + 2 * pad) / 2, top_room + pad + ry
        E = lambda a, b, yy=cy: (((m.X - cx) / max(a, 0.5)) ** 2 + ((m.Y - yy) / max(b, 0.5)) ** 2) <= 1
        body = E(rx, ry, cy + th) | E(rx, ry)
        side, top = E(rx, ry, cy + th) & ~E(rx, ry), E(rx, ry)
        if kind == 'heart':
            m.fill(_ring_of(body, t) & ~body, INK)
            m.fill(side, RED); m.fill(top, CREAM)
            m.fill(E(rx * 0.3, ry * 0.32), INK)                      # the heart's shadow
            hw, hcy = hh * 0.62, cy - hh * 0.55
            x = (m.X - cx) / hw * 1.15
            y = -((m.Y - hcy) / (hh * 0.5)) * 1.15
            core = (x * x + y * y - 1) ** 3 - x * x * y ** 3 <= 0
            m.fill(_ring_of(core, t) & ~core, INK)
            m.fill(core, RED)
            m.fill(core & (np.hypot(x + 0.45, y - 0.4) < 0.22), CREAM)
        else:
            m.fill(_ring_of(body, t) & ~body, CREAM)
            m.fill(side, RED); m.fill(top, INK)
            tw, tb = hh * 1.0, cy + ry * 0.2
            r_ = max(2, hh * 0.12)
            dx_ = np.maximum(np.abs(m.X - cx) - (tw / 2 - r_), 0)
            dy_ = np.maximum((tb - hh + r_) - m.Y, 0)
            tab = (np.abs(m.X - cx) <= tw / 2) & (m.Y >= tb - hh) & (m.Y <= tb) & (np.hypot(dx_, dy_) <= r_)
            m.fill(_ring_of(tab, t) & ~tab, INK)
            m.fill(tab, CREAM)
            m.fill(tab & (m.Y > tb - max(2, hh * 0.1)), RED)        # the tablet's red foot
            pal = dict(lino3.W2['pal'], foot=INK, btn_face=[CREAM, CREAM])
            fs = hh * 0.82
            scene.draw_foot(m, {'pal': pal}, cx - fs * 0.24, tb - hh * 0.55, fs, mirror=True)
            scene.draw_foot(m, {'pal': pal}, cx + fs * 0.24, tb - hh * 0.55, fs, mirror=False)
        _sprites[key] = (m.img.copy(), cx, cy)
    return _sprites[key]


def bar_hi(up_, W, TH):
    """bar_sprite's design (one chevron per lane) in screen pixels."""
    W, TH = max(30, int(W)), max(8, int(TH))
    key = ('bhi', up_, W, TH)
    if key not in _sprites:
        t = max(2, W // 110)
        m = Mini(W + 2 * t, TH + 2 * t)
        m.img[...] = 0
        m.fill(np.ones(m.X.shape, bool), INK)
        m.fill((m.X >= t) & (m.X < W + t) & (m.Y >= t) & (m.Y < TH + t), RED if up_ else CREAM)
        col = CREAM if up_ else INK
        a = TH * 0.32
        cy = (TH + 2 * t) / 2
        sw = max(2, TH // 6)
        for lane in range(3):
            cx = t + (lane + 0.5) * W / 3
            d = (m.Y - cy) * (1 if up_ else -1) + a * 0.5
            chev = (np.abs(m.X - cx) <= a * 1.6) & (np.abs(d - np.abs(m.X - cx) * 0.62) <= sw * 0.6)
            m.fill(chev, col)
        _sprites[key] = (m.img.copy(), (W + 2 * t) / 2, (TH + 2 * t) / 2)
    return _sprites[key]


# --- round 26: each note drawn clean at a few fixed sizes, then scaled smoothly ----------
NOTE_MIPS = [7, 9, 12, 16, 21, 28, 37, 48]
BAR_MIPS = [24, 32, 43, 57, 76, 101, 134]
NK = 0.92                                  # notes a little bigger: 0.92 of the lane instead of 0.8
_scaled = {}


def place(dst, fn, mips, w, x, y, S):
    """Draw the clean icon of the next size up, scaled down (at most ~25%) to the exact width in
    screen pixels. Its shape only ever changes at a few fixed sizes, never pixel by pixel."""
    w = max(mips[0], w)
    m = next((v for v in mips if v >= w), mips[-1])
    spr, ox, oy = fn(m)
    k = w / m
    big = up(spr, S)
    nw, nh = max(1, int(round(big.shape[1] * k))), max(1, int(round(big.shape[0] * k)))
    key = (hash(spr.tobytes()), spr.shape, nw)
    if key not in _scaled:
        _scaled[key] = np.array(Image.fromarray(big).resize((nw, nh), Image.NEAREST))
    paste(dst, _scaled[key], x * S - ox * S * k, y * S - oy * S * k)


# --- one frame -----------------------------------------------------------------------
def frame(cfg, t, S, nframes_fire=240, fire_i=0):
    """t = time in beats."""
    global HI_PX
    HI_PX = cfg.get('hi_px', 1)
    notes_now = visible_notes(t)
    flash = set()
    for (d, kind, lane, dt) in notes_now:
        if any(abs(t + d / scene.SP - m) < 0.01 for m in cfg.get('misses', ())):
            continue
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

    # notes, bars and ropes, far to near, on their own layer (they never darken)
    nl = np.zeros_like(out)
    lw = lambda y: 2 * s.halfw(y) / 3
    for (d, kind, lane, dt) in sorted(notes_now, key=lambda n: -n[0]):
        if kind == 'bell':
            if d < -0.01:
                continue
            y = s.y_of_depth(max(0, d))
            if cfg.get('look') == 'd':
                place_hi(nl, lambda w_, u_=(lane == 'up'): plank_hi(u_, w_), (2 * s.halfw(y) - 2) * S, s.vpx * S, y * S)
                continue
            if cfg.get('look') == 'std_hi':
                bw_ = (2 * s.halfw(y) - 2) * S
                place_hi(nl, lambda w_, u_=(lane == 'up'): bar_hi(u_, w_, max(12, w_ * 0.075)), bw_, s.vpx * S, y * S)
                continue
            if cfg.get('mip'):
                place(nl, (lambda w_, u_=(lane == 'up'): clean_bar(u_, w_)) if not cfg.get('look') else
                      (lambda w_, u_=(lane == 'up'), up2=cfg['look'] != 'a': plank(u_, w_, up2)),
                      BAR_MIPS, 2 * s.halfw(y) - 2, s.vpx, y, S)
                continue
            spr, ox, oy = bar_sprite(lane == 'up', 2 * s.halfw(y) - 2, max(3, lw(y) * 0.2))
            sc = (2 * s.halfw(y) - 2) / max(1, spr.shape[1] - 2)
            paste(nl, up(spr, S), (s.vpx - ox) * S, (y - oy) * S)
            continue
        if kind == 'note_h':
            draw_rope(nl, s, lane, d, dt, S)
            if dt <= 0.8 and cfg.get('look') == 'std_hi':
                yt = s.y_of_depth(min(0.8, dt))
                place_hi(nl, lambda w_: stamp_hi('h', w_), lw(yt) * 0.45 * S, s.lane_x(lane, yt) * S, yt * S)
            elif dt <= 0.8:
                yt = s.y_of_depth(min(0.8, dt))
                spr, ox, oy = note_sprite('h', lw(yt) * 0.45)
                paste(nl, up(spr, S), (s.lane_x(lane, yt) - ox) * S, (yt - oy) * S)
            y0 = s.y_of_depth(max(0, d))
            if cfg.get('mip'):
                if cfg.get('look') == 'std_hi':
                    place_hi(nl, lambda w_: stamp_hi('h', w_), lw(y0) * 0.8 * S, s.lane_x(lane, y0) * S, y0 * S)
                    continue
                if cfg.get('look') == 'd':
                    place_hi(nl, lambda w_: token_hi('h', w_), max(lw(y0) * 0.62, cfg.get('note_floor', 0)) * S,
                             s.lane_x(lane, y0) * S, y0 * S)
                    continue
                fh_ = (lambda w_: clean_note('h', w_)) if not cfg.get('look') else \
                      (lambda w_: flat_bold('h', w_)) if cfg['look'] == 'a' else (lambda w_: token('h', w_))
                kk = {'a': 1.0, 'b': 0.62, 'c': 0.62}.get(cfg.get('look'), NK)
                place(nl, fh_, NOTE_MIPS, max(lw(y0) * kk, cfg.get('note_floor', 0)), s.lane_x(lane, y0), y0, S)
                continue
            spr, ox, oy = note_sprite('h', lw(y0) * 0.8)
            paste(nl, up(spr, S), (s.lane_x(lane, y0) - ox) * S, (y0 - oy) * S)
            continue
        if d < -0.015:
            continue
        y = s.y_of_depth(max(-0.01, d))
        k = {'note_q': 'q', 'note_e': 'e', 'note_o': 'o'}[kind]
        if any(abs((t + d / scene.SP) % scene.LOOP - sb) < 0.01 for sb in cfg.get('stomp_beats', ())):
            if cfg.get('sign_hi'):
                place_hi(nl, lambda w_: sign_hi('stomp', w_), lw(y) * 0.8 * S, s.lane_x(lane, y) * S, y * S)
                continue
            if cfg.get('mip'):
                place(nl, stomp_sprite, NOTE_MIPS, lw(y) * NK, s.lane_x(lane, y), y, S)
                continue
            spr, ox, oy = stomp_sprite(lw(y) * 0.8)      # both thumbs: a pair of feet on a black stamp
            paste(nl, up(spr, S), (s.lane_x(lane, y) - ox) * S, (y - oy) * S)
            continue
        if any(abs(t + d / scene.SP - hb) < 0.01 for hb in cfg.get('heal_beats', ())):
            if cfg.get('sign_hi'):
                place_hi(nl, lambda w_: sign_hi('heart', w_), lw(y) * 0.8 * S, s.lane_x(lane, y) * S, y * S)
                continue
            if cfg.get('mip'):
                place(nl, heart_sprite, NOTE_MIPS, lw(y) * NK, s.lane_x(lane, y), y, S)
                continue
            spr, ox, oy = heart_sprite(lw(y) * 0.8)       # a healing step: a heart on a step stamp
            paste(nl, up(spr, S), (s.lane_x(lane, y) - ox) * S, (y - oy) * S)
            continue
        if cfg.get('mip'):
            if cfg.get('look') == 'std_hi':
                place_hi(nl, lambda w_, k_=k: stamp_hi(k_, w_), lw(y) * 0.8 * S, s.lane_x(lane, y) * S, y * S)
                continue
            if cfg.get('look') == 'd':
                place_hi(nl, lambda w_, k_=k: token_hi(k_, w_), max(lw(y) * 0.62, cfg.get('note_floor', 0)) * S,
                         s.lane_x(lane, y) * S, y * S)
                continue
            fn = (lambda w_, k_=k: clean_note(k_, w_)) if not cfg.get('look') else \
                 (lambda w_, k_=k: flat_bold(k_, w_)) if cfg['look'] == 'a' else \
                 (lambda w_, k_=k, sh_=cfg['look'] == 'c': token(k_, w_, sh_))
            kk = {'a': 1.0, 'b': 0.62, 'c': 0.62}.get(cfg.get('look'), NK)
            place(nl, fn, NOTE_MIPS, max(lw(y) * kk, cfg.get('note_floor', 0)), s.lane_x(lane, y), y, S)
            continue
        spr, ox, oy = note_sprite(k, lw(y) * 0.8)
        paste(nl, up(spr, S), (s.lane_x(lane, y) - ox) * S, (y - oy) * S)

    if cfg.get('sky_beat'):
        sky_beat(out, s, cfg, t, S)
    if cfg.get('world_juice'):
        world_juice(out, s, cfg, t, S, lv, since_up)
    if cfg.get('levels'):
        draw_combo(out, s, lv, since_up, beat_sec, fire_i, S)
    out[:hud_rows] = np.where(top_keep[..., 3:4] > 0, top_keep, out[:hud_rows]) if False else out[:hud_rows]
    # the judgement plate and buttons always sit above the notes
    out[btn_rows:] = bot_keep
    hp = health_at(cfg, t) if cfg.get('health_demo') else None
    if hp is not None:
        danger(out, s, cfg, t, S, hp)
    over(out[:btn_rows], nl[:btn_rows], 0, 0)            # the notes, never darkened
    if cfg.get('juice'):
        juice(out, s, t, S, cfg.get('misses', ()), cfg.get('stomp_beats', ()))
    if hp is not None:
        hearts_hud(out, s, t, S, hp)
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


# --- round 18: the sky keeps time -----------------------------------------------------
def _stars(s, cfg):
    """The scene's own stars, found by replaying its random draws."""
    W, H = s.W, s.H
    rng = np.random.default_rng(7)
    out = []
    for _ in range(int(W * H * cfg.get('stars', 0.0))):
        x, y = rng.integers(0, W), rng.integers(int(H * 0.08), int(s.vpy * 0.85))
        rng.random()
        big = bool(cfg.get('cross_stars') and rng.random() < 0.3)
        out.append((int(x), int(y), big))
    return out


_masks = {}


def masks(cfg):
    """Art-pixel masks of open night sky and of the lit house windows, from one probe render."""
    key = cfg['name']
    if key not in _masks:
        SKY, WIN = '#010203', '#020304'
        pal = dict(cfg['pal'], sky=[SKY, SKY], sky_line=SKY, star=SKY, star2=SKY, win_lit=WIN)
        img = scene.draw(dict(cfg, pal=pal, figures=[], fire=False, extra_fn=None, levels=None,
                              notes_fn=lambda s_, p_: None, rings_fn=lambda s_: None), 0, 1, 0, 0)
        sky = np.all(img[..., :3] == C(SKY)[:3], axis=-1)
        win = np.all(img[..., :3] == C(WIN)[:3], axis=-1)
        lab = np.zeros(win.shape, int)         # number each window, so whole windows flash
        n = 0
        for y0, x0 in zip(*np.nonzero(win)):
            if lab[y0, x0]:
                continue
            n += 1
            stack = [(y0, x0)]
            while stack:
                y, x = stack.pop()
                if 0 <= y < win.shape[0] and 0 <= x < win.shape[1] and win[y, x] and not lab[y, x]:
                    lab[y, x] = n
                    stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
        _masks[key] = (sky, lab)
    return _masks[key]


def sky_beat(out, s, cfg, t, S):
    ink, cream, red = C(INK), C(CREAM), C(RED)
    beat = math.floor(t)
    tb = (t - beat) * 0.5                      # seconds since the beat
    p = rift(tb * 0.6)                         # Rift shape, a touch longer so it reads
    skym, winm = masks(cfg)
    def sky(X, Y):
        x, y = X // S, Y // S
        return 0 <= y < s.H and 0 <= x < s.W and skym[y, x] and np.all(out[Y, X, :3] == ink[:3])
    if p > 0:
        # a quarter of the stars twinkle on each beat, taking turns
        for i, (x, y, big) in enumerate(_stars(s, cfg)):
            if (i * 7 + beat) % 4 or not skym[y, x]:
                continue                       # hidden stars (behind a house) stay hidden
            arm = 1 + (2 if big else 1) * p
            for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                for k in range(1, int(round(arm)) + 1):
                    X, Y = int((x + dx * k) * S), int((y + dy * k) * S)
                    if sky(X, Y):
                        out[Y:Y + S, X:X + S] = cream if k == 1 else red
            X, Y = x * S, y * S
            out[Y:Y + S, X:X + S] = cream
        # the moon: a dotted halo of light opens round it and fades
        if not cfg.get('moon_beat', True):
            return
        mx, my, mr = s.W * 0.22, s.H * 0.15, s.W * 0.06
        for (rr, col, keep) in ((mr + 1.5 + 2 * (1 - p), cream, 0.45), (mr + 3.5 + 3 * (1 - p), red, 0.8)):
            if p < keep:
                continue
            n = int(2 * math.pi * rr * 1.2)
            for a in range(n):
                if a % 2:
                    continue
                ang = a / n * 2 * math.pi
                X, Y = int((mx + math.cos(ang) * rr) * S), int((my + math.sin(ang) * rr) * S)
                if sky(X, Y):
                    out[Y:Y + S, X:X + S] = col


# --- round 19: more juice in the world ---------------------------------------------------
def world_juice(out, s, cfg, t, S, lv, since_up):
    ink, cream, red = C(INK), C(CREAM), C(RED)
    skym, winm = masks(cfg)
    beat = math.floor(t)
    tb = (t - beat) * 0.5
    # 1. embers: thrown up by the fire on each beat, drifting up and out, more at higher combo
    by = s.vpy + s.H * 0.012
    for b in range(beat - 5, beat + 1):
        age = (t - b) * 0.5                    # seconds since that beat
        if age < 0:
            continue
        r = np.random.default_rng(b * 13 + 5000)
        for k in range(2 * lv):
            life = 1.4 + r.random() * 1.2
            if age > life:
                continue
            vx = (r.random() - 0.5) * 30
            vy = 26 + r.random() * 22
            x = s.vpx + vx * age + 4 * math.sin(age * 3 + k)
            y = by - 12 - vy * age + 4 * age * age
            if y < s.H * 0.05 or y > s.vpy:
                continue
            col = cream if age < life * 0.35 else red
            if age > life * 0.75 and (int(t * 30) + k) % 2:
                continue                       # flickers out
            X, Y = int(x * S), int(y * S)
            if 0 <= X < out.shape[1] - S and 0 <= Y < out.shape[0] - S:
                out[Y:Y + S, X:X + S] = col
    # 2. windows catch the fire's flare: a few flash cream on each beat
    p = rift(tb * 0.8)
    if p > 0.35 and cfg.get('window_flash', True):
        ys, xs = np.nonzero(winm)
        pick = (winm[ys, xs] * 7 + beat * 3) % 4 == 0
        for (y, x) in zip(ys[pick], xs[pick]):
            out[y * S:(y + 1) * S, x * S:(x + 1) * S] = cream
    # 3. on a level-up, sparks burst out of the combo and fall away
    if since_up is not None and since_up < 0.5:
        cx, cy = s.W / 2, 24 + 10.5
        r = np.random.default_rng(int(t // cfg['levels']) + 77)
        for k in range(22):
            ang = k / 22 * 2 * math.pi + r.random() * 0.2
            sp = 40 + r.random() * 30
            x = cx + math.cos(ang) * sp * since_up * 1.3
            y = cy + math.sin(ang) * sp * since_up * 0.8 + 60 * since_up * since_up
            if since_up > 0.35 and k % 2:
                continue
            X, Y = int(x * S), int(y * S)
            n = 2 * S if since_up < 0.15 else S
            if 0 <= X < out.shape[1] - n and 0 <= Y < out.shape[0] - n:
                out[Y:Y + n, X:X + n] = cream if k % 3 else red


# --- round 20: health - heart notes, hearts in the HUD, the screen darkens in danger ---
HEART = ['.##.##.', '#######', '#######', '.#####.', '..###..', '...#...']


def heart_sprite(w):
    """A healing step: the same flat stamp as a step note, with a heart standing upright on it."""
    w = max(4, int(round(w)))
    key = ('heart_up', w)
    if key not in _sprites:
        hh = max(4, int(round(w * 0.62)))       # the standing heart's height
        h = int(w * 0.36 + w * 0.08) + 6 + hh + 2
        m = Mini(w + 6, h)
        m.img[...] = 0
        cx, cy = (w + 6) / 2, hh + 2 + w * 0.18 + 2.5
        rx = w / 2
        ry = max(1.5, rx * 0.36)
        th = max(1, round(w * 0.08))
        outer = lino.ellipse_mask(m, cx, cy + th, rx + 1, ry + 1) | lino.ellipse_mask(m, cx, cy, rx + 1, ry + 1)
        m.fill(outer, INK)
        m.fill(lino.ellipse_mask(m, cx, cy + th, rx, ry), RED)
        m.fill(lino.ellipse_mask(m, cx, cy, rx, ry), CREAM)
        m.fill(lino.ellipse_mask(m, cx, cy, max(1, rx * 0.3), max(0.8, ry * 0.32)), INK)   # its shadow
        # the heart, upright, point resting on the middle of the face
        hw = hh * 0.62
        hcy = cy - hh * 0.55
        x = (m.X - cx) / hw * 1.15
        y = -((m.Y - hcy) / (hh * 0.5)) * 1.15
        core = (x * x + y * y - 1) ** 3 - x * x * y ** 3 <= 0
        k1 = core.copy(); k1[1:] |= core[:-1]; k1[:-1] |= core[1:]; k1[:, 1:] |= core[:, :-1]; k1[:, :-1] |= core[:, 1:]
        m.fill(k1 & ~core, INK)
        m.fill(core, RED)
        if hh >= 7:
            m.fill(core & (np.hypot(x + 0.45, y - 0.4) < 0.25), CREAM)
        _sprites[key] = (m.img.copy(), cx, cy)
    return _sprites[key]


def stomp_sprite(w):
    """A stomp (both thumbs on one button): a black stamp with a pair of bare feet standing on it,
    soles to the player, so it reads from far up the road like the heart."""
    w = max(4, int(round(w)))
    key = ('stomp_up', w)
    if key not in _sprites:
        hh = max(5, int(round(w * 0.66)))       # the feet's height
        h = int(w * 0.36 + w * 0.08) + 6 + hh + 2
        m = Mini(w + 6, h)
        m.img[...] = 0
        cx, cy = (w + 6) / 2, hh + 2 + w * 0.18 + 2.5
        rx = w / 2
        ry = max(1.5, rx * 0.36)
        th = max(1, round(w * 0.08))
        outer = lino.ellipse_mask(m, cx, cy + th, rx + 1, ry + 1) | lino.ellipse_mask(m, cx, cy, rx + 1, ry + 1)
        m.fill(outer, CREAM)
        m.fill(lino.ellipse_mask(m, cx, cy + th, rx, ry), RED)
        m.fill(lino.ellipse_mask(m, cx, cy, rx, ry), INK)
        # an upright cream tablet with the middle button's two feet on it, standing on the stamp
        tw, tb = hh * 1.0, cy + ry * 0.2
        tab = (np.abs(m.X - cx) <= tw / 2) & (m.Y >= tb - hh) & (m.Y <= tb)
        corner = (np.abs(m.X - cx) > tw / 2 - 1.5) & (m.Y < tb - hh + 1.5)
        tab &= ~corner
        k1 = tab.copy(); k1[1:] |= tab[:-1]; k1[:-1] |= tab[1:]; k1[:, 1:] |= tab[:, :-1]; k1[:, :-1] |= tab[:, 1:]
        m.fill(k1 & ~tab, INK)
        m.fill(tab, CREAM)
        pal = dict(lino3.W2['pal'], foot=INK, btn_face=[CREAM, CREAM])
        fs = hh * 0.82
        scene.draw_foot(m, {'pal': pal}, cx - fs * 0.24, tb - hh * 0.52, fs, mirror=True)
        scene.draw_foot(m, {'pal': pal}, cx + fs * 0.24, tb - hh * 0.52, fs, mirror=False)
        if hh >= 9:
            m.fill(tab & (m.Y > tb - 1.5), RED)      # a red foot of the tablet
        _sprites[key] = (m.img.copy(), cx, cy)
    return _sprites[key]


def health_at(cfg, t):
    """Health (0-10) at beat t in the demo, eased over 0.3 s after each change."""
    tl = cfg['health_demo']
    v = tl[0][1]
    for (b, hp) in tl[1:]:
        if t >= b:
            u = _ss((t - b) * 0.5 / 0.3)
            v = v + (hp - v) * u
    return v


def danger(out, s, cfg, t, S, hp):
    """At 4 health and below the street darkens toward its edges, step by step, in lino
    dither. The notes and the hit rings stay lit, so the eye goes where it has to."""
    D = min(1.0, max(0.0, (3.6 - hp) / 2.6))      # starts at 3 health, darkest at 1
    if D <= 0:
        return
    tb = ((t - math.floor(t)) * 0.5)
    D *= 0.92 + 0.08 * rift(tb)                 # a heartbeat in the dark
    H, W = s.H, s.W
    ex = (s.X - s.vpx) / (W * 0.5)
    ey = (s.Y - H * 0.6) / (H * 0.55)
    edge = np.clip(np.hypot(ex, ey), 0, 1.2) / 1.2
    L = D * (0.6 + 0.4 * edge)
    th = BAYER[s.Yi % 4, s.Xi % 4]
    for ln in range(3):                         # the hit rings stay lit
        rx = lino.lane_w(s, s.hity) * 0.43 + 3
        e = ((s.X - s.lane_x(ln, s.hity)) / rx) ** 2 + ((s.Y - s.hity) / (rx * 0.36 + 2)) ** 2
        L = np.where(e <= 1, 0, L)
    L = np.where(s.Y >= s.btn_top - 1, np.minimum(L, 0.32), L)  # the buttons stay easy to find
    to_ink = th < L * 0.95
    to_mid = (th < L * 2.5) & ~to_ink               # at full dark nothing but the notes stays bright
    ink, mid = C(INK), C('#4a3c38')
    ink_s, mid_s = up(to_ink, S), up(to_mid, S)
    o = out[..., :3]
    is_ink = np.all(o == ink[:3], axis=-1)
    out[ink_s] = ink
    out[mid_s & ~is_ink] = mid


def hearts_hud(out, s, t, S, hp):
    """Five hearts under the progress bar; each holds 2 health. The last one beats when low."""
    ink, cream, red, dim = C(INK), C(CREAM), C(RED), C('#4a3c38')
    hpi = int(round(hp))
    beat_p = rift(((t - math.floor(t)) * 0.5))
    for i in range(5):
        x0, y0 = 3 + i * 9, 9
        fill = max(0, min(2, hpi - 2 * i))
        big = hpi <= 3 and fill > 0 and (2 * (i + 1) >= hpi) and beat_p > 0.5
        for yy, row in enumerate(HEART):
            for xx, c in enumerate(row):
                if c != '#':
                    continue
                for (ddx, ddy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    X, Y = (x0 + xx + ddx) * S, (y0 + yy + ddy) * S
                    if not (0 <= yy + ddy < 6 and 0 <= xx + ddx < 7 and HEART[yy + ddy][xx + ddx] == '#'):
                        out[Y:Y + S, X:X + S] = cream if big else ink
        for yy, row in enumerate(HEART):
            for xx, c in enumerate(row):
                if c != '#':
                    continue
                on = fill == 2 or (fill == 1 and xx < 4)
                col = red if on else dim
                if on and (xx, yy) == (1, 1):
                    col = cream
                X, Y = (x0 + xx) * S, (y0 + yy) * S
                out[Y:Y + S, X:X + S] = col


# --- round 17: hit juice, kept to the hit line and the buttons ---------------------------
def _hits(t, window=0.35):
    """(seconds since hit, kind, lane) for every hit, hold end and bell in the last window."""
    out = []
    for rep in range(-1, int(t // scene.LOOP) + 2):
        for (bt, kind, lane, ln) in scene.PATTERN:
            for when, what in ((bt, kind), ) + (((bt + ln, 'hold_end'),) if ln else ()):
                b = when + rep * scene.LOOP
                th = (t - b) * 0.5
                if 0 <= th < window:
                    out.append((th, what, lane))
    return out


def _px(out, x, y, col, S, size=1):
    xi, yi = int(round(x)), int(round(y))
    n = S * size
    if 0 <= yi < out.shape[0] - n and 0 <= xi < out.shape[1] - n:
        out[yi:yi + n, xi:xi + n] = col


def juice(out, s, t, S, misses=(), stomps=()):
    ink, cream, red = C(INK), C(CREAM), C(RED)
    H, W = s.H, s.W
    gap = max(1, round(W * 0.02)); bw = (W - 4 * gap) / 3
    top = int(s.btn_top)
    for (th, kind, lane) in _hits(t):
        if any(abs(((t - th * 2) % scene.LOOP) - sb) < 0.01 for sb in stomps) and kind != 'hold_end':
            kind = 'stomp'
        lanes = (0, 1, 2) if kind == 'bell' else (lane,)
        if any(abs((t - th * 2) - m) < 0.01 for m in misses):
            if th < 0.25:                      # a miss: the ring cracks in black and red
                for ln in lanes:
                    cx, cy = s.lane_x(ln, s.hity) * S, s.hity * S
                    rx = lino.lane_w(s, s.hity) * 0.43 * S
                    for q in np.linspace(-1, 1, 15):
                        for sg in (1, -1):
                            _px(out, cx + q * rx * 0.5, cy + sg * q * rx * 0.2, red if abs(q) > 0.6 else ink, S, 2)
            continue
        for ln in lanes:
            cx, cy = s.lane_x(ln, s.hity) * S, s.hity * S
            rx = lino.lane_w(s, s.hity) * 0.43 * S
            ry = rx * 0.36
            # 1. a carved star: eight short cuts flying out flat from the ring, 0.14 s
            if th < 0.14:
                k = th / 0.14
                for a in range(8):
                    ang = a * math.pi / 4 + math.pi / 8
                    ca, sa = math.cos(ang), math.sin(ang)
                    if sa < -0.3 and kind != 'bell':
                        sa *= 0.4                       # keep the cuts off the incoming notes
                    r0 = 1.12 + 0.6 * _ss(k)
                    ln_ = 0.55 * (1 - k) + 0.12
                    for q in np.linspace(0, ln_, 10):
                        _px(out, cx + ca * rx * (r0 + q), cy + sa * ry * (r0 + q) * 1.8, cream if q < ln_ * 0.6 else red, S, 2 if q < ln_ * 0.4 else 1)
            # 2. a shock ring spreading from the hit ring, dashed as it fades, 0.2 s
            if th < 0.2:
                k = th / 0.2
                e = 1.15 + 0.6 * _ss(k)
                for a in np.linspace(0, 2 * math.pi, 64, endpoint=False):
                    if k > 0.5 and int(a * 10) % 2:
                        continue
                    _px(out, cx + math.cos(a) * rx * e, cy + math.sin(a) * ry * e, red if kind in ('bell', 'stomp') else cream, S, 2 if kind == 'stomp' else 1)
            # 3. wood chips: a few red and cream flecks thrown out and falling, 0.35 s
            r = np.random.default_rng((int(round((t - th * 2) * 2)) + 1000) * 31 + ln * 7 + (kind == 'bell'))
            for c in range(6 if kind != 'hold_end' else 3):
                vx = (r.random() - 0.5) * rx * 5.5
                vy = -(0.4 + r.random() * 0.8) * ry * 6
                x = cx + vx * th
                y = cy + vy * th + 0.5 * (ry * 60) * th * th
                _px(out, x, y, red if c % 2 else cream, S, 2 if th < 0.2 else 1)
        # 4. the pressed button sinks a pixel and its border lights, 0.12 s
        if kind != 'hold_end' and th < 0.12:
            for ln in lanes:
                x0 = int((gap + ln * (bw + gap)) * S); x1 = int((gap + ln * (bw + gap) + bw) * S)
                y0 = int((top + gap) * S); y1 = int(H * 0.985 * S)
                blk = out[y0:y1, x0:x1].copy()
                out[y0 + S:y1, x0:x1] = blk[:-S]
                out[y0:y0 + S, x0:x1] = ink
                bdr = np.all(out[y0:y1, x0:x1, :3] == red[:3], axis=-1)
                out[y0:y1, x0:x1][bdr] = cream
    # 5. a bell lands with a one-pixel thump of the whole street, 0.06 s
    for (th, kind, lane) in _hits(t, 0.06):
        if kind == 'bell' or any(abs(((t - th * 2) % scene.LOOP) - sb) < 0.01 for sb in stomps):
            out[S:] = out[:-S].copy()
            break


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
R16 = dict(R15, name='r16_houses', wall_flat=True)

# round 17: juice on hits
R17 = dict(R16, name='r17_juice', juice=True)

# round 18: stars and the moon keep time
R18 = dict(R17, name='r18_sky', sky_beat=True)

# round 19: no moon pulse, stars only on open sky, embers, window flares, level-up sparks
R19 = dict(R18, name='r19_juice', moon_beat=False, world_juice=True)

# round 20: a heart for the healing step, hearts in the HUD, the street darkens at 4 health and below
R20 = dict(R19, name='r20_health', levels=100,
           health_demo=[(0, 5), (2.0, 4), (4.5, 3), (7.0, 2), (10.0, 1), (13.0, 3)],
           misses=(2.0, 4.5, 7.0, 10.0), heal_beats=(13.0,))

# round 21: a heart heals 4 (two hearts), the heart sits in a ring, the dark starts at 3
R21 = dict(R20, name='r21_health', health_demo=[(0, 5), (2.0, 4), (4.5, 3), (7.0, 2), (10.0, 1), (13.0, 5)])

# round 22: the heart is carved on a step note's stamp
R22 = dict(R21, name='r22_heart_stamp')

# round 23: the heart stands upright on the stamp
R23 = dict(R22, name='r23_heart_up')

# round 24: deeper danger dark, windows dark and still
R24 = dict(R23, name='r24_dark', window_flash=False, pal=dict(R23['pal'], win_lit='#141014'))

# round 25: a stomp note with a pair of feet standing on it (the middle lane, beat 7 of each bar)
R25 = dict(R24, name='r25_stomp', stomp_beats=(7.0,), misses=(2.0, 4.5, 6.0, 10.0),
           health_demo=[(0, 5), (2.0, 4), (4.5, 3), (6.0, 2), (10.0, 1), (13.0, 5)])

# round 26: notes and bars drawn clean at fixed sizes and scaled smoothly, a little bigger
R26 = dict(R25, name='r26_mip', mip=True)

# round 27: three readability options
R27 = {'a': dict(R26, name='r27_a', look='a', note_floor=9),
       'b': dict(R26, name='r27_b', look='b', note_floor=10),
       'c': dict(R26, name='r27_c', look='c', note_floor=10)}

# round 28: option D - notes and bars at screen resolution, the world stays chunky lino
R28 = dict(R26, name='r28_d', look='d', note_floor=10)

# round 29: the standard (round 25) stamps and bars, drawn at screen resolution
R29 = dict(R26, name='r29_std_hi', look='std_hi')

# round 30: the heart and the two feet join the high-res stamps; all notes drawn 2 screen px per pixel
R30 = dict(R29, name='r30_signs', sign_hi=True, hi_px=2)
