#!/usr/bin/env python3
"""How the charts follow the music: density per section (build-up and climax), signature pattern
occurrences, where each mechanic first appears and whether it is alone, and how often a phrase's
lane pattern is echoed or mirrored by a later phrase.

    python3 tools/audio/music/chart_report.py [song ids]
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from charts import DIFFS, Charter  # noqa: E402
from render import STORY, load_song  # noqa: E402


def mech(n):
    return "call" if n.call else n.k


def report(sid):
    song = load_song(sid)
    ch = Charter(song)
    out = {"sections": {}, "signature": {}, "firsts": {}, "phrases": {}}
    for d in DIFFS:
        notes = ch.build(d)
        # density per section
        for sec in song.sections:
            inside = [n for n in notes if sec.b <= n.b < sec.b + sec.len and n.k != "rest"]
            out["sections"].setdefault(sec.name, {"energy": sec.energy})[d] = round(len(inside) / (sec.len * song.spb), 2)
        # signature
        sig = [n for n in notes if n.sig is not None]
        out["signature"][d] = len(sig)
        # first appearances
        firsts = {}
        for n in sorted(notes, key=lambda n: n.b):
            m = mech(n)
            if m in firsts or m == "step":
                continue
            near = [o for o in notes if o is not n and mech(o) not in ("step", "rest", m) and abs(o.b - n.b) <= 2]
            firsts[m] = {"b": n.b, "alone": not near}
        out["firsts"][d] = firsts
        # phrases: lane patterns of 2-bar phrases; an answer is a later phrase that repeats, mirrors
        # (2 - lane) or shifts the same rhythm
        span = song.bpb * 2
        groups = {}
        for n in notes:
            if n.k in ("step", "hold", "ring"):
                groups.setdefault(int(n.b // span), []).append((round(n.b % span, 3), n.lane))
        pats = {k: tuple(sorted(v)) for k, v in groups.items() if len(v) >= 3}
        keys = sorted(pats)
        answered = 0
        kinds = {"repeat": 0, "mirror": 0, "rhythm": 0}
        for i, k in enumerate(keys):
            p = pats[k]
            rhythm = tuple(x for x, _ in p)
            lanes = tuple(y for _, y in p)
            for k2 in keys[i + 1:i + 5]:
                q = pats[k2]
                if tuple(x for x, _ in q) != rhythm:
                    continue
                l2 = tuple(y for _, y in q)
                if l2 == lanes:
                    kinds["repeat"] += 1
                elif l2 == tuple(2 - y for y in lanes):
                    kinds["mirror"] += 1
                else:
                    kinds["rhythm"] += 1
                answered += 1
                break
        out["phrases"][d] = {"phrases": len(keys), "answered": answered, **kinds}
    return out


def main(argv):
    ids = argv or STORY
    res = {}
    for sid in ids:
        r = report(sid)
        res[sid] = r
        print(f"== {sid}")
        print("   section          e   " + "  ".join(f"{d:>6}" for d in DIFFS) + "   (notes/s)")
        for name, row in r["sections"].items():
            print(f"   {name:<16} {row['energy']}   " + "  ".join(f"{row.get(d, 0):>6.2f}" for d in DIFFS))
        print("   signature notes: " + ", ".join(f"{d} {r['signature'][d]}" for d in DIFFS))
        for d in DIFFS:
            f = r["firsts"][d]
            ph = r["phrases"][d]
            print(f"   {d:<7} firsts: " + ", ".join(f"{m}@{v['b']:g}{'' if v['alone'] else '(!)'}" for m, v in f.items())
                  + f" | phrases {ph['phrases']}, answered {ph['answered']} (repeat {ph['repeat']}, "
                    f"mirror {ph['mirror']}, same rhythm {ph['rhythm']})")
    with open("/tmp/mamuthones_stems/chart_report.json", "w") as fp:
        json.dump(res, fp, indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
