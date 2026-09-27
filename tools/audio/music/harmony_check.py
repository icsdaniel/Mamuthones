#!/usr/bin/env python3
"""Harmony check: melody notes on strong beats against the tenore chord (root, fifth, octave).
Lists clashes (minor second, tritone, major seventh against the root or the fifth)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import STORY, load_song  # noqa: E402

CLASH = {1, 6, 11}


def check(sid):
    s = load_song(sid)
    notes = [e for e in s.events if e.inst in ("boghe", "mancosedda") and e.pitch is not None]
    strong = [e for e in notes if s.rank_of(e.b) <= 3 and e.dur >= 0.5]
    bad = []
    for e in strong:
        root = s.pitch(s.root_at(e.b))
        for ref in (root, root + 7):
            if (e.pitch - ref) % 12 in CLASH:
                bad.append((e.b, e.inst, int(e.pitch), int(ref)))
                break
    return len(strong), bad


if __name__ == "__main__":
    for sid in sys.argv[1:] or STORY:
        n, bad = check(sid)
        print(f"{sid:10s} strong melody notes {n:4d}  clashes {len(bad):3d} ({100 * len(bad) / max(1, n):.1f}%)",
              bad[:8])
