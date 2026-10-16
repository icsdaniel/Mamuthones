#!/usr/bin/env python3
"""Pattern charts: taps that follow the melody's rhythm and shape, tilts locked to the beat, stomps on
the drops and holds that mean something (Daniele, 2026-10-15: "focus on understanding what the melody
and the beats are ... the play should consist of patterns").

    python3 tools/audio/music/pattern_chart.py <pattern config.json> [--write] [--grid]

Reads the per-sixteenth analysis written by pattern_analysis.py and the bar map in the config (which
bars are grooves, drum breaks, the build, where the drops land, where the drone and the seesaw holds
go). --grid prints every bar with the drums, the lead and all four charts side by side, for review.

How a chart is made, per difficulty (rules settled with three outside reviewers, 2026-10-15):
  1. Rhythm: the lead's onsets on the level's grid (sixteenths at Expert, eighths at Hard and Medium,
     every other beat at Easy). Drum beats fill in where the lead rests in a groove. A level keeps the
     strongest of them (onset, place in the bar, drum under it, the "& of 4" pickup above all) up to
     its density for the section.
  2. Patterns: bars that sound alike (the same pitch class on three quarters of their sixteenths)
     are charted once and repeated, so a riff always plays the same.
  3. Lanes follow the tune: one pitch-to-button map per section, so a note keeps its button. A pitch
     the tune keeps returning to (the launeddas pivot) takes the middle and the notes that move away
     go to the side they move to; otherwise low notes left, high notes right. Two notes a sixteenth
     apart always go to the two thumbs; Medium's middle button carries at most 40 %.
  4. Tilts sit on the pulse: in the drum breaks the bells answer the drums (beats 1 and 2 at Hard and
     Expert, beat 1 below); in grooves Expert tilts on 1 and 3, Hard on 1 and 3 in loud bars, Medium
     on 3. A tilt owns its space (a sixteenth before, a sixteenth after at Expert, an eighth after
     below) and is a full ring on a strong tune note. No tilt while a thumb holds.
  5. Stomps land on the drops that have the bass under them, plus the config's extra bass hits, with
     a beat of rest after.
  6. Holds: the launeddas drone (left thumb holds while the right plays the tune), seesaw holds on
     the intro's bass, holds on the pivot note, and a hold through the stop before the last drop.
  7. Chords where a bass hit lands under a tune note (Hard and Expert).
  8. The game's readability rules (validate_charts.py) are applied last; a note they reject is
     dropped, lowest priority first.
"""
from __future__ import annotations

import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio"))
import validate_charts as V  # noqa: E402

DIFFS = ("easy", "medium", "hard", "expert")
# notes per second the rhythm layer aims at, by section energy (0 calm, 1 groove, 2 loud)
TARGET = {
    "expert": (3.0, 5.0, 6.0),
    "hard": (1.9, 3.0, 3.5),
    "medium": (1.3, 2.0, 2.4),
    "easy": (0.5, 0.85, 1.0),
}
# the least time between two tilts, and between two Expert chords (loud bars, other bars), in seconds:
# a fast song tilts and chords less often per beat
TILT_GAP = {"expert": 0.88, "hard": 1.0, "medium": 1.9, "easy": 4.0}
CHORD_GAP = {"expert": (1.4, 0.7), "hard": (4.0, 4.0)}
# the room a tilt keeps clear, in seconds: before it, and after it (Expert, other levels)
TILT_BEFORE = 0.2
TILT_AFTER = {"expert": 0.28, "hard": 0.4, "medium": 0.4, "easy": 0.8}
# the least time between two stomps (Hard and Expert, Medium)
STOMP_GAP = (8.0, 15.0)
ON = 0.5          # a lead onset counts from this strength
SIXTEENTH_ON = 0.5


def rng(spec):
    out = []
    for k in spec:
        if isinstance(k, str) and "-" in k:
            a, b = k.split("-")
            out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(k))
    return out


