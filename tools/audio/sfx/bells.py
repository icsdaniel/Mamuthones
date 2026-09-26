"""Modal synthesis of the Mamuthones' bell load.

Physical picture: a Mamuthone carries a load of hand-hammered sheet-iron cowbells
of different sizes on his back. A jolt (the tilt) swings every clapper; each bell is
struck once, often twice (the clapper bounces off the opposite wall), at slightly
different moments. Each bell is modelled as a bank of damped inharmonic modes:

  * mode ratios of a folded-sheet bell (no integer ratios), jittered per bell because
    each one is hammered by hand;
  * every mode is a close doublet (the bell is not round: degenerate modes split),
    which gives the slow beating shimmer of real cowbells;
  * higher modes decay faster (T60 ~ f^-0.85); bigger bells ring longer;
  * the clapper is a short force pulse: its duration (hardness) low-passes which modes
    get excited, so soft hits are darker, not just quieter;
  * a small hardening nonlinearity: pitch glides down a little as the amplitude drops;
  * riveted seams chatter: noise gated by the bell's own envelope;
  * a restrike partly damps the ringing bell (the clapper rests against the wall);
  * a short stone-street reflection pattern is baked in.

Run:  python3 tools/audio/sfx/bells.py
"""
from __future__ import annotations

import sys
import numpy as np

from dsp import (SR, add_at, bandpass, limit, convolve_ir, db, fade, highpass, lowpass, make_ir,
                 normalize_peak, pan, resonator, trim_tail, write_ogg, write_wav)

# Folded-sheet bell mode ratios (fundamental = 1). Chosen away from integer ratios
# so the load sounds like iron, not a tuned instrument.
MODE_RATIOS = np.array([1.00, 1.43, 1.89, 2.36, 2.71, 3.22, 3.78, 4.41, 5.06, 5.77, 6.63, 7.58, 8.61, 9.74, 10.93, 12.2])


class Bell:
    def __init__(self, f0: float, t60: float, rng: np.random.Generator, size: float):
        self.f0 = f0
        self.size = size  # 0 small .. 1 big
        n = len(MODE_RATIOS)
        self.freqs = f0 * MODE_RATIOS * rng.uniform(0.965, 1.035, n)
        self.freqs[0] = f0
        # doublet split in Hz (0.15%..0.9% of the mode frequency)
        self.split = self.freqs * rng.uniform(0.0015, 0.009, n)
        self.split_amp = rng.uniform(0.25, 0.8, n)
        base = 1.0 / (1.0 + 0.13 * np.arange(n)) * rng.uniform(0.4, 1.0, n)
        base[0] *= 0.55  # a cowbell's lowest mode is weaker than the cluster above it
        self.amps = base
        self.t60 = t60 * rng.uniform(0.85, 1.15) * (f0 / self.freqs) ** 0.85
        self.t60 = np.maximum(self.t60, 0.018)
        self.glide = rng.uniform(0.002, 0.006)
        self.seam = rng.uniform(0.02, 0.07)  # seam-rattle amount
        # the clapper's own knock: bigger bells hang bigger, lower-sounding clappers
        self.clapper_f = rng.uniform(1300, 2600) * float(np.clip((f0 / 700.0) ** 0.5, 0.45, 1.4))
        self.pan = 0.0  # where it hangs across the back (set by make_load)


