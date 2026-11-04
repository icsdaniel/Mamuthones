"""Juice stings (Daniele, 2026-10-31: "give the game more juice and flavor"): combo milestones,
a combo lost, the unison multiplier rising and topping out, and the results screen's count,
grade stamp and new best, plus the bells falling when health runs out.

Everything tuned is in C (Sound resamples it to the song's key, like the bell chimes), and
built from the same drums, chimes and cowbells as the rest of the game, so the stings sound
like the procession, not like a slot machine.

Run:  python3 tools/audio/sfx/juice.py
"""
from __future__ import annotations

import numpy as np

from bells import Bell, make_load, render_ring, strike_response
from dsp import (SR, add_at, bandpass, convolve_ir, db, fade, highpass, lowpass, make_ir, pan,
                 resonator, trim_tail, write_wav)
from fx import frame_drum, wood_knock

C6 = 1046.5


def tone(rng, f0: float, dur=0.55, bright=1.0, decay=0.3) -> np.ndarray:
    """A small tuned bell (the chime's recipe at any pitch): near-harmonic partials with a slow
    shimmer and the clapper's tick."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, d in ((1.0, 1.0, decay), (2.0, 0.42 * bright, decay * 0.5), (3.0, 0.2 * bright, decay * 0.28),
                    (4.07, 0.14 * bright, decay * 0.16), (5.4, 0.07 * bright, decay * 0.1)):
        if f0 * r > SR * 0.45:
            continue
        beat = 1 + 0.15 * np.sin(2 * np.pi * rng.uniform(2.5, 4.0) * t)
        out += a * beat * np.sin(2 * np.pi * f0 * r * rng.uniform(0.999, 1.001) * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
    out *= np.clip(t / 0.0015, 0, 1)
    m = int(0.012 * SR)
    out[:m] += highpass(rng.standard_normal(m), 4000, 2) * np.exp(-np.arange(m) / (0.0015 * SR)) * 0.35
    return fade(out, 0.0003, 0.06)


def semis(f: float, s: float) -> float:
    return f * 2 ** (s / 12)


def room(x: np.ndarray, t60=0.8, wet=-12.0, seed=7) -> np.ndarray:
    stereo = x.ndim == 2
    ir = make_ir(t60, t60 + 0.2, np.random.default_rng(seed), stereo=stereo, early=[(0.011, 0.3), (0.023, 0.2)], bright=6500)
    return x + convolve_ir(x, ir)[: len(x)] * db(wet)


def stereo(n: float) -> np.ndarray:
    return np.zeros((int(n * SR), 2))


def arpeggio(out: np.ndarray, rng, steps, start: float, gap: float, base=C6, gain=1.0, spread=0.6, decay=0.3):
    """Chimes struck one after another, left to right, rising."""
    k = len(steps)
    for i, s in enumerate(steps):
        p = -spread + 2 * spread * i / max(1, k - 1)
        x = tone(rng, semis(base, s), 0.7, 1.0, decay) * gain * (0.85 + 0.15 * i / max(1, k - 1))
        add_at(out, pan(x, p), int((start + gap * i) * SR))


def shake(out: np.ndarray, rng, start: float, count=5, gain=0.4, lo=2600, hi=4400):
    """A light shake of tiny bells (the bell cue's sparkle)."""
    tiny = [Bell(float(f), 0.3, rng, 0.0) for f in rng.uniform(lo, hi, 4)]
    t = start
    for k in range(count):
        b = tiny[k % len(tiny)]
        x = strike_response(b, int(0.4 * SR), rng.uniform(0.4, 0.7) * (1 - 0.1 * k), 9000, rng, 0.4)
        add_at(out, pan(highpass(x, 1500, 2) * gain, rng.uniform(-0.6, 0.6)), int(t * SR))
        t += rng.uniform(0.02, 0.04)


# ----------------------------------------------------------------------------- in play

def combo(tier: int) -> np.ndarray:
    """A combo milestone: a run of chimes rising up the key's major chord (tier 1: three, tier 2:
    four to the octave, tier 3: five over the octave, on a soft frame drum), with a sparkle of tiny
    bells on top. Short and quick, so it ends before the next beat or two."""
    rng = np.random.default_rng([311, tier])
    steps = {1: [0, 4, 7], 2: [0, 4, 7, 12], 3: [0, 4, 7, 12, 16]}[tier]
    out = stereo(1.1)
    arpeggio(out, rng, steps, 0.0, 0.045, gain=0.8, decay=0.22)
    shake(out, rng, 0.045 * len(steps), 3 + tier, 0.3)
    if tier >= 2:
        add_at(out, pan(frame_drum(rng, 98, 0.55 + 0.2 * tier, 0.7, 0.45, 0.7), 0.0), 0)
    return room(out, 0.7, -14, 31)


def combo_break() -> np.ndarray:
    """A long combo lost: the chimes tumbling down out of tune, damped fast, over a dull thud of
    wood. Under the miss's buzz, so it adds weight, not another alarm."""
    rng = np.random.default_rng(321)
    out = stereo(0.7)
    for i, s in enumerate([7, 3, 0, -5]):
        x = tone(rng, semis(C6, s) * rng.uniform(0.97, 0.985), 0.4, 0.7, 0.07)
        add_at(out, pan(x * (0.7 - 0.1 * i), 0.4 - 0.25 * i), int((0.035 * i + rng.uniform(0, 0.008)) * SR))
    add_at(out, pan(wood_knock(rng, 300, 0.9, 0.25, 0.9), 0.0), int(0.1 * SR))
    add_at(out, pan(frame_drum(rng, 70, 0.6, 0.3, 0.4, 0.3), 0.0), int(0.1 * SR))
    return lowpass(room(out, 0.5, -16, 32), 6000, 2)


def unison_up(top: bool) -> np.ndarray:
    """The multiplier rises a step: a short upward swish of tiny bells into the fifth and octave rung
    together. At the top step, a drum and the load ring under it, a bigger reward."""
    rng = np.random.default_rng([331, int(top)])
    out = stereo(1.6 if top else 0.9)
    # the swish: band-passed noise sweeping up
    m = int(0.16 * SR)
    t = np.arange(m) / m
    sweep = np.zeros(m)
    noise = rng.standard_normal(m)
    for k in range(8):
        a, b = k * m // 8, (k + 1) * m // 8
        f = 1500 * 2 ** (2.2 * k / 8)
        sweep[a:b] = bandpass(noise, f, f * 1.6, 2)[a:b]
    sweep *= t ** 1.5 * 0.25
    add_at(out, pan(sweep, -0.3), 0)
    add_at(out, pan(sweep[::-1][::-1] * 0.8, 0.3), int(0.004 * SR))
    hit = 0.15
    add_at(out, pan(tone(rng, semis(C6, 7), 0.8, 1.0, 0.3) * 0.7, -0.25), int(hit * SR))
    add_at(out, pan(tone(rng, semis(C6, 12), 0.8, 1.0, 0.3) * 0.6, 0.25), int((hit + 0.012) * SR))
    shake(out, rng, hit, 4, 0.3)
    if top:
        add_at(out, pan(frame_drum(rng, 88, 1.2, 0.9, 0.8, 0.5), 0.0), int(hit * SR))
        ring = render_ring("village", False, "perfect", 2)
        add_at(out, ring * 0.6, int((hit + 0.01) * SR))
        arpeggio(out, rng, [12, 16, 19, 24], hit + 0.08, 0.05, gain=0.45, decay=0.25)
    return room(out, 0.9, -12, 33)


def fail() -> np.ndarray:
    """Health ran out: the load falls in a heap, cowbells clanking down one on another and a body
    landing on the stones, then quiet."""
    rng = np.random.default_rng(341)
    out = stereo(1.8)
    bells = sorted(make_load("village"), key=lambda b: -b.f0)
    t = 0.0
    for i, b in enumerate(bells[:7]):
        x = strike_response(b, int(0.6 * SR), rng.uniform(0.5, 0.9) * (1 - 0.06 * i), 4000, rng, 0.35)
        add_at(out, pan(x * 0.6, rng.uniform(-0.6, 0.6)), int(t * SR))
        t += rng.uniform(0.05, 0.11) * (1 + 0.15 * i)
    add_at(out, pan(frame_drum(rng, 52, 1.4, 1.0, 1.0, 0.2), 0.0), int(0.06 * SR))
    add_at(out, pan(wood_knock(rng, 220, 1.0, 0.3, 1.0), 0.0), int(0.07 * SR))
    return lowpass(room(out, 1.0, -12, 34), 5000, 2)


# ----------------------------------------------------------------------------- results

def count_tick() -> np.ndarray:
    """One bead of the score counting up: a tiny wooden tick with a glint of metal (Sound raises
    its pitch as the count climbs)."""
    rng = np.random.default_rng(351)
    x = wood_knock(rng, 1900, 0.8, 0.07, 0.05)
    x = x + tone(rng, semis(C6, 24), 0.07, 0.4, 0.02) * 0.25
    return fade(x, 0.0003, 0.02)


def stamp(tier: int) -> np.ndarray:
    """The grade stamping onto the results: a heavy drum and a wooden slam, as if a carved seal
    were pressed into the table. Tier 1 (F-C) just the slam; tier 2 (B-A) a bell rings out of it;
    tier 3 (S, S+) the whole load rings and chimes cascade up."""
    rng = np.random.default_rng([361, tier])
    out = stereo(2.2 if tier == 3 else 1.4)
    add_at(out, pan(frame_drum(rng, 60, 1.5, 1.0, 1.0, 0.5), 0.0), 0)
    add_at(out, pan(wood_knock(rng, 260, 1.0, 0.3, 1.0), 0.0), 0)
    m = int(0.06 * SR)
    add_at(out, pan(bandpass(rng.standard_normal(m), 400, 3000, 2) * np.exp(-np.arange(m) / (0.01 * SR)) * 0.6, 0.0), 0)
    if tier >= 2:
        big = Bell(392.0, 1.6, np.random.default_rng(362), 0.6)
        add_at(out, pan(strike_response(big, int(1.3 * SR), 0.9, 5000, rng) * 0.45, 0.0), int(0.01 * SR))
    if tier >= 3:
        ring = render_ring("village", False, "perfect", 1)
        add_at(out, ring * 0.9, int(0.02 * SR))
        arpeggio(out, rng, [0, 4, 7, 12, 16, 19, 24], 0.08, 0.055, gain=0.55, spread=0.8, decay=0.3)
        shake(out, rng, 0.5, 6, 0.35)
    return room(out, 1.1, -11, 35)


def new_best() -> np.ndarray:
    """A new best: a quick roll on the frame drum into chimes climbing two octaves, with the tiny
    bells sparkling on top."""
    rng = np.random.default_rng(371)
    out = stereo(2.0)
    t = 0.0
    k = 0
    while t < 0.24:
        add_at(out, pan(frame_drum(rng, 120, 0.25 + 0.5 * t / 0.24, 0.2, 0.3, 0.6), -0.2 if k % 2 else 0.2), int(t * SR))
        t += 0.06 * (1 - 0.4 * t / 0.24)
        k += 1
    add_at(out, pan(frame_drum(rng, 98, 1.1, 0.9, 0.7, 0.5), 0.0), int(0.26 * SR))
    arpeggio(out, rng, [0, 4, 7, 12, 16, 19, 24], 0.26, 0.06, gain=0.7, spread=0.7, decay=0.32)
    shake(out, rng, 0.7, 7, 0.35, 3000, 5200)
    return room(out, 1.0, -11, 36)


def write(rel: str, x: np.ndarray, peak_db: float) -> None:
    x = trim_tail(x, -66, 0.06)
    write_wav(rel, fade(x * db(peak_db) / (np.max(np.abs(x)) + 1e-12), 0.0003, 0.05))


def main() -> None:
    for tier in (1, 2, 3):
        write(f"juice/combo_{tier}.wav", combo(tier), -3.0)
        write(f"juice/stamp_{tier}.wav", stamp(tier), -1.5)
    write("juice/combo_break.wav", combo_break(), -4.0)
    write("juice/unison_up.wav", unison_up(False), -3.0)
    write("juice/unison_top.wav", unison_up(True), -2.0)
    write("juice/fail.wav", fail(), -2.0)
    write("juice/count_tick.wav", count_tick(), -6.0)
    write("juice/new_best.wav", new_best(), -2.0)


if __name__ == "__main__":
    main()
