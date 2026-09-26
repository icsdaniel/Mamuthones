#!/usr/bin/env python3
"""Validate every song file in game/data/songs/ (Python standard library only).

Checks the documented format (docs/architecture.md, "Song files"), that notes are sorted, lanes
and hold lengths are sane, the readability rules of docs/design.md section 4, per-difficulty
mechanics, and that every note ends inside the audio (the OGG length is read from the file).
Prints a summary per chart: notes, notes per second (average and peak) and the mechanics used.

    python3 tools/audio/validate_charts.py [song.json ...] [--quiet]

Exit status is 1 when any error is found.
"""
from __future__ import annotations

import json
import os
import struct
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GAME = os.path.join(ROOT, "game")
SONGS = os.path.join(GAME, "data", "songs")

DIFFS = ("easy", "medium", "hard", "expert")
KINDS = ("step", "hold", "bell", "ring", "swipe", "rest")
EPS = 1e-3

# Readability rules (design section 4). Gaps are in beats; "third" means a compound (triplet)
# grid, where an eighth is a third of a beat.
RULES = {
    # min gap between any two inputs (not counting notes on the same beat)
    "overall_gap": {"easy": 1.0, "medium": 0.5, "hard": 0.25, "expert": 0.25},
    "overall_gap_third": {"easy": 1.0, "medium": 1 / 3, "hard": 1 / 3, "expert": 1 / 6},
    # min gap between two inputs of the same hand
    "hand_gap": {"easy": 1.0, "medium": 0.5, "hard": 0.5, "expert": 0.25},
    "hand_gap_third": {"easy": 1.0, "medium": 2 / 3, "hard": 1 / 3, "expert": 1 / 6},
    "bell_gap": 0.5,                 # bells at least half a beat apart
    "easy_min_gap_s": 0.6,           # easy never asks for two inputs closer than this
    "easy_peak_nps": 1.5,            # easy stays beginner friendly
    "peak_window_s": 4.0,
    # first difficulty (index into DIFFS) where each extra may appear in a story song
    "min_level": {"hold": 1, "swipe": 2, "call": 2, "ring": 2, "triple": 3},
}


# ------------------------------------------------------------------ audio length

