#!/usr/bin/env python3
"""Strong onsets of a song that sit between its sixteenths, for the charter's free notes.

    python3 tools/audio/music/offgrid_onsets.py <song config.json> <out.json>

Reads the lead stem (constant-Q flux) and the drums (150 Hz-6 kHz flux, short window), picks the
peaks, and keeps those that are strong and further than OFF_MS from every sixteenth slot of the song
(a swung song's late sixteenths count as slots). Timing is read against the song's own on-grid hits,
so a detector's constant lag does not make a note look off the grid. Writes [{t, s, src}] in seconds.
"""
from __future__ import annotations

import json
import sys

import librosa
import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import pattern_analysis as pa

OFF_MS = 35.0      # further than this from a sixteenth slot = off the grid
MIN_S = 0.8        # strength (1 = the song's loud hits)


def peaks(flux, pct, win):
    thr = np.percentile(flux, pct)
    return np.array([i for i in range(win, len(flux) - win)
                     if flux[i] > thr and flux[i] == flux[i - win:i + win + 1].max()], dtype=int)


def onsets(cfg):
    out = []
    y, sr = pa.load(cfg["stems"]["lead"])
    H = 128
    C = np.abs(librosa.cqt(y, sr=sr, hop_length=H, fmin=librosa.midi_to_hz(48), n_bins=60, bins_per_octave=12)) ** 0.6
    fl = np.r_[0, np.maximum(C[:, 1:] - C[:, :-1], 0).sum(0)]
    t = librosa.frames_to_time(np.arange(len(fl)), sr=sr, hop_length=H)
    pk = peaks(fl, 92, 5)
    out += [("lead", t[i], fl[i] / np.percentile(fl, 98)) for i in pk]
    y, sr = pa.load(cfg["stems"]["drums"])
    t2, (m,) = pa.band_flux(y, sr, [(150, 6000)], W=512, H=64)
    pk = peaks(m, 92, 5)
    out += [("drum", t2[i] - 0.012, m[i] / np.percentile(m, 98)) for i in pk]
    return out


def main(cfg_path, out_path):
    cfg = json.load(open(cfg_path))
    spb, off, sw = 60.0 / cfg["bpm"], cfg["offset"], cfg.get("swing", 0.0)
    res = []
    found = onsets(cfg)
    for src in ("lead", "drum"):
        rows = [r for r in found if r[0] == src]
        t = np.array([r[1] for r in rows])
        s = np.array([r[2] for r in rows])
        u = (t - off) / spb
        k = np.round(u * 4)
        d = (u - (k / 4 + (k % 2) * sw)) * spb * 1000
        strong = s >= MIN_S
        bias = float(np.median(d[strong & (np.abs(d) < OFF_MS)])) if (strong & (np.abs(d) < OFF_MS)).any() else 0.0
        d = d - bias
        t = t - bias / 1000
        for i in np.where(strong & (np.abs(d) > OFF_MS))[0]:
            res.append({"t": round(float(t[i]), 3), "s": round(float(s[i]), 2), "src": src, "d": round(float(d[i]), 1)})
    res.sort(key=lambda r: r["t"])
    json.dump(res, open(out_path, "w"))
    print(f"{cfg['song']}: {len(res)} off-grid onsets -> {out_path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