class Song:
    def __init__(self, cfg, ana):
        self.cfg, self.a = cfg, ana
        self.spb = 60.0 / cfg["bpm"]
        self.swing = cfg.get("swing", 0.0)
        self.n = ana["slots"]
        self.kind = {}
        for k, bars in cfg["bars"].items():
            for b in bars:
                self.kind[b] = k
        self.energy = {}
        for spec, e in cfg["energy"].items():
            for b in rng([spec]):
                self.energy[b] = e
        self.drone = [b for a, c in cfg.get("drone", []) for b in range(a, c + 1)]
        self.seesaw = [b for a, c in cfg.get("seesaw", []) for b in range(a, c + 1)]
        self.end_slot = int(cfg["end_beat"] * 4)
        self.bars = self.end_slot // 16 + 1

    # --- reading the analysis
    def lead(self, s):
        return self.a["on"][s] if s < self.n else 0.0

    def drum(self, s):
        return max(self.a["dl"][s], self.a["dm"][s]) if s < self.n else 0.0

    def pitch(self, s):
        return self.a["pitch"][s]

    def metric(self, s):
        i = s % 16
        return 4 if i == 0 else 3 if i == 8 else 2 if i % 4 == 0 else 1 if i % 2 == 0 else 0

    def score(self, s):
        return 2.0 * min(self.lead(s), 1.5) + 0.6 * self.metric(s) + 0.6 * min(self.drum(s), 1.0)

    # --- bars that sound alike share one pattern
    def alike(self, x, y):
        """Share of the sixteenths where two bars sound the same pitch class."""
        pc = self.a["pc"]
        if (y + 1) * 16 > self.n or (x + 1) * 16 > self.n:
            return 0.0
        return sum(pc[x * 16 + i] == pc[y * 16 + i] for i in range(16)) / 16

    def clusters(self):
        """Bar -> the earlier bar it repeats (itself if none): same kind of bar, and the same pitch
        class on at least three quarters of its sixteenths."""
        rep, seen = {}, []
        for bar in range(self.bars):
            rep[bar] = bar
            for other in seen:
                if self.kind.get(other) == self.kind.get(bar) and self.alike(bar, other) >= 0.75:
                    rep[bar] = other
                    break
            else:
                seen.append(bar)
        return rep


# ------------------------------------------------------------------ rhythm

def pick_rhythm(song, diff, bar):
    """Slots (absolute) of the plain taps in one bar, before tilts, stomps and holds."""
    kind = song.kind.get(bar, "groove")
    e = song.energy.get(bar, 1)
    lo, hi = bar * 16, min(bar * 16 + 16, song.end_slot + 1, song.n)
    cands = []
    for s in range(lo, hi):
        i = s % 16
        lead, drum = song.lead(s), song.drum(s)
        if diff == "expert":
            six = SIXTEENTH_ON if song.spb / 4 < 0.2 else 0.35     # a slow song's sixteenths are roomy
            ok = (i % 2 == 0 and lead >= ON) or (i % 2 == 1 and lead >= six and e >= 1)
            ok = ok or (i % 4 == 0 and drum >= 0.6 and kind in ("groove", "transition", "ending"))
            if kind == "build":
                ok = song.a["dm"][s] >= 0.4 or lead >= ON or i % 4 == 0   # the snare roll as it sounds
        elif diff == "hard":
            ok = i % 2 == 0 and (lead >= ON or (i % 4 == 0 and drum >= 0.6) or drum >= 0.8 or kind == "build")
        elif diff == "medium":
            # the beat, plus the tune's eighths (its "& of 4" pickup above all)
            ok = (i % 4 == 0 and (lead >= ON or drum >= 0.6 or kind == "build")) or \
                 (i % 2 == 0 and lead >= 0.6 and e >= 1)
        else:
            ok = i % 8 == 0 and (lead >= ON or drum >= 0.5 or e == 0)
        if ok:
            cands.append(s)
    target = TARGET[diff][e] * song.spb * 4         # notes in this bar
    if kind == "build":
        target = {"expert": 16, "hard": 8, "medium": 4, "easy": 2}[diff]

    def sc(s):   # the "& of 4" pushes into the next bar: keep it
        return song.score(s) + (1.0 if s % 16 == 14 and song.lead(s) >= ON else 0.0)
    keep = sorted(cands, key=lambda s: -sc(s))[:max(1, round(target))]
    return sorted(keep)


# ------------------------------------------------------------------ lanes

