"""Turns a Song's events into stems, a stereo mix and a mastered OGG file."""
from __future__ import annotations

import os

import numpy as np
import soundfile as sf

import dsp
from dsp import SR
from instruments import RENDERERS

# gain, pan, reverb send
MIX = {
    "bassu": (0.95, -0.12, 0.18), "contra": (0.8, 0.14, 0.18), "mesu": (0.62, -0.3, 0.2),
    "boghe": (0.8, 0.04, 0.24), "calls": (0.75, 0.35, 0.3),
    "tumbu": (0.5, 0.0, 0.12), "mancosa": (0.95, -0.18, 0.16), "mancosedda": (0.72, 0.22, 0.16),
    "frame": (2.0, 0.18, 0.14), "rim": (2.0, 0.18, 0.14), "shake": (0.8, None, 0.25), "bass": (1.0, 0.0, 0.1), "stomp": (0.7, -0.1, 0.1),
    "clap": (0.55, 0.25, 0.2), "count": (0.6, 0.0, 0.05),
    "bells": (0.8, None, 0.25), "rope": (0.8, None, 0.1), "fire": (0.45, None, 0.0),
    "crowd": (0.6, None, 0.15),
    "kick": (0.75, 0.0, 0.0), "snare": (1.1, 0.0, 0.12), "hat": (0.6, 0.2, 0.05),
    "impact": (0.35, 0.0, 0.3), "riser": (0.25, 0.0, 0.2),
    "pad": (0.9, None, 0.2), "sub": (0.4, 0.0, 0.0), "lead": (1.0, -0.1, 0.22), "chop": (1.2, 0.15, 0.2),
    "arp": (0.6, 0.35, 0.25),
}

# instruments that keep sounding through a stand-still (sustains without new onsets)
THROUGH = {"fire", "crowd", "tumbu"}
DUCKED = {"pad", "sub"}
# ...but inside a stand-still the music really stops: the drone drops out and ringing drum tails
# are cut, so the rest is heard as a rest; the crowd only quietens, the fire keeps crackling
STOP_DUCK_DEFAULT = -40.0
STOP_DUCKED = {"tumbu": -30.0, "crowd": -14.0, "fire": 0.0, "rim": 0.0, "shake": 0.0, "calls": 0.0}


