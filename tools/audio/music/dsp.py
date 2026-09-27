"""Signal helpers for the music pipeline: filters, reverb, loudness (ITU-R BS.1770-4),
true peak, a look-ahead limiter and a tiny PNG writer for spectrograms.

Everything works on float64 numpy arrays at SR = 44100 Hz. Stereo is shape (N, 2).
"""
from __future__ import annotations

import struct
import zlib

import numpy as np
from scipy import signal
from scipy.ndimage import maximum_filter1d, minimum_filter1d, uniform_filter1d

SR = 44100


# ---------------------------------------------------------------- filters

def lowpass(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def peaking(x, fc, gain_db, q=1.0):
    """RBJ peaking EQ."""
    a_ = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a_, -2 * np.cos(w0), 1 - alpha * a_]
    a = [1 + alpha / a_, -2 * np.cos(w0), 1 - alpha / a_]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def resonator(x, fc, bw):
    """Two-pole resonator with unity gain at DC (Klatt style), for cascade formants."""
    r = np.exp(-np.pi * bw / SR)
    c = -r * r
    b_ = 2 * r * np.cos(2 * np.pi * fc / SR)
    a0 = 1 - b_ - c
    return signal.lfilter([a0], [1, -b_, -c], x)


def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    return signal.lfilter([1 - a], [1, -a], x, axis=0)


# ---------------------------------------------------------------- noise and utility

def rng(seed):
    return np.random.default_rng(seed)


def pink(n, r):
    """Pink-ish noise via filtering white noise (Paul Kellet's economy filter)."""
    w = r.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    y = signal.lfilter(b, a, w)
    return y / (np.std(y) + 1e-12)


def smooth_noise(n, rate_hz, r):
    """Band-limited random wander in [-1, 1] changing at about rate_hz."""
    k = max(2, int(n * rate_hz / SR) + 2)
    pts = r.uniform(-1, 1, k)
    return np.interp(np.linspace(0, k - 1, n), np.arange(k), pts)


def pan(mono, p):
    """Constant-power pan, p in [-1, 1]."""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], axis=1)


def db(x):
    return 20 * np.log10(np.maximum(x, 1e-12))


def add_at(dst, src, start):
    """Mix src into dst beginning at sample start (clipped to dst)."""
    if start >= len(dst):
        return
    s0 = max(0, start)
    off = s0 - start
    n = min(len(src) - off, len(dst) - s0)
    if n > 0:
        dst[s0:s0 + n] += src[off:off + n]


# ---------------------------------------------------------------- reverb

_ir_cache: dict = {}


def reverb_ir(t60, predelay=0.012, bright=6000, seed=7, early=()):
    """Stereo, decorrelated exponentially decaying noise impulse response."""
    key = (t60, predelay, bright, seed, tuple(early))
    if key in _ir_cache:
        return _ir_cache[key]
    r = rng(seed)
    n = int(SR * min(t60 * 1.2, 4.0))
    t = np.arange(n) / SR
    env = np.exp(-6.9 * t / t60)
    ir = np.zeros((n + int(predelay * SR), 2))
    for ch in range(2):
        nz = r.standard_normal(n) * env
        # darker tail: the high end dies faster than the low end
        nz = lowpass(nz, bright) * 0.7 + lowpass(nz, bright * 0.3) * 0.5
        ir[int(predelay * SR):, ch] = nz
    for (dt, g) in early:  # discrete reflections (walls of a piazza)
        i = int(dt * SR)
        if i < len(ir):
            ir[i, 0] += g * 3
            ir[min(len(ir) - 1, i + int(0.0031 * SR)), 1] += g * 3
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    _ir_cache[key] = ir
    return ir


def convolve_reverb(mono_or_stereo, ir):
    x = mono_or_stereo
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    out = np.zeros((len(x), 2))
    for ch in range(2):
        out[:, ch] = signal.fftconvolve(x[:, ch], ir[:, ch])[: len(x)]
    return out


# ---------------------------------------------------------------- loudness (BS.1770-4)

