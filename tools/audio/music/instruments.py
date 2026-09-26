"""Instrument synthesis. Each renderer takes the song, the instrument's events and the total
length in samples and returns a mono (N,) or stereo (N, 2) float array.

- Voices (canto a tenore style): glottal-pulse source with period doubling for the throat-sung
  bassu and contra, cascade formant filters on open vowels, consonant-like onsets (b, m).
- Launeddas style reeds: three continuous pipes (circular breathing), odd-harmonic reed tone,
  finger-articulation dips and grace taps for repeated notes.
- Frame drum, bass drum, stomps, claps, count-in sticks, procession bells, rope, calls, fire, crowd.
- Remix kit: kick, snare, hats, sub bass, supersaw pads, pluck lead, chopped voices, risers.
"""
from __future__ import annotations

import glob
import os

import numpy as np
import soundfile as sf
from scipy import signal
from scipy.ndimage import uniform_filter1d

from dsp import SR, add_at, bandpass, highpass, lowpass, peaking, pink, resonator, rng, smooth_noise

# ------------------------------------------------------------------ helpers


def mtof(m):
    return 440.0 * 2 ** ((np.asarray(m, dtype=float) - 69) / 12)


def s_of(song, b):
    return int(round(song.time(b) * SR))


def ffill(a):
    """Forward then backward fill NaNs."""
    idx = np.where(~np.isnan(a), np.arange(len(a)), 0)
    np.maximum.accumulate(idx, out=idx)
    out = a[idx]
    if np.isnan(out[0]):
        first = np.argmax(~np.isnan(out)) if (~np.isnan(out)).any() else 0
        out[:first] = out[first] if (~np.isnan(out)).any() else 100.0
    return out


# ------------------------------------------------------------------ voices

VOWELS = {
    "a": [(730, 90), (1090, 110), (2440, 150), (3400, 250), (4200, 300)],
    "o": [(560, 80), (850, 100), (2410, 150), (3400, 250), (4200, 300)],
    "e": [(520, 80), (1800, 110), (2480, 160), (3400, 250), (4200, 300)],
    "u": [(360, 70), (720, 90), (2400, 160), (3400, 250), (4200, 300)],
    "i": [(310, 70), (2150, 120), (2950, 170), (3500, 250), (4200, 300)],
    "m": [(260, 60), (1100, 350), (2300, 450), (3400, 450), (4200, 450)],
}

VOICE = {
    # mult: glottal f0 / sung pitch (2 = period doubled, the pitch heard is the subharmonic)
    "bassu": dict(mult=2.0, dbl=0.62, oq=0.32, fs=0.90, breath=0.015, jit=0.006, vib=0.0, gain=1.0,
                  lp=6500, rasp=(1400, 5.0, 1.2), close=0.04, buzz=0.08, edge=0.5),
    "contra": dict(mult=2.0, dbl=0.32, oq=0.36, fs=0.95, breath=0.012, jit=0.004, vib=0.0, gain=0.9,
                   lp=7000, rasp=(1900, 4.0, 1.5), close=0.05, buzz=0.06, edge=0.45),
    "mesu": dict(mult=1.0, dbl=0.0, oq=0.5, fs=1.0, breath=0.02, jit=0.003, vib=6.0, gain=0.8,
                 lp=7000, rasp=None),
    "boghe": dict(mult=1.0, dbl=0.0, oq=0.42, fs=1.04, breath=0.018, jit=0.003, vib=22.0, gain=1.0,
                  lp=9000, rasp=(2850, 6.0, 2.0)),
    "call": dict(mult=1.0, dbl=0.08, oq=0.3, fs=1.08, breath=0.05, jit=0.01, vib=0.0, gain=1.0,
                 lp=9000, rasp=(2600, 5.0, 1.5)),
    "crowd": dict(mult=1.0, dbl=0.0, oq=0.5, fs=1.0, breath=0.05, jit=0.01, vib=0.0, gain=1.0,
                  lp=5000, rasp=None),
}


def glottal(frac, oq, close=0.34):
    """Rosenberg glottal flow pulse over one period (frac in [0, 1)). A short closing phase
    (small close) is a pressed, buzzy voice: the sudden closure is rich in high harmonics."""
    tp = oq * (1 - close)
    tn = oq * close
    g = np.zeros_like(frac)
    m1 = frac < tp
    g[m1] = 0.5 * (1 - np.cos(np.pi * frac[m1] / tp))
    m2 = (frac >= tp) & (frac < tp + tn)
    g[m2] = np.cos(np.pi * (frac[m2] - tp) / (2 * tn))
    return g


