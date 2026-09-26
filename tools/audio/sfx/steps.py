"""Steps and hold drones.

A step is two layers played together by the Sound autoload:
  * steps/foot_{lane}_{take}.wav: a leather-soled footfall on stone (heel thump, grit,
    scuff), different for each lane and three takes each;
  * steps/tone_{lane}_{pc}.wav: a short tuned wooden knock at the lane's pitch, for the
    even pitch classes 0, 2, .. 10 of the song's key_root; the Sound autoload plays an
    odd key's tone from the one a semitone below at pitch_scale 2^(1/12) (a 6 % resample
    of a 0.34 s knock is inaudible, and it halves the files).
Lanes are root, fifth and octave: Left = root, Middle = fifth, Right = octave.

Hold drones: loops/drone_{lane}_{pc}.ogg, a launeddas-style double reed drone at the
lane's pitch. Every partial is a whole multiple of 1/LOOP Hz and the vibrato is a whole
number of cycles per loop, so the file is exactly periodic and loops without a seam.

Run:  python3 tools/audio/sfx/steps.py
"""
from __future__ import annotations

import numpy as np

from dsp import (SR, add_at, bandpass, convolve_ir, db, fade, highpass, lowpass,
                 make_ir, periodic_lfo, periodic_noise, resonator, trim_tail,
                 write_ogg, write_wav)

LANE_INTERVALS = (0, 7, 12)
LOOP = 3.0  # seconds, drone loop length


def base_midi(pc: int) -> int:
    """Lane-0 pitch for a key: D3 (50) up to C#4 (61), so steps sit under the tunes."""
    return 50 + (pc - 2) % 12


def mtof(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def footfall(lane: int, take: int) -> np.ndarray:
    rng = np.random.default_rng([31, lane, take])
    dur = 0.32
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # heel thump: the body's weight into stone (low, short, pitch falling)
    f = (78, 70, 88)[lane] * rng.uniform(0.94, 1.06)
    fr = f * (1 + 0.8 * np.exp(-t / 0.012))
    thump = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.03)
    out += thump * (0.9, 1.0, 0.75)[lane]
    # sole contact: band-limited noise, the stone's hard slap
    slap = bandpass(rng.standard_normal(n), 250, 2600, 2) * np.exp(-t / 0.012)
    out += slap * 0.55
    # grit crunching under the sole: sparse tiny impulses in the first 40 ms
    grit = np.zeros(n)
    for _ in range(int(rng.integers(10, 22))):
        k = int(rng.uniform(0.001, 0.045) * SR)
        grit[k] += rng.uniform(-1, 1)
    grit = resonator(highpass(grit, 1800, 2), rng.uniform(3000, 5000), 1.5) * 0.35
    out += grit
    # leather scuff (the foot rolls forward), stronger on the right lane (toe push)
    sc_len = int(0.09 * SR)
    sc_t = np.arange(sc_len) / SR
    scuff = bandpass(rng.standard_normal(sc_len), 900, 4200, 2) * np.sin(np.pi * sc_t / (0.09)) ** 2
    add_at(out, scuff * (0.10, 0.06, 0.16)[lane], int(0.012 * SR))
    # small stone street reflection
    ir = make_ir(0.35, 0.4, np.random.default_rng(5), stereo=False,
                 early=[(0.009, 0.3), (0.016, 0.2), (0.027, 0.12)], bright=5000)
    out = out + convolve_ir(out, ir)[:n] * db(-13)
    return fade(out, 0.0005, 0.06)


