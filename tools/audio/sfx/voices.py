"""Synthesized voices: the Issohadore's call and the crowd murmur. No words: only
vowel shapes, pitch contours and breath, made with a source-filter model
(harmonic glottal source with vocal-effort tilt, jitter and shimmer, through a
four-formant vocal tract), then placed in a stone street / piazza.

Run:  python3 tools/audio/sfx/voices.py
"""
from __future__ import annotations

import numpy as np
from scipy import signal

from dsp import (SR, convolve_ir, db, fade, formant_gain, highpass, loop_crossfade, lowpass,
                 make_ir, pan, shaped_noise, trim_tail, write_ogg, write_wav, bandpass)

HOP = 64
VOWELS = {  # adult male, raised effort (F1 goes up when shouting)
    "a": (830, 1300, 2600, 3500, 4400),
    "o": (600, 950, 2500, 3400, 4400),
    "e": (560, 1850, 2600, 3500, 4400),
    "u": (420, 820, 2400, 3300, 4400),
    "i": (380, 2150, 2900, 3600, 4400),
    "@": (560, 1450, 2500, 3400, 4400),
}
BW = np.array([90.0, 120.0, 240.0, 320.0, 450.0])


def interp_track(points, n_ctrl, hop_s):
    """points: [(time_s, value_or_tuple)] -> per-control-step array (n_ctrl, k)."""
    ts = np.array([p[0] for p in points])
    vs = np.array([np.atleast_1d(p[1]) for p in points], dtype=float)
    tc = np.arange(n_ctrl) * hop_s
    return np.stack([np.interp(tc, ts, vs[:, j]) for j in range(vs.shape[1])], axis=1)


def presence(f, amount):
    """Higher-pole correction: the four-pole cascade alone rolls off far too fast
    above F4; real voices (especially shouting) keep energy at 2-5 kHz."""
    return (1 + (f / 1000.0) ** 2) ** (0.5 * amount) * (1 + (f / 3000.0) ** 2) ** 1.5


def render_voice(f0c, formc, ampc, sr, rng, tilt=1.1, fmax=7000.0, breath=0.03,
                 jitter=0.01, shimmer=0.06, rough=0.0, fscale=1.0, pres=2.0):
    """f0c (n_ctrl,), formc (n_ctrl, 5), ampc (n_ctrl,) at control rate HOP samples."""
    n_ctrl = len(f0c)
    n = n_ctrl * HOP
    tc = np.arange(n_ctrl) * HOP
    ta = np.arange(n)
    # jitter: slow random pitch wander; shimmer: amplitude flutter
    jit = signal.sosfiltfilt(signal.butter(2, 25, fs=sr / HOP, output="sos"), rng.standard_normal(n_ctrl)) * jitter * 3
    shim = signal.sosfiltfilt(signal.butter(2, 40, fs=sr / HOP, output="sos"), rng.standard_normal(n_ctrl)) * shimmer * 3
    f0c = f0c * (1 + jit)
    ampc = ampc * np.clip(1 + shim, 0.3, 2)
    f0 = np.interp(ta, tc, f0c)
    phase = 2 * np.pi * np.cumsum(f0) / sr
    out = np.zeros(n)
    formc = formc * fscale
    kmax = int(fmax / max(60.0, f0c.min()))
    for k in range(1, kmax + 1):
        fk = f0c * k
        g = formant_gain(fk, formc.T, BW) * k ** (-tilt) * presence(fk, pres)
        g[fk > fmax] = 0
        if g.max() < 1e-5:
            continue
        a = np.interp(ta, tc, g * ampc)
        out += a * np.sin(k * phase)
        if rough > 0 and k < kmax:
            # sub-harmonic roughness of a strained, loud voice
            gs = formant_gain(fk + f0c * 0.5, formc.T, BW) * (k + 0.5) ** (-tilt) * rough * presence(fk, pres)
            out += np.interp(ta, tc, gs * ampc) * np.sin((k + 0.5) * phase)
    # aspiration noise through the same vocal tract
    frames_t = None

    def shape(t, f):
        idx = np.clip((t * sr / HOP).astype(int), 0, n_ctrl - 1)
        return np.stack([formant_gain(f, formc[i], BW) * ampc[i] for i in idx]) * (f > 300) * presence(f, pres) / (1 + (f / 7000) ** 4)

    nz = shaped_noise(n, rng, shape, 512, 128)
    out += nz * breath * 8
    return out


