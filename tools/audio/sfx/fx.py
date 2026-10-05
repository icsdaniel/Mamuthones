"""Rope throw, count-in, carved-wood UI sounds and the looping ambiences (fire, wind).

Run:  python3 tools/audio/sfx/fx.py
"""
from __future__ import annotations

import numpy as np

from bells import Bell, body_thump, make_load, render_ring, render_row, strike_response
from dsp import (SR, add_at, bandpass, convolve_ir, limit, db, fade, highpass, loop_crossfade,
                 lowpass, make_ir, pan, periodic_lfo, resonator, shaped_noise, trim_tail,
                 write_ogg, write_wav)

MEMBRANE = [1.0, 1.594, 2.136, 2.296, 2.653, 2.918, 3.156, 3.501, 3.600, 3.652]


def frame_drum(rng, f0=96.0, strength=1.0, center=0.5, dur=0.5, slap=0.4) -> np.ndarray:
    """Circular membrane modes (Bessel ratios) with a small pitch drop, a hand slap
    and the knock of the wooden frame. center 1 = hit in the middle (deep), 0 = edge."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    glide = 1 + 0.05 * strength * np.exp(-t / 0.04)
    for k, r in enumerate(MEMBRANE):
        a = (1.0 if k == 0 else (0.25 + 0.6 * (1 - center)) / (1 + 0.3 * k)) * rng.uniform(0.7, 1.1)
        d = 0.28 / (1 + 0.5 * k)
        ph = 2 * np.pi * np.cumsum(f0 * r * glide) / SR
        out += a * np.sin(ph) * np.exp(-t / d)
    m = int(0.03 * SR)
    s = bandpass(rng.standard_normal(m), 600, 5000, 2) * np.exp(-np.arange(m) / (0.004 * SR))
    out[:m] += s * slap * 2
    frame = resonator(rng.standard_normal(m) * np.exp(-np.arange(m) / (0.002 * SR)), 950, 8)
    out[:m] += frame * 0.6 * (1 - center)
    return fade(out * strength, 0.0005, 0.05)


def wood_knock(rng, f=820.0, strength=1.0, dur=0.22, hollow=0.5) -> np.ndarray:
    """A knock on carved wood: free-bar modes decaying fast, a contact tick and a
    hollow body resonance."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 0.045), (2.756, 0.45, 0.018), (5.404, 0.2, 0.008), (8.933, 0.1, 0.004)):
        out += a * np.sin(2 * np.pi * f * r * rng.uniform(0.99, 1.01) * t) * np.exp(-t / d)
    out += hollow * np.sin(2 * np.pi * f * 0.31 * t) * np.exp(-t / 0.03)
    m = int(0.01 * SR)
    out[:m] += highpass(rng.standard_normal(m), 2000, 2) * np.exp(-np.arange(m) / (0.0008 * SR)) * 0.5
    out *= np.clip(t / 0.0006, 0, 1)
    ir = make_ir(0.35, 0.4, np.random.default_rng(3), stereo=False, early=[(0.006, 0.25), (0.013, 0.15)], bright=5000)
    out = out + convolve_ir(out, ir)[:n] * db(-18)
    return fade(out * strength, 0.0003, 0.04)


# ----------------------------------------------------------------------------- rope

