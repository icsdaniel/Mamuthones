"""The two-thumb stomp: the loudest thing the player does with the step buttons.

Both feet come down together on the stone (two heel stamps ~10 ms apart, one each side),
the whole body drops under thirty kilos of iron (the full load's impact boom) and the load
crashes as it lands. The dull take is an off-time stomp; the half stomp is one foot only.

Run:  python3 tools/audio/sfx/hits.py
"""
from __future__ import annotations

import numpy as np

from bells import impact, make_load, render_accent
from dsp import (SR, add_at, bandpass, convolve_ir, db, fade, highpass, limit, lowpass, make_ir, pan,
                 resonator, trim_tail, write_wav)


def stamp(rng: np.random.Generator, f: float, dur: float = 0.35, dull: bool = False) -> np.ndarray:
    """One heel stamped into stone: a driven, falling kick, the sole's slap and a hard heel click."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    fr = f * (1 + 2.4 * np.exp(-t / 0.01))
    kick = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / (0.07 if not dull else 0.04))
    kick = np.tanh(kick * 2.2) / np.tanh(2.2)
    slap = bandpass(rng.standard_normal(n), 220, 3000, 2) * np.exp(-t / 0.014) * 0.9
    hn = int(0.03 * SR)
    he = rng.standard_normal(hn) * np.exp(-np.arange(hn) / (0.002 * SR))
    heel = resonator(he, rng.uniform(1300, 1600), 4) + 0.6 * resonator(he, rng.uniform(2600, 3200), 5)
    heel *= 0.8 / (np.max(np.abs(heel)) + 1e-9)
    x = kick * 0.9 + slap
    x[:hn] += heel * (0.35 if dull else 1.0)
    if dull:
        x = lowpass(x, 1800, 2)
    return fade(x, 0.0004, 0.05)


def stomp(take: int, dull: bool = False) -> np.ndarray:
    rng = np.random.default_rng([181, take, int(dull)])
    n = int(1.6 * SR)
    out = np.zeros((n, 2))
    # both feet: left first, the right 7-13 ms later, a little lower
    add_at(out, pan(stamp(rng, 60 * rng.uniform(0.97, 1.03), dull=dull), -0.35), 0)
    add_at(out, pan(stamp(rng, 54 * rng.uniform(0.97, 1.03), dull=dull) * 0.9, 0.35),
           int(rng.uniform(0.007, 0.013) * SR))
    pk = np.max(np.abs(out))
    # the body and the load dropping together
    boom = impact(rng, "full", False, pk * (0.9 if not dull else 0.5))
    add_at(out, pan(boom, 0.0), 0)
    if not dull:
        crash = render_accent("full", False, take % 2, make_load("full"))
        crash = highpass(crash, 250, 2) * (pk * 0.55 / (np.max(np.abs(crash)) + 1e-9))
        add_at(out, pan(crash, 0.18 * (1 if take % 2 else -1)), int(0.004 * SR))
    ir = make_ir(1.1, 1.3, np.random.default_rng(191), stereo=True,
                 early=[(0.012, 0.35), (0.021, 0.25), (0.034, 0.18), (0.052, 0.12)], bright=4500)
    out = out + convolve_ir(out, ir)[:n] * db(-10 if not dull else -18)
    if dull:
        out = out[: int(0.5 * SR)]
    return out


def half(take: int) -> np.ndarray:
    """One thumb only: a single heavy foot, darker, with no crash (the other foot is missing)."""
    rng = np.random.default_rng([185, take])
    x = stamp(rng, 64 * rng.uniform(0.97, 1.03), 0.3, dull=True)
    x = x + impact(rng, "light", False, np.max(np.abs(x)) * 0.35)[: len(x)]
    return pan(x, 0.0)


def main() -> None:
    takes = [stomp(k) for k in range(3)]
    for k, x in enumerate(takes):
        y = limit(x * db(0.0) / np.max(np.abs(x)) * db(2.0), -1.0)
        write_wav(f"fx/stomp_{k + 1}.wav", trim_tail(fade(y, 0.0004, 0.0), -56, 0.08))
    for k in range(2):
        x = stomp(k, dull=True)
        y = limit(x * db(-3.0) / np.max(np.abs(x)), -1.0)
        write_wav(f"fx/stomp_ok_{k + 1}.wav", trim_tail(fade(y, 0.0004, 0.0), -56, 0.05))
    for k in range(2):
        x = half(k)
        write_wav(f"fx/stomp_half_{k + 1}.wav", trim_tail(fade(x * db(-5.0) / np.max(np.abs(x)), 0.0004, 0.0), -56, 0.04))
    print("wrote stomps")


if __name__ == "__main__":
    main()