def voice_line(song, events, n, kind, seed=1):
    """Render one monophonic voice from events carrying pitch, vowel, legato, accent."""
    prof = VOICE[kind]
    r = rng(seed)
    f0 = np.full(n, np.nan)
    amp = np.zeros(n)
    vib = np.zeros(n)
    weights = {}

    def w(v):
        if v not in weights:
            weights[v] = np.zeros(n)
        return weights[v]

    evs = sorted(events, key=lambda e: e.b)
    prev_pitch = None
    prev_end = -1
    for e in evs:
        s = s_of(song, e.b)
        end = s_of(song, e.b + e.dur)
        if end <= s:
            continue
        pitch = e.pitch
        legato = e.p.get("legato", False) and prev_end >= s - int(0.03 * SR)
        drone = e.p.get("drone", False)
        syll = e.p.get("syll", False)
        vel = e.vel
        pre = 0 if legato else int((0.05 if not syll else 0.035) * SR)
        a0 = max(0, s - pre)
        # pitch: scoop into the note (boghe), glide from the previous note when legato
        ln = end - a0
        seg = np.full(ln, float(pitch))
        if legato and prev_pitch is not None:
            gl = min(ln, int(0.045 * SR))
            seg[:gl] = prev_pitch + (pitch - prev_pitch) * (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, gl)))
        elif kind == "boghe" and not syll:
            gl = min(ln, int(0.06 * SR))
            seg[:gl] -= 0.35 * (1 - np.linspace(0, 1, gl)) ** 2
        f0[a0:end] = seg
        # vibrato only on long notes, after a delay
        if prof["vib"] > 0 and e.dur * song.spb > 0.5:
            d0 = s + int(0.25 * SR)
            if d0 < end:
                ramp = np.clip(np.linspace(0, 3, end - d0), 0, 1)
                vib[d0:end] = np.maximum(vib[d0:end], ramp * prof["vib"])
        # amplitude envelope
        rel = int((0.07 if not syll else 0.03) * SR)
        att = int((0.012 if not drone else 0.014) * SR)
        env = np.ones(end + rel - s)
        if not legato:
            env[:att] = np.linspace(0, 1, att) ** 1.5
        if syll:  # syllables decay a little, like "bam"
            env[: end - s] *= np.exp(-np.arange(end - s) / (SR * max(0.15, e.dur * song.spb * 1.5)))
            env[: end - s] = 0.55 + 0.45 * env[: end - s]
        if e.p.get("accent"):
            k = min(len(env), int(0.12 * SR))
            env[:k] *= 1 + 0.35 * np.exp(-np.arange(k) / (0.04 * SR))
        env[end - s:] = env[end - s - 1] * np.linspace(1, 0, rel) ** 2
        seg_end = min(n, end + rel)
        env = env[: seg_end - s]
        s_c = max(0, s)
        if legato:
            amp[s_c:seg_end] = np.maximum(amp[s_c:seg_end], vel * env[s_c - s:])
        else:
            # a new syllable cuts the previous one: later notes own their span
            amp[s_c:seg_end] = vel * env[s_c - s:]
        if pre:
            # a nasal murmur ("m"/"b") leading into the vowel: the vowel's attack is on the beat
            mur = np.linspace(0, 1, pre) ** 0.5 * 0.22 * vel
            prev_level = amp[a0 - 1] if a0 > 0 else 0.0
            # the previous vowel closes into the murmur over the first part of the consonant
            k = min(len(mur), int(0.015 * SR))
            mur[:k] = np.maximum(mur[:k], np.linspace(prev_level, mur[k - 1] if k else 0, k))
            amp[a0:s] = mur[-(s - a0):]
            w("m")[a0:s] = 1.0
        # vowels (several letters glide through the note)
        vs = e.p.get("vowel", "a")
        k = len(vs)
        bounds = np.linspace(s, seg_end, k + 1).astype(int)
        for i, v in enumerate(vs):
            w(v)[bounds[i]:bounds[i + 1]] = 1.0
            if pre:
                w(v)[a0:s] = 0.0
        prev_pitch = pitch
        prev_end = end

    if not evs:
        return np.zeros(n)
    f0 = ffill(f0)
    for v in weights:
        weights[v] = uniform_filter1d(weights[v], int(0.02 * SR))
    out = np.zeros(n)
    # synthesize only where the voice sounds (plus a margin), one segment at a time
    active = uniform_filter1d((amp > 0).astype(float), int(0.4 * SR)) > 0
    edges = np.flatnonzero(np.diff(np.concatenate([[0], active.astype(np.int8), [0]])))
    for a, b in zip(edges[::2], edges[1::2]):
        out[a:b] = _voice_segment(f0[a:b], amp[a:b], {v: wv[a:b] for v, wv in weights.items()},
                                  vib[a:b], prof, kind, r)
    return out