def rope(take: int) -> np.ndarray:
    """The Issohadore's rope (soha): a quick swish into a crack as it pulls tight, the
    rope whistling on through the air and slapping down on a shoulder."""
    rng = np.random.default_rng([91, take])
    dur = 0.75
    n = int(dur * SR)
    crack_t = 0.035 + rng.uniform(-0.005, 0.005)
    swing = rng.uniform(0.22, 0.32)
    t_end = crack_t + swing

    def shape(t, f):
        # whoosh: band centre sweeps up into the crack and falls as the rope swings on
        pre = np.clip(t / crack_t, 0, 1) ** 2 * (t < crack_t)
        post = np.exp(-np.clip(t - crack_t, 0, None) / (swing * 0.45)) * (t >= crack_t)
        amp = pre * 0.6 + post
        fc = np.where(t < crack_t, 600 + 1400 * t / crack_t, 2000 * np.exp(-np.clip(t - crack_t, 0, None) / 0.12) + 450)
        bw = 0.9
        g = np.exp(-((np.log2(np.maximum(f[None, :], 1.0) / fc[:, None])) ** 2) / (2 * bw ** 2))
        return amp[:, None] * g

    out = shaped_noise(n, rng, shape) * 1.3
    # doppler-ish flutter of the rope's twist
    tt = np.arange(n) / SR
    out *= 1 + 0.35 * np.sin(2 * np.pi * rng.uniform(22, 30) * tt)
    # the crack: a sharp pressure step plus a short bright burst and a low tug
    k = int(crack_t * SR)
    m = int(0.02 * SR)
    burst = highpass(rng.standard_normal(m), 1500, 2) * np.exp(-np.arange(m) / (0.0015 * SR))
    add_at(out, burst * 1.6, k)
    tug_n = int(0.08 * SR)
    tt2 = np.arange(tug_n) / SR
    add_at(out, np.sin(2 * np.pi * 130 * tt2) * np.exp(-tt2 / 0.018) * 0.4, k)
    # fibres creaking as the rope tightens (stick-slip)
    cr_n = int(0.06 * SR)
    imp = np.zeros(cr_n)
    pos = 0.0
    while pos < cr_n:
        imp[int(pos)] = rng.uniform(0.5, 1.0)
        pos += SR / rng.uniform(140, 220)
    creak = resonator(imp, 900, 4) * np.exp(-np.arange(cr_n) / (0.02 * SR)) * 0.25
    add_at(out, creak, k + int(0.004 * SR))
    # the rope lands on a sheepskin shoulder: soft, low slap
    land = int(t_end * SR)
    ln = int(0.08 * SR)
    add_at(out, lowpass(rng.standard_normal(ln), 900, 2) * np.exp(-np.arange(ln) / (0.012 * SR)) * 0.5, land)
    ir = make_ir(0.8, 0.9, np.random.default_rng(92), stereo=False, early=[(0.021, 0.3), (0.045, 0.2)], bright=4000)
    out = out + convolve_ir(out, ir)[:n] * db(-10)
    return fade(out, 0.002, 0.05)


# ----------------------------------------------------------------------------- UI

def carve(take: int) -> np.ndarray:
    """A gouge cutting across the grain: irregular stick-slip chatter through the
    wood's resonances, ending when the chip breaks off."""
    rng = np.random.default_rng([101, take])
    dur = rng.uniform(0.26, 0.36)
    n = int((dur + 0.15) * SR)
    cut = int(dur * SR)
    imp = np.zeros(n)
    pos = 0.0
    while pos < cut:
        frac = pos / cut
        imp[int(pos)] = rng.uniform(0.3, 1.0) * (0.4 + 0.6 * np.sin(np.pi * min(1, frac * 1.2)))
        pos += SR / (rng.uniform(250, 520) * (1 + 0.4 * frac))
    body = sum(resonator(imp, f, q) * g for f, q, g in ((1250, 6, 1.0), (2600, 8, 0.7), (4300, 10, 0.4), (620, 5, 0.5)))
    fr = bandpass(rng.standard_normal(n), 2500, 9000, 2) * 0.05
    env = np.zeros(n)
    env[:cut] = np.linspace(0.5, 1.0, cut)
    fr *= env
    out = body * 0.5 + fr
    # the chip breaks off: a tiny sharp knock
    add_at(out, wood_knock(rng, rng.uniform(1500, 1900), 0.5, 0.08, 0.1), cut)
    return fade(out, 0.002, 0.04)