def tone(lane: int, pc: int) -> np.ndarray:
    """Tuned wooden knock: a short, warm near-harmonic tone with a bar overtone."""
    m = base_midi(pc) + LANE_INTERVALS[lane]
    f = mtof(m)
    dur = 0.34
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng([41, lane, pc])
    partials = [(1.0, 1.0, 0.24), (2.0, 0.32, 0.13), (3.0, 0.10, 0.08), (3.93, 0.14, 0.035), (5.4, 0.05, 0.02)]
    out = np.zeros(n)
    for r, a, d in partials:
        fr = f * r
        if fr > 16000:
            continue
        out += a * np.sin(2 * np.pi * fr * t + rng.uniform(-0.2, 0.2) * 0) * np.exp(-t / d)
    # soft mallet: slightly slower attack than the footfall (2 ms)
    att = np.clip(t / 0.002, 0, 1)
    out *= att
    ir = make_ir(0.4, 0.45, np.random.default_rng(6), stereo=False,
                 early=[(0.009, 0.3), (0.016, 0.2), (0.027, 0.12)], bright=5000)
    out = out + convolve_ir(out, ir)[:n] * db(-16)
    return fade(out, 0.0005, 0.05)


def drone(lane: int, pc: int) -> np.ndarray:
    """Double-reed drone, exactly periodic over LOOP seconds."""
    rng = np.random.default_rng([51, lane, pc])
    n = int(LOOP * SR)
    t = np.arange(n) / SR
    res = 1.0 / LOOP
    f = round(mtof(base_midi(pc) + LANE_INTERVALS[lane]) / res) * res
    out = np.zeros(n)
    for reed, detune, gain in ((0, 0.0, 1.0), (1, 2 * res, 0.55)):
        f0 = f + detune
        vib_cycles = int(round(5.0 * LOOP)) + reed  # ~5 Hz vibrato, whole cycles per loop
        vib = 0.0025 * np.sin(2 * np.pi * vib_cycles * t / LOOP + rng.uniform(0, 6.28))
        for k in range(1, 40):
            fk = f0 * k
            if fk > 12000:
                break
            a = 1.0 / k ** 1.0 * (0.45 if k % 2 == 0 else 1.0)
            # reed "formant" around 1.5 kHz gives the nasal launeddas colour
            a *= 1 + 1.5 * np.exp(-((np.log2(fk / 1500.0)) ** 2) / 0.4)
            # vibrato as phase modulation with whole cycles, so the loop stays periodic
            beta = 0.0025 * fk / (vib_cycles / LOOP)
            out += gain * a * np.sin(2 * np.pi * fk * t + beta * np.sin(2 * np.pi * vib_cycles * t / LOOP) + rng.uniform(0, 6.28))
    # breath: periodic noise shaped around the reed formant, gently pulsing
    br = periodic_noise(n, rng, 0.0, lo=600, hi=4000)
    pulse = 1 + 0.3 * periodic_lfo(n, rng, 6)
    out += br * pulse * 0.06 * np.std(out)
    # slow swell of the blowing pressure (periodic)
    out *= 1 + 0.08 * periodic_lfo(n, rng, 3)
    return out


def main() -> None:
    for lane in range(3):
        for k in range(3):
            x = footfall(lane, k)
            write_wav(f"steps/foot_{lane}_{k + 1}.wav", x * db(-3) / np.max(np.abs(x)))
    tones = {}
    for lane in range(3):
        for pc in range(0, 12, 2):
            tones[(lane, pc)] = tone(lane, pc)
    for (lane, pc), x in tones.items():
        # equal loudness across pitches: normalise RMS, higher lanes a little softer
        rms = np.sqrt(np.mean(x[: int(0.15 * SR)] ** 2))
        y = x * db(-17 - 1.0 * lane) / rms
        assert np.max(np.abs(y)) < db(-1.5)
        write_wav(f"steps/tone_{lane}_{pc:02d}.wav", y)
    for lane in range(3):
        for pc in range(12):
            x = drone(lane, pc)
            rms = np.sqrt(np.mean(x ** 2))
            y = x * db(-20 - 1.0 * lane) / rms
            assert np.max(np.abs(y)) < db(-2), np.max(np.abs(y))
            write_ogg(f"loops/drone_{lane}_{pc:02d}.ogg", y, 0.3)
    print("wrote steps and drones")


if __name__ == "__main__":
    main()