def automation_gain(song, n, b0, b1, db, ramp_s=0.08):
    """A level change over [b0, b1) with short ramps (remix drops and section layers)."""
    g = np.ones(n)
    a = int(round(song.time(b0) * SR))
    e = min(n, int(round(song.time(b1) * SR)))
    if e <= a or a >= n:
        return g
    r = min(int(ramp_s * SR), (e - a) // 3)
    low = 10 ** (db / 20)
    g[a:e] = low
    if r > 0:
        g[a:a + r] = np.linspace(1, low, r)
        g[e - r:e] = np.linspace(low, 1, r)
    return g


def stop_gain(song, n, db):
    """Gain curve that falls to db inside every stand-still (short ramps at both ends)."""
    g = np.ones(n)
    low = 10 ** (db / 20)
    ramp = int(0.05 * SR)
    for (sb, sl) in song.stops:
        a = int(round(song.time(sb) * SR)) + int(0.01 * SR)
        e = int(round(song.time(sb + sl) * SR)) - int(0.005 * SR)   # back up just before the next beat
        b = e - ramp
        if b <= a or a >= n:
            continue
        a1 = min(n, a + ramp)
        g[a:a1] = np.minimum(g[a:a1], np.linspace(1, low, a1 - a))
        g[a1:b] = low
        e = min(n, e)
        if e > b:
            g[b:e] = np.minimum(g[b:e], np.linspace(low, 1, e - b))
    return g


def apply_stops(song):
    """Silence everything but sustaining ambience inside each stand-still window."""
    if not song.stops:
        return list(song.events)
    out = []
    through = THROUGH | getattr(song, "through", set())
    for e in song.events:
        if e.inst in through:
            out.append(e)
            continue
        keep = True
        for (sb, sl) in song.stops:
            if sb - 1e-6 <= e.b < sb + sl - 1e-6:
                keep = False
                # a bell's cue and the temptations sound inside the stand-still, on their own stems
                # so the stand-still's ducking leaves them alone
                if e.p.get("cue") or e.p.get("tempt") or (e.inst == "calls" and e.p.get("kind") != "hup"):
                    inst = {"frame": "rim", "bells": "shake"}.get(e.inst, e.inst)
                    e = type(e)(inst, e.b, e.dur, e.pitch, e.vel, e.p)
                    keep = True
                break
            if e.b < sb and e.b + e.dur > sb - 0.05:
                # a note running into the rest is cut just before it
                e = type(e)(e.inst, e.b, max(0.05, sb - e.b - 0.12), e.pitch, e.vel, e.p)
        if keep:
            out.append(e)
    return out


def total_samples(song):
    return int(round((song.time(song.end_b) + song.tail) * SR))


def render_stems(song):
    n = total_samples(song)
    evs = apply_stops(song)
    by = {}
    for e in evs:
        by.setdefault(e.inst, []).append(e)
    stems = {}
    for inst, lst in by.items():
        y = RENDERERS[inst](song, lst, n)
        stems[inst] = y
    return stems, n


def mix(song, stems, n):
    dry = np.zeros((n, 2))
    wet_in = np.zeros((n, 2))
    over = getattr(song, "mix", {}) or {}
    kick_env = None
    if "kick" in stems:
        kick_env = dsp.envelope_follow(stems["kick"], 0.001, 0.12)
        kick_env = kick_env / (kick_env.max() + 1e-9)
    for inst, y in stems.items():
        g, p, send = MIX[inst]
        g *= over.get(inst, 1.0)
        st = y * g if y.ndim == 2 else dsp.pan(y * g, p if p is not None else 0.0)
        if kick_env is not None and inst in DUCKED:
            st = st * (1 - 0.6 * kick_env)[:, None]
        for (a0, a1, db, insts) in getattr(song, "automation", []):
            if inst in insts:
                st = st * automation_gain(song, len(st), a0, a1, db)[:, None]
        duck = STOP_DUCKED.get(inst, STOP_DUCK_DEFAULT)
        if song.stops and duck < 0:
            st = st * stop_gain(song, len(st), duck)[:, None]
        dry += st
        wet_in += st * send
    rv = song.reverb
    ir = dsp.reverb_ir(rv["t60"], rv.get("predelay", 0.015), rv.get("bright", 6000), 7,
                      tuple(rv.get("early", ())))
    wet = dsp.convolve_reverb(wet_in, ir) * rv.get("wet", 1.0)
    out = dry + wet
    out = dsp.highpass(out, 28)
    # leave room for the player's bells and steps: a gentle, wide dip where they live
    out = dsp.peaking(out, 2300, -2.0, 0.8)
    # a little air on top: the reeds' and bells' shimmer, the voices' breath
    out = dsp.peaking(out, 7500, 2.5, 0.6)
    # keep the tail tidy
    fade = int(min(song.tail, 2.5) * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return out


def master(x, target=-14.0, ceiling=-1.5):
    """Loudness to target and true peak under the ceiling together: the limiter's own ceiling is
    lowered while true peaks still get through, and the loudness is brought back each pass."""
    c = ceiling
    y = x
    for _ in range(16):
        lk = dsp.integrated_loudness(y)
        y = dsp.limiter(y * 10 ** ((target - lk) / 20), c)
        tp = dsp.true_peak_db(y)
        if abs(dsp.integrated_loudness(y) - target) < 0.15 and tp <= ceiling + 0.2:
            break
        if tp > ceiling + 0.2:
            c -= 0.7 * (tp - ceiling)
    return y


def write_ogg(path, x, quality=0.45):
    """Vorbis at the given quality (libsndfile compression level = 1 - quality)."""
    # written in one-second blocks: libsndfile's Vorbis encoder crashes on one huge write
    x = np.ascontiguousarray(x, dtype=np.float32)
    with sf.SoundFile(path, "w", SR, x.shape[1], format="OGG", subtype="VORBIS",
                      compression_level=1 - quality) as f:
        for i in range(0, len(x), SR):
            f.write(x[i:i + SR])
    y, _ = sf.read(path, always_2d=True)
    return y


def save_stems(stems, dirpath):
    os.makedirs(dirpath, exist_ok=True)
    for inst, y in stems.items():
        m = y.mean(axis=1) if y.ndim == 2 else y
        sf.write(os.path.join(dirpath, inst + ".flac"), (m / max(1.0, np.max(np.abs(m)))).astype(np.float32),
                 SR, subtype="PCM_24")