def unlock() -> np.ndarray:
    """A frame-drum roll swelling into a hit, with a cascade of small bells and the
    full load answering. Stereo."""
    rng = np.random.default_rng(111)
    dur = 2.6
    n = int(dur * SR)
    out = np.zeros((n, 2))
    # roll: accelerating strokes, crescendo, alternating hands
    t = 0.0
    k = 0
    while t < 0.48:
        s = 0.25 + 0.6 * (t / 0.48)
        add_at(out, pan(frame_drum(rng, 110, s, 0.2, 0.4, 0.6), -0.2 if k % 2 else 0.2), int(t * SR))
        t += 0.09 * (1 - 0.55 * t / 0.48)
        k += 1
    hit = int(0.5 * SR)
    add_at(out, pan(frame_drum(rng, 92, 1.4, 0.9, 1.0, 0.5), 0.0), hit)
    # cascade: small bells struck one after another from left to right
    bells = make_load("light")
    for i, b in enumerate(sorted(bells, key=lambda b: b.f0)):
        st = hit + int((0.02 + 0.07 * i) * SR)
        x = strike_response(b, int(1.4 * SR), 0.8, 7000, rng)
        add_at(out, pan(x * 0.55, -0.7 + 0.35 * i), st)
    ring = render_ring("village", False, "perfect", 0)
    add_at(out, ring * 1.1, hit + int(0.42 * SR))
    ir = make_ir(1.3, 1.5, np.random.default_rng(112), stereo=True, early=[(0.02, 0.2), (0.037, 0.15)], bright=5000)
    out = out + convolve_ir(out, ir)[:n] * db(-9)
    return out


def result() -> np.ndarray:
    """End-of-song sting: a deep drum, the whole row ringing together, a low bell."""
    rng = np.random.default_rng(121)
    dur = 3.2
    n = int(dur * SR)
    out = np.zeros((n, 2))
    add_at(out, pan(frame_drum(rng, 62, 1.6, 1.0, 1.2, 0.3), 0.0), 0)
    add_at(out, pan(frame_drum(rng, 96, 1.0, 0.6, 0.8, 0.6), 0.0), int(0.004 * SR))
    ring = render_ring("full", False, "perfect", 1)
    add_at(out, ring * 1.3, int(0.01 * SR))
    row = render_row(False, True, 0)
    add_at(out, row * 1.6, int(0.012 * SR))
    big = Bell(118.0, 3.0, np.random.default_rng(122), 1.0)
    add_at(out, pan(strike_response(big, int(2.8 * SR), 1.0, 3000, rng) * 0.7, 0.0), int(0.02 * SR))
    return out


def cue(take: int) -> np.ndarray:
    """The bell cue before a tilt on Easy and Medium: a light shake of a few tiny
    bells, soft and high, gone in a quarter second; nothing like a ring of the load."""
    rng = np.random.default_rng([181, take])
    n = int(0.26 * SR)
    out = np.zeros(n)
    tiny = [Bell(float(f), 0.25, rng, 0.0) for f in rng.uniform(2600, 4200, 4)]
    t = 0.0
    for k in range(int(rng.integers(3, 5))):
        b = tiny[k % len(tiny)]
        start = int(t * SR)
        add_at(out, strike_response(b, n - start, rng.uniform(0.4, 0.7) * (1 - 0.15 * k), 9000, rng, 0.35), start)
        t += rng.uniform(0.018, 0.035)
    # body at 2-3 kHz: a soft, damped "tik" of a fingertip on a small bell's rim, so
    # the cue cuts through the music without sounding like a ring of the load
    tk = int(0.05 * SR)
    e = rng.standard_normal(tk) * np.exp(-np.arange(tk) / (0.004 * SR))
    tik = resonator(e, rng.uniform(2300, 2600), 7) + 0.5 * resonator(e, rng.uniform(2900, 3200), 8)
    add_at(out, tik * 0.8 * np.max(np.abs(out)) / (np.max(np.abs(tik)) + 1e-9), 0)
    add_at(out, tik * 0.5 * np.max(np.abs(out)) / (np.max(np.abs(tik)) + 1e-9), int(t * SR * 0.5))
    out = highpass(out, 1500, 2)
    return fade(out, 0.0008, 0.06)


