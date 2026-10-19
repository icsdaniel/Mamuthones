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
    "easy": (0.5, 1.0, 1.15),
}
# the least time between two tilts, and between two Expert chords (loud bars, other bars), in seconds:
# a fast song tilts and chords less often per beat
TILT_GAP = {"expert": 0.85, "hard": 1.0, "medium": 1.9, "easy": 4.0}
CHORD_GAP = {"expert": (1.4, 0.7), "hard": (2.5, 2.5)}
# the room a tilt keeps clear, in seconds: before it, and after it (Expert, other levels)
# (a bell with no tap of its own keeps a little more before it at Expert: BELL_BEFORE)
TILT_BEFORE = {"expert": 0.2, "hard": 0.2, "medium": 0.25, "easy": 0.5}
TILT_AFTER = {"expert": 0.22, "hard": 0.28, "medium": 0.28, "easy": 0.8}
BELL_BEFORE = 0.2
# the least time between two stomps (Hard and Expert, Medium)
STOMP_GAP = (8.0, 12.0)
EASY_TILT_S = 4.0   # Easy rings about this often in the grooves
ON = 0.5          # a lead onset counts from this strength
SIXTEENTH_ON = 0.4


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

    def same_rhythm(self, x, y):
        """Two bars with the same tune rhythm and the same kick and snare (15 of 16 sixteenths)."""
        if (y + 1) * 16 > self.n or (x + 1) * 16 > self.n:
            return False
        a = self.a
        def sig(b, i):
            s = b * 16 + i
            return (a["on"][s] >= ON, a["dl"][s] >= 0.6, a["dm"][s] >= 0.6)
        return sum(sig(x, i) == sig(y, i) for i in range(16)) >= 14

    def clusters(self):
        """Bar -> the earlier bar it repeats (itself if none): same kind of bar, and the same pitch
        class on at least three quarters of its sixteenths, or the same rhythm with half the pitches."""
        rep, seen = {}, []
        drops = set(self.cfg.get("drops", [])) | set(self.cfg.get("hit_bars", []))   # (a drum-hit bar too)
        for bar in range(self.bars):
            rep[bar] = bar
            if bar in drops:            # a drop is charted on its own
                seen.append(bar)
                continue
            for other in seen:
                if other in drops:
                    continue
                if self.kind.get(other) == self.kind.get(bar) and (
                        self.alike(bar, other) >= 0.75 or (self.alike(bar, other) >= 0.4 and self.same_rhythm(bar, other))):
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
            # the tune's eighths (softer ones too), the beat, and the bass's own eighths
            ok = i % 2 == 0 and (lead >= 0.4 or (i % 4 == 0 and drum >= 0.6) or drum >= 0.8
                                 or song.a["bass"][s] >= 0.6 or kind == "build")
        elif diff == "medium":
            # the beat, plus the tune's eighths (its "& of 4" pickup above all)
            ok = (i % 4 == 0 and (lead >= ON or drum >= 0.6 or kind == "build")) or \
                 (i % 2 == 0 and lead >= 0.6 and e >= 1) or \
                 (i % 2 == 0 and kind == "build" and song.kind.get(bar - 1) == "build")   # a build speeds up
        else:
            step = 4 if song.spb >= 0.75 else 8       # a slow song's Easy plays on the beat
            ok = i % step == 0 and (lead >= ON or drum >= 0.5 or e == 0)
            # the tune rests on the beat but sounds an eighth later: Easy plays the tune note
            # (not over a four-on-the-floor kick: there Easy keeps the kick)
            if step == 8 and i % 8 == 2 and lead >= 0.6 and song.lead(s - 2) < ON \
                    and not (song.cfg.get("four_on_floor") and song.a["dl"][s - 2] >= 0.6):
                ok = True
                cands = [c for c in cands if c != s - 2]
            # a quick song's Easy also takes the tune's notes on slots 6 and 14 (the & of 2 and the
            # pickup into the next bar) when the tune rests on the beat after; the 0.6 s gap then keeps
            # the stronger of each close pair
            if step == 8 and i in (6, 14) and lead >= 0.6 and kind != "build" and song.lead(s + 2) < ON:
                ok = True
        if ok:
            cands.append(s)
    if bar in song.cfg.get("hit_bars", []) and diff != "easy":
        # a drum-hit bar (the band stabs together): the taps go on the kicks and snares, not the tune
        # (Expert the kicks and snares, Hard the kicks on the eighth grid, Medium the beats and the
        # last kick)
        kicks = [s for s in range(lo, hi) if song.a["dl"][s] >= 0.6]
        if diff == "expert":
            hits = sorted(set(kicks) | {s for s in range(lo, hi) if song.a["dm"][s] >= 0.6})
        elif diff == "hard":       # an off-beat kick moves to the eighth before
            hits = sorted({s - s % 2 for s in kicks})
        else:
            hits = sorted({s for s in range(lo, hi, 4) if song.drum(s) >= 0.4} | {s - s % 2 for s in kicks[-1:]})
        return hits, len(hits)
    target = TARGET[diff][e] * song.spb * 4         # notes in this bar
    if kind == "build":
        target = {"expert": 16, "hard": 8, "medium": 8 if song.kind.get(bar - 1) == "build" else 4, "easy": 2}[diff]

    def sc(s):   # the "& of 4" pushes into the next bar: keep it
        bonus = (3.0 if diff == "medium" else 1.0) if s % 16 == 14 and song.lead(s) >= ON else 0.0
        if diff == "easy" and s % 8 == 2 and song.lead(s - 2) < ON:
            bonus += 2.0        # Easy's tune note an eighth after a resting beat comes before an added pickup
        if diff == "easy" and s % 8 == 0:
            bonus += 1.0        # and the beat itself before either
        return song.score(s) + bonus
    ranked = sorted(cands, key=lambda s: -sc(s))
    if diff == "easy":      # Easy keeps the strongest notes 0.6 s apart (into the next bar too)
        g = 0.6 / (song.spb / 4) - 1e-6
        kept = []
        for x in ranked:
            if all(abs(x - y) >= g for y in kept) and (x % 16 < 16 - g or song.lead(lo + 16) < ON):
                kept.append(x)
        return kept, max(1, min(len(kept), int(np.ceil(target - 0.25))))
    return ranked, max(1, round(target))


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
        lane_of = phrase_lanes(tuned)
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
    # the buttons follow the tune's shape inside a run: a rising note never sits left of the note
    # before it, a falling one never right of it, and a repeated pitch keeps its button
    order = sorted(out)
    slot_s = song.spb / 4
    for a, b in zip(order, order[1:]):
        if b - a > 2 or song.lead(a) < ON or song.lead(b) < ON or song.kind.get(b // 16) == "build":
            continue
        pa, pb = song.pitch(a), song.pitch(b)
        la, lb = out[a], out[b]
        allow = forced.get(b, (0, 1, 2))
        if pb == pa:     # (a quick repeat below Expert trades with the middle button, not across)
            gap_ok = (b - a) * slot_s >= (0.2 if diff == "expert" else 0.3)
            want = la if gap_ok else (1 if la != 1 else lb) if diff != "expert" else lb
        elif (pb > pa) != (lb > la) or lb == la:
            want = min(2, la + 1) if pb > pa else max(0, la - 1)
            if want == la and (b - a) * slot_s < 0.2:
                want = lb
        else:
            continue
        if want in allow:
            out[b] = want
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
        heavy = max(0.45, float(np.percentile(down, 60))) if down else 9
        for bar in range(song.bars):
            s0 = bar * 16
            if (bar % 4 == 0 and song.kind.get(bar) == "groove" and song.energy.get(bar, 1) >= 2
                    and (max(song.a["bass"][s0:s0 + 4]) >= heavy or song.cfg.get("four_on_floor"))
                    and song.a["dl"][s0] >= 0.6
                    and all(abs(s0 - x) * song.spb / 4 >= STOMP_GAP[lv < 2] for x in out)):
                out.append(s0)
    # the song's last hit
    # (the last kick or snare at or before the end, on any sixteenth)
    end = [b for b, k in song.kind.items() if k == "ending"]
    if end:
        lo = min(end) * 16
        hits = [x for x in range(lo, min(song.end_slot + 1, song.n)) if (song.a["dl"][x] >= 0.6 or song.a["dm"][x] >= 0.6)
                and (lv == 3 or x % 2 == 0)]     # below Expert on the eighth grid
        if hits:
            # (a drop stomp within a beat before the last hit gives way to it)
            out = [x for x in out if x < hits[-1] - 4] + [hits[-1]]
        elif song.drum(lo) >= 0.5:
            out.append(lo)
    # the bass coming back after two bars or more without it (Medium and up)
    bass_on = [max(song.a["bass"][b * 16:b * 16 + 16]) >= 0.6 for b in range(song.bars)]
    for bar in range(2, song.bars):
        s0 = bar * 16
        if bass_on[bar] and not bass_on[bar - 1] and not bass_on[bar - 2] and song.a["bass"][s0] >= 0.6 \
                and song.kind.get(bar) in ("groove", "transition") \
                and all(abs(s0 - x) * song.spb / 4 >= 8.0 for x in out):
            out.append(s0)
    return sorted(set(out))


def tilt_slots(song, diff, skip_bars=()):
    """Tilts on the pulse. Breaks: the bells answer the drums (Hard and Expert on beats 1 and 2,
    lower levels beat 1). Grooves: Expert on beats 1 and 3, Hard on 1 and 3 in loud bars and 1
    otherwise, Medium on beat 3, Easy none (it rings in the breaks)."""
    lv = DIFFS.index(diff)
    out = []
    stomp_bars = {x - x % 16 for x in stomp_slots(song, diff)}
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
        elif k in ("groove", "transition") and bar in song.cfg.get("hit_bars", []):
            out.append(s0)          # a drum-hit bar rings its downbeat only: the hits are taps
        elif k in ("groove", "transition") and bar not in skip_bars:
            if lv == 3:
                # beat 3 in loud bars, phrase ends, and every bar of a slow song (a bar of 3 s or more)
                # (in loud bars every other bar, so the hands get bars of taps between)
                b3 = (e >= 2 and bar % 2 == 1) or bar % 4 == 3 or song.spb * 4 >= 3.0
                out += [s0, s0 + 8] if b3 else [s0]
            elif lv == 2:     # quieter bars tilt every other bar, unless the bar is long
                # (a slow song's Hard is made harder with bells, chords and holds, not sixteenths:
                # Daniele, 2026-10-16) beat 3 too every other bar
                slow = song.spb * 4 >= 3.0
                # (loud bars: beat 3 every other bar, on the bars where Expert has it too)
                out += [s0, s0 + 8] if (e >= 2 or slow) and bar % 2 else [s0] if bar % 2 == 0 or e >= 2 or song.spb * 4 >= 2.4 else []
            elif lv == 1:     # every other bar, counted from the last bar that rang (a stomp bar can't);
                # every bar when loud or the bar is long
                # (on Hard's bars: the even ones, or the bar after a stomp bar that couldn't ring)
                if s0 not in stomp_bars and (song.spb * 4 >= 2.5 or e >= 2 or bar % 2 == 0
                                             or (s0 - 16 in stomp_bars and not any(x == s0 - 16 for x in out))):
                    out += [s0]
    if lv == 0:
        extra = []
        # Easy rings every 4 bars in the grooves, every 2 when the bar is long, some 6.5 s apart
        every = 2 if song.spb * 4 >= 2.0 else 4
        gap_e = EASY_TILT_S / song.spb * 4
        for bar in range(0, song.bars, every):
            s0 = bar * 16
            if song.kind.get(bar) == "groove" and all(abs(s0 - x) >= gap_e for x in out + extra):
                extra.append(s0)
        for bar in song.cfg.get("drops", []):        # and on every drop that stomps above
            s0 = bar * 16
            if all(abs(s0 - x) >= gap_e / 2 for x in out + extra):
                extra.append(s0)
        out += extra
    # a tilt on silence reads as a mistake: it needs a drum, the bass or a tune note under it
    out = [t for t in out if t < song.n and (song.drum(t) >= 0.4 or song.a["bass"][t] >= 0.5
                                             or song.lead(t) >= ON or song.a["e"][t] > 0.5)]
    # the tune's pickup into a downbeat (the last sixteenth of the bar) keeps its note at Expert:
    # the downbeat tilt moves to beat 2 when the tune rests there
    # (decided per 8 bars, the same at every level, so the bell keeps its place in a riff)
    if lv >= 1:
        shifted = set()
        for blk in range(0, song.bars, 8):        # decided per 8 bars, so the bell doesn't flip each phrase
            gro = [b for b in range(blk, blk + 8) if song.kind.get(b) in ("groove", "transition")]
            hits = [b for b in gro if song.lead(b * 16 - 1) >= 0.7 and song.lead(b * 16 + 4) < ON]
            if gro and len(hits) * 2 > len(gro):
                shifted |= set(gro)
        out = [t + 4 if t // 16 in shifted and t % 16 in (0, 8) else t for t in out]   # the bar's tilts, a beat later
    if lv == 3 and not song.cfg.get("four_on_floor"):
        # the tune's two-note pickup into a downbeat where the tune rests keeps its notes at Expert: the
        # bell moves to beat 2. Decided per 8 bars (a riff keeps its bell in place), only in phrases where
        # most bars have a real pickup, never in stomp bars, and only onto a drum or the bass
        def pickup(s0):
            three = song.lead(s0 - 3) >= ON and song.lead(s0 - 4) < ON and song.lead(s0 - 5) < ON   # A-B-A
            return (song.spb / 4 < 0.2 and song.lead(s0 - 1) >= 0.6 and song.lead(s0 - 2) >= 0.6
                    and (three or (song.lead(s0 - 3) < ON and song.lead(s0 - 4) < ON)) and song.lead(s0) < ON
                    and sum(song.lead(x) >= ON for x in range(s0 - 16, s0)) < 12)
        shift = set()
        for blk in range(0, song.bars, 8):
            gro = [b for b in range(blk, blk + 8) if song.kind.get(b) in ("groove", "transition")
                   and b * 16 not in stomp_bars]
            hits = [b for b in gro if pickup(b * 16)]
            if gro and len(hits) * 2 >= len(gro):
                shift |= set(hits)
        moved = []
        for t in out:
            b = t // 16
            if t % 16 == 0 and b in shift and song.lead(t + 4) < ON and (song.drum(t + 4) >= 0.4 or song.a["bass"][t + 4] >= 0.5):
                moved.append(t + 4)
            else:
                moved.append(t)
        out = moved
    out = [t for t in out if t * song.spb / 4 >= 1.5]       # never a tilt as the song's first sound
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


def build_chart(song, diff, reps, hold_floor=0):
    lv = DIFFS.index(diff)
    notes = {}            # slot -> list of note dicts
    prio = {}             # (slot, lane or 'b') -> priority for the repair pass

    # rhythm, one pattern per cluster of alike bars
    # each bar's candidates, best first, and how many it keeps; the taps are chosen after the tilts,
    # stomps and holds have taken their room, so a bar is refilled to its density
    ranked = {}
    canon = {}
    for bar in range(song.bars):
        r = reps.get(bar, bar)
        if r not in canon:
            cands, target = pick_rhythm(song, diff, r)
            canon[r] = ([s - r * 16 for s in cands], target)
        cs = []
        for i in canon[r][0]:
            x = bar * 16 + i
            if x > song.end_slot:
                continue
            # a copied tap that lands on a note still ringing moves to the tune's onset next to it
            # (on the eighth grid below Expert), or is left out
            if r != bar and song.lead(r * 16 + i) >= ON and song.lead(x) < ON and song.kind.get(bar) != "build":
                near = [y for y in (x + 1, x - 1) if song.lead(y) >= ON and y // 16 == bar and (lv == 3 or y % 2 == 0)]
                if not near:
                    if song.energy.get(bar, 1) >= 2:
                        cs.append(x) if x not in cs else None     # a loud bar keeps its density
                    continue
                x = near[0]
            if x not in cs:
                cs.append(x)
        ranked[bar] = (cs, canon[r][1])
    rhythm = [s for bar in ranked for s in ranked[bar][0]]      # every candidate, pruned below

    stomps = stomp_slots(song, diff)

    # holds: (slot, lane, length in slots)
    holds = []
    tilts0 = tilt_slots(song, diff)
    if lv >= 1:
        for bar in song.drone:                      # the launeddas drone, left thumb (after a stomp, from beat 2)
            holds.append((bar * 16, 0, 14) if bar * 16 not in stomps else (bar * 16 + 4, 0, 10))
        for bar in song.seesaw:                     # the intro's bass: left on 1, right on 3
            holds.append((bar * 16, 0, 6))
            holds.append((bar * 16 + 8, 2, 6))
        clear = max(2, int(np.ceil(TILT_AFTER[diff] / (song.spb / 4) - 1e-6)))
        for bar in song.cfg.get("pivot_holds", []):  # the note the tune keeps returning to
            if song.kind.get(bar) == "build":
                continue
            s0 = bar * 16
            piv = max(set(song.a["pc"][s0:s0 + 16]), key=song.a["pc"][s0:s0 + 16].count)
            moves = [song.pitch(s) for s in range(s0, s0 + 16)
                     if song.a["pc"][s] != piv and song.lead(s) >= ON]
            pp = [song.pitch(s) for s in range(s0, s0 + 16) if song.a["pc"][s] == piv]
            up = sum(1 for p in moves if p > pp[0]) >= len(moves) / 2 if pp else True
            # from the pivot note's first sounding after beat 1 (the tilt), shorter as the level rises so
            # the free thumb gets more of the tune
            first = max([t for t in tilts0 if s0 <= t < s0 + 8], default=s0)
            st = next((x for x in range(first + clear, s0 + 8) if song.a["pc"][x] == piv and song.lead(x) >= ON
                       and x % (1 if lv == 3 else 2) == 0), first + max(4, clear))
            holds.append((st, 0 if up else 2, {1: 8, 2: 6, 3: 4}[lv]))
        for a, c in song.cfg.get("tension_hold", []):  # through the stop, out into the drop
            st = round(a * 4)
            if lv < 3:
                st -= st % 2
            holds.append((st, 0, round(c * 4) - st))
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
    ends = [x for x in stomps if song.kind.get(x // 16) == "ending"]
    if ends:          # the last stomp is the song's last input
        rhythm = [s for s in rhythm if s < max(ends)]

    # tilts: a tilt owns its space, an eighth after it (and a sixteenth before at Expert)
    skip = ()
    tilts = tilt_slots(song, diff, skip)
    tilts = [t for t in tilts if t not in stomps and t not in hold_slots
             and not any(abs(t - x) < 4 for x in stomps)
             and not any(h[0] <= t <= h[0] + h[2] for h in holds)]   # a tilt needs both thumbs
    slot_s = song.spb / 4
    after = max(1, int(np.ceil(TILT_AFTER[diff] / slot_s - 1e-6)) - 1)
    before_t = max(1, int(np.ceil(TILT_BEFORE[diff] / slot_s - 1e-6)) - 1)
    bell_before = max(1, int(np.ceil(BELL_BEFORE / slot_s - 1e-6)) - 1) if lv == 3 else before_t
    def ring_here(t):   # a full ring on a strong tune note
        return song.lead(t) >= 0.6
    keep_ring = {t for t in tilts if lv >= 2 and t in rhythm and ring_here(t)}
    rhythm = [s for s in rhythm if not any(0 < s - t <= after or 0 < t - s <= (before_t if t in keep_ring else bell_before)
                                           for t in tilts)]
    rhythm = [s for s in rhythm if s not in tilts or s in keep_ring]
    if lv >= 2:      # Hard and Expert breaks: the bells alone on beats 1 and 2
        rhythm = [s for s in rhythm if not (song.kind.get(s // 16) == "break" and s % 16 < 8)]
    # each bar keeps its best remaining candidates up to its density (a ring counts as one)
    free = set(rhythm)
    rhythm = []
    for bar, (cands, target) in ranked.items():
        rings = sum(1 for t in keep_ring if t // 16 == bar)
        rhythm += [s for s in cands if s in free][:max(rings, target)]
    keep_ring = {t for t in keep_ring if t in rhythm}

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
        if lv == 3 and song.kind.get(s // 16) == "ending":   # the last stomp swings to a side
            prev = [x for x in rhythm if s - 4 <= x < s]
            ln_ = 2 if prev and lane.get(max(prev)) == 2 else 0
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

    # short holds on the tune's longer notes (Daniele, 2026-10-15: "hold notes that are shorter but
    # more frequent"): a tune note that rings on with no new note after it becomes a hold of half a
    # beat to a beat, when nothing else needs that thumb meanwhile. Made before the chords, so a hold
    # keeps its thumb; Hard and Expert hold at least as often as the level below
    held = [(h[0], h[0] + h[2]) for h in holds]
    held_lane = [h[1] for h in holds]
    handed = set()          # holds handed to the other thumb: the contour pass leaves them there

    def short_holds(min_ring, max_per_bar, min_s, limit=10 ** 6, reattack=False):
        made = 0
        per_bar = {}
        for a, b in held:
            per_bar[a // 16] = per_bar.get(a // 16, 0) + 1
        for s in sorted(notes, key=lambda x: -song.score(x) if limit < 10 ** 6 else x):
            if made >= limit:
                break
            if s not in notes:          # gave way to a hold before it
                continue
            here = notes[s]
            if len(here) != 1 or here[0]["k"] != "step" or s in forced:
                continue
            if lv < 3 and s % 2:
                continue
            # a new tune note (or, on the eighth grid, a note that began a sixteenth before: a swung
            # song's long notes start late), not in a roll
            fresh = song.lead(s) >= ON or (lv < 3 and song.lead(s - 1) >= ON and song.a["pc"][s - 1] == song.a["pc"][s]
                                           and song.a["e"][s] > 0.3)
            if not fresh or song.kind.get(s // 16) == "build" or s // 16 in song.cfg.get("hit_bars", []):
                continue
            if lv == 1 and (s in stomps or (s % 16 == 0 and song.energy.get(s // 16, 1) >= 2)):
                continue
            ring = 0
            while s + ring + 1 < song.n and song.a["pc"][s + ring + 1] == song.a["pc"][s] \
                    and song.lead(s + ring + 1) < (1.01 if reattack else 0.7 if lv == 3 else 0.9) and song.a["e"][s + ring + 1] > 0.3:   # no fresh attack
                ring += 1
            # or a bass note that rings on under it
            bring = 0
            if song.a["bass"][s] >= 0.6:
                while s + bring + 1 < song.n and song.a["bass"][s + bring + 1] < 0.5 and bring < 7:
                    bring += 1
            if ring + 1 < min_ring and bring + 1 < min_ring + 1:
                continue
            # as long as the note rings, in eighths: half a beat up to a beat (two at Expert)
            ln = min(max(ring + 1, bring) // 2 * 2, 8 if lv == 3 and song.spb * 4 < 3.0 else 4)
            if lv == 3 and slot_s * 2 < 0.3 and ln == 2 and max(ring + 1, bring) >= 3:
                ln = 3      # Expert, a quick song: three sixteenths, so a short hold still reads as held
            if ln < 2 or ln * song.spb / 4 < min_s - 1e-6:      # shorter reads as a tap with a tail
                continue
            if any(a <= s + ln + 1 and s <= b + 1 for a, b in held):     # one thumb holds at a time
                continue
            bar = s // 16
            if per_bar.get(bar, 0) >= max_per_bar:
                continue
            lane_ = orig_lane = here[0]["lane"]
            # no press on the held button just before the hold starts (0.3 s) or just after it ends
            # (0.2 s): the hold takes another button, or isn't made
            def near_lanes():
                out = set()
                for x in notes:
                    dt = (s - x) * slot_s
                    de = (x - s - ln) * slot_s
                    if (0 < dt < 0.3) or (0 < de < 0.2 - 1e-6):
                        out |= {n.get("lane") for n in notes[x]}
                return out
            busy = near_lanes()
            # the thumbs take turns holding: a new hold goes to the side that has held less in the last
            # 8 bars, if that button is free and the tune's shape allows it (it moves the way the tune
            # moves from the note before); against the shape only when one side has held three more
            recent = [l for (a, _), l in zip(held, held_lane) if s - 128 <= a < s]
            if lane_ != 1 and s not in forced:
                opp = 2 - lane_
                prev = max((x for x in notes if s - 8 <= x < s and any("lane" in n for n in notes[x])), default=None)
                fits_shape = prev is None or song.pitch(prev) == song.pitch(s) or \
                    (opp > max(n.get("lane", 1) for n in notes[prev])) == (song.pitch(s) > song.pitch(prev))
                if recent.count(lane_) - recent.count(opp) >= (1 if fits_shape else 3) and opp not in busy:
                    lane_ = opp      # (the tap keeps its button if the hold isn't made)
            if lane_ in busy:      # (to the side that has held less)
                alt = sorted((l for l in (0, 2, 1) if l not in busy), key=lambda l: (l == 1, recent.count(l)))
                if not alt:
                    continue
                lane_ = alt[0]
                here[0]["lane"] = lane_
            span = range(s + 1, s + ln + 2)
            if any(x in tilts or x in stomps for x in span):
                continue
            clash = [x for x in span if x in notes and any(n.get("lane") == lane_ or n["k"] in ("bell", "ring", "stomp", "hold")
                                                           for n in notes[x])]
            # weaker taps on the held button inside the hold give way to it (a hold over a repeated
            # note): two at Expert, one at Hard
            if clash and not (lv >= 1 and len(clash) <= (2 if lv == 3 else 1) and all(
                    len(notes[x]) == 1 and notes[x][0]["k"] == "step" and x not in forced
                    and song.score(x) < song.score(s) for x in clash)):
                continue
            # the free thumb plays eighths at most while the other holds: at Expert a weak sixteenth
            # under the hold gives way
            others = sorted(x for x in range(s + 1, s + ln + 1) if x in notes and x not in clash)
            drop = list(clash)
            if lv == 1 and drop and sum(1 for x in notes if x // 16 == bar) - len(drop) < 4:
                continue      # a Medium bar keeps four events at least
            if any((b - a) * song.spb / 4 < 0.2 or (b - a < 2 and song.spb / 4 < 0.2) for a, b in zip(others, others[1:])) \
                    or any(len(notes[x]) > 1 for x in others):
                continue
            for x in drop:
                del notes[x]
            here[0] = {"k": "hold", "lane": lane_, "len": ln / 4}
            held.append((s, s + ln))
            held_lane.append(lane_)
            if lane_ != orig_lane:
                handed.add(s)
            prio[(s, lane_)] = 80
            per_bar[bar] = per_bar.get(bar, 0) + 1
            made += 1
        return made

    if lv >= 1:
        n_holds = len(holds)
        if lv == 1:      # Medium: one hold a bar at most, from about a third of a second, a third of the bars
            n_holds += short_holds(3, 1, 0.3)
            if n_holds < 0.35 * song.bars:
                n_holds += short_holds(2, 1, 0.25, round(0.35 * song.bars - n_holds))   # half a beat, up to 120 BPM
            if n_holds < 0.35 * song.bars:    # then over the same note struck again (a pivot note re-attacked)
                n_holds += short_holds(3, 1, 0.3, round(0.35 * song.bars - n_holds), reattack=True)
        else:
            # long enough to feel held first (Hard 0.4 s, Expert 0.3 s); shorter ones only when the
            # level would hold less than it should (Expert half as often again as Hard)
            n_holds += short_holds(3, 2, 0.4 if lv == 2 else 0.3)
            for mr, mb, ms in ((3, 2, max(0.25, 2 * slot_s)), (2, 2, max(0.2, 2 * slot_s)), (2, 3, max(0.2, 2 * slot_s))):
                if n_holds < hold_floor and (lv == 3 or mb == 2):
                    n_holds += short_holds(mr, mb, ms, round(hold_floor - n_holds))
            # a slow song's sixteenth runs: a note struck twice on one button becomes a half-beat hold
            if n_holds < hold_floor and song.spb * 4 >= 3.0:
                n_holds += short_holds(2, 2, 0.4, round(hold_floor - n_holds), reattack=True)

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
            slow = song.spb * 4 >= 3.0          # a slow song's Hard chords about once a bar
            per = max((8 if slow else 32) if lv == 2 else (4 if e >= 2 else 8),
                      round(CHORD_GAP[diff][min(e, 2) >= 2] / song.spb * 4))
            if len(here) != 1 or here[0]["k"] != "step" or s % 2 or s - last < per or e < 1:
                continue
            if lv == 3 and e >= 2 and (s // 16) % 2 and not slow:    # loud bars alternate: chords, then a sixteenth stream
                continue
            bass, drum = song.a["bass"][s], song.drum(s)
            if bass < 0.6 and not ((lv == 3 or slow) and drum >= 0.7 and song.lead(s) >= ON):
                continue
            if s in forced or any(a <= s <= b for a, b in held):
                continue
            near = [x for x in notes if 0 < abs(x - s) * song.spb / 4 < 0.2]
            if near and lv == 3 and all(len(notes[x]) == 1 and notes[x][0]["k"] == "step" and x not in forced
                                        and not any(a <= x <= b for a, b in held)
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

    # a two-note trill (the tune alternating two pitches every sixteenth, as the analysis hears it)
    # alternates two buttons side by side: at Expert by pitch (the lower note left of the higher),
    # below note by note, as the kept notes may all land on one of the two pitches
    pc, n_ = song.a["pc"], song.n
    trill_slots = set()
    s_ = 0
    while s_ < n_ - 2:
        j = s_
        while j + 1 < n_ and pc[j + 1] != pc[j] and (j == s_ or pc[j + 1] == pc[j - 1]) and song.a["e"][j + 1] > 0.3:
            j += 1
        if j - s_ + 1 >= 6 and song.kind.get(s_ // 16) != "build":
            trill_slots.update(range(s_, j + 1))
            run = [x for x in sorted(notes) if s_ <= x <= j and len(notes[x]) == 1 and notes[x][0]["k"] == "step"]
            if len(run) >= 3:
                lo_pc = pc[s_] if song.pitch(s_) <= song.pitch(s_ + 1) else pc[s_ + 1]
                low = min(notes[run[0]][0]["lane"], 1)
                for k_, x in enumerate(run):
                    share = sum(1 for y in run if pc[y] == lo_pc) / len(run)
                    # (by pitch only where this half bar keeps both notes, or it is one button over and over)
                    half = [y for y in run if y // 8 == x // 8]
                    both = 0.25 <= share <= 0.75 and len({pc[y] for y in half}) > 1
                    new_ = (low if pc[x] == lo_pc else low + 1) if lv == 3 and both else low + k_ % 2
                    if x not in forced or new_ in forced[x]:
                        notes[x][0]["lane"] = new_
        s_ = max(j, s_ + 1)
    # the buttons follow the tune's shape (again, after the passes above moved some)
    if lv >= 1:
        order = sorted(x for x in notes if any(n["k"] in ("step", "ring", "hold") for n in notes[x]))
        def lane_at(x):
            ns = [n for n in notes[x] if "lane" in n]
            return max(n["lane"] for n in ns) if ns else None
        def same_run(x, lane):     # presses in a row on this button, ending at x
            k = 0
            for y in reversed([y for y in order if y <= x]):
                if lane_at(y) != lane:
                    break
                k += 1
            return k
        for a_, b_ in zip(order, order[1:]):
            if b_ - a_ > 2 or song.lead(a_) < ON or song.lead(b_) < ON or song.kind.get(b_ // 16) == "build":
                continue
            st = [n for n in notes[b_] if n["k"] in ("step", "hold")]
            if len(notes[b_]) != 1 or not st or b_ in forced or b_ in handed:
                continue
            if st[0]["k"] == "hold":     # a hold moves only to a button nothing presses while it's down
                end = b_ + st[0]["len"] * 4
                near = {n.get("lane") for y in notes if y != b_ and b_ - 0.3 / slot_s <= y <= end + 0.3 / slot_s
                        for n in notes[y]}
            else:
                near = set()
            pa, pb = song.pitch(a_), song.pitch(b_)
            la, lb = lane_at(a_), st[0]["lane"]
            if song.a["pc"][a_] == song.a["pc"][b_] and la is not None and st[0]["k"] == "step" and lb != la \
                    and (b_ - a_) * slot_s >= (0.2 if lv == 3 else 0.3) - 1e-6 and len(notes[a_]) == 1 \
                    and b_ not in trill_slots and same_run(a_, la) < 3:
                st[0]["lane"] = la      # a repeated note keeps its button (the jack pass below has the last word)
                continue
            if pa == pb or la is None or ((pb > pa) == (lb > la) and lb != la):
                continue
            want = min(2, la + 1) if pb > pa else max(0, la - 1)
            if want != la and want not in near:
                st[0]["lane"] = want
    # over a four-on-the-floor kick, Medium and Hard never leave beat 2 empty after the downbeat
    if lv in (1, 2) and song.cfg.get("four_on_floor"):
        for bar in range(song.bars):
            s0 = bar * 16
            if song.kind.get(bar) not in ("groove", "transition") or s0 not in notes or song.drum(s0 + 4) < 0.6:
                continue
            if any(x in notes for x in range(s0 + 1, s0 + 8)) or any(a <= s0 + 4 <= b for a, b in held):
                continue
            used = {n.get("lane") for x in (s0, s0 + 8) if x in notes for n in notes[x]}
            lane = next((l for l in (1, 0, 2) if l not in used), 1)
            notes[s0 + 4] = [{"k": "step", "lane": lane}]
            prio[(s0 + 4, lane)] = 40
    # a build's snare roll is a two-thumb roll: left and right in turn (Hard and Expert)
    if lv >= 2:
        side = 0
        for x in sorted(notes):
            if song.kind.get(x // 16) != "build" or x in forced:
                continue
            st = [n for n in notes[x] if n["k"] == "step"]
            if len(st) == 1 and len(notes[x]) == 1:
                st[0]["lane"] = side
                side = 2 - side
    # twin half bars (the same pitches and the same tune and drum rhythm on seven of eight sixteenths)
    # play like the first time: the same taps (up to two added, one swapped) on the same buttons, so
    # a riff and its answer read alike. Tilts, stomps, holds and chords keep their places
    hits_ = set(song.cfg.get("hit_bars", []))
    def sig_at(s):
        return (pc[s], song.lead(s) >= ON, song.drum(s) >= 0.6)
    def plain(x):          # a single tap the pass may move or copy
        return x in notes and len(notes[x]) == 1 and notes[x][0]["k"] == "step"
    def held_at(x):
        return x in forced or any(a <= x <= b for a, b in held)
    firsts = []
    for h in range(min(song.n, song.end_slot + 1) // 8):
        bar = h // 2
        if song.kind.get(bar) in ("build", "break") or bar in hits_:
            continue
        src = next((g for g in firsts if song.kind.get(g // 2) == song.kind.get(bar)
                    and sum(sig_at(g * 8 + i) == sig_at(h * 8 + i) for i in range(8)) >= 7), None)
        if src is None:
            firsts.append(h)
            continue
        # the taps: where the first time had a plain tap and this one nothing (or the reverse)
        # (Easy's taps keep their spacing; its buttons follow below)
        add = [i for i in range(8) if plain(src * 8 + i) and h * 8 + i not in notes and not held_at(h * 8 + i)]
        # (a tap the first time didn't have is cut only when one is added too: the level keeps its density)
        cut = [i for i in range(8) if plain(h * 8 + i) and src * 8 + i not in notes]
        if lv >= 1 and len(add) >= len(cut) and 0 < len(add) + len(cut) <= 3:
            for i in cut:
                del notes[h * 8 + i]
            for i in add:
                notes[h * 8 + i] = [dict(notes[src * 8 + i][0])]
                prio[(h * 8 + i, notes[h * 8 + i][0]["lane"])] = 10
        # the buttons
        for i in range(8):
            a_, b_ = src * 8 + i, h * 8 + i
            if plain(a_) and plain(b_) and (b_ not in forced or notes[a_][0]["lane"] in forced[b_]):
                notes[b_][0]["lane"] = notes[a_][0]["lane"]
    # last: the same button never twice inside 0.2 s, and never pressed within 0.3 s of a hold on it
    # starting or letting go (a later pass may have made one); the tap moves to a free button or goes
    def presses():
        out = []
        for x in notes:
            for nd in notes[x]:
                if nd["k"] in ("step", "ring", "hold"):
                    out.append((x, nd["lane"], nd))
                elif nd["k"] == "stomp":
                    out.append((x, nd["lane"], nd))
        return out
    for x in sorted(notes):
        if x not in notes:
            continue
        for nd in [n for n in notes[x] if n["k"] in ("step", "ring")]:     # (a ring: the fourth-press rule only)
            bad = set()
            for y, ln_, od in presses():
                if od is nd:
                    continue
                dt = (x - y) * slot_s
                if y != x and abs(dt) < 0.2:
                    bad.add(ln_)
                if od["k"] == "hold":
                    end = y + od["len"] * 4
                    if (y != x and abs(dt) < 0.3) or (0 <= (x - end) * slot_s < 0.3) or y <= x <= end:
                        bad.add(ln_)
            bad |= {n.get("lane") for n in notes[x] if n is not nd}
            hard_bad = set(bad)
            if lv == 3 and song.kind.get(x // 16) != "build" and nd["k"] == "step":      # Expert: a moving tune never takes one button three times inside 0.75 s
                prev = sorted(y for y, ln_, od in presses() if ln_ == nd["lane"] and 0 < (x - y) * slot_s < 0.75)
                if len(prev) >= 2 and song.pitch(prev[-1]) != song.pitch(x):
                    bad.add(nd["lane"])
                    if all(l in bad for l in (0, 1, 2)) and nd["lane"] not in hard_bad:
                        continue     # (no other button is free: the note stays where it is)
            if lv >= 1 and song.kind.get(x // 16) != "build" and nd["lane"] not in bad:
                # any level: a fourth press in a row on one button (within a second, or four eighths
                # of a slow song) moves to another button, whatever the pitch, if one is free: to the
                # side the tune moves toward
                last3 = sorted({y: ln_ for y, ln_, od in presses() if 0 < (x - y) * slot_s < max(1.0, 6.5 * slot_s)}.items())[-3:]
                if len(last3) == 3 and all(l_ == nd["lane"] for _, l_ in last3):
                    alt = [l for l in (0, 1, 2) if l not in bad and l != nd["lane"] and (x not in forced or l in forced[x])]
                    if alt:
                        d = song.pitch(x) - song.pitch(last3[-1][0])
                        toward = [l for l in alt if (l - nd["lane"]) * d > 0]
                        nd["lane"] = min(toward or alt, key=lambda l: abs(l - nd["lane"]))
                    continue
            if nd["lane"] not in bad:
                continue
            alt = [l for l in (0, 1, 2) if l not in bad and (x not in forced or l in forced[x])]
            if alt:
                nd["lane"] = min(alt, key=lambda l: abs(l - nd["lane"]))
            elif nd["k"] == "step":     # (a ring with nowhere to go stays: the repair pass decides)
                notes[x].remove(nd)
        if not notes[x]:
            del notes[x]

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


def lift(song, diff, lower, upper):
    """A harder level never plays fewer inputs in a bar than the level below: the lower level's
    missing taps are added where they fit (then the readability rules have the last word)."""
    slot_s = song.spb / 4
    sl = lambda n: round(n["b"] * 4)
    unit = 8 if diff == "expert" else 16          # Expert never thinner than Hard in any half bar
    def per_bar(ch):
        out = {}
        for n in ch:
            if n["k"] != "rest":
                out[sl(n) // unit] = out.get(sl(n) // unit, 0) + 1
        return out
    lb, ub = per_bar(lower), per_bar(upper)
    up = list(upper)
    added = []
    def fit(x, want):
        """The button a tap at slot x can take on this level (want, if free), or None."""
        lanes_near = set()
        for m in up:
            y = sl(m)
            dt = abs(x - y) * slot_s
            # the level's own clearance around a tilt (a stomp keeps 0.3 s)
            if m["k"] in ("bell", "ring") and (x - y) * slot_s < (TILT_AFTER[diff] if x > y else 0) - 1e-6 \
                    and x > y or m["k"] in ("bell", "ring") and x <= y and (y - x) * slot_s < TILT_BEFORE[diff] - 1e-6 \
                    or m["k"] == "stomp" and dt < 0.3:
                return None
            # under a hold the free thumb may play (on another button, not as the hold starts)
            if m["k"] == "hold" and y - 1 <= x <= y + m["len"] * 4 + 1 and (
                    abs(x - y) <= 1 or want == m["lane"] or diff != "expert"):
                return None
            if m["k"] == "hold" and y < x < y + m["len"] * 4 + 0.3 / slot_s:
                lanes_near.add(m["lane"])
            if m["k"] == "hold" and abs(x - (y + m["len"] * 4)) * slot_s < 0.2 and any(sl(o) == x for o in up if o["k"] == "step"):
                return None      # (no chord as a hold lets go)
            if dt < 0.2 and m["k"] == "step" and not (diff == "expert" and x == y and m["lane"] != want):
                return None      # (at Expert, Hard's tap on an Expert tap's slot may join it as a chord)
            if dt < 0.3 and "lane" in m:
                lanes_near.add(m["lane"])
        return want if want not in lanes_near else next((l for l in (0, 2, 1) if l not in lanes_near), None)
    for bar, cnt in sorted(lb.items()):
        need = cnt - ub.get(bar, 0) + (1 if diff == "hard" and cnt >= 3 and song.kind.get(bar) == "groove" else 0)
        if need <= 0:
            continue
        for n in sorted((n for n in lower if n["k"] == "step" and sl(n) // unit == bar),
                        key=lambda n: -song.score(sl(n))):
            if need <= 0:
                break
            lane = fit(sl(n), n["lane"])
            if lane is None:
                continue
            m = {"b": n["b"], "k": "step", "lane": lane}
            up.append(m)
            added.append(m)
            need -= 1
    if diff == "hard":     # Hard never plays Medium's rhythm in a groove bar: two more of its own candidates
        when = lambda ch, bar: {sl(n) for n in ch if n["k"] != "rest" and sl(n) // 16 == bar}
        for bar in range(song.bars):
            lo_ = when(lower, bar)
            if song.kind.get(bar) not in ("groove", "transition", "ending") or len(lo_) < 3 or when(up, bar) != lo_:
                continue
            k_ = 0
            # (its rhythm's candidates first, then any eighth with the tune, a drum or the bass on it)
            extra = [x for x in range(bar * 16, min(bar * 16 + 16, song.end_slot), 2)
                     if song.lead(x) >= ON or song.drum(x) >= 0.4 or song.a["bass"][x] >= 0.5]
            cands = sorted(pick_rhythm(song, diff, bar)[0], key=lambda s: -song.score(s))
            for x in cands + sorted((x for x in extra if x not in cands), key=lambda s: -song.score(s)):
                if k_ >= 2:
                    break
                if x in lo_ or x // 16 != bar:
                    continue
                prev = max((m for m in up if "lane" in m and sl(m) < x), key=sl, default=None)
                want = 1 if prev is None else min(2, max(0, prev["lane"] + (1 if song.pitch(x) > song.pitch(sl(prev)) else
                                                                            -1 if song.pitch(x) < song.pitch(sl(prev)) else 0)))
                lane = fit(x, want)
                if lane is None:
                    continue
                m = {"b": round(x / 4 + (song.swing if x % 2 else 0.0), 4), "k": "step", "lane": lane}
                up.append(m)
                added.append(m)
                k_ += 1
    if diff == "expert":     # Expert holds wherever Hard does: Hard's hold on Expert's tap on the same note
        nh = lambda ch: sum(1 for n in ch if n["k"] == "hold")
        for h in sorted((n for n in lower if n["k"] == "hold"), key=lambda n: -song.score(sl(n))):
            if nh(up) >= nh(lower) * 1.3:
                break
            x, ln = sl(h), round(h["len"] * 4)
            if any(m["k"] == "hold" and sl(m) - 2 <= x + ln and x - 2 <= sl(m) + m["len"] * 4 for m in up):
                continue
            at = [m for m in up if sl(m) == x]
            if any(m["k"] != "step" for m in at) or len(at) > 2:
                continue
            if len(at) == 2:         # a chord: the hold takes the button Hard holds, if it's one of the two
                at = [m for m in at if m["lane"] == h["lane"]]
                if not at:
                    continue
            elif not at:             # an empty slot: Hard's hold, if nothing on Expert crowds it
                if any(m["k"] != "rest" and abs(sl(m) - x) * slot_s < 0.2 for m in up):
                    continue
                at = [{"b": h["b"], "k": "step", "lane": h["lane"]}]
                up.append(at[0])
            lane = at[0]["lane"]
            if any(m.get("lane") == lane and 0 < (x - sl(m)) * slot_s < 0.3 for m in up):
                continue
            span = [m for m in up if x < sl(m) <= x + ln + 1]
            if any(m["k"] in ("bell", "ring", "stomp") for m in span):
                continue
            # the held button's taps inside give way (at most two); the free thumb keeps the rest
            same = [m for m in span if m.get("lane") == lane]
            if len(same) > 2 or any(m["k"] != "step" for m in same):
                continue
            for m in same:
                up.remove(m)
            at[0]["k"], at[0]["len"] = "hold", h["len"]
            added.append(at[0])
        # the tune's note just after a ring, when the tilt leaves room for it (a slow song's sixteenth)
        if TILT_AFTER[diff] <= slot_s + 1e-6:
            for r in [m for m in up if m["k"] in ("bell", "ring")]:
                x = sl(r) + 1
                if song.lead(x) < 0.6 or any(m["k"] != "rest" and (abs(sl(m) - x) * slot_s < 0.2 or
                                                                      (m["k"] == "hold" and sl(m) <= x <= sl(m) + m["len"] * 4))
                                              for m in up if m is not r):
                    continue
                nxt = min((m for m in up if m["k"] == "step" and sl(m) > x), key=sl, default=None)
                if nxt is None:
                    continue
                d = 1 if song.pitch(x) > song.pitch(sl(nxt)) else -1
                lane = min(2, max(0, nxt["lane"] + d))
                if lane == nxt["lane"]:
                    lane = 1
                busy = {m.get("lane") for m in up if m["k"] != "rest" and abs(sl(m) - x) * slot_s < 0.3}
                if lane in busy:
                    continue
                m = {"b": x / 4, "k": "step", "lane": lane}
                up.append(m)
                added.append(m)
    up.sort(key=lambda n: (n["b"], n["k"]))
    prio = {(sl(n), n.get("lane", "b")): (0 if any(n is a for a in added) else 50) for n in up}
    prio.update({(sl(n), n.get("lane", "b")): 100 for n in up if n["k"] in ("hold", "stomp")})
    prio.update({(sl(n), n.get("lane", "b")): 90 for n in up if n["k"] in ("bell", "ring")})
    return repair(song, diff, up, prio)


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
    charts = {}
    for d in DIFFS:      # each level holds at least as often as the one below
        below = charts.get(DIFFS[DIFFS.index(d) - 1], []) if d != "easy" else []
        # Hard holds at least as often as Medium and about every other bar, Expert half as often
        # again as Hard and most bars
        floor = max(sum(1 for n in below if n["k"] == "hold") * (1.5 if d == "expert" else 1.3),
                    {"hard": 0.9 if song.spb * 4 >= 3.0 else 0.5, "expert": 1.2 if song.spb * 4 >= 3.0 else 0.9}.get(d, 0) * song.bars)
        charts[d] = build_chart(song, d, reps, round(floor))
    for lo_, hi_ in (("medium", "hard"), ("hard", "expert")):
        charts[hi_] = lift(song, hi_, charts[lo_], charts[hi_])
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