def k_weighting_coeffs(fs=SR):
    """Pre-filter (high shelf) and RLB high-pass, derived for any sample rate."""
    g = 3.999843853973347
    q = 0.7071752369554196
    fc = 1681.974450955533
    k = np.tan(np.pi * fc / fs)
    vh = 10 ** (g / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b1 = np.array([(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0])
    a1 = np.array([1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0])
    fc2 = 38.13547087602444
    q2 = 0.5003270373238773
    k2 = np.tan(np.pi * fc2 / fs)
    a02 = 1 + k2 / q2 + k2 * k2
    b2 = np.array([1.0, -2.0, 1.0])
    a2 = np.array([1.0, 2 * (k2 * k2 - 1) / a02, (1 - k2 / q2 + k2 * k2) / a02])
    return (b1, a1), (b2, a2)


def integrated_loudness(x, fs=SR):
    """Gated integrated loudness in LUFS of a (N,) or (N, C) signal."""
    if x.ndim == 1:
        x = x[:, None]
    (b1, a1), (b2, a2) = k_weighting_coeffs(fs)
    y = signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)
    blk = int(0.4 * fs)
    hop = int(0.1 * fs)
    if len(y) < blk:
        return -70.0
    sq = y ** 2
    cs = np.vstack([np.zeros((1, sq.shape[1])), np.cumsum(sq, axis=0)])
    starts = np.arange(0, len(y) - blk + 1, hop)
    z = (cs[starts + blk] - cs[starts]) / blk  # (blocks, C)
    zsum = z.sum(axis=1)
    lk = -0.691 + 10 * np.log10(np.maximum(zsum, 1e-20))
    keep = lk > -70
    if not keep.any():
        return -70.0
    rel = -0.691 + 10 * np.log10(zsum[keep].mean()) - 10
    keep &= lk > rel
    return float(-0.691 + 10 * np.log10(zsum[keep].mean()))


def true_peak_db(x, fs=SR):
    """True peak in dBTP using 4x oversampling (BS.1770-4 annex 2 style)."""
    if x.ndim == 1:
        x = x[:, None]
    m = 0.0
    for ch in range(x.shape[1]):
        up = signal.resample_poly(x[:, ch], 4, 1)
        m = max(m, float(np.max(np.abs(up))))
    return float(db(m))


# ---------------------------------------------------------------- dynamics

def limiter(x, ceiling_db=-1.5, lookahead=0.004, release=0.06):
    """Look-ahead brickwall limiter on a stereo signal (linked channels).

    The gain curve is a min filter followed by a moving average of the same width, which
    guarantees the gain at every peak is at most the needed reduction while staying smooth.
    """
    ceil = 10 ** (ceiling_db / 20)
    peak = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    need = np.minimum(1.0, ceil / np.maximum(peak, 1e-9))
    w1 = max(3, int(lookahead * SR) | 1)
    g = uniform_filter1d(minimum_filter1d(need, w1), w1)
    w2 = max(3, int(release * SR) | 1)
    g = np.minimum(g, uniform_filter1d(minimum_filter1d(g, w2), w2))
    return x * (g[:, None] if x.ndim == 2 else g)


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def envelope_follow(x, att=0.002, rel=0.08):
    """Cheap peak envelope (used for side-chain ducking in remixes)."""
    a = np.abs(x)
    a = maximum_filter1d(a, int(att * SR) * 2 + 1)
    return uniform_filter1d(a, int(rel * SR) + 1)


# ---------------------------------------------------------------- analysis helpers

def stft_mag(x, n_fft=2048, hop=512):
    if x.ndim == 2:
        x = x.mean(axis=1)
    win = np.hanning(n_fft)
    nfr = 1 + max(0, (len(x) - n_fft) // hop)
    idx = np.arange(n_fft)[None, :] + hop * np.arange(nfr)[:, None]
    frames = x[idx] * win
    return np.abs(np.fft.rfft(frames, axis=1))


def write_png_gray(path, img):
    """img: 2D uint8 array (rows top to bottom). Minimal PNG writer, stdlib only."""
    h, w = img.shape
    raw = b"".join(b"\x00" + img[r].tobytes() for r in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def spectrogram_png(path, x, height=256, width=1400, fmax=8000):
    """Log-frequency spectrogram as a grey PNG (dark = loud) for eyeballing arrangements."""
    mag = stft_mag(x, 2048, max(64, len(x) // width))
    freqs = np.fft.rfftfreq(2048, 1 / SR)
    edges = np.geomspace(40, fmax, height + 1)
    rows = []
    for i in range(height):
        sel = (freqs >= edges[i]) & (freqs < edges[i + 1])
        if not sel.any():
            sel = np.argmin(np.abs(freqs - edges[i]))
            rows.append(mag[:, sel])
        else:
            rows.append(mag[:, sel].mean(axis=1))
    s = db(np.array(rows[::-1]) + 1e-9)
    s = np.clip((s - (s.max() - 70)) / 70, 0, 1)
    img = (255 * (1 - s)).astype(np.uint8)
    write_png_gray(path, img[:, :width])