def rope_grab(take: int) -> np.ndarray:
    """A hand closing on the rope: palm friction on the fibres and a short creak as
    the twist takes the load."""
    rng = np.random.default_rng([191, take])
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    rub = bandpass(rng.standard_normal(n), 900, 5000, 2) * np.exp(-t / 0.03) * 0.35
    imp = np.zeros(n)
    pos = rng.uniform(0.008, 0.015) * SR
    while pos < 0.11 * SR:
        imp[int(pos)] = rng.uniform(0.5, 1.0)
        pos += SR / rng.uniform(110, 190)
    creak = (resonator(imp, rng.uniform(650, 800), 5) + 0.6 * resonator(imp, rng.uniform(1300, 1600), 6))
    creak *= np.clip(t / 0.01, 0, 1) * np.exp(-np.clip(t - 0.03, 0, None) / 0.04)
    out = rub + creak * 0.5
    return fade(out, 0.0008, 0.04)


# ----------------------------------------------------------------------------- ambience

def fire_loop(seconds=20.0, xf=1.5) -> np.ndarray:
    """A bonfire: a breathing low roar, hiss, and crackles and pops of burning wood."""
    rng = np.random.default_rng(131)
    n = int((seconds + xf) * SR)
    out = np.zeros((n, 2))
    for c in range(2):
        roar = lowpass(rng.standard_normal(n), 380, 2)
        breath = 1 + 0.5 * lowpass(rng.standard_normal(n), 0.6, 1) * 40
        out[:, c] += roar * np.clip(breath, 0.3, 2.2) * 0.5
        hiss = bandpass(rng.standard_normal(n), 3000, 9000, 2) * 0.04
        out[:, c] += hiss * (1 + 0.5 * lowpass(rng.standard_normal(n), 2, 1) * 20)
    # crackles: Poisson, clustered, log-distributed sizes
    t = 0.0
    while t < seconds + xf - 0.1:
        t += rng.exponential(1 / 9.0)
        burst = 1 if rng.random() > 0.2 else int(rng.integers(3, 8))
        for b in range(burst):
            tb = t + b * rng.uniform(0.004, 0.03)
            size = np.exp(rng.normal(-1.2, 0.8))
            m = int(rng.uniform(0.003, 0.012) * SR)
            e = rng.standard_normal(m) * np.exp(-np.arange(m) / (m / 4))
            e = resonator(e, rng.uniform(1500, 6500), rng.uniform(1, 4))
            add_at(out, pan(e * size, rng.uniform(-0.7, 0.7)), int(tb * SR))
    # a few pops with body (sap pockets bursting) and a log settling
    for _ in range(int(seconds / 3)):
        tb = rng.uniform(0, seconds + xf - 0.3)
        m = int(0.06 * SR)
        e = rng.standard_normal(m) * np.exp(-np.arange(m) / (0.006 * SR))
        e = lowpass(e, 2500, 2) + resonator(e, rng.uniform(400, 900), 3) * 0.5
        add_at(out, pan(e * rng.uniform(1.0, 2.0), rng.uniform(-0.5, 0.5)), int(tb * SR))
    for _ in range(2):
        tb = rng.uniform(0, seconds + xf - 1.0)
        m = int(0.5 * SR)
        e = lowpass(rng.standard_normal(m), 600, 2) * np.hanning(m) ** 3 * 0.8
        add_at(out, pan(e, rng.uniform(-0.3, 0.3)), int(tb * SR))
    L, X = int(seconds * SR), int(xf * SR)
    return loop_crossfade(out[: L + X], L, X)


