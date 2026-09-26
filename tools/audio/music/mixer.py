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
    "frame": (2.0, 0.18, 0.14), "bass": (1.0, 0.0, 0.1), "stomp": (0.7, -0.1, 0.1),
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
    # keep the tail tidy
    fade = int(min(song.tail, 2.5) * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return out


def master(x, target=-14.0, ceiling=-1.5):
    for _ in range(8):
        lk = dsp.integrated_loudness(x)
        if abs(lk - target) < 0.15:
            break
        x = x * 10 ** ((target - lk) / 20)
        x = dsp.limiter(x, ceiling)
    for _ in range(4):
        tp = dsp.true_peak_db(x)
        if tp <= ceiling + 0.2:
            break
        x = dsp.limiter(x, ceiling - (tp - ceiling) - 0.1)
    return x


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
