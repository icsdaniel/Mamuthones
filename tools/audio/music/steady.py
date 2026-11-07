#!/usr/bin/env python3
"""Steady a song's beat: measure where its bars really fall and warp the audio onto the chart's grid.

    python3 tools/audio/music/steady.py measure <song id> [...]          # print the drift, bar by bar
    python3 tools/audio/music/steady.py warp <song id> <source.wav> [<lift source.wav>]

Suno's takes do not always hold their tempo: in Shrove Tuesday, Piazza and Bonfires the music wanders
up to 40-60 ms ahead of or behind a steady grid from one phrase to the next. The game places every
note on a steady grid (bpm and offset), so in those passages a note on the beat sounds early or late
against the music however well it was chosen, and the analysis the charter reads was sampled in the
wrong place (Daniele, 2026-11-07: "Make sure that the player feels the tempo").

measure: for every bar, the shift (ms) that best lines the music's attacks (kick, snare, tune) up with
the sixteenth grid, read over that bar and its neighbours, then a smooth path through those shifts
(Viterbi, so one noisy bar cannot jerk it). A bar with no clear rhythm follows its neighbours.

warp: rubberband (R3 engine, one pass with a time map) moves each bar line to its place on the grid.
The tempo changes it makes are a fraction of a percent, so the pitch and the sound are unchanged. It
writes game/audio/music/<id>.ogg (and <id>_lift.ogg from the lift source) and the beat map
recorded/<id>_beatmap.json: for each bar, where it sat in the source and where it sits now.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf
from scipy.ndimage import gaussian_filter1d

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import music_fit as F  # noqa: E402

ROOT = F.ROOT
RECORDED = os.path.join(HERE, "recorded")
SHIFTS = np.arange(-80, 81)          # ms
STEP_PENALTY = 0.06                  # per ms of change between neighbouring bars (in score std units)


def envelope(A):
    c = np.zeros(len(A.t))
    for b in ("low", "mid", "tune"):
        if b in A.con:
            x = A.con[b]
            c += x / (np.percentile(x, 99) + 1e-9)
    return gaussian_filter1d(c, 0.006 / A.dt)


def measure(sid, A=None):
    song = json.load(open(os.path.join(F.SONGS, sid + ".json")))
    spb, off, sw = 60.0 / song["bpm"], song["offset"], float(song.get("swing", 0.0))
    A = A or F.Audio(sid)
    c = envelope(A)
    nbars = int((A.t[-1] - off) / spb / 4)
    S = np.zeros((nbars, len(SHIFTS)))
    for k in range(nbars):
        sl = np.arange(max(0, k - 1) * 16, min(nbars, k + 2) * 16)
        t = off + (sl / 4 + (sl % 2) * sw) * spb
        w = np.where(sl % 4 == 0, 1.0, np.where(sl % 2 == 0, 0.6, 0.35))
        S[k] = [(c[A.idx(t + d / 1000)] * w).sum() for d in SHIFTS]
    conf = (S.max(1) - S.mean(1)) / (S.std(1) + 1e-9)
    Z = (S - S.mean(1, keepdims=True)) / (S.std(1, keepdims=True) + 1e-9)
    Z *= np.clip(conf / 3.0, 0, 1)[:, None]          # a bar with no clear rhythm has no say
    # Viterbi: the best smooth path of shifts
    D = np.abs(SHIFTS[:, None] - SHIFTS[None, :]) * STEP_PENALTY
    acc = Z[0].copy()
    back = np.zeros((nbars, len(SHIFTS)), int)
    for k in range(1, nbars):
        m = acc[None, :] - D                # [to, from]
        back[k] = m.argmax(1)
        acc = Z[k] + m.max(1)
    path = np.zeros(nbars, int)
    path[-1] = int(acc.argmax())
    for k in range(nbars - 1, 0, -1):
        path[k - 1] = back[k][path[k]]
    shift = SHIFTS[path].astype(float)
    raw = SHIFTS[S.argmax(1)]
    return {"song": sid, "bpm": song["bpm"], "offset": off, "spb": spb, "bars": nbars,
            "shift_ms": shift.tolist(), "raw_ms": raw.tolist(), "conf": np.round(conf, 2).tolist()}


def describe(m):
    s = np.array(m["shift_ms"])
    return (f"{m['song']:22} median {np.median(s):+5.0f} ms  range {s.min():+4.0f}..{s.max():+4.0f}  "
            f"bar-to-bar max {np.abs(np.diff(s)).max() if len(s) > 1 else 0:3.0f} ms")


def track(wav, hint):
    """The song's beats as it plays them: librosa's beat tracker on the percussive part, held to the
    tempo hint (tightness 400 follows a slow drift, like Shrove Tuesday remix speeding up from 128.5 to
    131 bpm, without jumping at every fill), then smoothed over five beats."""
    import librosa
    y, sr = librosa.load(wav, sr=22050, mono=True)
    _, yp = librosa.effects.hpss(y, margin=2.0)
    o = librosa.onset.onset_strength(y=yp, sr=sr, hop_length=128, aggregate=np.median)
    _, beats = librosa.beat.beat_track(onset_envelope=o, sr=sr, hop_length=128, start_bpm=hint,
                                       tightness=400, units="time", trim=False)
    beats = np.asarray(beats, float)
    k = 5
    sm = np.convolve(np.pad(beats, (k // 2, k // 2), mode="reflect", reflect_type="odd"), np.ones(k) / k, "valid")
    return sm


def warp_file(src, anchors, out_wav):
    """Rubberband (R3, one pass) with a time map: each (source s, target s) anchor lands exactly."""
    x, sr = sf.read(src, always_2d=True)
    dur = len(x) / sr
    anchors = [(a, b) for a, b in anchors if 0.0 < a < dur - 0.05]
    a0, b0 = anchors[0]
    pad = max(0.0, b0 - a0)          # the music moves later than the file starts: silence first
    pre = int(round(pad * sr))
    if pre:
        x = np.vstack([np.zeros((pre, x.shape[1])), x])
    target_len = dur + (anchors[-1][1] - anchors[-1][0]) + pad
    with tempfile.TemporaryDirectory() as td:
        tm = os.path.join(td, "map.txt")
        with open(tm, "w") as f:
            for a, b in anchors:
                f.write(f"{int(round(a * sr)) + pre} {int(round(b * sr)) + pre}\n")
        inp, outp = os.path.join(td, "in.wav"), os.path.join(td, "out.wav")
        sf.write(inp, x, sr, subtype="FLOAT")
        subprocess.run(["rubberband", "-q", "-3", "--timemap", tm, "-D", f"{target_len:.6f}", inp, outp], check=True)
        y, _ = sf.read(outp, always_2d=True)
    y = y[pre:]
    peak = np.abs(y).max()
    if peak > 0.999:
        y = y * (0.999 / peak)
    sf.write(out_wav, y, sr, subtype="PCM_16")
    return len(y) / sr


def steady_wav(sid, wav, hint, out_dir):
    """Warp a song's WAV to a constant tempo: beat i of the take goes to first + i * (mean beat)."""
    B = track(wav, hint)
    T = (B[-1] - B[0]) / (len(B) - 1)
    anchors = [(float(b), float(B[0] + i * T)) for i, b in enumerate(B)]
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, sid + ".wav")
    L = warp_file(wav, anchors, out)
    dev = np.array([a - b for a, b in anchors]) * 1000
    json.dump({"song": sid, "source": os.path.basename(wav), "bpm": 60 / T, "beats": [[round(a, 4), round(b, 4)] for a, b in anchors]},
              open(os.path.join(RECORDED, sid + "_beatmap.json"), "w"))
    print(f"{sid}: {len(B)} beats, steady at {60 / T:.3f} bpm; the take wandered {dev.min():+.0f}..{dev.max():+.0f} ms "
          f"from it; {L:.2f} s -> {out}")
    return out, 60 / T


