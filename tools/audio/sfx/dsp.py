"""Shared DSP helpers for the Sound area's offline synthesis tools.

Everything is numpy/scipy; outputs are float arrays in [-1, 1] at SR.
"""
from __future__ import annotations

import os
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "audio", "sfx")


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(round(dur * SR))) / SR


def fade(x: np.ndarray, fin: float = 0.0015, fout: float = 0.02) -> np.ndarray:
    """Raised-cosine fade in/out so one-shots start and end at silence (no clicks)."""
    x = x.copy()
    n_in = max(1, int(fin * SR))
    n_out = max(1, int(fout * SR))
    w_in = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n_in))
    w_out = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n_out))
    x[:n_in] = (x[:n_in].T * w_in).T
    x[-n_out:] = (x[-n_out:].T * w_out).T
    return x


def trim_tail(x: np.ndarray, floor_db: float = -72.0, fout: float = 0.03, min_len: float = 0.05) -> np.ndarray:
    """Cut the silent tail (below floor_db of peak, 20 ms RMS) and fade out."""
    mono = x if x.ndim == 1 else np.max(np.abs(x), axis=1)
    peak = np.max(np.abs(mono)) + 1e-12
    win = int(0.02 * SR)
    env = np.sqrt(np.convolve(mono ** 2, np.ones(win) / win, mode="same"))
    above = np.nonzero(env > peak * db(floor_db))[0]
    end = int(above[-1]) + win if len(above) else len(mono)
    end = max(end, int(min_len * SR))
    end = min(end, len(mono))
    return fade(x[:end], 0.0, fout)


def normalize_peak(x: np.ndarray, peak_db: float) -> np.ndarray:
    return x * (db(peak_db) / (np.max(np.abs(x)) + 1e-12))


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def lowpass(x, fc, order=2):
    sos = signal.butter(order, fc, btype="lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, btype="highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def resonator(x, f, q):
    """Two-pole resonant bandpass (peaking), unity gain at f."""
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x, axis=0)


def exp_env(n: int, t60: float) -> np.ndarray:
    return np.exp(-6.9078 * np.arange(n) / (t60 * SR))


def make_ir(t60: float, dur: float, rng: np.random.Generator, stereo: bool = True,
            early: list[tuple[float, float]] | None = None, bright: float = 5000.0,
            predelay: float = 0.004) -> np.ndarray:
    """Synthetic room / street impulse response: sparse early reflections + a
    decaying, darkening noise tail (decorrelated per channel)."""
    n = int(dur * SR)
    ch = 2 if stereo else 1
    ir = np.zeros((n, ch))
    t = np.arange(n) / SR
    for c in range(ch):
        tail = rng.standard_normal(n) * np.exp(-6.9078 * t / t60)
        # the tail darkens as it decays (air + stone absorb highs faster)
        lo = lowpass(tail, bright, 1)
        lo2 = lowpass(tail, bright * 0.25, 1)
        mix = np.clip(t / (t60 * 0.6), 0, 1)
        tail = lo * (1 - mix) + lo2 * mix
        onset = np.clip((t - predelay) / 0.02, 0, 1)
        ir[:, c] = tail * onset * 0.35
        if early:
            for (d, g) in early:
                k = int((d + rng.uniform(-0.002, 0.002)) * SR)
                if k < n:
                    ir[k, c] += g * rng.choice([-1, 1]) * rng.uniform(0.7, 1.0)
    # unit energy per channel, so a wet gain of -12 dB really is 12 dB under the dry sound
    ir /= np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True)) + 1e-12
    return ir if stereo else ir[:, 0]