def strike_response(bell: Bell, n: int, strength: float, fc: float, rng: np.random.Generator,
                    damp: float = 1.0, pos_var: float = 0.35) -> np.ndarray:
    """One clapper strike on a bell: modal response of length n samples."""
    t = np.arange(n) / SR
    out = np.zeros(n)
    # strike position changes which modes are excited
    pos = rng.uniform(1 - pos_var, 1 + pos_var, len(bell.freqs))
    hard = 1.0 / np.sqrt(1.0 + (bell.freqs / fc) ** 4)
    tg = 0.12
    glide_t = t + bell.glide * strength * tg * (1 - np.exp(-t / tg))
    for k, f in enumerate(bell.freqs):
        if f > SR * 0.45:
            continue
        a = bell.amps[k] * pos[k] * hard[k]
        if a < 1e-4:
            continue
        env = np.exp(-6.9078 * t / (bell.t60[k] * damp))
        ph0 = rng.uniform(-0.3, 0.3)
        f2 = f + bell.split[k]
        s = np.sin(2 * np.pi * f * glide_t + ph0) + bell.split_amp[k] * np.sin(2 * np.pi * f2 * glide_t + ph0)
        # sine phases start at ~0 so the onset has no step
        out += a * env * s
    out *= strength
    # clapper contact: a very short knock plus a filtered tick
    m = int(0.03 * SR)
    tick = rng.standard_normal(m) * np.exp(-np.arange(m) / (0.0012 * SR))
    tick = lowpass(highpass(tick, min(fc * 0.5, 4000), 2), 10000, 2)
    knock = resonator(rng.standard_normal(m) * np.exp(-np.arange(m) / (0.004 * SR)), bell.clapper_f, 6)
    click = (0.10 * tick + 0.18 * knock) * strength * min(1.0, fc / 3000)
    out[:m] += click * fade(np.ones(m), 0.0004, 0.01)
    # seam chatter: noise gated by how hard the bell is vibrating
    env = np.sqrt(lowpass(out ** 2, 30, 1).clip(0))
    thr = 0.25 * np.max(env)
    gate = np.clip(env - thr, 0, None)
    lo_c = min(4.0 * bell.f0, 5000)
    chatter = bandpass(rng.standard_normal(n), lo_c, min(lo_c * 3, 12000), 2) * gate * bell.seam * 1.5
    out += chatter
    # gentle nonlinearity so strong hits get a little dirtier (sheet metal)
    pk = np.max(np.abs(out)) + 1e-9
    out = np.tanh(out / pk * 1.2) / np.tanh(1.2) * pk
    return out


def ramp_damp(buf: np.ndarray, start: int, d: float) -> None:
    """A restrike damps what the bell was doing (the clapper touches the wall)."""
    r = int(0.003 * SR)
    end = min(len(buf), start + r)
    buf[start:end] *= np.linspace(1, d, end - start)
    buf[end:] *= d


# ----------------------------------------------------------------------------- loads

SETS = {
    #            n bells, f0 range,      T60 fund, body thump, render s, seed
    "light":   dict(n=5, lo=780, hi=1750, t60=0.60, thump=0.08, dur=1.6, seed=11, settle_t=0.5, settle_p=0.6, hard=1.15),
    "village": dict(n=8, lo=360, hi=1000, t60=1.15, thump=0.18, dur=2.2, seed=23, settle_t=0.85, settle_p=0.9, hard=1.0),
    "full":    dict(n=13, lo=165, hi=680, t60=1.95, thump=0.22, dur=3.2, seed=37, settle_t=1.2, settle_p=1.0, hard=0.9),
}


def make_load(set_id: str) -> list[Bell]:
    cfg = SETS[set_id]
    rng = np.random.default_rng(cfg["seed"])
    n = cfg["n"]
    # geometric spread of sizes with jitter, biggest first
    f = np.geomspace(cfg["lo"], cfg["hi"], n) * rng.uniform(0.94, 1.06, n)
    bells = []
    for i, f0 in enumerate(f):
        size = 1.0 - i / max(1, n - 1)
        t60 = cfg["t60"] * (np.sqrt(cfg["lo"] * cfg["hi"]) / f0) ** 0.45
        bells.append(Bell(float(f0), float(t60), rng, size))
    # spread across the shoulders: big bells near the middle, small ones out to the sides
    order = rng.permutation(n)
    for j, b in enumerate(bells):
        side = -1 if order[j] % 2 else 1
        b.pan = side * (0.12 + 0.45 * (1 - b.size)) * rng.uniform(0.7, 1.0)
    return bells