def prep(sid, wav, hint, out_dir):
    """Steady the WAV, then the whole song_prep pipeline on it (tempo, downbeat, stems, analysis, bar
    map), keeping the song file's own fields (titles, stop, version), then chart it."""
    import song_prep
    song_p = os.path.join(F.SONGS, sid + ".json")
    old = json.load(open(song_p))
    steady, bpm = steady_wav(sid, wav, hint, out_dir)
    args = [sid, steady, str(old["stop"]), old["title"]["en"], old["title"]["it"], f"{bpm:.2f}"]
    if old.get("version") == "remix":
        args.append("--remix")
    song_prep.main(args)
    # song_prep's grid reads the drums its own way: line its tempo and offset up with this file's
    # measure (the frame in which Rope and Workshop, the songs that already felt right, sit at 0 ms)
    # and run it again on that grid
    fit = grid_fit(sid)
    if fit:
        bpm2, first2 = fit
        spb2 = 60 / bpm2
        g0, d0 = song_prep.grid, song_prep.downbeat
        swing = json.load(open(song_p)).get("swing", 0.0)
        song_prep.grid = lambda drums, hint: (bpm2, first2 % spb2, swing, None)
        song_prep.downbeat = lambda *a_: (int(round((first2 - first2 % spb2) / spb2)), [0, 0, 0, 0])
        try:
            song_prep.main(args)
        finally:
            song_prep.grid, song_prep.downbeat = g0, d0
    new = json.load(open(song_p))
    for k, v in old.items():
        if k not in new:
            new[k] = v
    keep = ["id", "title", "stop", "kind", "version"]
    order = keep + [k for k in new if k not in keep]
    new = {k: new[k] for k in order if k in new}
    with open(song_p, "w") as f:
        json.dump(new, f, indent=1, ensure_ascii=False)
        f.write("\n")