def phrase_lanes(pitches, pivot=True):
    """Pitch -> lane for one section. A pitch the tune keeps returning to (the launeddas pivot, 40 %
    or more of the notes) takes the middle and what moves away from it goes to the side it moves
    to; otherwise the distinct pitches split into low, middle and high thirds."""
    if not pitches:
        return {}
    ds = sorted(set(pitches))
    top = max(ds, key=pitches.count)
    if pivot and pitches.count(top) >= 0.4 * len(pitches) and len(ds) > 1:
        return {p: 0 if p < top else 2 if p > top else 1 for p in ds}
    if len(ds) == 1:
        return {ds[0]: 1}
    if len(ds) == 2:
        return {ds[0]: 0, ds[1]: 2}
    # thirds by how often each pitch sounds, so each button gets its share
    out, acc, total = {}, 0, len(pitches)
    for p in ds:
        mid = acc + pitches.count(p) / 2
        out[p] = min(2, int(3 * mid / total))
        acc += pitches.count(p)
    return out


def sections_of(song):
    """Runs of bars of the same kind (a groove, a break, ...): one pitch-to-button map each."""
    out, cur = [], []
    for bar in range(song.bars):
        if cur and (song.kind.get(bar) != song.kind.get(cur[-1]) or len(cur) >= 4):
            out.append(cur)
            cur = []
        cur.append(bar)
    if cur:
        out.append(cur)
    return out


