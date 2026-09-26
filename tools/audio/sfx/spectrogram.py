"""Spectrogram pictures of the bell samples, for reviewers who can't listen.
Writes tools/audio/sfx/spectrograms/<name>.png: time left to right (first 2 s),
frequency bottom to top on a log axis from 60 Hz to 16 kHz (faint grid lines at
100 Hz, 1 kHz and 10 kHz), level from -80 dB (black) through ember to bone (0 dB).

    python3 tools/audio/sfx/spectrogram.py
"""
import os
import struct
import zlib

import numpy as np
import soundfile as sf
from scipy import signal

from dsp import OUT

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 600, 260
FILES = [
    "bells/light_down_perfect_1.wav", "bells/village_down_perfect_1.wav", "bells/full_down_perfect_1.wav",
    "bells/full_up_perfect_1.wav", "bells/full_down_good_1.wav", "bells/full_down_ok_1.wav",
    "bells/full_down_miss_1.wav", "bells/row_tight_down_1.ogg", "bells/row_loose_down_1.ogg",
    "voice/call_1.wav", "fx/rope_1.wav", "steps/tone_1_02.wav",
]


def png(path, rgb):
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def colour(v):
    """v in [0,1]: black #141110 -> red #c0392b -> ember #e0a24a -> bone #ede6da."""
    stops = np.array([[20, 17, 16], [192, 57, 43], [224, 162, 74], [237, 230, 218]], float)
    pos = np.array([0.0, 0.45, 0.75, 1.0])
    out = np.zeros(v.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(v, pos, stops[:, c])
    return out.astype(np.uint8)


def main():
    os.makedirs(os.path.join(HERE, "spectrograms"), exist_ok=True)
    for rel in FILES:
        x, sr = sf.read(os.path.join(OUT, rel), always_2d=True)
        x = x.mean(axis=1)[: 2 * sr]
        x = np.pad(x, (0, max(0, 2 * sr - len(x))))
        f, t, S = signal.stft(x, sr, nperseg=4096, noverlap=4096 - 147)
        P = 20 * np.log10(np.abs(S) + 1e-9)
        P -= P.max()
        ys = np.geomspace(60, 16000, H)[::-1]
        ts = np.linspace(0, 2.0, W)
        grid = np.zeros((H, W))
        fi = np.searchsorted(f, ys).clip(1, len(f) - 1)
        ti = np.searchsorted(t, ts).clip(0, len(t) - 1)
        grid = P[fi][:, ti]
        v = np.clip((grid + 80) / 80, 0, 1)
        img = colour(v)
        for g in (100, 1000, 10000):
            row = int(np.argmin(np.abs(ys - g)))
            img[row, ::4] = [110, 100, 90]
        png(os.path.join(HERE, "spectrograms", rel.replace("/", "_").rsplit(".", 1)[0] + ".png"), img)
    print("wrote", len(FILES), "spectrograms")


if __name__ == "__main__":
    main()