def call(take: int) -> np.ndarray:
    """An Issohadore's shout across the street: rising, held, falling. Vowels only."""
    rng = np.random.default_rng([61, take])
    specs = [
        # (duration, f0 points, vowel points, amp points)
        (0.95, [(0, 165), (0.12, 250), (0.3, 300), (0.7, 285), (0.95, 205)],
         [(0, "o"), (0.22, "o"), (0.34, "a"), (0.95, "a")],
         [(0, 0), (0.025, 0.9), (0.2, 0.75), (0.27, 0.5), (0.33, 1.0), (0.75, 0.85), (0.95, 0)]),
        (0.85, [(0, 210), (0.15, 230), (0.25, 320), (0.65, 300), (0.85, 240)],
         [(0, "a"), (0.17, "a"), (0.26, "e"), (0.85, "e")],
         [(0, 0), (0.025, 0.9), (0.16, 0.7), (0.21, 0.4), (0.26, 1.0), (0.66, 0.85), (0.85, 0)]),
        (0.65, [(0, 190), (0.1, 280), (0.35, 330), (0.65, 250)],
         [(0, "o"), (0.28, "o"), (0.5, "i"), (0.65, "i")],
         [(0, 0), (0.025, 0.95), (0.4, 1.0), (0.65, 0)]),
        (1.05, [(0, 250), (0.1, 310), (0.5, 295), (0.8, 250), (1.05, 190)],
         [(0, "a"), (0.55, "a"), (0.8, "o"), (1.05, "u")],
         [(0, 0), (0.025, 1.0), (0.55, 0.9), (0.85, 0.6), (1.05, 0)]),
    ]
    dur, fpts, vpts, apts = specs[take % len(specs)]
    lead = 0.012
    total = dur + lead + 0.02
    n_ctrl = int(total * SR / HOP)
    hop_s = HOP / SR
    shift = lambda pts: [(t + lead, v) for t, v in pts]
    f0c = interp_track(shift(fpts) + [(total, fpts[-1][1])], n_ctrl, hop_s)[:, 0]
    # vibrato after the voice settles
    tc = np.arange(n_ctrl) * hop_s
    f0c *= 1 + 0.018 * np.sin(2 * np.pi * 5.6 * tc) * np.clip((tc - 0.25) / 0.2, 0, 1)
    formc = interp_track([(t, VOWELS[v]) for t, v in shift(vpts)] + [(total, VOWELS[vpts[-1][1]])], n_ctrl, hop_s)
    ampc = interp_track([(0, 0)] + shift(apts) + [(total, 0)], n_ctrl, hop_s)[:, 0]
    ampc = np.clip(ampc, 0, None) ** 1.1
    v = render_voice(f0c, formc, ampc, SR, rng, tilt=0.95, fmax=10000, breath=0.035, pres=2.3,
                     jitter=0.012, shimmer=0.07, rough=0.12)
    # an "h" of breath before the voice
    hn = int(0.03 * SR)
    h = bandpass(rng.standard_normal(hn), 700, 3500, 2) * np.hanning(hn) * 0.05 * np.max(np.abs(v))
    v[: hn] += h
    v = highpass(v, 90, 2)
    # stone street: slap echoes off the house fronts and a short tail
    ir = make_ir(1.2, 1.4, np.random.default_rng(71), stereo=False,
                 early=[(0.043, 0.35), (0.071, 0.25), (0.118, 0.18), (0.19, 0.1)], bright=3500, predelay=0.02)
    wet = convolve_ir(v, ir)
    out = np.zeros(len(wet))
    out[: len(v)] += v
    out += wet * db(-7)
    return out


