#!/usr/bin/env python3
"""Renders what a player hears: a song with every chart note hit, mixed the way the Sound
autoload mixes it in the game, so music and feedback sounds can be judged together offline.

    python3 tools/audio/preview_play.py fires hard OUT.ogg [--from S] [--len S] [--root DIR]
        [--remix] [--set full|village|light] [--miss N] [--hard-flicks]

--root points at another copy of game/ (for example an older checkout) to render its audio
with the same player. Bus trims and the music duck are read from game/scripts/audio/sound.gd
so the preview follows the game. Steps play the foot and the lane's tuned knock (a ring note
plays both a step and a bell), bells alternate up and down as the charts write them, the row
joins at unison 4, holds sound the lane's drone and swipe or stomp notes play the stomp. Hits land within +-6 ms of the note,
like a good player; --miss N makes every Nth note a miss.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

import numpy as np
import soundfile as sf

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def gd_consts(path):
    src = open(path, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"^const (\w+)\s*(?::=|:\s*\w+\s*=|=)\s*(.+)$", src, re.M):
        out[m.group(1)] = m.group(2).strip()
    return out


def gd_dict(s):
    return {k: float(v) for k, v in re.findall(r'"(\w+)":\s*(-?[\d.]+)', s)}


def gd_floats(s):
    return [float(v) for v in re.findall(r"-?\d+\.?\d*", s)]


class Assets:
    def __init__(self, game):
        self.dir = os.path.join(game, "audio", "sfx")
        self.cache = {}

    def get(self, rel):
        if rel not in self.cache:
            p = os.path.join(self.dir, rel)
            if not os.path.exists(p):
                self.cache[rel] = None
            else:
                y, sr = sf.read(p, always_2d=True)
                assert sr == SR, p
                if y.shape[1] == 1:
                    y = np.repeat(y, 2, axis=1)
                self.cache[rel] = y
        return self.cache[rel]

    def takes(self, pattern, n):
        return [t for t in (self.get(pattern % (k + 1)) for k in range(n)) if t is not None]


def resample(y, ratio):
    """Plays y at pitch_scale = ratio (shorter and higher above 1)."""
    if abs(ratio - 1) < 1e-4:
        return y
    n = int(len(y) / ratio)
    x = np.arange(n) * ratio
    return np.stack([np.interp(x, np.arange(len(y)), y[:, c]) for c in range(2)], axis=1)


def add(dst, src, at, gain_db=0.0):
    if src is None or at >= len(dst):
        return
    if at < 0:
        src = src[-at:]
        at = 0
    k = min(len(src), len(dst) - at)
    dst[at:at + k] += src[:k] * 10 ** (gain_db / 20)


def limiter(x, ceiling_db, release=0.06, look=0.0015):
    c = 10 ** (ceiling_db / 20)
    peak = np.max(np.abs(x), axis=1)
    la = int(look * SR)
    need = np.minimum(1.0, c / np.maximum(peak, 1e-9))
    need = np.concatenate([need[la:], np.ones(la)])
    # instant attack over the look-ahead, exponential release
    g = np.empty_like(need)
    a = np.exp(-1 / (release * SR))
    cur = 1.0
    for i in range(len(need)):
        v = need[i]
        cur = v if v < cur else v + (cur - v) * a
        g[i] = cur
    return x * g[:, None]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("song")
    ap.add_argument("diff")
    ap.add_argument("out")
    ap.add_argument("--from", dest="t0", type=float, default=None)
    ap.add_argument("--len", type=float, default=30.0)
    ap.add_argument("--root", default=os.path.join(ROOT, "game"))
    ap.add_argument("--sound-gd", default=None)
    ap.add_argument("--remix", action="store_true")
    ap.add_argument("--set", default="full")
    ap.add_argument("--miss", type=int, default=0)
    ap.add_argument("--hard-flicks", action="store_true")
    ap.add_argument("--music-only", action="store_true")
    a = ap.parse_args()

    game = a.root
    song = json.load(open(os.path.join(game, "data", "songs", a.song + ".json")))
    gd = gd_consts(a.sound_gd or os.path.join(game, "scripts", "audio", "sound.gd"))
    trim = gd_dict(gd["BUS_TRIM_DB"])
    duck_db = float(gd.get("DUCK_DB", "3.0"))
    duck_hold = float(gd.get("DUCK_HOLD", "0.13"))
    duck_att = float(gd.get("DUCK_ATTACK", "0.015"))
    duck_rel = float(gd.get("DUCK_RELEASE", "0.12"))
    row_db = gd_floats(gd.get("ROW_DB", "[-80, -20, -16, -12, -9, -6]"))

    info = song["remix"] if a.remix else song
    audio = info["audio"].replace("res://", "")
    music, sr = sf.read(os.path.join(game, audio), always_2d=True)
    assert sr == SR
    bpm, offset = info["bpm"], info["offset"]
    t0 = a.t0 if a.t0 is not None else song.get("preview", 0.0)
    n0, n = int(t0 * SR), int(a.len * SR)
    music = music[n0:n0 + n]
    n = len(music)

    A = Assets(game)
    sfx = np.zeros((n, 2))
    belbus = np.zeros((n, 2))
    duck_env = np.zeros(n)
    rng = np.random.default_rng(7)
    pc = song["key_root"] % 12
    tone_ratio = 2 ** (1 / 12) if pc % 2 else 1.0
    tone_pc = pc - (pc % 2)
    up = True
    notes = sorted(song["charts"][a.diff], key=lambda x: x["b"])
    step_count = 0
    streak = 0
    jangle_until = -1
    misses = []
    for i, nt in enumerate(notes):
        t = offset + nt["b"] * 60 / bpm - t0 + rng.uniform(-0.006, 0.006)
        at = int(t * SR)
        if at < -SR * 4 or at >= n:
            if nt["k"] in ("bell", "ring"):
                up = not up
            continue
        miss = a.miss and (i % a.miss == a.miss - 1)
        k = nt["k"]
        if k in ("step", "ring", "hold", "swipe") and k != "swipe":
            lane = nt.get("lane", 1)
            q = "perfect" if not miss else "miss"
            feet = A.takes(f"steps/foot_{lane}_%d.wav", 3) if not miss else A.takes(f"steps/foot_ok_{lane}_%d.wav", 3)
            if feet:
                add(sfx, resample(feet[step_count % len(feet)], rng.uniform(0.97, 1.03)), at, rng.uniform(-1.5, 0.5))
            tone = A.get(f"steps/tone_{lane}_{tone_pc:02d}.wav")
            if tone is not None:
                add(sfx, resample(tone, tone_ratio), at, -2.0 if miss else 0.0)
            step_count += 1
            if k == "hold":
                dr = A.get(f"loops/drone_{lane}_{pc:02d}.ogg")
                if dr is not None:
                    ln = int(nt.get("len", 1) * 60 / bpm * SR)
                    seg = dr[:ln].copy()
                    f = min(len(seg), int(0.09 * SR))
                    seg[:int(0.03 * SR)] *= np.linspace(0, 1, int(0.03 * SR))[:, None]
                    seg[-f:] *= np.linspace(1, 0, f)[:, None]
                    add(sfx, seg, at)
        if k in ("bell", "ring"):
            d = "up" if up else "down"
            up = not up
            q = "miss" if miss else "perfect"
            takes = A.takes(f"bells/{a.set}_{d}_{q}_%d.wav", 3)
            if takes:
                add(belbus, resample(takes[i % len(takes)], rng.uniform(0.9975, 1.0025)), at, rng.uniform(-0.5, 0) + (1.0 if a.hard_flicks else 0.0))
            if a.hard_flicks and not miss:
                acc = A.takes(f"bells/{a.set}_{d}_accent_%d.wav", 2)
                if acc:
                    add(belbus, acc[i % len(acc)], at, 1.0)
            if not miss:
                if 0 <= at < n:
                    duck_env[max(0, at):min(n, at + int(duck_hold * SR))] = 1.0
                row = A.takes(f"bells/row_tight_{d}_%d.wav", 3)
                if row:
                    add(belbus, row[i % len(row)], at, row_db[4] + rng.uniform(-1, 0))
                streak += 1
                if streak >= 4 and at > jangle_until:
                    jg = A.get(f"bells/{a.set}_jangle_1.wav")
                    if jg is not None:
                        add(belbus, jg, at, -6.0 + 1.5 * min(streak - 4, 4))
                        jangle_until = at + int(0.45 * SR)
            else:
                streak = 0
        if miss and "MISS_CUTOFF" in gd:
            misses.append(at)
        if k in ("swipe", "stomp"):
            # the stomp replaced the rope swipe on the same beats; older builds play the rope
            stomps = A.takes("fx/stomp_%d.wav", 3)
            if stomps and not miss:
                add(belbus, stomps[i % len(stomps)], at, rng.uniform(-0.5, 0))
                duck_env[max(0, at):min(n, at + int(duck_hold * SR))] = 1.0
            elif not stomps:
                ropes = A.takes("fx/rope_%d.wav", 3)
                if ropes:
                    add(sfx, ropes[i % len(ropes)], at)
    # music duck: attack, hold, release (as Sound._process does it)
    g = np.zeros(n)
    cur = 0.0
    up_s, dn_s = 1 / (duck_att * SR), 1 / (duck_rel * SR)
    for i in range(n):
        cur = min(1.0, cur + up_s) if duck_env[i] > 0 else max(0.0, cur - dn_s)
        g[i] = cur
    mus = music * (10 ** ((trim.get("Music", 0) - duck_db * g) / 20))[:, None]
    if misses:
        # a miss muffles the music: the low-pass drops to MISS_CUTOFF and opens over MISS_RECOVER
        lo_hz, rec = float(gd["MISS_CUTOFF"]), float(gd["MISS_RECOVER"])
        m = np.zeros(n)
        for at in misses:
            k = np.arange(max(0, at), min(n, at + int(rec * SR)))
            m[k] = np.maximum(m[k], 1 - (k - at) / (rec * SR))
        fc = lo_hz * (20000.0 / lo_hz) ** (1 - m * m)
        coef = np.exp(-2 * np.pi * fc / SR)
        y = np.zeros(2)
        for i in np.nonzero(m > 0)[0]:
            if i == 0 or m[i - 1] == 0:
                y = mus[i].copy()
            y = (1 - coef[i]) * mus[i] + coef[i] * y
            mus[i] = y

    ceil_b = -3.5
    m = re.search(r"lim\.ceiling_db = (-?[\d.]+)", open(a.sound_gd or os.path.join(game, "scripts", "audio", "sound.gd")).read())
    if m:
        ceil_b = float(m.group(1))
    belbus = limiter(belbus * 10 ** (trim.get("Bells", 0) / 20), ceil_b, 0.12)
    sfx = sfx * 10 ** (trim.get("Sfx", 0) / 20)
    out = mus if a.music_only else mus + belbus + sfx
    out = limiter(out, -1.0, 0.06)
    f = int(0.02 * SR)
    out[:f] *= np.linspace(0, 1, f)[:, None]
    out[-int(0.5 * SR):] *= np.linspace(1, 0, int(0.5 * SR))[:, None]
    os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
    fmt = "OGG" if a.out.endswith(".ogg") else None
    if fmt:
        with sf.SoundFile(a.out, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=0.45) as fh:
            for i in range(0, len(out), SR):
                fh.write(out[i:i + SR].astype(np.float32))
    else:
        sf.write(a.out, out.astype(np.float32), SR)
    print(a.out)


if __name__ == "__main__":
    sys.exit(main())