def _voice_segment(f0, amp, weights, vib, prof, kind, r):
    n = len(f0)
    drift = smooth_noise(n, 3, r) * 8 + smooth_noise(n, 30, r) * prof["jit"] * 1200 * 0.3
    vibwave = np.sin(2 * np.pi * 5.4 * np.arange(n) / SR + r.uniform(0, 6)) * uniform_filter1d(vib, 2000)
    freq = mtof(f0) * 2 ** ((drift + vibwave) / 1200) * prof["mult"]
    phase = np.cumsum(freq / SR)
    frac = phase % 1.0
    cyc = np.floor(phase).astype(np.int64)
    g = glottal(frac, prof["oq"], prof.get("close", 0.34))
    src = np.diff(g, prepend=0.0) / np.maximum(freq, 50) * 200
    if prof["dbl"] > 0:
        # period doubling: every other glottal cycle weaker, heard as the pitch an octave down
        src *= 1 + prof["dbl"] * np.where(cyc % 2 == 0, 1.0, -1.0)
    shimmer = 1 + smooth_noise(n, 40, r) * prof["jit"] * 4
    src *= shimmer
    src += bandpass(r.standard_normal(n), 800, 6000) * prof["breath"]
    # throat buzz: noise that pulses with the glottal cycle (the rattle of the false folds)
    if prof.get("buzz"):
        src += bandpass(r.standard_normal(n), 1500, 7000) * g * prof["buzz"]
    total = np.zeros(n)
    wsum = sum(weights.values()) + 1e-9
    for v, wv in weights.items():
        if wv.max() < 1e-3:
            continue
        y = src
        for (fc, bw) in VOWELS[v]:
            y = resonator(y, fc * prof["fs"], bw)
        # a fixed per-vowel gain (measured once on a reference source) keeps vowels level
        y = y * _vowel_gain(v, prof["fs"])
        if v == "m":
            y *= 0.6
        total += y * wv / wsum
    if prof["rasp"]:
        fc, gdb, q = prof["rasp"]
        total = peaking(total, fc, gdb, q)
    if prof.get("edge"):
        # the cascade rolls the top off; the buzzy edge of the source goes around it
        total += highpass(src, 1800) * prof["edge"]
    total = lowpass(highpass(total, 60 if kind != "bassu" else 35), prof["lp"])
    out = total * uniform_filter1d(amp, 64) * prof["gain"]
    return out / 3.0


_vg = {}