def wind_loop(seconds=52.0, xf=2.0) -> np.ndarray:
    """Winter wind in the lanes: slow gusts, a low rumble and a stone-corner whistle."""
    rng = np.random.default_rng(141)
    n = int((seconds + xf) * SR)
    out = np.zeros((n, 2))
    gust_ctrl = None
    for c in range(2):
        g_rng = np.random.default_rng(142)  # gusts shared by both ears, detail decorrelated

        def shape(t, f, c=c):
            nonlocal gust_ctrl
            # about one gust shape every 0.4 s, never repeating within the 52 s loop
            k = int(seconds * 2.5)
            gust = 0.55 + 0.45 * np.interp(t, np.linspace(0, t[-1], k),
                                           np.convolve(g_rng.standard_normal(k), np.hanning(7), "same") / 2.5)
            gust = np.clip(gust, 0.1, 1.3)
            gust_ctrl = gust
            fc = 250 + 700 * gust
            body = 1 / (1 + (f[None, :] / fc[:, None]) ** 2)
            rumble = 1.5 / (1 + (f[None, :] / 80.0) ** 4) * (f[None, :] > 25)
            wf = 620 + 380 * gust + 30 * c
            whistle = 5.0 * np.exp(-((f[None, :] - wf[:, None]) / 18.0) ** 2) * np.clip(gust - 0.7, 0, None)[:, None]
            return gust[:, None] * (body + rumble + whistle)

        out[:, c] = shaped_noise(n, rng, shape, 4096, 1024)
    out = highpass(out, 30, 2)
    L, X = int(seconds * SR), int(xf * SR)
    return loop_crossfade(out[: L + X], L, X)


# ----------------------------------------------------------------------------- miss

def miss(take: int) -> np.ndarray:
    """A missed note, made to be unmistakable on a phone speaker: a cracked bell's buzz (two
    saturated tones a tritone apart, 330 and 466 Hz) that slides down a fourth like a groan,
    opened by a dry wooden clack and a short metal rattle. All of it sits at 0.5-4 kHz, where a
    phone plays loud, and nothing in it is tuned to the song, so it never reads as a hit."""
    rng = np.random.default_rng([223, take])
    dur = 0.34
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = 330.0 * (1 + 0.025 * (take - 1))
    slide = 2 ** (-5 / 12 * np.clip(t / 0.22, 0, 1) ** 0.8)   # down a fourth
    env = np.exp(-t / 0.11) * np.clip(t / 0.004, 0, 1)
    buzz = np.zeros(n)
    for r, a in ((1.0, 1.0), (1.414, 0.85)):
        ph = 2 * np.pi * np.cumsum(f0 * r * slide) / SR
        # a square-ish wave with a little wobble: a reed-like, rasping buzz
        buzz += a * np.tanh(4.0 * np.sin(ph + 0.3 * np.sin(2 * np.pi * 31 * t)))
    buzz = bandpass(buzz * env, 280, 4200, 2)
    buzz = np.tanh(buzz * 1.6)
    clack = wood_knock(rng, 1250, 1.0, 0.12, 0.2)
    m = int(0.09 * SR)
    noise = rng.standard_normal(m) * np.exp(-np.arange(m) / (0.018 * SR))
    rattle = resonator(noise, 2150, 12) + 0.7 * resonator(noise, 3350, 14)
    out = buzz * 0.9
    out[: len(clack)] += clack * 0.7
    out[:m] += rattle * 0.25
    return fade(out, 0.0004, 0.05)


# ----------------------------------------------------------------------------- main

def level(x, rms_db, ceiling_db=-3.0):
    """Scale to an RMS level; the rare transient above the ceiling (a big crackle) is
    soft-clipped instead of lowering the whole bed."""
    y = x * db(rms_db) / (np.sqrt(np.mean(x ** 2)) + 1e-12)
    c = db(ceiling_db)
    return c * np.tanh(y / c)