QUALITY = {
    # spread: max onset spread (s); part: chance each bell rings; strength and hardness (fc);
    # second: chance of a clapper bounce; damp: decay multiplier; clanks: bell-on-bell knocks
    "perfect": dict(spread=0.010, part=1.00, strength=1.00, fc=6500, second=0.55, damp=1.00, clanks=0, settle=0.6, gain=0.0, level=0.0),
    "good":    dict(spread=0.022, part=0.92, strength=0.80, fc=4200, second=0.40, damp=0.92, clanks=0, settle=0.5, gain=-2.5, level=-3.0),
    "ok":      dict(spread=0.090, part=0.45, strength=0.55, fc=3000, second=0.15, damp=0.30, clanks=3, settle=0.3, gain=-6.0, level=-7.5),
    "miss":    dict(spread=0.030, part=0.60, strength=0.35, fc=650,  second=0.00, damp=0.035, clanks=0, settle=0.0, gain=-11.0, level=-11.0),
    # early: the jolt comes before the body is set, so the small bells lead and are
    # choked against the sheepskin; late: a heavy flam, the big bells dragging behind
    "early":   dict(spread=0.015, part=0.85, strength=0.70, fc=6000, second=0.10, damp=0.22, clanks=1, settle=0.0, gain=-5.0, level=-5.0),
    "late":    dict(spread=0.020, part=1.00, strength=0.80, fc=2800, second=0.00, damp=0.75, clanks=0, settle=0.3, gain=-4.0, level=-4.0),
}
TAKES = {"perfect": 3, "good": 3, "ok": 3, "miss": 3, "early": 2, "late": 2}