def convolve_ir(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    if ir.ndim == 1:
        return signal.fftconvolve(x, ir)[: len(x) + len(ir) - 1]
    if x.ndim == 1:
        return np.stack([signal.fftconvolve(x, ir[:, c]) for c in range(ir.shape[1])], axis=1)
    return np.stack([signal.fftconvolve(x[:, c], ir[:, c]) for c in range(ir.shape[1])], axis=1)


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Equal-power pan, p in [-1, 1]."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def add_at(dst: np.ndarray, src: np.ndarray, start: int) -> None:
    end = min(len(dst), start + len(src))
    if end > start:
        dst[start:end] += src[: end - start]


def loop_crossfade(x: np.ndarray, loop_len: int, xf: int) -> np.ndarray:
    """Given x of length loop_len + xf, fold the last xf samples over the start
    with an equal-power crossfade so x[:loop_len] loops seamlessly."""
    assert len(x) >= loop_len + xf
    y = x[:loop_len].copy()
    w = np.linspace(0, np.pi / 2, xf)
    fin = np.sin(w)
    fout = np.cos(w)
    if x.ndim == 2:
        fin = fin[:, None]
        fout = fout[:, None]
    y[:xf] = x[:xf] * fin + x[loop_len:loop_len + xf] * fout
    return y


def periodic_noise(n: int, rng: np.random.Generator, color: float = 0.0,
                   lo: float = 0.0, hi: float | None = None) -> np.ndarray:
    """Noise built in the frequency domain: exactly periodic with period n, so it
    loops without a seam. color: spectral slope in dB/octave (0 white, -3 pink, -6 brown)."""
    f = np.fft.rfftfreq(n, 1 / SR)
    mag = np.ones_like(f)
    nz = f > 0
    mag[nz] = (f[nz] / 1000.0) ** (color / 6.0206)
    mag[~nz] = 0
    if lo > 0:
        mag *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        mag *= 1 / np.sqrt(1 + (f / hi) ** 4)
    ph = rng.uniform(0, 2 * np.pi, len(f))
    y = np.fft.irfft(mag * np.exp(1j * ph), n)
    return y / (np.std(y) + 1e-12)


def periodic_lfo(n: int, rng: np.random.Generator, max_cycles: int, smooth: float = 1.0) -> np.ndarray:
    """Slow random modulation in [-1, 1] that is exactly periodic over n samples."""
    t = np.arange(n) / n
    y = np.zeros(n)
    for k in range(1, max_cycles + 1):
        y += rng.standard_normal() / (k ** smooth) * np.sin(2 * np.pi * k * t + rng.uniform(0, 2 * np.pi))
    return y / (np.max(np.abs(y)) + 1e-12)


def write_wav(rel: str, x: np.ndarray) -> str:
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    assert np.max(np.abs(x)) <= db(-1.0) + 1e-6, f"{rel} peak too high"
    sf.write(path, x.astype(np.float32), SR, subtype="PCM_16")
    return path


def write_ogg(rel: str, x: np.ndarray, quality: float = 0.4) -> str:
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Leave headroom for Vorbis overshoot.
    assert np.max(np.abs(x)) <= db(-1.5) + 1e-6, f"{rel} peak too high"
    # written in blocks: libsndfile's Vorbis writer crashes on very large single writes
    y = x.astype(np.float32)
    with sf.SoundFile(path, "w", SR, 1 if y.ndim == 1 else y.shape[1], format="OGG",
                      subtype="VORBIS", compression_level=1.0 - quality) as f:
        for i in range(0, len(y), 32768):
            f.write(y[i:i + 32768])
    return path


def shaped_noise(n: int, rng: np.random.Generator, shape_fn, nfft: int = 1024, hop: int = 256) -> np.ndarray:
    """Time-varying filtered noise: white noise STFT frames multiplied by the
    magnitude shape_fn(frame_times[s], freqs[Hz]) -> (frames, bins), then overlap-added."""
    f, t, Z = signal.stft(rng.standard_normal(n + nfft), SR, nperseg=nfft, noverlap=nfft - hop)
    shape = shape_fn(t, f)  # (frames, bins)
    Z = Z * shape.T
    _, y = signal.istft(Z, SR, nperseg=nfft, noverlap=nfft - hop)
    return y[:n]


def formant_gain(f: np.ndarray, formants, bws) -> np.ndarray:
    """Magnitude of a cascade of two-pole resonators (vocal tract), unity at DC.
    f: (...,) frequencies; formants, bws broadcastable to f."""
    g = np.ones_like(f, dtype=float)
    for F, B in zip(formants, bws):
        g = g * (F * F) / np.sqrt((F * F - f * f) ** 2 + (f * B) ** 2)
    return g


def limit(x: np.ndarray, ceiling_db: float = -1.5, lookahead: float = 0.002, release: float = 0.06) -> np.ndarray:
    """Offline look-ahead peak limiter: the gain dips just before a peak that would pass
    the ceiling and recovers over `release` seconds. Leaves quieter material untouched."""
    from scipy.ndimage import minimum_filter1d
    c = db(ceiling_db)
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    g = np.minimum(1.0, c / np.maximum(a, 1e-12))
    la = max(1, int(lookahead * SR))
    g = minimum_filter1d(g, 2 * la + 1)
    # release: rise back slowly, fall at once
    k = 1 - np.exp(-1 / (release * SR))
    cur = 1.0
    res = np.empty_like(g)
    for i in range(len(g)):
        gi = g[i]
        cur = gi if gi < cur else cur + (gi - cur) * k
        res[i] = cur
    # smooth the attack edges (the min filter already looks ahead by la samples)
    win = np.hanning(la + 2)[1:-1]
    win /= win.sum()
    res = np.minimum(res, np.convolve(res, win, mode="same"))
    res = np.convolve(res, win, mode="same")
    res = np.minimum(res, g)  # never above what the ceiling needs
    y = x * (res if x.ndim == 1 else res[:, None])
    return y
