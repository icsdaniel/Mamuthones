"""Measurements: onset detection on stems, chart-to-onset timing, rests and cues, track features."""
from __future__ import annotations

import numpy as np
from scipy.ndimage import maximum_filter1d, uniform_filter1d

import dsp
from dsp import SR

N_FFT = 2048
HOP = 128
LAG = 4
# measured with synthetic clicks and tone changes (see self_test): frame centre minus this is the onset
BIAS = -0.010


def onset_times(x, delta=0.05):
    """Spectral-flux onsets (log magnitude, frequency max-filtered reference, like SuperFlux).
    Silent stretches are skipped, so sparse stems are cheap."""
    if x.ndim == 2:
        x = x.mean(axis=1)
    peak = np.max(np.abs(x))
    if peak < 1e-6:
        return np.array([])
    x = (x / peak).astype(np.float32)
    win = np.hanning(N_FFT).astype(np.float32)
    nfr = 1 + (len(x) - N_FFT) // HOP
    # frames with any energy (plus neighbours)
    blk = np.abs(x[: (len(x) // HOP) * HOP]).reshape(-1, HOP).max(axis=1)
    live = maximum_filter1d(blk > 1e-4, int(N_FFT / HOP) * 2 + 3)[:nfr]
    idx_fr = np.flatnonzero(live)
    d = np.zeros(nfr, dtype=np.float32)
    if len(idx_fr) == 0:
        return np.array([])
    chunk = 8000
    for c0 in range(0, len(idx_fr), chunk):
        fr = idx_fr[c0:c0 + chunk]
        fr2 = np.concatenate([np.maximum(fr - LAG, 0), fr])
        idx = np.arange(N_FFT)[None, :] + HOP * fr2[:, None]
        lm = np.log1p(1000 * np.abs(np.fft.rfft(x[idx] * win, axis=1)))
        k = len(fr)
        ref = maximum_filter1d(lm[:k], 5, axis=1)
        d[fr] = np.maximum(0, lm[k:] - ref).sum(axis=1)
    d[:LAG] = 0
    # normalise against the loudest flux in the surrounding seconds, so a soft legato passage is
    # judged against itself and not against the loudest attack in the whole stem
    local = maximum_filter1d(d, int(3.0 * SR / HOP) | 1)
    out = d / np.maximum(local, d.max() * 0.08 + 1e-9)
    base = uniform_filter1d(out, int(0.25 * SR / HOP) | 1)
    loc = maximum_filter1d(out, int(0.05 * SR / HOP) | 1)
    peaks = np.where((out == loc) & (out > base + delta) & (out > 0.03))[0]
    t = (peaks * HOP + N_FFT / 2) / SR - BIAS
    return t


def self_test():
    """Onset bias check on a click train and on legato pitch changes."""
    n = SR * 4
    x = np.zeros(n)
    true = np.arange(0.5, 3.5, 0.37)
    for t in true:
        i = int(t * SR)
        k = np.arange(2000)
        x[i:i + 2000] += np.sin(2 * np.pi * 800 * k / SR) * np.exp(-k / 400)
    got = onset_times(x)
    err = [got[np.argmin(np.abs(got - t))] - t for t in true]
    return float(np.mean(err)), float(np.max(np.abs(err)))


def timing_report(song, sources, stems, charts):
    """For each chart note, distance to the nearest onset in the stem that drives it."""
    cache = {}
    res = {}
    for d, lst in sources.items():
        errs = []
        misses = []
        shifted = []
        for (b, k, stem, ln) in lst:
            if k == "rest" or stem is None:
                continue
            if stem not in stems:
                misses.append((b, k, stem, None))
                continue
            if stem not in cache:
                cache[stem] = onset_times(stems[stem])
            on = cache[stem]
            t = song.time(b)
            if len(on) == 0:
                misses.append((b, k, stem, None))
                continue
            e = float(np.min(np.abs(on - t)))
            errs.append(e)
            # control: the same check with every note moved by a sixteenth-and-a-bit
            shifted.append(float(np.min(np.abs(on - (t + 0.37 * song.spb)))))
            if e > 0.02:
                misses.append((b, k, stem, round(e * 1000, 1)))
        errs = np.array(errs)
        sh = np.array(shifted)
        res[d] = {
            "checked": len(errs),
            "within_20ms": float(np.mean(errs <= 0.02)) if len(errs) else 1.0,
            "median_ms": float(np.median(errs) * 1000) if len(errs) else 0.0,
            "p95_ms": float(np.percentile(errs, 95) * 1000) if len(errs) else 0.0,
            "control_within_20ms": float(np.mean(sh <= 0.02)) if len(sh) else 0.0,
            "misses": misses[:12],
        }
    return res


def rest_report(song, stems, sources):
    """Stand-stills must be real rests: no onsets in the rhythmic/melodic stems inside them."""
    from mixer import THROUGH
    skip = THROUGH | {"calls", "count", "rim", "shake"}   # cues and temptations are allowed
    on = {k: onset_times(v) for k, v in stems.items() if k not in skip}
    rests = sorted({(b, ln) for lst in sources.values() for (b, k, stem, ln) in lst if k == "rest"})
    bad = []
    for (b, ln) in rests:
        t0, t1 = song.time(b) + 0.06, song.time(b + ln) - 0.06
        for k, o in on.items():
            hits = o[(o > t0) & (o < t1)]
            if len(hits):
                bad.append((b, k, len(hits)))
    return {"rests": len(rests), "with_onsets": bad}


def cue_report(song, stems, sources):
    """Every bell and ring has an audible cue (rim click or call) within the beat before it."""
    names = ("frame", "rim", "calls", "rope", "snare", "hat", "count") + \
        (("bells", "shake") if song.kind == "piazza" else ())
    cue_on = np.concatenate([onset_times(stems[k]) for k in names if k in stems] or [np.array([])])
    total = 0
    ok = 0
    for d, lst in sources.items():
        for (b, k, stem, ln) in lst:
            if k not in ("bell", "ring"):
                continue
            total += 1
            t = song.time(b)
            if np.any((cue_on > t - song.spb - 0.02) & (cue_on < t - 0.08)):
                ok += 1
    return {"bells": total, "cued": ok}


def mix_onsets(x):
    """Onsets heard in the final mix (not the stems): a log-magnitude spectral flux with a 1024
    window, normalised over 2 s, peaks above a 0.2 s local mean. This is the same measurement the
    play review makes on the shipped OGG files."""
    from scipy.signal import stft
    from scipy.ndimage import maximum_filter1d
    m = x.mean(axis=1) if x.ndim == 2 else x
    hop = 128
    _, _, Z = stft(m, SR, nperseg=1024, noverlap=1024 - hop, boundary=None, padded=False)
    L = np.log1p(100 * np.abs(Z))
    ref = maximum_filter1d(L, 3, axis=0)
    d = np.maximum(0, L[:, 2:] - ref[:, :-2]).sum(0)
    d = np.concatenate([[0, 0], d])
    d /= maximum_filter1d(d, int(2 * SR / hop) | 1) + 1e-9
    base = uniform_filter1d(d, int(0.2 * SR / hop) | 1)
    loc = maximum_filter1d(d, int(0.04 * SR / hop) | 1)
    pk = np.where((d == loc) & (d > base + 0.08) & (d > 0.1))[0]
    return (pk * hop + 512) / SR


def mix_timing_report(song, charts, onsets, offset=None, tol=0.02):
    """Per chart: the share of notes with an onset in the main mix within tol, and the same for the
    chart shifted by 0.37 beat (the control)."""
    off = song.offset if offset is None else offset
    res = {}
    for name, notes in charts.items():
        ts = np.array([off + n["b"] * song.spb for n in notes if n["k"] != "rest"])
        if not len(ts) or not len(onsets):
            continue
        idx = np.clip(np.searchsorted(onsets, ts), 1, len(onsets) - 1)
        e = np.minimum(np.abs(onsets[idx] - ts), np.abs(onsets[idx - 1] - ts))
        ts2 = ts + 0.37 * song.spb
        idx2 = np.clip(np.searchsorted(onsets, ts2), 1, len(onsets) - 1)
        e2 = np.minimum(np.abs(onsets[idx2] - ts2), np.abs(onsets[idx2 - 1] - ts2))
        res[name] = {"within_20ms": float(np.mean(e <= tol)), "control": float(np.mean(e2 <= tol))}
    return res


def features(x):
    """A few numbers that tell tracks apart: centroid, spread of loudness, onset rate, chroma."""
    m = x.mean(axis=1) if x.ndim == 2 else x
    mag = dsp.stft_mag(m, 4096, 2048)
    freqs = np.fft.rfftfreq(4096, 1 / SR)
    p = mag ** 2
    cen = (p * freqs).sum(axis=1) / (p.sum(axis=1) + 1e-12)
    rms = np.sqrt(p.sum(axis=1))
    loud = dsp.db(rms + 1e-9)
    act = loud > loud.max() - 40
    chroma = np.zeros(12)
    sel = (freqs > 60) & (freqs < 2000)
    pc = (np.round(12 * np.log2(freqs[sel] / 440.0)) + 9) % 12
    e = p[:, sel].sum(axis=0)
    for i in range(12):
        chroma[i] = e[pc == i].sum()
    chroma /= chroma.sum() + 1e-12
    on = onset_times(m)
    return {
        "centroid_hz": float(np.median(cen[act])),
        "loudness_range_db": float(np.percentile(loud[act], 95) - np.percentile(loud[act], 10)),
        "onsets_per_s": float(len(on) / (len(m) / SR)),
        "low_share": float(p[:, freqs < 200].sum() / p.sum()),
        "chroma": chroma.round(3).tolist(),
    }
