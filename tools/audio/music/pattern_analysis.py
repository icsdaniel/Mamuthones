#!/usr/bin/env python3
"""What the music is doing on every sixteenth, from a song's stems, for the pattern charter.

    python3 tools/audio/music/pattern_analysis.py <song config.json> <out.json>

The config names the stems ("stems": {"drums": [...], "bass": [...], "lead": [...]}), the bpm, offset
and length. Per sixteenth slot it writes:
  dl, dm, dh   drum onset strength in the low (kick), mid (snare, toms) and high (hats) bands
  bass         bass onset strength
  pc, on, e    the lead's strongest pitch class, its onset strength and its loudness
  pitch        the lead's pitch class placed in the octave nearest the note before (melodic contour)
All strengths are scaled so the song's loud hits sit near 1.

librosa's pyin crashes under numba in this environment and single-stem pitch trackers caught the
bleed between Suno's stems, so the lead is read as a pitch-class profile (harmonic-summed
constant-Q in the lead register), which survives octave errors and bleed.
"""
from __future__ import annotations

import json
import sys

import librosa
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly


def load(paths):
    y = None
    for p in paths:
        x, sr = sf.read(p, always_2d=True)
        x = x.mean(1)
        y = x if y is None else y[:len(x)] + x[:len(y)]
    y = resample_poly(y, 1, 2)
    return y, sr // 2


def band_flux(y, sr, bands, W=1024, H=128):
    fr = np.lib.stride_tricks.sliding_window_view(y, W)[::H] * np.hanning(W)
    S = np.abs(np.fft.rfft(fr)) ** 0.5
    fq = np.fft.rfftfreq(W, 1 / sr)
    t = (np.arange(len(fr)) * H + W / 2) / sr
    out = []
    for a, b in bands:
        e = S[:, (fq >= a) & (fq < b)]
        out.append(np.r_[0, np.maximum(e[1:] - e[:-1], 0).sum(1)])
    return t, out


def at_slots(t, env, times, win=0.035):
    v = np.array([env[(t > x - win) & (t < x + win)].max(initial=0.0) for x in times])
    ref = np.percentile(v[v > 0], 97) if (v > 0).any() else 1.0
    return np.round(np.minimum(v / (ref + 1e-9), 2.0), 2)


def analyse(cfg):
    spb = 60.0 / cfg["bpm"]
    n = int((cfg["length"] - cfg["offset"]) / spb * 4)
    times = cfg["offset"] + np.arange(n) * spb / 4
    # a swung song's off-beat sixteenths sound late: read them where they sound
    times = times + (np.arange(n) % 2) * cfg.get("swing", 0.0) * spb
    st = cfg["stems"]
    res = {"bpm": cfg["bpm"], "offset": cfg["offset"], "slots": n}

    y, sr = load(st["drums"])
    t, (lo, mi, hi) = band_flux(y, sr, [(30, 150), (150, 2500), (5000, 11000)])
    res["dl"], res["dm"], res["dh"] = (at_slots(t, e, times).tolist() for e in (lo, mi, hi))

    y, sr = load(st["bass"])
    t, (b,) = band_flux(y, sr, [(30, 400)])
    res["bass"] = at_slots(t, b, times).tolist()

    y, sr = load(st["lead"])
    H, bpo = 256, 36
    C = np.abs(librosa.cqt(y, sr=sr, hop_length=H, fmin=librosa.midi_to_hz(36), n_bins=bpo * 6,
                           bins_per_octave=bpo)) ** 0.6
    mid = np.arange(C.shape[0]) / 3 + 36
    sal = np.zeros_like(C)
    for h, w in ((1, 1.0), (2, .6), (3, .4), (4, .3)):
        sh = int(round(np.log2(h) * bpo))
        sal[:C.shape[0] - sh] += w * C[sh:]
    lo_m, hi_m = cfg.get("lead_register", [55, 88])
    pcs = np.zeros((12, C.shape[1]))
    for i in np.where((mid >= lo_m) & (mid <= hi_m))[0]:
        pcs[int(round(mid[i])) % 12] += sal[i]
    flux = np.r_[0, np.maximum(C[:, 1:] - C[:, :-1], 0)[mid >= lo_m].sum(0)]
    tf = librosa.frames_to_time(np.arange(C.shape[1]), sr=sr, hop_length=H)
    regi = np.where((mid >= lo_m) & (mid <= hi_m))[0]
    pc, on, e, octp = [], [], [], []
    for x in times:
        m = (tf >= x - 0.005) & (tf < x + 0.09)
        v = pcs[:, m].mean(1) if m.any() else np.zeros(12)
        c = int(v.argmax())
        pc.append(c)
        e.append(float(v.max()))
        on.append(float(flux[(tf > x - 0.04) & (tf < x + 0.04)].max(initial=0.0)))
        # the octave the pitch class is loudest in
        ib = [i for i in regi if int(round(mid[i])) % 12 == c]
        sv = sal[ib][:, m].mean(1) if m.any() else np.zeros(len(ib))
        octp.append(int(round(mid[ib[int(sv.argmax())]])) if len(ib) else 60 + c)
    on = np.array(on) / (np.percentile(flux, 98) + 1e-9)     # against every frame, not every slot
    e = np.array(e) / (np.percentile(e, 95) + 1e-9)
    # contour: the octave each pitch class is loudest in, with stray octave jumps (a harmonic winning
    # for a moment) pulled back toward the bar's median
    pitch = list(octp)
    for b0 in range(0, len(pitch), 16):
        seg = pitch[b0:b0 + 16]
        med = float(np.median(seg))
        for i in range(b0, min(b0 + 16, len(pitch))):
            while pitch[i] - med > 9:
                pitch[i] -= 12
            while med - pitch[i] > 9:
                pitch[i] += 12
    res["pc"], res["pitch"] = pc, pitch
    # a legato line (an arpeggio on a pad) has no attacks: a new pitch class that sounds counts as
    # an onset too
    for i in range(1, len(pc)):
        if pc[i] != pc[i - 1] and e[i] > 0.3 and on[i] < 0.6:
            on[i] = 0.6
    res["on"] = np.round(np.minimum(on, 2), 2).tolist()
    res["e"] = np.round(np.minimum(e, 2), 2).tolist()
    return res


if __name__ == "__main__":
    cfg = json.load(open(sys.argv[1]))
    json.dump(analyse(cfg), open(sys.argv[2], "w"))
    print("wrote", sys.argv[2])
