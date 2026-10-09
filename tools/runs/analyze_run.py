"""Summarise a run log saved by the game (RunLog, Downloads/mamuthones-last-run.json).

    python3 tools/runs/analyze_run.py path/to/mamuthones-last-run.json

Prints the phone and settings, frame pacing, the song clock against the audio clock, timing by
note kind, lane and position inside runs of eighth notes, and what happened around every miss,
stray and wrong step.
"""
import collections
import json
import statistics as st
import sys


def ms(x):
    return round(x * 1000)


def main(path):
    d = json.load(open(path))
    h, res = d["header"], d["result"]
    notes, events, frames = d["notes"], d["events"], d["frames"]
    print(f"{h.get('model')} {h.get('os')} {h.get('os_version')}, {h.get('refresh_hz', 0):.0f} Hz, build {h.get('build')}")
    print(f"{h['song_id']} {h['difficulty']}: grade {res['grade']}, accuracy {res['accuracy']:.3f}, stats {res['stats']}")
    print("settings", h.get("settings"))
    fs = h.get("frame_stats", {})
    print(f"frames: {fs.get('fps', 0):.0f} fps, {fs.get('slow')} slow, slowest {ms(fs.get('worst', 0))} ms")
    clock = [f[4] + f[5] - f[1] for f in frames if f[4] >= 0]
    if clock:
        c = sorted(clock)
        print(f"audio clock - song clock: median {ms(st.median(c))} ms, p1 {ms(c[len(c)//100])}, p99 {ms(c[99*len(c)//100])}")
    downs = [e for e in events if e[2] == "down"]
    print(f"touches {len(downs)}, outside the button zone {sum(1 for e in downs if not e[3]['in_zone'])}")
    hit = [n for n in notes if n[7] is not None and n[6] not in ("miss", "wrong", "")]
    by = collections.defaultdict(list)
    for n in hit:
        by[n[2]].append(n[7] - n[1])
    for k, v in sorted(by.items()):
        print(f"  {k:6} {len(v):3} hits, median {ms(st.median(v)):+} ms, spread {ms(st.pstdev(v))} ms")
    beat = 60.0 / h["bpm"]
    lane = [n for n in notes if n[2] in ("step", "hold", "stomp", "ring")]
    pos, run = collections.defaultdict(list), 0
    for a, b in zip(lane, lane[1:]):
        run = run + 1 if abs((b[1] - a[1]) / beat - 0.5) < 0.05 else 0
        if b[7] is not None and b[6] not in ("miss", "wrong"):
            pos[min(run, 6)].append(b[7] - b[1])
    print("by place in a run of eighths:", ", ".join(f"{k}: {ms(st.median(v)):+} ms ({len(v)})" for k, v in sorted(pos.items())))
    for n in notes:
        if n[6] == "miss":
            near = [e for e in events if e[2] in ("press", "ring") and abs(e[1] - n[1]) < 0.35]
            print(f"miss {n[2]} lane {n[3]} at {n[1]:.2f}s:", [(e[2], ms(e[1] - n[1]), e[3].get("lane"), e[3].get("j")) for e in near])
    for e in events:
        if e[2] in ("stray", "wrong", "locked"):
            print(e[2], f"{e[1]:.2f}s", e[3])


if __name__ == "__main__":
    main(sys.argv[1])