def _vowel_gain(v, fs):
    key = (v, fs)
    if key not in _vg:
        n = SR // 2
        ph = np.cumsum(np.full(n, 140.0) / SR)
        src = np.diff(glottal(ph % 1.0, 0.45), prepend=0.0) / 140 * 200
        y = src
        for (fc, bw) in VOWELS[v]:
            y = resonator(y, fc * fs, bw)
        _vg[key] = 1.0 / (np.sqrt(np.mean(y[n // 4:] ** 2)) + 1e-9)
    return _vg[key]


def render_voice(kind):
    def f(song, evs, n):
        return voice_line(song, evs, n, kind, seed=hash((song.id, kind)) % 1000)
    return f


CALL_SHAPES = {
    # kind: (start midi, end midi, vowels, seconds)
    "ohi": (62, 69, "oi", 0.5),
    "hup": (57, 55, "a", 0.16),
    "hei": (64, 67, "ei", 0.35),
    "aio": (60, 64, "aio", 0.7),
    "oo": (57, 62, "o", 0.9),
}


def render_calls(song, evs, n):
    """Issohadore and row shouts, rendered through the voice engine with a pressed, loud profile."""
    from score import Ev
    lines = []
    for e in evs:
        m0, m1, vw, sec = CALL_SHAPES[e.p.get("kind", "ohi")]
        m0 += e.p.get("shift", 0)
        m1 += e.p.get("shift", 0)
        dur_b = sec / song.spb
        steps = 6
        for i in range(steps):
            t = i / steps
            lines.append(Ev("calls", e.b + t * dur_b, dur_b / steps, m0 + (m1 - m0) * t ** 0.7, e.vel,
                            {"vowel": vw[min(len(vw) - 1, int(t * len(vw)))], "legato": i > 0,
                             "accent": i == 0}))
    if not lines:
        return np.zeros(n)
    return voice_line(song, lines, n, "call", seed=5) * 1.3


# ------------------------------------------------------------------ launeddas

PIPE = {
    "tumbu": dict(odd=0.95, even=0.10, nh=40, bright=0.9, noise=0.006, body=(900, 3.0)),
    "mancosa": dict(odd=0.80, even=0.14, nh=28, bright=1.0, noise=0.012, body=(1800, 4.0)),
    "mancosedda": dict(odd=0.75, even=0.16, nh=22, bright=1.0, noise=0.014, body=(2600, 4.0)),
}


def render_pipe(kind):
    def f(song, evs, n):
        prof = PIPE[kind]
        r = rng(hash((song.id, kind)) % 1000)
        freq = np.full(n, np.nan)
        amp = np.zeros(n)
        dips = np.zeros(n)
        evs = sorted(evs, key=lambda e: e.b)
        for i, e in enumerate(evs):
            s = s_of(song, e.b)
            end = s_of(song, e.b + e.dur)
            nxt = s_of(song, evs[i + 1].b) if i + 1 < len(evs) else None
            # circular breathing: bridge small gaps so the sound never stops mid-phrase
            if nxt is not None and 0 < nxt - end < 0.3 * song.spb * SR:
                end = nxt
            freq[s:end] = mtof(e.pitch)
            amp[s:end] = e.vel
            same = i > 0 and abs(evs[i - 1].pitch - e.pitch) < 0.01 and s_of(song, evs[i - 1].b + evs[i - 1].dur) >= s - 10
            if e.p.get("drone"):
                a = int(0.03 * SR)
                amp[s:s + a] *= np.linspace(0, 1, a)
            elif same or e.p.get("tap"):
                # a repeated note is re-struck with a quick grace tap on the note above
                g = int(0.016 * SR)
                freq[max(0, s - g):s] = mtof(e.pitch + e.p.get("tap_int", 2))
                dips[max(0, s - g):s + 20] = 0.35
            else:
                # finger articulation: a short dip in the reed's sound as the finger lifts
                k = int(0.012 * SR)
                dips[max(0, s - k):s + k // 3] = np.maximum(dips[max(0, s - k):s + k // 3], 0.55)
            if e.p.get("accent"):
                k = int(0.05 * SR)
                amp[s:s + k] *= 1.25
        if not evs:
            return np.zeros(n)
        freq = ffill(freq)
        freq = uniform_filter1d(freq, int(0.003 * SR))
        freq *= 2 ** ((smooth_noise(n, 0.7, r) * 4 + smooth_noise(n, 12, r) * 1.5) / 1200)
        amp = uniform_filter1d(amp, int(0.004 * SR)) * (1 - uniform_filter1d(dips, int(0.004 * SR)))
        # additive odd-harmonic reed via the sin(kx) recurrence (cheap and band-limited)
        x = 2 * np.pi * np.cumsum(freq / SR)
        s1 = np.sin(x)
        c2 = 2 * np.cos(x)
        s_prev, s_cur = np.zeros(n), s1
        out = np.zeros(n)
        bright = np.clip(amp, 0, 1.3) ** 0.5
        for k in range(1, prof["nh"] + 1):
            ak = (prof["odd"] / k ** 0.85) if k % 2 == 1 else (prof["even"] / k)
            ak = ak * bright ** (k * 0.04)
            mask = (k * freq < 15000).astype(float)
            out += ak * s_cur * mask
            s_prev, s_cur = s_cur, c2 * s_cur - s_prev
        out *= amp
        out += bandpass(r.standard_normal(n), 2500, 8000) * prof["noise"] * amp
        fc, g = prof["body"]
        out = peaking(out, fc, g, 1.2)
        out = highpass(out, 70)
        return out * 0.3
    return f


# ------------------------------------------------------------------ drums


def _t(sec):
    return np.arange(int(sec * SR)) / SR


def drum_hit(inst, hit, vel, r):
    if inst == "frame":
        if hit == "dum":
            t = _t(0.6)
            f = 92 * (1 + 0.6 * np.exp(-t / 0.012)) * r.uniform(0.98, 1.02)
            ph = 2 * np.pi * np.cumsum(f / SR)
            y = np.sin(ph) * np.exp(-t / 0.2) + 0.45 * np.sin(2.29 * ph) * np.exp(-t / 0.07)
            y += 0.25 * np.sin(3.6 * ph) * np.exp(-t / 0.04)
            y += lowpass(r.standard_normal(len(t)), 1500) * np.exp(-t / 0.008) * 0.6
            return y * vel
        if hit in ("tak", "slap"):
            t = _t(0.3)
            modes = [(310, 0.05), (590, 0.035), (880, 0.025), (1230, 0.018)]
            y = sum(np.sin(2 * np.pi * fm * r.uniform(0.98, 1.02) * t) * np.exp(-t / d) for fm, d in modes) * 0.35
            nz = bandpass(r.standard_normal(len(t)), 900 if hit == "tak" else 700, 6000)
            y += nz * np.exp(-t / (0.012 if hit == "tak" else 0.025)) * (0.9 if hit == "tak" else 1.6)
            return y * vel * (0.8 if hit == "tak" else 1.1)
        if hit == "rim":
            t = _t(0.15)
            y = np.sin(2 * np.pi * 1850 * t) * np.exp(-t / 0.018) * 0.6
            y += np.sin(2 * np.pi * 2710 * t) * np.exp(-t / 0.012) * 0.4
            y += bandpass(r.standard_normal(len(t)), 2000, 9000) * np.exp(-t / 0.004) * 1.2
            return y * vel * 0.8
    if inst == "bass":
        t = _t(1.2)
        f = 52 * (1 + 1.0 * np.exp(-t / 0.025)) * r.uniform(0.99, 1.01)
        ph = 2 * np.pi * np.cumsum(f / SR)
        y = np.sin(ph) * np.exp(-t / 0.5) + 0.3 * np.sin(1.47 * ph) * np.exp(-t / 0.25)
        y += 0.15 * np.sin(2.1 * ph) * np.exp(-t / 0.12)
        y += lowpass(r.standard_normal(len(t)), 2500) * np.exp(-t / 0.005) * 0.8
        return np.tanh(y * 1.3) * vel
    if inst == "stomp":
        t = _t(0.35)
        f = 70 * (1 + 0.8 * np.exp(-t / 0.01))
        y = np.sin(2 * np.pi * np.cumsum(f / SR)) * np.exp(-t / 0.07)
        y += bandpass(r.standard_normal(len(t)), 150, 2500) * np.exp(-t / 0.02) * 0.8
        return y * vel
    if inst == "clap":
        t = _t(0.3)
        env = np.zeros(len(t))
        for d in (0.0, 0.009, 0.018):
            i = int(d * SR)
            env[i:] += np.exp(-(t[: len(t) - i]) / 0.006)
        env += np.exp(-t / 0.06) * 0.4
        return bandpass(r.standard_normal(len(t)), 900, 7000) * env * vel * 0.9
    if inst == "count":
        # two sticks: bright and dry, pitched up on the first beat of the bar
        t = _t(0.12)
        f0 = 2400 if vel > 0.9 else 2000
        y = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.02) + 0.5 * np.sin(2 * np.pi * f0 * 1.51 * t) * np.exp(-t / 0.01)
        y += bandpass(r.standard_normal(len(t)), 2500, 10000) * np.exp(-t / 0.003)
        return y * vel * 0.7
    raise ValueError(inst + hit)


def fade_tail(y, sec=0.05):
    k = min(len(y), int(sec * SR))
    y = y.copy()
    y[-k:] *= np.linspace(1, 0, k) ** 2
    return y


def render_drum(inst):
    def f(song, evs, n):
        r = rng(hash((song.id, inst)) % 1000)
        out = np.zeros(n)
        for e in evs:
            y = fade_tail(drum_hit(inst, e.p.get("hit", "hit"), e.vel, r))
            add_at(out, y, s_of(song, e.b))
        return out
    return f


# ------------------------------------------------------------------ procession bells

_bell_bank = None


def bell_bank():
    """The Sound area's bell samples if present (game/audio/sfx/bells), else synthesized ones."""
    global _bell_bank
    if _bell_bank is not None:
        return _bell_bank
    here = os.path.dirname(os.path.abspath(__file__))
    d = os.path.normpath(os.path.join(here, "..", "..", "..", "game", "audio", "sfx", "bells"))
    bank = []
    for p in sorted(glob.glob(os.path.join(d, "*_perfect_*.wav")) + glob.glob(os.path.join(d, "*_good_*.wav"))):
        y, sr = sf.read(p, always_2d=True)
        y = y.mean(axis=1)
        if sr != SR:
            y = signal.resample_poly(y, SR, sr)
        bank.append(y / (np.max(np.abs(y)) + 1e-9))
    if not bank:
        r = rng(3)
        for i in range(12):
            bank.append(synth_bell(r.uniform(380, 900), r))
    _bell_bank = bank
    return bank


def synth_bell(f0, r, decay=0.9):
    t = _t(1.6)
    ratios = [1.0, 1.48, 2.31, 2.92, 3.71, 4.45, 5.62]
    y = np.zeros(len(t))
    for i, q in enumerate(ratios):
        y += np.sin(2 * np.pi * f0 * q * r.uniform(0.985, 1.015) * t + r.uniform(0, 6)) * np.exp(-t / (decay / (1 + i * 0.6))) / (1 + i * 0.5)
    y += bandpass(r.standard_normal(len(t)), 1500, 9000) * np.exp(-t / 0.006) * 0.8
    return y / np.max(np.abs(y))


def render_bells(song, evs, n):
    """A row of Mamuthones jumping: many bells struck within a few tens of ms, stereo spread."""
    r = rng(hash((song.id, "bells")) % 1000)
    bank = bell_bank()
    out = np.zeros((n, 2))
    for e in evs:
        count = e.p.get("count", 10)
        spread = e.p.get("spread", 0.035)
        s = s_of(song, e.b)
        for i in range(count):
            y = bank[r.integers(len(bank))]
            rate = 2 ** (r.uniform(-4, 3) / 12)
            y = signal.resample(y, int(len(y) / rate)) if abs(rate - 1) > 0.01 else y
            # the first bell strikes on the beat, the rest follow a little late
            d = 0 if i == 0 else int(abs(r.normal(0, spread)) * SR)
            g = e.vel * (1.0 if i == 0 else r.uniform(0.3, 0.8)) / np.sqrt(count) * 1.6
            p = r.uniform(-0.8, 0.8) * e.p.get("width", 1.0)
            a = (p + 1) * np.pi / 4
            add_at(out[:, 0], y * g * np.cos(a), s + d)
            add_at(out[:, 1], y * g * np.sin(a), s + d)
    return out


# ------------------------------------------------------------------ rope, fire, crowd


def render_rope(song, evs, n):
    """Whoosh sweeping across the stereo field in the throw's direction, cracking on the beat."""
    r = rng(11)
    out = np.zeros((n, 2))
    for e in evs:
        s = s_of(song, e.b)
        pre = int(0.38 * SR)
        t = np.linspace(0, 1, pre)
        nz = r.standard_normal(pre)
        # swept band: rising centre frequency and loudness
        y = np.zeros(pre)
        blocks = 16
        for i in range(blocks):
            a, b = i * pre // blocks, (i + 1) * pre // blocks
            fc = 300 * (10 ** (i / blocks * 1.1))
            seg = bandpass(nz[max(0, a - 400):b], fc * 0.6, fc * 1.8)[-(b - a):]
            y[a:b] = seg
        y *= t ** 2.2 * 0.8
        crack_t = _t(0.12)
        crack = bandpass(r.standard_normal(len(crack_t)), 1200, 9000) * np.exp(-crack_t / 0.012) * 1.6
        crack[:30] += np.hanning(60)[30:] * 1.5 * np.sign(r.standard_normal(30))
        d = e.p.get("dir", 1)
        pos = -d * (1 - t) + d * t * 0.6
        a = (pos + 1) * np.pi / 4
        add_at(out[:, 0], y * np.cos(a), s - pre)
        add_at(out[:, 1], y * np.sin(a), s - pre)
        ae = (d * 0.7 + 1) * np.pi / 4
        add_at(out[:, 0], crack * np.cos(ae) * e.vel, s)
        add_at(out[:, 1], crack * np.sin(ae) * e.vel, s)
    return out * 0.8


def render_fire(song, evs, n):
    """Bonfire ambience: low roar plus random crackles (stereo). Events give level over spans."""
    r = rng(hash((song.id, "fire")) % 1000)
    level = np.zeros(n)
    for e in evs:
        s, end = s_of(song, e.b), s_of(song, e.b + e.dur)
        s0, e0 = max(0, s), min(n, end)
        if e0 <= s0:
            continue
        ramp = np.ones(e0 - s0) * e.vel
        k = min(len(ramp) // 2, int(1.5 * SR))
        ramp[:k] *= np.linspace(0, 1, k)
        ramp[-k:] *= np.linspace(1, 0, k)
        level[s0:e0] = np.maximum(level[s0:e0], ramp)
    if level.max() == 0:
        return np.zeros((n, 2))
    out = np.zeros((n, 2))
    for ch in range(2):
        roar = lowpass(pink(n, r), 400) * (0.6 + 0.4 * smooth_noise(n, 0.8, r)) * 0.25
        hiss = bandpass(r.standard_normal(n), 3000, 9000) * 0.02 * (0.5 + 0.5 * smooth_noise(n, 2, r))
        out[:, ch] = roar + hiss
    # crackles: sparse, heavy-tailed amplitudes
    rate = 9.0
    count = int(n / SR * rate)
    pos = r.integers(0, n - 2000, count)
    for p in pos:
        ln = int(r.uniform(0.0008, 0.004) * SR)
        c = r.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 3)) * min(1.0, r.pareto(2.5) * 0.25 + 0.05)
        pn = r.uniform(0, 1)
        out[p:p + ln, 0] += c * (1 - pn)
        out[p:p + ln, 1] += c * pn
    out = highpass(out, 40)
    return out * level[:, None]


def render_crowd(song, evs, n):
    """Piazza crowd: a babble of formant voices on random syllables plus shaped noise and cheers."""
    from score import Ev
    r = rng(hash((song.id, "crowd")) % 1000)
    level = np.zeros(n)
    cheers = []
    for e in evs:
        if e.p.get("cheer"):
            cheers.append(e)
            continue
        s, end = max(0, s_of(song, e.b)), min(n, s_of(song, e.b + e.dur))
        if end > s:
            level[s:end] = np.maximum(level[s:end], e.vel)
    if level.max() == 0 and not cheers:
        return np.zeros((n, 2))
    level = uniform_filter1d(level, int(1.0 * SR))
    out = np.zeros((n, 2))
    total_s = n / SR
    for v in range(10):
        lines = []
        t = r.uniform(0, 1.0)
        base = r.uniform(48, 62)
        while t < total_s - 1:
            dur = r.uniform(0.12, 0.3)
            b = (t - song.offset) / song.spb
            lines.append(Ev("crowd", b, dur / song.spb, base + r.uniform(-3, 4), r.uniform(0.4, 1.0),
                            {"vowel": "aeiou"[r.integers(5)], "syll": True}))
            t += dur + (r.uniform(0.02, 0.1) if r.random() > 0.15 else r.uniform(0.4, 1.4))
        y = voice_line(song, lines, n, "crowd", seed=100 + v)
        p = r.uniform(-0.9, 0.9)
        a = (p + 1) * np.pi / 4
        out[:, 0] += y * np.cos(a)
        out[:, 1] += y * np.sin(a)
    for ch in range(2):
        out[:, ch] += bandpass(pink(n, r), 250, 3000) * 0.12 * (0.7 + 0.3 * smooth_noise(n, 3, r))
    out = lowpass(out, 6000) * level[:, None]
    for e in cheers:
        s = s_of(song, e.b)
        ln = int(e.dur * song.spb * SR)
        t = np.linspace(0, 1, ln)
        env = np.sin(np.pi * t) ** 0.7 * e.vel
        for ch in range(2):
            nz = bandpass(pink(ln, r), 400, 4000) * env
            add_at(out[:, ch], nz * 0.5, s)
    return out


# ------------------------------------------------------------------ remix kit


def low_hz(midi):
    """A pitch folded into the kick's range (35-70 Hz)."""
    f = 440.0 * 2 ** ((midi - 69) / 12)
    while f >= 70:
        f /= 2
    while f < 35:
        f *= 2
    return f


def kick(vel, r, style="808", hz=None):
    """808: a long, tuned boom (hz is the chord root); punch: a short thump tuned to the key."""
    if style == "808":
        t = _t(0.9)
        f = (hz or 46) + 110 * np.exp(-t / 0.035)
        y = np.sin(2 * np.pi * np.cumsum(f / SR)) * np.exp(-t / 0.45)
    else:
        t = _t(0.35)
        f = (hz or 52) + 140 * np.exp(-t / 0.02)
        y = np.sin(2 * np.pi * np.cumsum(f / SR)) * np.exp(-t / 0.14)
    y += lowpass(r.standard_normal(len(t)), 4000) * np.exp(-t / 0.002) * 0.5
    return np.tanh(y * 1.6) * vel


def snare(vel, r, style="snare"):
    t = _t(0.35)
    if style == "clap":
        env = np.zeros(len(t))
        for d in (0.0, 0.011, 0.022):
            i = int(d * SR)
            env[i:] += np.exp(-t[: len(t) - i] / 0.007)
        env += np.exp(-t / 0.09) * 0.6
        return bandpass(r.standard_normal(len(t)), 1000, 8000) * env * vel
    y = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05) * 0.6
    y += bandpass(r.standard_normal(len(t)), 1500, 9000) * np.exp(-t / (0.09 if style == "snare" else 0.05))
    return y * vel


def hat(vel, r, open_=False):
    t = _t(0.4 if open_ else 0.08)
    y = highpass(r.standard_normal(len(t)), 7000) * np.exp(-t / (0.12 if open_ else 0.018))
    return y * vel * 0.5


def render_kit(inst):
    def f(song, evs, n):
        r = rng(hash((song.id, inst)) % 1000)
        out = np.zeros(n)
        for e in evs:
            st = e.p.get("style", "")
            if inst == "kick":
                if (st or "808") == "808":
                    hz = low_hz(song.pitch(song.root_at(e.b)))
                else:
                    hz = low_hz(song.key_root)
                y = kick(e.vel, r, st or "808", hz)
            elif inst == "snare":
                y = snare(e.vel, r, st or "snare")
            elif inst == "hat":
                y = hat(e.vel, r, e.p.get("open", False))
            elif inst == "impact":
                t = _t(2.5)
                y = np.sin(2 * np.pi * np.cumsum((38 + 60 * np.exp(-t / 0.05)) / SR)) * np.exp(-t / 0.8)
                y += lowpass(r.standard_normal(len(t)), 1200) * np.exp(-t / 0.4) * 0.3
                y *= e.vel
            elif inst == "riser":
                ln = int(e.dur * song.spb * SR)
                t = np.linspace(0, 1, ln)
                nz = r.standard_normal(ln)
                y = np.zeros(ln)
                blocks = 24
                for i in range(blocks):
                    a, b = i * ln // blocks, (i + 1) * ln // blocks
                    fc = 400 * 2 ** (i / blocks * 4)
                    y[a:b] = bandpass(nz[max(0, a - 500):b], fc * 0.7, fc * 1.5)[-(b - a):]
                y *= t ** 2 * e.vel
                add_at(out, y, s_of(song, e.b))
                continue
            else:
                raise ValueError(inst)
            add_at(out, fade_tail(y), s_of(song, e.b))
        return out
    return f


def saw_blep(freq, phase0=0.0):
    dt = freq / SR
    ph = (np.cumsum(dt) + phase0) % 1.0
    y = 2 * ph - 1
    m = ph < dt
    t = ph[m] / dt[m]
    y[m] -= t + t - t * t - 1
    m = ph > 1 - dt
    t = (ph[m] - 1) / dt[m]
    y[m] -= t * t + t + t + 1
    return y


def render_pad(song, evs, n):
    """Supersaw chords (events carry a list of MIDI notes) through a low-pass, slow envelope."""
    r = rng(21)
    out = np.zeros((n, 2))
    for e in evs:
        s, end = s_of(song, e.b), s_of(song, e.b + e.dur)
        ln = end - s + int(0.4 * SR)
        if ln <= 0:
            continue
        env = np.ones(ln)
        a = min(ln, int(e.p.get("attack", 0.25) * SR))
        env[:a] = np.linspace(0, 1, a)
        rl = int(0.4 * SR)
        env[-rl:] *= np.linspace(1, 0, rl)
        for m in e.p["notes"]:
            for ch in range(2):
                y = np.zeros(ln)
                for dtn in (-11, -4, 3, 10) if ch == 0 else (-9, -2, 5, 12):
                    y += saw_blep(np.full(ln, mtof(m) * 2 ** (dtn / 1200)), r.uniform(0, 1))
                add_at(out[:, ch], y * env * e.vel * 0.05, s)
    cut = song.remix_style.get("pad_cut", 1800) if song.remix_style else 1800
    return lowpass(out, cut, order=2)


def render_sub(song, evs, n):
    out = np.zeros(n)
    for e in evs:
        s, end = s_of(song, e.b), s_of(song, e.b + e.dur)
        ln = end - s
        if ln <= 0:
            continue
        t = np.arange(ln) / SR
        f = mtof(e.pitch)
        y = np.sin(2 * np.pi * f * t) + 0.12 * np.sin(4 * np.pi * f * t)
        env = np.ones(ln)
        a = int(0.005 * SR)
        env[:a] = np.linspace(0, 1, a)
        rl = min(ln, int(0.03 * SR))
        env[-rl:] *= np.linspace(1, 0, rl)
        add_at(out, np.tanh(y * env * 1.4) * e.vel, s)
    return out * 0.7


def render_lead(song, evs, n):
    """Plucky saw lead with a decaying filter, per note (the song's melody, re-voiced)."""
    out = np.zeros(n)
    style = (song.remix_style or {}).get("lead", "pluck")
    for e in evs:
        s = s_of(song, e.b)
        ln = int((e.dur * song.spb + 0.25) * SR)
        f = mtof(e.pitch)
        t = np.arange(ln) / SR
        if style == "square":
            ph = (f * t) % 1
            y = np.where(ph < 0.5, 1.0, -1.0) * 0.6 + saw_blep(np.full(ln, f * 1.005)) * 0.3
        else:
            y = saw_blep(np.full(ln, f)) + 0.5 * saw_blep(np.full(ln, f * 2 ** (7 / 1200)))
        # time-varying low-pass approximated by crossfading two filtered copies
        bright = lowpass(y, min(9000, f * 10))
        dark = lowpass(y, f * 2.5)
        k = np.exp(-t / (0.12 if style == "pluck" else 0.4))
        y = bright * k + dark * (1 - k)
        env = np.exp(-t / max(0.15, e.dur * song.spb * 0.9))
        a = int(0.003 * SR)
        env[:a] *= np.linspace(0, 1, a)
        env[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
        add_at(out, y * env * e.vel * 0.35, s)
    return out


def render_chop(song, evs, n):
    """Chopped voices: slices of the story song's own vocal stems, retriggered and re-pitched."""
    out = np.zeros(n)
    src = song.chop_source or {}
    for e in evs:
        stem = src.get(e.p["stem"])
        if stem is None:
            continue
        s0 = e.p["src_s"]
        ln = int(e.p["src_len"] * SR)
        sl = stem[s0:s0 + ln].copy()
        if len(sl) < 64:
            continue
        shift = e.p.get("shift", 0)
        rate = 2 ** (shift / 12)
        if shift:
            sl = signal.resample(sl, max(64, int(len(sl) / rate)))
        g = int(0.004 * SR)
        sl[:g] *= np.linspace(0, 1, g)
        sl[-g * 3:] *= np.linspace(1, 0, g * 3)
        if e.p.get("reverse"):
            sl = sl[::-1]
        pk = np.max(np.abs(sl)) + 1e-9
        # the slice starts a little before its vowel; shift it so the vowel lands on the beat
        pre = int(e.p.get("pre", 0.0) / rate * SR)
        add_at(out, sl / pk * e.vel * 0.5, s_of(song, e.b) - pre)
    return out


RENDERERS = {
    "bassu": render_voice("bassu"), "contra": render_voice("contra"), "mesu": render_voice("mesu"),
    "boghe": render_voice("boghe"), "calls": render_calls,
    "tumbu": render_pipe("tumbu"), "mancosa": render_pipe("mancosa"), "mancosedda": render_pipe("mancosedda"),
    "frame": render_drum("frame"), "bass": render_drum("bass"), "stomp": render_drum("stomp"),
    "clap": render_drum("clap"), "count": render_drum("count"),
    "bells": render_bells, "rope": render_rope, "fire": render_fire, "crowd": render_crowd,
    "kick": render_kit("kick"), "snare": render_kit("snare"), "hat": render_kit("hat"),
    "impact": render_kit("impact"), "riser": render_kit("riser"),
    "pad": render_pad, "sub": render_sub, "lead": render_lead, "arp": render_lead, "chop": render_chop,
}