def main() -> None:
    ropes = [rope(k) for k in range(3)]
    pk = max(np.max(np.abs(r)) for r in ropes)
    for k, r in enumerate(ropes):
        write_wav(f"fx/rope_{k + 1}.wav", r * db(-2) / pk)
    # count-in: a frame drum with a stick click on the rim (the click is what a phone
    # speaker plays); the first beat is a fifth higher and louder
    rng = np.random.default_rng(151)
    hi = frame_drum(rng, 156, 1.0, 0.7, 0.28, 0.6) + wood_knock(rng, 2250, 0.9, 0.28, 0.05)
    lo = frame_drum(rng, 104, 0.8, 0.4, 0.28, 0.8) + wood_knock(rng, 1500, 0.65, 0.28, 0.05)
    pk = max(np.max(np.abs(hi)), np.max(np.abs(lo)))
    write_wav("fx/count_hi.wav", fade(hi * db(-2) / pk, 0.0005, 0.03))
    write_wav("fx/count_lo.wav", fade(lo * db(-2) / pk, 0.0005, 0.03))
    taps = [wood_knock(np.random.default_rng([161, k]), 820 * (1 + 0.03 * (k - 1)), 1.0) for k in range(3)]
    pk = max(np.max(np.abs(x)) for x in taps)
    for k, x in enumerate(taps):
        write_wav(f"ui/tap_{k + 1}.wav", x * db(-6) / pk)
    r = np.random.default_rng(171)
    back = np.zeros(int(0.3 * SR))
    add_at(back, wood_knock(r, 700, 0.8, 0.22), 0)
    add_at(back, wood_knock(r, 520, 0.6, 0.22), int(0.075 * SR))
    write_wav("ui/back_1.wav", fade(back * db(-6) / np.max(np.abs(back)), 0.0003, 0.04))
    cues = [cue(k) for k in range(3)]
    # by loudness, not peak (the tik's peak would hold it down): about 9 dB over the
    # first cut, peaks still under -1.5 dBFS
    for k, x in enumerate(cues):
        y = x * db(-17) / np.sqrt(np.mean(x[: int(0.1 * SR)] ** 2))
        write_wav(f"ui/cue_{k + 1}.wav", limit(y, -1.5))
    grabs = [rope_grab(k) for k in range(3)]
    pk = max(np.max(np.abs(x)) for x in grabs)
    for k, x in enumerate(grabs):
        write_wav(f"fx/grab_{k + 1}.wav", x * db(-8) / pk)
    carves = [carve(k) for k in range(3)]
    pk = max(np.max(np.abs(x)) for x in carves)
    for k, x in enumerate(carves):
        write_wav(f"ui/carve_{k + 1}.wav", x * db(-5) / pk)
    u = unlock()
    pad = np.zeros((int(0.006 * SR), 2))  # keeps Vorbis pre-echo off the first sample
    write_ogg("ui/unlock.ogg", np.concatenate([pad, fade(trim_tail(u * db(-2) / np.max(np.abs(u)), -60, 0.1), 0.001, 0.0)]), 0.4)
    res = result()
    write_ogg("ui/result.ogg", np.concatenate([pad, fade(trim_tail(res * db(-2) / np.max(np.abs(res)), -60, 0.1), 0.001, 0.0)]), 0.4)
    fire = fire_loop()
    write_ogg("ambience/fire.ogg", level(fire, -27), 0.3)
    wind = wind_loop()
    write_ogg("ambience/wind.ogg", level(wind, -28), 0.2)
    write_misses()
    print("wrote fx, ui, ambience")


def write_misses() -> None:
    misses = [miss(k) for k in range(3)]
    pk = max(np.max(np.abs(x)) for x in misses)
    for k, x in enumerate(misses):
        write_wav(f"fx/miss_{k + 1}.wav", x * db(-1.5) / pk)


if __name__ == "__main__":
    main()