def body_thump(rng: np.random.Generator, level: float, f: float = 85.0, dur: float = 0.18) -> np.ndarray:
    """The load landing on the sheepskin and the jump landing: a low, short thud."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    fr = f * (1 + 0.6 * np.exp(-t / 0.02))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    tone = np.sin(ph) * np.exp(-t / 0.045)
    noise = lowpass(rng.standard_normal(n), 400, 2) * np.exp(-t / 0.02) * 0.5
    x = (tone + noise) * level
    return fade(x, 0.001, 0.02)


def render_ring(set_id: str, up: bool, quality: str, take: int, bells: list[Bell] | None = None) -> np.ndarray:
    cfg = SETS[set_id]
    q = QUALITY[quality]
    bells = bells or make_load(set_id)
    rng = np.random.default_rng([cfg["seed"], int(up), list(QUALITY).index(quality), take])
    n = int(cfg["dur"] * SR)
    # the perfect ring is stereo (the load spread across your back, for headphones);
    # the others are mono and narrower, which also tells them apart
    stereo = quality == "perfect"
    out = np.zeros((n, 2)) if stereo else np.zeros(n)
    place = (lambda x, p: pan(x, p)) if stereo else (lambda x, p: x)
    nb = len(bells)
    # which bells lead: down = the load drops, the big bells hit hardest and first;
    # up = the load is flung up, the small bells lead and the big ones lag and ring less.
    ringers = [i for i in range(nb) if rng.random() < q["part"]] or [int(rng.integers(nb))]
    if quality == "miss":
        ringers = [i for i in range(nb) if bells[i].size > 0.35] or [0]
    lags = {}
    for i in ringers:
        u = rng.random()
        lag = q["spread"] * (u ** 1.5) if quality in ("perfect", "good") else q["spread"] * u
        if up and quality in ("perfect", "good"):
            lag += 0.008 * bells[i].size  # big bells answer a little later on the upswing
        if quality == "late":
            lag += 0.045 * bells[i].size ** 1.5  # the big bells drag
        elif quality == "early":
            lag += 0.03 * bells[i].size  # the small ones are already ringing
        lags[i] = lag
    first = min(lags.values())  # the ring starts at sample 0: no added latency
    for i in ringers:
        b = bells[i]
        lag = lags[i] - first
        emph = (0.55 + 0.9 * b.size) if not up else (1.25 - 0.55 * b.size)
        if quality == "early":
            emph = 1.4 - 0.9 * b.size
        elif quality == "late":
            emph = 0.45 + 1.1 * b.size
        st = q["strength"] * emph * rng.uniform(0.8, 1.1)
        # heavier bells carry heavier clappers: a longer contact excites fewer high modes
        fc = q["fc"] * cfg["hard"] * (1.25 if up else 0.9) * rng.uniform(0.85, 1.15)
        damp = q["damp"] * (0.92 if up else 1.0)
        start = int(lag * SR)
        m = n - start
        buf = np.zeros(m)
        buf += strike_response(b, m, st, fc, rng, damp)
        if quality == "late" and b.size > 0.3:
            # the flam: the big clappers hit twice, 25-45 ms apart, nearly as hard
            d2 = int(rng.uniform(0.025, 0.045) * SR)
            ramp_damp(buf, d2, 0.8)
            buf[d2:] += strike_response(b, m - d2, st * rng.uniform(0.7, 0.9), fc, rng, damp)
        elif rng.random() < q["second"]:
            d2 = int(rng.uniform(0.035, 0.11) * SR * (0.7 + 0.6 * b.size))
            if d2 < m:
                ramp_damp(buf, d2, rng.uniform(0.55, 0.85))
                buf[d2:] += strike_response(b, m - d2, st * rng.uniform(0.35, 0.65), fc * 0.8, rng, damp)
        # the load settles: clappers keep swinging and tap again, softer, for a few
        # hundred ms (the jangle after the jolt)
        tt = 0.0
        for _ in range(2):
            # small bells on short straps swing back sooner than big ones
            if rng.random() >= q["settle"] * cfg["settle_p"]:
                break
            tt += rng.uniform(0.11, 0.26) * (0.8 + 0.5 * b.size) * cfg["settle_t"]
            d3 = int(tt * SR)
            if d3 < m:
                ramp_damp(buf, d3, rng.uniform(0.7, 0.9))
                buf[d3:] += strike_response(b, m - d3, st * rng.uniform(0.12, 0.3), fc * 0.7, rng, damp)
        # a louder bell for a bigger bell (more metal), mildly
        add_at(out, place(buf * (0.6 + 0.6 * b.size), b.pan), start)
    # bell-on-bell clanks for the uneven "ok" ring
    for _ in range(q["clanks"]):
        b = bells[int(rng.integers(nb))]
        start = int(rng.uniform(0.0, 0.12) * SR)
        m = int(0.25 * SR)
        add_at(out, place(strike_response(b, m, 0.7, 7000, rng, 0.06, pos_var=0.6) * 0.8, b.pan), start)
    # body thump: stronger on the down ring and on a miss (the dull knock)
    th = cfg["thump"] * (1.0 if not up else 0.35)
    if quality == "miss":
        th = cfg["thump"] * 2.2
        out = lowpass(out, 2600, 2)
        # the muffled clappers knock on iron: a short dull clack at 1-2.5 kHz, so the
        # knock still reads on a phone speaker that has no bass
        kn = int(0.05 * SR)
        e = rng.standard_normal(kn) * np.exp(-np.arange(kn) / (0.006 * SR))
        clack = resonator(e, rng.uniform(1100, 1400), 5) + 0.7 * resonator(e, rng.uniform(1900, 2400), 6)
        add_at(out, clack * 0.9 * np.max(np.abs(out)) / (np.max(np.abs(clack)) + 1e-9), int(0.002 * SR))
    elif quality == "ok":
        th *= 1.2
    tf = {"light": 110.0, "village": 92.0, "full": 74.0}[set_id]
    add_at(out, place(body_thump(rng, th * np.max(np.abs(out) + 1e-9) * 2.0, tf * (1.1 if up else 1.0)), 0.0), 0)
    # street reflections (stone walls), low in the mix
    ir = make_ir(0.9, 1.0, np.random.default_rng(99), stereo=stereo,
                 early=[(0.011, 0.35), (0.017, 0.25), (0.029, 0.18), (0.041, 0.12), (0.063, 0.08)],
                 bright=4500)
    wet = convolve_ir(out, ir)[: len(out)]
    out = out + wet * db(-11 if quality != "miss" else -20)
    out *= db(q["gain"])
    return out


def render_accent(set_id: str, up: bool, take: int, bells: list[Bell]) -> np.ndarray:
    """The extra weight of a hard flick, layered over the ring: the big bells slammed by
    their clappers with a hard, bright contact, and a heavier body jolt. Short and mono."""
    cfg = SETS[set_id]
    rng = np.random.default_rng([cfg["seed"], 77, int(up), take])
    n = int(0.7 * SR)
    out = np.zeros(n)
    for b in bells:
        if b.size < 0.4:
            continue
        start = int(rng.uniform(0, 0.006) * SR)
        x = strike_response(b, n - start, 1.2 * (0.5 + b.size), 9000 * cfg["hard"], rng, 0.45)
        add_at(out, x, start)
    add_at(out, body_thump(rng, cfg["thump"] * 2.5 * np.max(np.abs(out)), {"light": 120.0, "village": 98.0, "full": 80.0}[set_id]), 0)
    return fade(out, 0.0008, 0.12)


def render_jangle(set_id: str, bells: list[Bell]) -> np.ndarray:
    """The load keeps jangling after a streak: sparse, soft clapper taps on every bell,
    thinning out over about 1.8 s. Starts almost silent (it plays under a ring)."""
    cfg = SETS[set_id]
    rng = np.random.default_rng([cfg["seed"], 88])
    n = int(2.2 * SR)
    out = np.zeros(n)
    for b in bells:
        t = rng.uniform(0.09, 0.2)
        for k in range(int(rng.integers(2, 5))):
            if t > 1.6:
                break
            start = int(t * SR)
            st = rng.uniform(0.1, 0.25) * np.exp(-t / 0.7)
            add_at(out, strike_response(b, n - start, st, 2500 * cfg["hard"], rng, 0.6), start)
            t += rng.uniform(0.12, 0.35) * (0.8 + 0.5 * b.size) * cfg["settle_t"]
    return fade(out, 0.02, 0.2)


def render_set(set_id: str) -> dict[str, np.ndarray]:
    bells = make_load(set_id)
    res = {}
    for up in (True, False):
        for quality in QUALITY:
            for k in range(TAKES[quality]):
                res[f"{set_id}_{'up' if up else 'down'}_{quality}_{k + 1}"] = render_ring(set_id, up, quality, k, bells)
    # Level each (direction, quality) group to a fixed loudness offset from the perfect
    # down ring (RMS of the first 300 ms). Up rings are a touch lighter than down rings.
    def loud(x):
        # total power over both channels, so stereo and mono rings compare fairly
        y = x[: int(0.3 * SR)]
        return np.sqrt(np.mean(y ** 2) * (y.shape[1] if y.ndim == 2 else 1)) + 1e-12
    ref = np.mean([loud(v) for k, v in res.items() if "_down_perfect_" in k])
    for up in ("up", "down"):
        for quality, qd in QUALITY.items():
            keys = [k for k in res if f"_{up}_{quality}_" in k]
            cur = np.mean([loud(res[k]) for k in keys])
            target = ref * db(qd["level"] + (-1.0 if up == "up" else 0.0))
            for k in keys:
                res[k] = res[k] * (target / cur)
        for k in range(2):
            x = render_accent(set_id, up == "up", k, bells)
            res[f"{set_id}_{up}_accent_{k + 1}"] = x * (ref * db(-5.0) / loud(x))
    j = render_jangle(set_id, bells)
    res[f"{set_id}_jangle_1"] = j * (ref * db(-12.0) / (np.sqrt(np.mean(j ** 2)) + 1e-12))
    # Then the whole set to a loudness target (heavier loads a little louder) and a
    # look-ahead limiter on the few strike peaks that would pass -1.5 dBFS, so light
    # sets are not left quiet by their spiky attacks.
    target = {"light": -16.5, "village": -16.0, "full": -15.5}[set_id]
    g = db(target) / ref
    for k in res:
        floor = -44 if "_miss_" in k else -52
        res[k] = trim_tail(limit(res[k] * g, -1.5), floor, 0.04)
        res[k] = fade(res[k], 0.0008, 0.0)
    return res


# ----------------------------------------------------------------------------- row

def render_row(up: bool, tight: bool, take: int) -> np.ndarray:
    """The rest of the row: six other Mamuthones' loads, at a distance, across the
    stereo field. Tight = unison (onsets within ~10 ms), loose = a ragged row."""
    rng = np.random.default_rng([500, int(up), int(tight), take])
    dur = 3.0
    n = int(dur * SR)
    out = np.zeros((n, 2))
    pans = [-0.85, -0.55, -0.25, 0.25, 0.55, 0.85]
    for m, p in enumerate(pans):
        lrng = np.random.default_rng(700 + m)  # each Mamuthone keeps his own load
        nb = int(lrng.integers(6, 10))
        f = np.geomspace(lrng.uniform(170, 260), lrng.uniform(700, 1000), nb) * lrng.uniform(0.93, 1.07, nb)
        bells = [Bell(float(x), 1.3 * (420 / x) ** 0.45, lrng, 1 - i / (nb - 1)) for i, x in enumerate(f)]
        dist = 0.55 + 0.45 * abs(p)
        if tight:
            off = abs(rng.normal(0, 0.006))
        else:
            off = abs(rng.normal(0, 0.045)) + rng.uniform(0, 0.03)
        load = np.zeros(n)
        for b in bells:
            if rng.random() > 0.85:
                continue
            emph = (0.55 + 0.9 * b.size) if not up else (1.25 - 0.55 * b.size)
            lag = off + (0.012 if tight else 0.04) * rng.random() ** 1.5
            start = int(lag * SR)
            if start >= n:
                continue
            fc = (5000 if tight else 3500) * rng.uniform(0.8, 1.2)
            add_at(load, strike_response(b, n - start, 0.8 * emph, fc, rng) * (0.6 + 0.6 * b.size), start)
        load = lowpass(load, 5200 / dist, 1) / dist
        out += pan(load, p)
    ir = make_ir(1.5, 1.8, np.random.default_rng(123), stereo=True,
                 early=[(0.019, 0.3), (0.031, 0.22), (0.047, 0.16), (0.074, 0.12), (0.11, 0.08)],
                 bright=4000, predelay=0.012)
    wet = convolve_ir(out, ir)[:n]
    out = out * 0.7 + wet * db(-4)
    return out


def main() -> None:
    only = [a for a in sys.argv[1:] if a in SETS or a == "row"] or ["light", "village", "full", "row"]
    for s in ("light", "village", "full"):
        if s in only:
            for name, x in render_set(s).items():
                write_wav(f"bells/{name}.wav", x)
            print("wrote", s)
    if "row" in only:
        rows = {}
        for up in (True, False):
            for tight in (False, True):
                for k in range(3):
                    rows[f"row_{'tight' if tight else 'loose'}_{'up' if up else 'down'}_{k + 1}"] = render_row(up, tight, k)
        peak = max(np.max(np.abs(v)) for v in rows.values())
        for name, x in rows.items():
            # a distant layer played 3 to 17 dB down: its tail can stop at -46 dB
            y = trim_tail(x * db(-2.0) / peak, -46, 0.08)
            y = fade(y, 0.002, 0.0)
            # the row stands a few metres away: ~10 ms of air before it arrives
            y = np.concatenate([np.zeros((int(0.010 * SR), 2)), y])
            # WAV, not OGG: starting a Vorbis playback costs ~0.7 ms, too much per bell
            write_wav(f"bells/{name}.wav", y)
        print("wrote row")


if __name__ == "__main__":
    main()