def ogg_length(path: str) -> float | None:
    """Duration of an Ogg Vorbis file from its last granule position and the header's rate."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return None
    i = data.find(b"\x01vorbis")
    if i < 0:
        return None
    rate = struct.unpack("<I", data[i + 12:i + 16])[0]
    j = data.rfind(b"OggS")
    while j >= 0:
        gran = struct.unpack("<q", data[j + 6:j + 14])[0]
        if gran > 0:
            return gran / float(rate)
        j = data.rfind(b"OggS", 0, j)
    return None


def res_to_path(res: str) -> str:
    return os.path.join(GAME, res[len("res://"):]) if res.startswith("res://") else res


# ------------------------------------------------------------------ helpers

def is_third_grid(notes) -> bool:
    """True when the chart uses triplet positions (compound meter or triplet passages)."""
    for n in notes:
        f = n["b"] % 1
        if abs(f - 1 / 3) < 0.01 or abs(f - 2 / 3) < 0.01 or abs(f - 1 / 6) < 0.01 or abs(f - 5 / 6) < 0.01:
            return True
    return False


def assign_hands(notes, hand_gap):
    """Greedy hand assignment: lane 0 left, lane 2 right, lane 1 and swipes whichever hand is free.
    Returns a list of (note index, message) for inputs no hand can play in time."""
    last = {"L": -1e9, "R": -1e9}
    busy = {"L": -1e9, "R": -1e9}   # a hold keeps its hand down until this beat
    used_at = {}
    problems = []
    order = sorted(range(len(notes)), key=lambda i: (notes[i]["b"], {0: 0, 2: 1}.get(notes[i].get("lane", 1), 2)))
    for i in order:
        n = notes[i]
        k = n["k"]
        if k in ("bell", "rest"):
            continue
        b = n["b"]
        lane = n.get("lane", 1)
        taken = used_at.get(round(b, 3), set())
        if k == "swipe" or lane == 1:
            cands = [h for h in ("L", "R") if h not in taken]
            cands.sort(key=lambda h: (busy[h] > b + EPS, last[h]))
            h = cands[0] if cands else "L"
        else:
            h = "L" if lane == 0 else "R"
        if h in taken:
            problems.append((i, f"two inputs for one hand at b={b}"))
            continue
        if busy[h] > b + EPS:
            problems.append((i, f"hand {h} is holding a note at b={b}"))
        elif b - last[h] < hand_gap - EPS:
            problems.append((i, f"hand {h} too fast at b={b} (gap {b - last[h]:.3f} < {hand_gap:.3f} beats)"))
        last[h] = b
        used_at.setdefault(round(b, 3), set()).add(h)
        if k == "hold":
            busy[h] = b + n.get("len", 0)
    return problems


def nps_stats(notes, bpm, offset, window):
    times = sorted(offset + n["b"] * 60.0 / bpm for n in notes if n["k"] != "rest")
    if not times:
        return 0, 0.0, 0.0
    span = max(times[-1] - times[0], 1.0)
    peak = 0
    j = 0
    for i in range(len(times)):
        while times[i] - times[j] >= window:
            j += 1
        peak = max(peak, i - j + 1)
    return len(times), len(times) / span, peak / window


def mechanics_of(notes):
    m = {}
    beats = {}
    for n in notes:
        k = n["k"]
        m[k] = m.get(k, 0) + 1
        if k == "step" and n.get("call"):
            m["call"] = m.get("call", 0) + 1
        beats.setdefault(round(n["b"], 3), []).append(n)
    triples = sum(1 for lst in beats.values()
                  if any(x["k"] == "ring" for x in lst) and sum(1 for x in lst if x["k"] in ("step", "ring")) >= 2)
    if triples:
        m["triple"] = triples
    return m


# ------------------------------------------------------------------ chart check

def check_chart(song: dict, name: str, notes: list, audio_len: float | None):
    errs = []
    bpm = song["bpm"]
    spb = 60.0 / bpm
    kind = song.get("kind", "story")
    tutorial = kind == "tutorial"
    level = DIFFS.index(name) if name in DIFFS else 3
    if not isinstance(notes, list) or not notes:
        return [f"{name}: chart is empty"], {}

    # format
    for i, n in enumerate(notes):
        where = f"{name}[{i}]"
        if not isinstance(n, dict) or "b" not in n or "k" not in n:
            errs.append(f"{where}: needs b and k")
            continue
        if not isinstance(n["b"], (int, float)) or n["b"] < 0:
            errs.append(f"{where}: bad beat {n['b']!r}")
        k = n["k"]
        if k not in KINDS:
            errs.append(f"{where}: unknown kind {k!r}")
            continue
        if kind == "piazza" and k != "bell":
            errs.append(f"{where}: piazza charts hold bells only")
        if k in ("step", "hold", "ring"):
            if n.get("lane") not in (0, 1, 2):
                errs.append(f"{where}: {k} needs lane 0, 1 or 2")
        elif "lane" in n:
            errs.append(f"{where}: {k} takes no lane")
        if k == "hold":
            ln = n.get("len")
            if not isinstance(ln, (int, float)) or ln < 0.5 or ln > 16:
                errs.append(f"{where}: hold len must be 0.5..16 beats, got {ln!r}")
        if k == "rest" and "len" in n and (not isinstance(n["len"], (int, float)) or n["len"] <= 0):
            errs.append(f"{where}: rest len must be > 0")
        if k == "swipe" and n.get("dir") not in (1, -1):
            errs.append(f"{where}: swipe dir must be 1 or -1")
        if "call" in n and (k != "step" or n["call"] is not True):
            errs.append(f"{where}: call is only for steps and must be true")
        extra = set(n) - {"b", "k", "lane", "len", "dir", "call"}
        if extra:
            errs.append(f"{where}: unknown fields {sorted(extra)}")
    if errs:
        return errs, {}

    # sorted, inside audio
    for i in range(1, len(notes)):
        if notes[i]["b"] < notes[i - 1]["b"] - 1e-9:
            errs.append(f"{name}: notes not sorted at index {i} (b={notes[i]['b']})")
            break
    last_end = max(n["b"] + (n.get("len", 0) if n["k"] in ("hold", "rest") else 0) for n in notes)
    end_t = song["offset"] + last_end * spb
    if audio_len is not None and end_t > audio_len - 0.25:
        errs.append(f"{name}: last note ends at {end_t:.2f}s, audio is {audio_len:.2f}s")
    if end_t > song.get("length", 1e9) + 1e-3:
        errs.append(f"{name}: last note ends at {end_t:.2f}s after song length {song.get('length')}")

    third = is_third_grid(notes) or song.get("_third", False)
    rules_gap = RULES["overall_gap_third" if third else "overall_gap"][name] if name in DIFFS else 0.5
    hand_gap = RULES["hand_gap_third" if third else "hand_gap"][name] if name in DIFFS else 0.5
    if name == "easy":
        rules_gap = max(rules_gap, RULES["easy_min_gap_s"] / spb - EPS) if not tutorial else rules_gap

    # same-beat groups
    groups = {}
    for n in notes:
        groups.setdefault(round(n["b"], 3), []).append(n)
    for b, lst in groups.items():
        lanes = [n["lane"] for n in lst if "lane" in n]
        if len(lanes) != len(set(lanes)):
            errs.append(f"{name}: two notes on one lane at b={b}")
        bells = [n for n in lst if n["k"] in ("bell", "ring")]
        if len(bells) > 1:
            errs.append(f"{name}: more than one bell at b={b}")
        if any(n["k"] == "bell" for n in lst) and any(n["k"] in ("step", "hold") for n in lst):
            errs.append(f"{name}: a step and a bell on one beat must be written as a ring (b={b})")
        if len(lst) > 1:
            kinds = sorted(n["k"] for n in lst)
            triple = kinds == ["ring", "step"]
            if not triple:
                errs.append(f"{name}: {kinds} together at b={b}")
            elif level < RULES["min_level"]["triple"] and not tutorial:
                errs.append(f"{name}: triple ring below expert at b={b}")
        if any(n["k"] == "rest" for n in lst) and len(lst) > 1:
            errs.append(f"{name}: a rest shares its beat with a note at b={b}")

    # overall spacing between distinct beats
    beats = sorted(b for b, lst in groups.items() if any(n["k"] != "rest" for n in lst))
    for a, c in zip(beats, beats[1:]):
        if c - a < rules_gap - EPS:
            errs.append(f"{name}: inputs {c - a:.3f} beats apart at b={a} (min {rules_gap:.3f})")

    # bells half a beat apart
    bell_bs = [n["b"] for n in notes if n["k"] in ("bell", "ring")]
    for a, c in zip(bell_bs, bell_bs[1:]):
        if c - a < RULES["bell_gap"] - EPS:
            errs.append(f"{name}: bells {c - a:.3f} beats apart at b={a}")

    # nothing under a hold's own lane; nothing inside a stand-still
    for n in notes:
        if n["k"] == "hold":
            hb, he = n["b"], n["b"] + n["len"]
            for m in notes:
                if m is not n and m.get("lane") == n["lane"] and hb - EPS <= m["b"] <= he + EPS:
                    errs.append(f"{name}: note hidden under the hold at b={hb} (lane {n['lane']}, b={m['b']})")
        if n["k"] == "rest":
            rb, re_ = n["b"], n["b"] + n.get("len", 1)
            for m in notes:
                if m is not n and rb - EPS <= m["b"] < re_ - EPS:
                    errs.append(f"{name}: note inside the stand-still at b={rb} (b={m['b']})")
                if m is not n and m["k"] == "hold" and m["b"] < rb and m["b"] + m["len"] > rb + EPS:
                    errs.append(f"{name}: hold runs into the stand-still at b={rb}")

    # hands
    for (i, msg) in assign_hands(notes, hand_gap):
        errs.append(f"{name}: {msg}")

    # mechanics per level (story songs; the tutorial teaches everything at every level)
    mech = mechanics_of(notes)
    if kind == "story" and name in DIFFS:
        for m, lv in RULES["min_level"].items():
            if mech.get(m) and level < lv:
                errs.append(f"{name}: {m} is not used below {DIFFS[lv]}")

    count, avg, peak = nps_stats(notes, bpm, song["offset"], RULES["peak_window_s"])
    if name == "easy" and not tutorial and peak > RULES["easy_peak_nps"] + EPS:
        errs.append(f"easy: peak {peak:.2f} notes/s is above {RULES['easy_peak_nps']}")
    summary = {"notes": count, "avg_nps": round(avg, 2), "peak_nps": round(peak, 2), "mechanics": mech}
    return errs, summary


def check_song(song: dict, audio_len: float | None = None):
    errs = []
    need = {"id": str, "title": dict, "stop": int, "kind": str, "bpm": (int, float), "offset": (int, float),
            "audio": str, "length": (int, float), "preview": (int, float), "key_root": int,
            "sections": list, "charts": dict}
    for k, t in need.items():
        if k not in song:
            errs.append(f"missing field {k}")
        elif not isinstance(song[k], t):
            errs.append(f"field {k} has the wrong type")
    if errs:
        return errs, {}
    if set(song["title"]) != {"en", "it"}:
        errs.append("title needs en and it")
    if song["kind"] not in ("story", "piazza", "tutorial"):
        errs.append(f"bad kind {song['kind']}")
    if not song["audio"].startswith("res://audio/music/"):
        errs.append("audio must live in res://audio/music/")
    if song["kind"] == "piazza":
        if set(song["charts"]) != {"piazza"}:
            errs.append("piazza songs have exactly one chart named piazza")
    elif set(song["charts"]) != set(DIFFS):
        errs.append(f"charts must be {DIFFS}")
    if song["kind"] == "tutorial":
        topics = [ls.get("topic") for ls in song.get("lessons", [])]
        for t in ("steps", "lanes", "bells", "holds", "still", "swipes", "full"):
            if t not in topics:
                errs.append(f"tutorial lacks lesson {t}")
    elif "lessons" in song:
        errs.append("only the tutorial has lessons")
    if "remix" in song:
        r = song["remix"]
        if not isinstance(r, dict) or set(r) != {"id", "bpm", "offset", "audio"}:
            errs.append("remix needs id, bpm, offset, audio")
        elif abs(r["bpm"] - song["bpm"]) > 1e-9:
            errs.append("remix must keep the song's bpm")
    last = -1.0
    for s in song["sections"]:
        if set(s) != {"name", "b", "len"}:
            errs.append(f"section fields {sorted(s)}")
        elif s["b"] < last - EPS:
            errs.append("sections not in order")
        else:
            last = s["b"] + s["len"]
    if not (0 <= song["preview"] < song["length"]):
        errs.append("preview outside the song")
    if audio_len is not None and abs(audio_len - song["length"]) > 0.1:
        errs.append(f"length {song['length']} differs from the audio ({audio_len:.2f}s)")

    summaries = {}
    for name, notes in song["charts"].items():
        e, summ = check_chart(song, name, notes, audio_len)
        errs.extend(e)
        summaries[name] = summ
    # lessons contain their mechanic in the easy chart
    if song["kind"] == "tutorial":
        want = {"steps": "step", "lanes": "step", "bells": "bell", "holds": "hold", "still": "rest",
                "swipes": "swipe", "full": "ring"}
        for ls in song.get("lessons", []):
            inside = [n for n in song["charts"].get("easy", []) if ls["b"] <= n["b"] < ls["b"] + ls["len"]]
            kinds = {n["k"] for n in inside}
            if want[ls["topic"]] not in kinds:
                errs.append(f"lesson {ls['topic']} has no {want[ls['topic']]} notes in easy")
            if ls["topic"] == "lanes" and len({n.get('lane') for n in inside}) < 3:
                errs.append("lesson lanes must use all three lanes")
    # difficulty order: density rises from easy to expert
    if song["kind"] != "piazza" and all(summaries.get(d) for d in DIFFS):
        counts = [summaries[d]["notes"] for d in DIFFS]
        if counts != sorted(counts):
            errs.append(f"note counts do not rise with difficulty: {counts}")
    return errs, summaries


def fmt_mech(m):
    order = ["step", "hold", "bell", "ring", "triple", "swipe", "call", "rest"]
    return " ".join(f"{k}:{m[k]}" for k in order if m.get(k))


def main(argv):
    quiet = "--quiet" in argv
    files = [a for a in argv if not a.startswith("--")]
    if not files:
        files = sorted(os.path.join(SONGS, f) for f in os.listdir(SONGS) if f.endswith(".json"))
    total_err = 0
    for path in files:
        try:
            with open(path, encoding="utf-8") as f:
                song = json.load(f)
        except (OSError, ValueError) as e:
            print(f"{os.path.basename(path)}: cannot read: {e}")
            total_err += 1
            continue
        audio = res_to_path(song.get("audio", ""))
        alen = ogg_length(audio)
        errs, summ = check_song(song, alen)
        if alen is None:
            errs.append(f"audio missing or unreadable: {song.get('audio')}")
        r = song.get("remix")
        if isinstance(r, dict):
            rlen = ogg_length(res_to_path(r.get("audio", "")))
            if rlen is None:
                errs.append(f"remix audio missing: {r.get('audio')}")
            else:
                for name, notes in song["charts"].items():
                    if notes:
                        end = r["offset"] + max(n["b"] + n.get("len", 0) for n in notes) * 60 / song["bpm"]
                        if end > rlen - 0.25:
                            errs.append(f"remix: {name} ends at {end:.2f}s, remix audio is {rlen:.2f}s")
        head = f"{song.get('id', path)} ({song.get('kind')}, {song.get('bpm')} bpm, {alen or 0:.1f}s)"
        print(("FAIL " if errs else "ok   ") + head)
        if not quiet:
            for name, s in summ.items():
                if s:
                    print(f"      {name:<7} {s['notes']:>4} notes  {s['avg_nps']:>4.2f}/s avg  "
                          f"{s['peak_nps']:>4.2f}/s peak  {fmt_mech(s['mechanics'])}")
        for e in errs[:40]:
            print("      ERROR " + e)
        if len(errs) > 40:
            print(f"      ... {len(errs) - 40} more")
        total_err += len(errs)
    print(f"{len(files)} song files, {total_err} errors")
    return 1 if total_err else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
