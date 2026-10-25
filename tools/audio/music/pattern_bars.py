#!/usr/bin/env python3
"""Propose the bar map a pattern chart needs (pattern_chart.py) from a song's analysis.

    python3 tools/audio/music/pattern_bars.py <pattern config.json>

Reads the analysis named in the config (pattern_analysis.py) and fills in "bars", "energy",
"drops", "medium_drops", "pivot_holds", "seesaw" and "end_beat" unless the config already has them,
then prints one line per bar so the map can be checked and corrected by hand:
  intro       drums silent before the first groove
  groove      a drum hit on three or four of the beats
  transition  two of the beats
  break       the drums stop after the downbeat (one hit, or none) inside the song
  calm        the bars after a break while the drums stay out
  build       a snare roll: twelve or more mid-band hits in the bar
  ending      the last bar with sound
A drop is the first groove bar after a break, a build or a drum fill. Energy is the bar's drum and lead level in
thirds (0 quiet, 1, 2 loud).
"""
from __future__ import annotations

import json
import sys

import numpy as np


def propose(cfg, a):
    n = a["slots"]
    bars = n // 16
    beat_hits, mids, level, piv = [], [], [], []
    for bar in range(bars):
        s0 = bar * 16
        hits = sum(1 for i in (0, 4, 8, 12) if max(a["dl"][s0 + i], a["dm"][s0 + i]) >= 0.6)
        beat_hits.append(hits)
        mids.append(sum(1 for i in range(16) if a["dm"][s0 + i] >= 0.5))
        level.append(float(np.mean([max(a["dl"][s], a["dm"][s]) for s in range(s0, s0 + 16)])
                           + 0.5 * np.mean(a["e"][s0:s0 + 16])))
        pcs = a["pc"][s0:s0 + 16]
        piv.append(max(pcs.count(p) for p in set(pcs)))
    last = max(b for b in range(bars) if level[b] > 0.05)
    kind = {}
    first_groove = next(b for b in range(bars) if beat_hits[b] >= 3)
    for bar in range(last + 1):
        if bar < first_groove:
            kind[bar] = "intro" if beat_hits[bar] == 0 else "pickup"
        elif bar == last:
            kind[bar] = "ending"
        elif mids[bar] >= 12 and beat_hits[bar] >= 2:
            kind[bar] = "build"
        elif beat_hits[bar] <= 1:
            kind[bar] = "calm" if kind.get(bar - 1) in ("break", "calm") else "break"
        elif beat_hits[bar] == 2:
            kind[bar] = "transition"
        else:
            kind[bar] = "groove"
    # two breaks in a row after a build: the second is the stop's tail
    lv = np.array([level[b] for b in range(last + 1)])
    q1, q2 = np.percentile(lv[lv > 0], [33, 70])
    energy = {}
    for bar in range(last + 1):
        e = 0 if kind[bar] == "intro" else (2 if level[bar] >= q2 else 1 if level[bar] >= q1 else 1)
        energy[bar] = e
    # a drop: the first groove after a break, a build or a drum fill (eight or more snare hits)
    drops = [b for b in range(1, last + 1) if kind[b] in ("groove", "ending")
             and (kind[b - 1] in ("break", "calm", "build") or mids[b - 1] >= 8)]
    # a song that keeps its drums going drops by getting louder: the phrase starts with the biggest
    # rise in level count too
    rise = {b: level[b] + level[b + 1] - level[b - 1] - level[b - 2] for b in range(4, last - 1, 4)
            if kind[b] == "groove"}
    if rise:
        cut = float(np.percentile(list(rise.values()), 80))
        drops += [b for b, r in rise.items() if r > 0 and r >= cut and all(abs(b - x) >= 4 for x in drops)]
    drops = sorted(set(drops))
    drops = [b for b in drops if b - 1 not in drops]
    loud_drops = [b for b in drops if energy[b] >= 2]
    pivots, prev = [], -9
    for bar in range(last + 1):
        if kind[bar] == "groove" and piv[bar] >= 11 and bar - prev >= 2 and bar not in drops:
            pivots.append(bar)
            prev = bar
    seesaw = [b for b in range(last + 1) if kind[b] == "intro"
              and sum(1 for i in (0, 8) if a["bass"][b * 16 + i] >= 0.5) >= 1][:3]
    out = {
        "bars": {},
        "energy": {str(b): energy[b] for b in range(last + 1)},
        "drops": drops,
        "medium_drops": loud_drops or drops[::2],
        "pivot_holds": pivots,
        "seesaw": [[b, b] for b in seesaw],
        "end_beat": (last * 16 + 12) / 4,
    }
    for b, k in kind.items():
        out["bars"].setdefault(k, []).append(b)
    return out, kind, beat_hits, mids, level


def main(path):
    cfg = json.load(open(path))
    a = json.load(open(cfg["analysis"]))
    prop, kind, hits, mids, level = propose(cfg, a)
    for k, v in prop.items():
        cfg.setdefault(k, v)
    with open(path, "w") as f:
        json.dump(cfg, f, indent=1, ensure_ascii=False)
        f.write("\n")
    for bar in sorted(kind):
        print(f"{bar:3d} {kind[bar]:10s} beats {hits[bar]} mids {mids[bar]:2d} level {level[bar]:.2f}"
              f" energy {prop['energy'][str(bar)]}{'  DROP' if bar in prop['drops'] else ''}"
              f"{'  pivot' if bar in prop['pivot_holds'] else ''}")


if __name__ == "__main__":
    main(sys.argv[1])