def grid_fit(sid, quiet=False):
    """The tempo and first downbeat that put this file's measured bar shifts at 0 ms (a straight-line
    fit through them, so a steady take with a slightly wrong tempo or offset is put right)."""
    m = measure(sid)
    sh = np.array(m["shift_ms"])
    conf = np.array(m["conf"])
    k = np.arange(len(sh))
    ok = conf >= np.percentile(conf, 25)
    b, a = np.polyfit(k[ok], sh[ok], 1)
    spb2 = m["spb"] + b / 4000.0
    first = m["offset"] + a / 1000.0
    if not quiet:
        print(f"{sid}: grid fit {a:+.1f} ms {b * 100:+.1f} ms/100 bars -> bpm {60 / spb2:.3f} offset {first:.4f}")
    if abs(a) < 2 and abs(b * len(sh)) < 3:
        return None
    return round(60 / spb2, 3), round(first, 4)


def shift_grid(sid, offset_ms, bpm=None):
    """A steady take whose grid is a little off: move the song's offset (and tempo) instead of the audio."""
    for p in (os.path.join(F.SONGS, sid + ".json"), os.path.join(RECORDED, sid + "_pattern.json"),
              os.path.join(RECORDED, sid + ".json")):
        if not os.path.exists(p):
            continue
        d = json.load(open(p))
        d["offset"] = round(d["offset"] + offset_ms / 1000.0, 4)
        if bpm:
            d["bpm"] = bpm
        with open(p, "w") as f:
            json.dump(d, f, indent=1, ensure_ascii=False)
            f.write("\n")


def main(argv):
    if argv[1] == "measure":
        ids = [a for a in argv[2:] if not a.startswith("-")] or sorted(f[:-5] for f in os.listdir(F.SONGS) if f.startswith("suno_") and f.endswith(".json"))
        for sid in ids:
            m = measure(sid)
            print(describe(m))
            if "-v" in argv:
                print("   ", " ".join(f"{x:+.0f}" for x in m["shift_ms"]))
    elif argv[1] == "prep":
        prep(argv[2], argv[3], float(argv[4]), argv[5])
    elif argv[1] == "shift":
        shift_grid(argv[2], float(argv[3]), float(argv[4]) if len(argv) > 4 else None)


if __name__ == "__main__":
    main(sys.argv)