def lanes_for(song, diff, slots, forced=None):
    """Lane per slot: one pitch-to-button map per section, so a note keeps its button."""
    forced = forced or {}
    out = {}
    sec_of = {}
    for i, sec in enumerate(sections_of(song)):
        for bar in sec:
            sec_of[bar] = i
    by_sec = {}
    for s in slots:
        by_sec.setdefault(sec_of.get(s // 16, -1), []).append(s)
    last_lane = 1
    for key in sorted(by_sec):
        ss = by_sec[key]
        bars_ = sorted({s // 16 for s in ss})
        tuned = [song.pitch(x) for b in bars_ for x in range(b * 16, min(b * 16 + 16, song.n)) if song.lead(x) >= ON]
        lane_of = phrase_lanes(tuned, pivot=diff != "easy")
        prev_p, prev_lane = None, last_lane
        for s in ss:
            if song.lead(s) >= ON:
                p = song.pitch(s)
                lane = lane_of[p]
            else:
                p = None
                lane = 2 if prev_lane == 0 else 0      # drum fill: the other side
            if song.kind.get(s // 16) == "build":
                lane = 2 if prev_lane == 0 else 0       # the snare roll: hand to hand
            allow = forced.get(s)
            if allow is not None and lane not in allow:
                lane = min(allow, key=lambda x: abs(x - lane) + (0.1 if x == 1 else 0))
            out[s] = lane
            prev_p, prev_lane = p, lane
        last_lane = prev_lane
    # Medium: the middle button is shared, so it never carries more than 40 % of a section
    if diff == "medium":
        for key, ss in by_sec.items():
            mids = [s for s in ss if out[s] == 1 and s not in forced]
            excess = len(mids) - int(0.4 * len(ss))
            if excess > 0 and ss:
                med = sorted(song.pitch(s) for s in ss)[len(ss) // 2]
                for s in mids[::2][:excess]:
                    out[s] = 0 if song.pitch(s) <= med else 2
    # two notes a sixteenth apart go to the two thumbs; no long runs on one button
    order = sorted(out)
    thumb = {}
    for j, s in enumerate(order):
        lane = out[s]
        t = "L" if lane == 0 else "R" if lane == 2 else None
        if j:
            ps = order[j - 1]
            if s - ps == 1:
                pt = thumb.get(ps)
                if lane == out[ps] or (t is not None and t == pt):
                    allow = forced.get(s, (0, 1, 2))
                    # the lower of the two notes to the left thumb, the higher to the right
                    up = song.pitch(s) >= song.pitch(ps)
                    want = ([2, 1] if up else [0, 1]) if pt is None or (pt == "L") == up else [1]
                    want += [x for x in (0, 1, 2) if x not in want]
                    want = [w for w in want if not ((w == 0 and pt == "L") or (w == 2 and pt == "R"))]
                    for w in want:
                        if w in allow and w != out[ps]:
                            lane = w
                            break
                    out[s] = lane
                    t = "L" if lane == 0 else "R" if lane == 2 else None
        if t is None:   # the middle goes to the thumb that is free
            prev_t = thumb.get(order[j - 1]) if j else "R"
            t = "R" if prev_t == "L" else "L"
        thumb[s] = t
    run, last, last_s = 0, None, -99
    for s in order:
        if out[s] == last and s - last_s <= 2:
            run += 1
            if run >= 3:
                allow = forced.get(s, (0, 1, 2))
                alt = [x for x in allow if x != last]
                if alt:
                    out[s] = min(alt, key=lambda x: abs(x - 1))
                    run = 0
        else:
            run = 0
        last, last_s = out[s], s
    return out


# ------------------------------------------------------------------ one chart

def stomp_slots(song, diff):
    """Stomps where the drop has the bass under it, plus the extra bass hits in the config."""
    lv = DIFFS.index(diff)
    if lv == 0:
        return []
    bars = song.cfg["drops"] if lv >= 2 else song.cfg["medium_drops"]
    win = song.cfg.get("drop_bass_window", 2)     # slots after the downbeat the bass may land in
    # a drop stomps when the bass lands with it, or the kick (or snare) comes back on its downbeat;
    # the bar after a build always does
    out = [b * 16 for b in bars if max(song.a["bass"][b * 16:b * 16 + win]) >= 0.6
           or song.drum(b * 16) >= 0.6 or song.kind.get(b - 1) == "build"]
    extra = song.cfg.get("bass_stomps" if lv >= 2 else "medium_bass_stomps", [])
    out += [round(b * 4) for b in extra]
    if song.cfg.get("auto_bass_stomps"):
        # the bass landing on a loud phrase's downbeat with the kick: a stomp, eight bars apart
        # (the song's heaviest downbeat basses: its top fifth, and at least 0.45)
        down = [max(song.a["bass"][b * 16:b * 16 + 4]) for b in range(song.bars) if song.kind.get(b) == "groove"]
        heavy = max(0.45, float(np.percentile(down, 80))) if down else 9
        for bar in range(song.bars):
            s0 = bar * 16
            if (bar % 4 == 0 and song.kind.get(bar) == "groove" and song.energy.get(bar, 1) >= 2
                    and max(song.a["bass"][s0:s0 + 4]) >= heavy and song.a["dl"][s0] >= 0.6
                    and all(abs(s0 - x) * song.spb / 4 >= STOMP_GAP[lv < 2] for x in out)):
                out.append(s0)
    return sorted(set(out))


def tilt_slots(song, diff, skip_bars=()):
    """Tilts on the pulse. Breaks: the bells answer the drums (Hard and Expert on beats 1 and 2,
    lower levels beat 1). Grooves: Expert on beats 1 and 3, Hard on 1 and 3 in loud bars and 1
    otherwise, Medium on beat 3, Easy none (it rings in the breaks)."""
    lv = DIFFS.index(diff)
    out = []
    for bar in range(song.bars):
        k = song.kind.get(bar)
        e = song.energy.get(bar, 1)
        s0 = bar * 16
        if s0 > song.end_slot - 4:
            break
        if k == "break":
            out += [s0, s0 + 4] if lv >= 2 else [s0]
        elif k in ("calm", "intro"):     # no drums: a bell on the phrase's downbeat
            if (lv >= 2 and bar % 2 == 0) or (lv == 1 and bar % 4 == 0):
                out.append(s0)
        elif k == "tension":
            out += [s0, s0 + 8] if lv >= 2 else [s0] if lv == 1 else []
        elif k in ("groove", "transition") and bar not in skip_bars:
            if lv == 3:
                out += [s0, s0 + 8] if e >= 2 or bar % 4 == 3 else [s0]    # beat 3 in loud bars and phrase ends
            elif lv == 2:     # a fast song's quieter bars tilt every other bar
                out += [s0, s0 + 8] if e >= 2 else [s0] if bar % 2 == 0 or song.spb * 4 >= 2.0 else []
            elif lv == 1:
                out += [s0]
    if lv == 0:
        extra = []
        for bar in range(0, song.bars, 2):
            s0 = bar * 16
            if song.kind.get(bar) == "groove" and all(abs(s0 - x) >= 32 for x in out + extra):
                extra.append(s0)
        out += extra
    # a tilt on silence reads as a mistake: it needs a drum, the bass or a tune note under it
    out = [t for t in out if t < song.n and (song.drum(t) >= 0.4 or song.a["bass"][t] >= 0.5
                                             or song.lead(t) >= ON or song.a["e"][t] > 0.5)]
    # the tune's pickup into a downbeat (the last sixteenth of the bar) keeps its note at Expert:
    # the downbeat tilt moves to beat 2 when the tune rests there
    if lv == 3:
        shifted = {t // 16 for t in out
                   if t % 16 == 0 and song.kind.get(t // 16) in ("groove", "transition") and song.lead(t - 1) >= 0.7
                   and song.lead(t) < ON and song.lead(t + 4) < ON and t + 4 not in out}
        out = [t + 4 if t // 16 in shifted and t % 16 in (0, 8) else t for t in out]   # the bar's tilts, a beat later
    # a tilt takes the same time at any tempo: keep them a few tenths of a second apart (a fast
    # song tilts on the downbeat only), breaks and downbeats first
    gap = TILT_GAP[diff] / song.spb * 4          # in slots
    order = sorted(set(out), key=lambda s: (song.kind.get(s // 16) != "break", s % 16 != 0, s))
    kept = []
    for s in order:
        brk = song.kind.get(s // 16) == "break"    # a break's answering pair stays, if not too quick
        g = gap
        if all(abs(s - x) >= (min(g, 0.4 / song.spb * 4) if brk and x // 16 == s // 16 else g) - 1e-6
               for x in kept):
            kept.append(s)
    return sorted(kept)


def build_chart(song, diff, reps):
    lv = DIFFS.index(diff)
    notes = {}            # slot -> list of note dicts
    prio = {}             # (slot, lane or 'b') -> priority for the repair pass

    # rhythm, one pattern per cluster of alike bars
    rhythm = []
    canon = {}
    for bar in range(song.bars):
        r = reps.get(bar, bar)
        if r not in canon:
            canon[r] = [s - r * 16 for s in pick_rhythm(song, diff, r)]
        rhythm += [bar * 16 + i for i in canon[r] if bar * 16 + i <= song.end_slot]

    stomps = stomp_slots(song, diff)

    # holds: (slot, lane, length in slots)
    holds = []
    if lv >= 1:
        for bar in song.drone:                      # the launeddas drone, left thumb
            if bar * 16 not in stomps:
                holds.append((bar * 16, 0, 14))
        for bar in song.seesaw:                     # the intro's bass: left on 1, right on 3
            holds.append((bar * 16, 0, 6))
            holds.append((bar * 16 + 8, 2, 6))
        for bar in song.cfg.get("pivot_holds", []):  # the note the tune keeps returning to
            s0 = bar * 16
            piv = max(set(song.a["pc"][s0:s0 + 16]), key=song.a["pc"][s0:s0 + 16].count)
            moves = [song.pitch(s) for s in range(s0, s0 + 16)
                     if song.a["pc"][s] != piv and song.lead(s) >= ON]
            pp = [song.pitch(s) for s in range(s0, s0 + 16) if song.a["pc"][s] == piv]
            up = sum(1 for p in moves if p > pp[0]) >= len(moves) / 2 if pp else True
            # from the pivot note's first sounding after beat 1 (the tilt), shorter as the level rises so
            # the free thumb gets more of the tune
            st = next((x for x in range(s0 + 2, s0 + 8) if song.a["pc"][x] == piv and song.lead(x) >= ON
                       and x % (1 if lv == 3 else 2) == 0), s0 + 4)
            holds.append((st, 0 if up else 2, {1: 8, 2: 6, 3: 4}[lv]))
        for a, c in song.cfg.get("tension_hold", []):  # through the stop, out into the drop
            holds.append((round(a * 4), 0, round((c - a) * 4)))
    hold_bars = {h[0] // 16 for h in holds}
    forced = {}
    hold_slots = {h[0] for h in holds}
    for s0, lane, ln in holds:
        for s in range(s0, s0 + ln + 1):
            forced[s] = tuple(x for x in (0, 1, 2) if x != lane)
    rhythm = [s for s in rhythm if s not in hold_slots]
    # one thumb under a hold: eighths at most at Expert and Hard, beats at Medium
    rhythm = [s for s in rhythm if s not in forced or s % (4 if lv == 1 else 2) == 0]

    # stomps: both thumbs rested an eighth before (the "& of 4" pickup stays at Hard and Expert)
    # and a beat after, so the thumbs can come back from the button
    before = 1 if lv >= 2 else 2
    rhythm = [s for s in rhythm if not any(0 < s - x < 4 or 0 < x - s <= before for x in stomps)]
    rhythm = [s for s in rhythm if s not in stomps]

    # tilts: a tilt owns its space, an eighth after it (and a sixteenth before at Expert)
    skip = ()
    tilts = tilt_slots(song, diff, skip)
    tilts = [t for t in tilts if t not in stomps and t not in hold_slots
             and not any(abs(t - x) < 4 for x in stomps)
             and not any(h[0] <= t <= h[0] + h[2] for h in holds)]   # a tilt needs both thumbs
    slot_s = song.spb / 4
    after = max(1, int(np.ceil(TILT_AFTER[diff] / slot_s - 1e-6)) - 1)
    before_t = max(1, int(np.ceil(TILT_BEFORE / slot_s - 1e-6)) - 1)
    def ring_here(t):   # a full ring on a strong tune note; Expert's loud bars and Hard's phrase starts ring more
        e = song.energy.get(t // 16, 1)
        th = 0.6 if lv == 3 else 0.7
        return song.lead(t) >= th
    keep_ring = {t for t in tilts if lv >= 2 and t in rhythm and ring_here(t)}
    rhythm = [s for s in rhythm if not any(0 < s - t <= after or 0 < t - s <= before_t for t in tilts)]
    rhythm = [s for s in rhythm if s not in tilts or s in keep_ring]
    if lv >= 2:      # Hard and Expert breaks: the bells alone on beats 1 and 2
        rhythm = [s for s in rhythm if not (song.kind.get(s // 16) == "break" and s % 16 < 8)]

    lane = lanes_for(song, diff, sorted(set(rhythm)), forced)
    for s0, ln_, _ in holds:
        rhythm = [x for x in rhythm if not (0 < s0 - x <= 2 and lane.get(x) == ln_)]
    # a repeated bar plays exactly like the first time
    for s in sorted(lane):
        r = reps.get(s // 16, s // 16)
        src = r * 16 + s % 16
        if r != s // 16 and src in lane and lane[src] in forced.get(s, (0, 1, 2)):
            lane[s] = lane[src]
    for s in rhythm:
        notes.setdefault(s, []).append({"k": "step", "lane": lane[s]})
        prio[(s, lane[s])] = song.score(s)
    for s0, ln_, ln in holds:
        notes.setdefault(s0, []).append({"k": "hold", "lane": ln_, "len": ln / 4})
        prio[(s0, ln_)] = 100
    for i, s in enumerate(stomps):
        ln_ = 1
        if lv == 3:   # Expert follows the rope to a side, unless the thumbs come from the other side
            want = (0, 2)[i % 2]
            prev = [x for x in rhythm if s - 4 <= x < s]
            if prev and lane.get(max(prev)) not in (want, 1):
                want = 1
            ln_ = want
        notes[s] = [{"k": "stomp", "lane": ln_}]
        prio[(s, ln_)] = 100
    for t in tilts:
        steps = [n for n in notes.get(t, []) if n["k"] == "step"]
        if steps:
            notes[t] = [{"k": "ring", "lane": steps[0]["lane"]}]
            prio[(t, steps[0]["lane"])] = 90
        else:
            notes[t] = [{"k": "bell"}]
        prio[(t, "b")] = 90

    # chords: two layers striking together (a bass hit or a drum under a tune note). Hard about one
    # every two bars; Expert up to one a beat in the loud bars and one every half bar elsewhere
    # (Daniele, 2026-10-15: "multi taps on expert")
    if lv >= 2:
        last = -99
        for s in sorted(notes):
            if s not in notes:          # taken by a chord beside it
                continue
            here = notes[s]
            e = song.energy.get(s // 16, 1)
            per = max(32 if lv == 2 else (4 if e >= 2 else 8),
                      round(CHORD_GAP[diff][min(e, 2) >= 2] / song.spb * 4))
            if len(here) != 1 or here[0]["k"] != "step" or s % 2 or s - last < per or e < 1:
                continue
            bass, drum = song.a["bass"][s], song.drum(s)
            if bass < 0.6 and not (lv == 3 and drum >= 0.7 and song.lead(s) >= ON):
                continue
            if s in forced:
                continue
            near = [x for x in notes if 0 < abs(x - s) * song.spb / 4 < 0.2]
            if near and lv == 3 and all(len(notes[x]) == 1 and notes[x][0]["k"] == "step" and x not in forced
                                        and x % 2 and song.score(x) < song.score(s) - 1.0 for x in near):
                for x in near:          # the chord wins over a weaker sixteenth beside it
                    del notes[x]
                near = []
            if near:
                continue
            other = 2 if here[0]["lane"] != 2 else 0
            here.append({"k": "step", "lane": other})
            prio[(s, other)] = song.score(s) - 0.5
            last = s

    # short holds on the tune's longer notes (Daniele, 2026-10-15: "hold notes that are shorter but
    # more frequent"): a tune note that rings on with no new note after it becomes a hold of half a
    # beat to a beat, on a side button, when nothing else needs that thumb meanwhile
    if lv >= 1:
        min_ring = {1: 4, 2: 3, 3: 2}[lv]
        max_per_bar = 3 if lv == 3 else 2
        per_bar = {}
        for s in sorted(notes):
            here = notes[s]
            if len(here) != 1 or here[0]["k"] != "step" or s in forced:
                continue
            if lv < 3 and s % 2:
                continue
            ring = 0
            while s + ring + 1 < song.n and song.a["pc"][s + ring + 1] == song.a["pc"][s] \
                    and song.lead(s + ring + 1) < 0.9 and song.a["e"][s + ring + 1] > 0.3:   # no fresh attack
                ring += 1
            # or a bass note that rings on under it
            bring = 0
            if song.a["bass"][s] >= 0.6:
                while s + bring + 1 < song.n and song.a["bass"][s + bring + 1] < 0.5 and bring < 7:
                    bring += 1
            if ring + 1 < min_ring and bring + 1 < min_ring + 1:
                continue
            # as long as the note rings, in eighths: half a beat up to a beat (two at Expert)
            ln = min(max(ring + 1, bring) // 2 * 2, 8 if lv == 3 else 4)
            if ln < 2:
                continue
            bar = s // 16
            if per_bar.get(bar, 0) >= max_per_bar:
                continue
            lane_ = here[0]["lane"]
            span = range(s + 1, s + ln + 2)
            if any(x in notes for x in span if any(n.get("lane") == lane_ or n["k"] in ("bell", "ring", "stomp")
                                                   for n in notes.get(x, []))):
                continue
            if any(x in tilts or x in stomps for x in span):
                continue
            # the free thumb plays eighths at most while the other holds
            others = sorted(x for x in range(s + 1, s + ln + 1) if x in notes)
            if any(b - a < 2 or (b - a) * song.spb / 4 < 0.25 for a, b in zip(others, others[1:])) \
                    or any(len(notes[x]) > 1 for x in others):
                continue
            here[0] = {"k": "hold", "lane": lane_, "len": ln / 4}
            prio[(s, lane_)] = 80
            per_bar[bar] = per_bar.get(bar, 0) + 1

    chart = []
    for s in sorted(notes):
        for nd in notes[s]:
            d = {"b": round(s / 4 + (song.swing if s % 2 else 0.0), 4), "k": nd["k"]}
            if "lane" in nd:
                d["lane"] = nd["lane"]
            if "len" in nd:
                d["len"] = nd["len"]
            chart.append(d)
    return repair(song, diff, chart, prio)


def repair(song, diff, chart, prio):
    """Drop the lowest-priority note named by each readability error until the chart is clean."""
    sd = {"bpm": song.cfg["bpm"], "offset": song.cfg["offset"], "length": song.cfg["length"],
          "kind": "story", "stop": 1, "sections": [], "swing": song.swing}
    for _ in range(400):
        errs, _ = V.check_chart(sd, diff, chart, None)
        errs = [e for e in errs if "peak" not in e]
        if not errs:
            return chart
        bs = [float(x) for x in re.findall(r"b=([0-9.]+)", errs[0])]
        if not bs:
            raise SystemExit(f"{diff}: can't repair {errs[0]}")
        cand = [n for n in chart if any(abs(n["b"] - b) < 1e-3 for b in bs) and n["k"] == "step"]
        if not cand:
            cand = [n for n in chart if any(abs(n["b"] - b) < 1e-3 for b in bs) and n["k"] in ("bell", "ring")]
            if not cand:
                held = [n for n in chart if n["k"] == "hold" and any(n["b"] < b + 1e-3 <= n["b"] + n["len"] + 1e-3 for b in bs)]
                if not held:
                    raise SystemExit(f"{diff}: can't repair {errs[0]}")
                held[0]["k"] = "step"      # the hold gives way: a plain step
                held[0].pop("len")
                continue
        worst = min(cand, key=lambda n: prio.get((round(n["b"] * 4), n.get("lane", "b")), 0))
        if worst["k"] == "ring":
            worst["k"] = "bell"
            worst.pop("lane")
        else:
            chart.remove(worst)
    raise SystemExit(f"{diff}: still failing {errs[:3]}")


# ------------------------------------------------------------------ output

NM = "C C# D D# E F F# G G# A A# B".split()


def grid_text(song, charts):
    sym = {"step": "LMR", "hold": "HHH", "ring": "!!!", "stomp": "SSS"}
    lines = []
    by = {d: {} for d in DIFFS}
    for d, ch in charts.items():
        for n in ch:
            s = round(n["b"] * 4)
            c = "T" if n["k"] == "bell" else sym[n["k"]][n.get("lane", 1)]
            if n["k"] == "ring":
                c = "!" + "LMR"[n["lane"]]
            if n["k"] == "hold":
                c = "H" + "LMR"[n["lane"]] + f"{n['len']:g}"
            if n["k"] == "stomp":
                c = "S" + "LMR"[n["lane"]]
            by[d].setdefault(s, []).append(c)
    for bar in range(song.bars):
        lo = bar * 16
        lines.append(f"bar {bar}  ({song.kind.get(bar, '?')}, energy {song.energy.get(bar, '?')})")
        def row(f):
            return "".join(f"{f(s):>5}" for s in range(lo, lo + 16))
        a = song.a
        lines.append("  drums " + row(lambda s: ("K" if s < song.n and a["dl"][s] >= .6 else "") +
                                         ("S" if s < song.n and a["dm"][s] >= .6 else "") +
                                         ("h" if s < song.n and a["dh"][s] >= .6 else "") or "."))
        lines.append("  bass  " + row(lambda s: "b" if s < song.n and a["bass"][s] >= .6 else "."))
        lines.append("  tune  " + row(lambda s: (NM[a["pc"][s]] + ("*" if a["on"][s] >= ON else ""))
                                       if s < song.n and (a["on"][s] >= ON or a["e"][s] > .3) else "."))
        for d in DIFFS[::-1]:
            lines.append(f"  {d[:3]:5} " + row(lambda s, d=d: "+".join(by[d].get(s, [])) or "."))
    return "\n".join(lines)


def main(argv):
    cfg = json.load(open(argv[1]))
    ana = json.load(open(cfg["analysis"]))
    song = Song(cfg, ana)
    reps = song.clusters()
    shared = sum(1 for b, r in reps.items() if b != r)
    print(f"  {len(set(reps.values()))} bar patterns, {shared} bars repeat an earlier one")
    charts = {d: build_chart(song, d, reps) for d in DIFFS}
    length = cfg["length"]
    for d in DIFFS:
        ch = charts[d]
        m = V.mechanics_of(ch)
        tilts = sum(1 for n in ch if n["k"] in ("bell", "ring"))
        _, avg, peak = V.nps_stats(ch, cfg["bpm"], cfg["offset"], 4.0)
        print(f"  {d:7} {len(ch):4d} notes  {avg:.2f}/s avg  {peak:.2f}/s peak  tilts {tilts / length * 60:4.1f}/min  "
              + " ".join(f"{k}:{v}" for k, v in sorted(m.items())))
    if "--grid" in argv:
        out = os.path.splitext(cfg["analysis"])[0] + "_grid.txt"
        open(out, "w").write(grid_text(song, charts))
        print("grid:", out)
    if "--write" in argv:
        p = os.path.join(ROOT, "game", "data", "songs", cfg["song"] + ".json")
        data = json.load(open(p))
        data["charts"] = charts
        with open(p, "w") as f:
            json.dump(data, f, indent=1, ensure_ascii=False)
            f.write("\n")
        print("wrote", p)


if __name__ == "__main__":
    main(sys.argv)