def crowd_loop(seconds: float = 24.0, xf: float = 2.0, voices: int = 26) -> np.ndarray:
    """Murmur of a crowd lining the street: many unintelligible voices at a distance."""
    sr = 22050  # rendered at half rate (the crowd is far away and darkened), resampled after
    rng = np.random.default_rng(81)
    total = seconds + xf + 0.1
    n_ctrl = int(total * sr / HOP)
    hop_s = HOP / sr
    tc = np.arange(n_ctrl) * hop_s
    mix = np.zeros((n_ctrl * HOP, 2))
    fric = np.zeros((n_ctrl * HOP, 2))
    vnames = list(VOWELS)
    for v in range(voices):
        kind = rng.choice(["m", "m", "f", "f", "c"])
        f_base = {"m": rng.uniform(100, 135), "f": rng.uniform(185, 230), "c": rng.uniform(250, 300)}[kind]
        fscale = {"m": 1.0, "f": 1.15, "c": 1.28}[kind]
        f0c = np.full(n_ctrl, f_base)
        ampc = np.zeros(n_ctrl)
        formc = np.zeros((n_ctrl, 5))
        t = rng.uniform(-1.0, 0.5)
        onsets = []
        cur_vowel = np.array(VOWELS[rng.choice(vnames)])
        while t < total:
            # a phrase: a few syllables with falling intonation, then a pause
            nsyl = int(rng.integers(3, 12))
            decl = rng.uniform(0.75, 0.95)
            start_f = f_base * rng.uniform(1.05, 1.35)
            for s in range(nsyl):
                d = rng.uniform(0.11, 0.27)
                i0, i1 = int(max(t, 0) / hop_s), int(min(t + d, total) / hop_s)
                if i1 > i0 and rng.random() < 0.45:
                    onsets.append(i0 * HOP)
                if i1 > i0:
                    frac = s / max(1, nsyl - 1)
                    fsyl = start_f * (1 - (1 - decl) * frac) * rng.uniform(0.94, 1.08)
                    seg = i1 - i0
                    w = np.sin(np.pi * np.linspace(0, 1, seg)) ** 0.7
                    ampc[i0:i1] = np.maximum(ampc[i0:i1], w * rng.uniform(0.5, 1.0))
                    f0c[i0:i1] = fsyl * (1 + 0.06 * (np.linspace(0, 1, seg) - 0.5) * rng.uniform(-1, 1))
                    nv = np.array(VOWELS[rng.choice(vnames)])
                    formc[i0:i1] = cur_vowel + (nv - cur_vowel) * np.linspace(0, 1, seg)[:, None] ** 0.5
                    cur_vowel = nv
                t += d
            t += rng.uniform(0.25, 1.8)
        formc[formc == 0] = np.array(VOWELS["@"])[None, :].repeat(n_ctrl, 0)[formc == 0]
        # a laugh now and then
        if rng.random() < 0.35:
            lt = rng.uniform(1, total - 2)
            for j in range(int(rng.integers(3, 6))):
                i0 = int((lt + j * 0.17) / hop_s)
                i1 = min(n_ctrl, i0 + int(0.11 / hop_s))
                ampc[i0:i1] = np.maximum(ampc[i0:i1], np.sin(np.pi * np.linspace(0, 1, i1 - i0)) * 0.9)
                f0c[i0:i1] = f_base * 1.5 * (1 - 0.04 * j)
                formc[i0:i1] = VOWELS["a"]
        y = render_voice(f0c, formc, ampc, sr, rng, tilt=1.35, fmax=4200, breath=0.05,
                         jitter=0.02, shimmer=0.08, fscale=fscale)
        dist = rng.uniform(0.5, 1.0)
        y = y / (np.std(y) + 1e-9) * (0.35 + 0.65 * dist) * rng.uniform(0.6, 1.0)
        p = rng.uniform(-0.9, 0.9)
        mix += pan(y, p)
        # consonant-like noise onsets (s, sh, t: not words, just the grain of speech)
        fr = np.zeros(len(y))
        for o in onsets:
            m = int(rng.uniform(0.03, 0.07) * sr)
            if o + m < len(fr):
                fr[o:o + m] += rng.standard_normal(m) * np.hanning(m) * rng.uniform(0.3, 1.0)
        fr = bandpass(fr, 2500, min(7000, sr * 0.45), 2) if sr > 16000 else fr
        fric += pan(fr * (0.35 + 0.65 * dist) * 0.25, p)
    # the crowd is at a distance: dull highs, piazza reverb
    mix = signal.resample_poly(mix, 2, 1, axis=0)
    mix = lowpass(mix, 3200, 2)
    # consonants are rendered at half rate too: move them up to 3-8 kHz at full rate
    fric = signal.resample_poly(fric, 2, 1, axis=0)
    n2 = len(fric)
    hf = np.stack([bandpass(np.random.default_rng(84 + c).standard_normal(n2), 3000, 8000, 2) for c in range(2)], axis=1)
    env = np.sqrt(lowpass(fric ** 2, 40, 1).clip(0))
    mix += hf * env * 0.6
    # shuffling feet and rustle bed
    n = len(mix)
    bed = np.stack([lowpass(highpass(rng.standard_normal(n), 150, 1), 1500, 2) for _ in range(2)], axis=1)
    mix += bed * 0.08 * np.std(mix)
    ir = make_ir(1.6, 2.0, np.random.default_rng(83), stereo=True,
                 early=[(0.03, 0.2), (0.055, 0.15), (0.09, 0.1)], bright=3000, predelay=0.015)
    wet = convolve_ir(mix, ir)[:n]
    mix = mix * 0.7 + wet * 0.6
    L = int(seconds * SR)
    X = int(xf * SR)
    return loop_crossfade(mix[: L + X], L, X)


def main(which=("call", "crowd")) -> None:
    calls = [call(k) for k in range(4)]
    # equal loudness (RMS of the voiced part), then one gain so the loudest peak is -1.5 dBFS
    loud = [np.sqrt(np.mean(c[: int(0.6 * SR)] ** 2)) for c in calls]
    calls = [c / l for c, l in zip(calls, loud)]
    pk = max(np.max(np.abs(c)) for c in calls)
    for k, c in enumerate(calls):
        y = trim_tail(c * db(-1.5) / pk, -48, 0.1)
        write_wav(f"voice/call_{k + 1}.wav", fade(y, 0.002, 0.0))
    if "crowd" not in which:
        print("wrote calls")
        return
    crowd = crowd_loop()
    crowd = crowd * db(-26) / np.sqrt(np.mean(crowd ** 2))
    write_ogg("ambience/crowd.ogg", crowd, 0.3)
    print("wrote calls and crowd")


if __name__ == "__main__":
    main()
