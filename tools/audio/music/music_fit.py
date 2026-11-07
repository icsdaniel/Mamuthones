#!/usr/bin/env python3
"""Does every note sit on something the player can hear? A check of a song's charts against its audio.

    python3 tools/audio/music/music_fit.py <song id> [<song id> ...] [--out DIR] [--json]

Daniele (2026-11-07): "Make sure that the player feels the tempo and hits the notes because they need
to follow the flow." Notes off the main beat are welcome where the music itself plays there, never
added at random.

This reads the audio the player hears (game/audio/music/<id>.ogg, and <id>_lift.ogg, the tune) and
not the analysis the charter used, so it is an independent check. For every sixteenth and for every
note it measures how sharp an attack the music has there ("salience": 1.0 is a typical strong hit in
that part of the song, 0 is nothing). Four bands are read: low (kick, bass), mid (snare, chords),
high (hats) and the tune stem.

It reports, per song and level:
  grid       how far the music's strong hits sit from the chart's beat grid (a drift or a constant
             offset makes every note feel late or early, however well it is placed)
  heard      the share of notes whose start lands on a clear attack in the music
  unheard    notes on an off-beat (an eighth or a sixteenth off the beat) with no attack under them:
             the "random" notes, the ones the player cannot feel
  pulse      groove bars where the chart leaves both beat 1 and beat 3 empty (the player loses the beat)
  missed     strong off-beat accents in the music (syncopations) that the level leaves out
  between    strong hits that fall between the sixteenths and repeat bar after bar (triplets, flams,
             pushes): candidates for notes off the grid, listed but never added automatically
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SONGS = os.path.join(ROOT, "game", "data", "songs")
MUSIC = os.path.join(ROOT, "game", "audio", "music")

SR = 22050
HOP = 128
W = 1024
BANDS = {"low": (30, 160), "mid": (160, 2500), "high": (5000, 10500)}
WIN = 0.035          # an attack counts for a note if it peaks within this many seconds of it
HEARD = 0.35         # salience from which a note counts as heard
ACCENT = 0.8         # salience of a strong accent
DIFFS = ("easy", "medium", "hard", "expert")


def load(path):
    y, sr = sf.read(path, always_2d=True)
    y = y.mean(1)
    if sr != SR:
        from math import gcd
        g = gcd(SR, sr)
        y = resample_poly(y, SR // g, sr // g)
    return y


def flux_bands(y, bands):
    fr = np.lib.stride_tricks.sliding_window_view(y, W)[::HOP] * np.hanning(W)
    S = np.log1p(30 * np.abs(np.fft.rfft(fr)))
    fq = np.fft.rfftfreq(W, 1 / SR)
    out = {}
    for name, (a, b) in bands.items():
        e = S[:, (fq >= a) & (fq < b)]
        f = np.r_[0, np.maximum(e[1:] - e[:-1], 0).mean(1)]
        out[name] = f
    t = (np.arange(len(fr)) * HOP + W / 2) / SR
    return t, out


class Audio:
    def __init__(self, sid):
        mix = load(os.path.join(MUSIC, sid + ".ogg"))
        self.t, self.env = flux_bands(mix, BANDS)
        lift = os.path.join(MUSIC, sid + "_lift.ogg")
        if os.path.exists(lift):
            _, e = flux_bands(load(lift), {"tune": (160, 8000)})
            n = min(len(e["tune"]), len(self.t))
            tune = np.zeros(len(self.t))
            tune[:n] = e["tune"][:n]
            self.env["tune"] = tune
        self.dt = HOP / SR
        # contrast: the flux above its own running median (a sustained sound is not an attack)
        k = int(0.15 / self.dt) | 1
        from scipy.ndimage import median_filter, maximum_filter
        self.con = {}
        for b, e in self.env.items():
            c = np.maximum(e - median_filter(e, size=k), 0)
            self.con[b] = c
        self.peak = {b: maximum_filter(c, size=int(2 * WIN / self.dt) | 1) for b, c in self.con.items()}
        self.ref = {}

    def idx(self, x):
        return np.clip(np.round((np.asarray(x) - self.t[0]) / self.dt).astype(int), 0, len(self.t) - 1)

    def set_ref(self, grid_times):
        """Each band's local loudness of a strong hit: the 90th percentile of its attacks on the
        sixteenth grid in the 8 s around (so a quiet intro's hits still count as hits there)."""
        g = np.asarray(grid_times)
        for b, p in self.peak.items():
            v = p[self.idx(g)]
            ref = np.zeros(len(self.t))
            step = int(1.0 / self.dt)
            glob = np.percentile(v, 90) + 1e-9
            for i in range(0, len(self.t), step):
                x = self.t[i]
                m = np.abs(g - x) < 4.0
                r = np.percentile(v[m], 90) if m.sum() > 8 else glob
                ref[i:i + step] = max(r, 0.25 * glob)
            self.ref[b] = ref

    def sal(self, x, bands=None):
        """Salience of the attack at time(s) x: the strongest band, against its local reference."""
        i = self.idx(x)
        best = None
        for b in (bands or self.peak):
            v = self.peak[b][i] / self.ref[b][i]
            best = v if best is None else np.maximum(best, v)
        return np.minimum(best, 2.0)

    def where(self, x, bands=None, win=0.06):
        """The exact time of the strongest attack within win of x."""
        lo, hi = self.idx(x - win), self.idx(x + win)
        best, bt = -1, x
        for b in (bands or self.con):
            c = self.con[b][lo:hi + 1] / (self.ref[b][lo:hi + 1])
            if len(c) and c.max() > best:
                best, bt = c.max(), self.t[lo + int(c.argmax())]
        return bt, best


def position(b):
    f = b % 1.0
    if abs(f) < 1e-3 or abs(f - 1) < 1e-3:
        return "beat"
    if abs(f - 0.5) < 1e-3:
        return "eighth"
    return "sixteenth"


def audit(sid, audio=None):
    song = json.load(open(os.path.join(SONGS, sid + ".json")))
    bpm, off, swing = song["bpm"], song["offset"], float(song.get("swing", 0.0))
    spb = 60.0 / bpm
    length = song["length"]
    A = audio or Audio(sid)
    n = int((length - off) / spb * 4)
    slots = np.arange(n)
    beats = slots / 4.0 + (slots % 2) * swing
    cfgp = os.path.join(HERE, "recorded", sid + "_pattern.json")
    shuffle = os.path.exists(cfgp) and json.load(open(cfgp)).get("shuffle", False)
    if shuffle:     # a shuffle's beat splits in three: read its slots at 0, 1/3, 2/3, 5/6
        beats = slots // 4 + np.array([0.0, 1 / 3, 2 / 3, 5 / 6])[slots % 4]
    times = off + beats * spb
    A.set_ref(times)
    sal = A.sal(times)
    # 32nd positions between the sixteenths: what "no note here" sounds like
    mids = off + ((beats[:-1] + beats[1:]) / 2) * spb
    null = A.sal(mids)
    res = {"song": sid, "bpm": bpm, "swing": swing, "length": length, "shuffle": bool(shuffle)}

    # --- the grid: where the strong hits sit against it, in 16-bar windows
    strong = [s for s in slots if sal[s] >= 1.0 and s % 4 == 0]
    devs = []
    for s in strong:
        bt, v = A.where(times[s], ("low", "mid"))
        devs.append((s, (bt - times[s]) * 1000))
    devs = np.array(devs) if devs else np.zeros((0, 2))
    win = []
    for b0 in range(0, n, 16 * 16):
        m = (devs[:, 0] >= b0) & (devs[:, 0] < b0 + 256) if len(devs) else []
        if len(devs) and m.sum() >= 6:
            win.append({"bar": b0 // 16, "ms": round(float(np.median(devs[m, 1])), 1), "hits": int(m.sum())})
    allmed = float(np.median(devs[:, 1])) if len(devs) else 0.0
    res["grid"] = {"median_ms": round(allmed, 1), "windows": win,
                   "spread_ms": round(float(np.std([w["ms"] for w in win])) if win else 0.0, 1)}
    # downbeat: is slot 0 of the bar the strongest beat on average?
    beat_str = [float(np.mean([A.sal(times[s], ("low",)) for s in slots if s % 16 == k * 4])) for k in range(4)]
    res["beats_low"] = [round(v, 2) for v in beat_str]
    res["null_p90"] = round(float(np.percentile(null, 90)), 2)

    # --- sections: which bars are grooves (the drums are playing)
    secs = song.get("sections", [])

    # --- strong off-beat accents and between-the-sixteenth hits in the music
    acc = []
    for s in slots:
        if s % 4 == 0 or sal[s] < ACCENT:
            continue
        # an accent stands out from its neighbours on the grid
        nb = [sal[j] for j in (s - 1, s + 1) if 0 <= j < n]
        if nb and sal[s] < max(nb) * 1.1:
            continue
        acc.append(int(s))
    between = []
    for i in range(len(mids)):
        if null[i] >= ACCENT and null[i] > 1.3 * max(sal[i], sal[i + 1]):
            between.append(i)
    # repeating between-hits: the same place in the bar in at least 4 bars
    pos = {}
    for i in between:
        pos.setdefault(i % 16, []).append(i // 16)
    rep = {k: v for k, v in pos.items() if len(v) >= 4}
    res["between"] = {"count": len(between), "repeating": {str(k): v for k, v in sorted(rep.items())}}

    # --- per level
    res["levels"] = {}
    for d in DIFFS:
        ch = song["charts"][d]
        rows = []
        for nt in ch:
            if nt["k"] == "rest":
                continue
            b = nt["b"]
            x = off + b * spb
            pos_ = position(b - (swing if abs((b % 0.5) - 0.25 - swing) < 0.02 else 0.0))
            v = float(A.sal(x))
            if nt["k"] == "bell":
                v = max(v, float(A.sal(x, ("low", "mid"))))
            rows.append({"b": b, "k": nt["k"], "lane": nt.get("lane"), "pos": pos_, "sal": round(v, 2)})
        pressed = [r for r in rows]
        heard = sum(1 for r in pressed if r["sal"] >= HEARD) / max(1, len(pressed))
        off_beat = [r for r in pressed if r["pos"] != "beat"]
        unheard = [r for r in off_beat if r["sal"] < HEARD]
        # pulse: groove bars (drums playing) with notes but nothing on beat 1 or 3
        by_bar = {}
        for r in pressed:
            by_bar.setdefault(int(r["b"] // 4), []).append(r)
        lost = []
        for bar, rs in by_bar.items():
            on13 = any(abs(r["b"] - bar * 4) < 1e-3 or abs(r["b"] - bar * 4 - 2) < 1e-3 for r in rs)
            held = any(nt["k"] == "hold" and nt["b"] < bar * 4 + 1e-3 and nt["b"] + nt["len"] > bar * 4 for nt in ch)
            if not on13 and not held and len(rs) >= 2:
                lost.append(bar)
        have = {int(np.argmin(np.abs(beats - r["b"]))) for r in rows}
        missed = [s for s in acc if not any(abs(s - h) <= 0 for h in have)]
        res["levels"][d] = {
            "notes": len(pressed), "nps": round(len(pressed) / max(1.0, length - 4.5), 2),
            "heard": round(heard, 3),
            "off_beat": len(off_beat), "unheard_off": len(unheard),
            "unheard_off_share": round(len(unheard) / max(1, len(off_beat)), 3),
            "unheard_list": [(r["b"], r["k"], r["pos"], r["sal"]) for r in unheard],
            "pulse_lost_bars": sorted(lost),
            "accents": len(acc), "missed_accents": len(missed),
            "missed_list": [round(float(beats[s]), 3) for s in missed],
            "mean_sal": round(float(np.mean([r["sal"] for r in rows])) if rows else 0.0, 2),
        }
    return res, A


def summary(res):
    g = res["grid"]
    out = [f"{res['song']}  {res['bpm']} bpm  grid {g['median_ms']:+.0f} ms (spread {g['spread_ms']} ms)"
           f"  beats(low) {res['beats_low']}  between-hits {res['between']['count']}"
           f" repeating at {list(res['between']['repeating'].keys())}"]
    for d, L in res["levels"].items():
        out.append(f"  {d:7} {L['notes']:4d} notes {L['nps']:.2f}/s  heard {L['heard']*100:5.1f}%  "
                   f"off-beat {L['off_beat']:3d} unheard {L['unheard_off']:3d} ({L['unheard_off_share']*100:4.1f}%)  "
                   f"pulse-lost bars {len(L['pulse_lost_bars']):2d}  accents missed {L['missed_accents']}/{L['accents']}")
    return "\n".join(out)


def main(argv):
    out = None
    if "--out" in argv:
        out = argv[argv.index("--out") + 1]
        os.makedirs(out, exist_ok=True)
    ids = [a for a in argv[1:] if not a.startswith("--") and a != out]
    if not ids or ids == ["all"]:
        ids = sorted(f[:-5] for f in os.listdir(SONGS) if f.startswith("suno_") and f.endswith(".json"))
    for sid in ids:
        res, _ = audit(sid)
        print(summary(res), flush=True)
        if out:
            json.dump(res, open(os.path.join(out, sid + ".json"), "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv)
