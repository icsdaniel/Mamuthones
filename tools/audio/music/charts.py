"""Charts written from the score.

Every note is taken from a chart candidate: an audible event the score wrote (a drum stroke, a
sung syllable, a reed note, a bell cue's landing, a rope crack, a musical stop). Each section says,
per difficulty, which layers of the music the player follows; then rules refine the result:

- bells on strong cues only (the score's bell cues always have a rim click before them);
- holds on long sung or piped notes; stand-stills exactly where the music stops;
- lanes follow the melody's contour inside each phrase (low left, high right), so a phrase and its
  answer mirror each other when the music does; each song's signature motif has hand-set lanes;
- difficulty gates from design section 4, and the song's own mechanics (stop order);
- readability: overall and per-hand gaps, bells half a beat apart, nothing under a hold's lane;
- the first appearance of every mechanic is isolated from the other extras.

The result passes tools/audio/validate_charts.py, which is imported here as the final gate.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import validate_charts as V  # noqa: E402

DIFFS = V.DIFFS
LEAD_STEMS = ("boghe", "mancosa", "mancosedda", "lead_pitch")

# Default layers per difficulty and section energy (0 calm .. 3 climax).
DEFAULTS = {
    "easy": {
        0: dict(steps=[("pulse", 1)], bells="phrase"),
        1: dict(steps=[("pulse", 2)], bells="phrase"),
        2: dict(steps=[("pulse", 3)], bells="phrase"),
        3: dict(steps=[("pulse", 3), ("mel", 3)], bells="phrase"),
    },
    "medium": {
        0: dict(steps=[("pulse", 2), ("mel", 2)], bells="bar", holds=2),
        1: dict(steps=[("pulse", 3), ("mel", 3), ("chorus", 2)], bells="bar", holds=3),
        2: dict(steps=[("pulse", 3), ("mel", 3), ("chorus", 3)], bells="bar", holds=3),
        3: dict(steps=[("pulse", 3), ("mel", 4), ("chorus", 3)], bells="bar", holds=3),
    },
    "hard": {
        0: dict(steps=[("pulse", 3), ("mel", 3)], bells="bar", holds=3),
        1: dict(steps=[("pulse", 3), ("mel", 4), ("chorus", 3)], bells="accent", holds=4),
        2: dict(steps=[("pulse", 4), ("mel", 4), ("chorus", 4), ("perc", 3)], bells="accent", holds=4),
        3: dict(steps=[("pulse", 4), ("mel", 4), ("chorus", 4), ("perc", 4)], bells="accent", holds=4),
    },
    "expert": {
        0: dict(steps=[("pulse", 3), ("mel", 4), ("chorus", 3)], bells="accent", holds=4),
        1: dict(steps=[("pulse", 4), ("mel", 5), ("chorus", 4), ("perc", 4)], bells="all", holds=5),
        2: dict(steps=[("pulse", 4), ("mel", 5), ("chorus", 5), ("perc", 4), ("fast", 4)], bells="all", holds=5),
        3: dict(steps=[("pulse", 5), ("mel", 5), ("chorus", 5), ("perc", 5), ("fast", 5)], bells="all", holds=5),
    },
}

# Average notes per second per stop and difficulty: the curve across the story.
TARGET = {
    1: {"easy": 0.6, "medium": 0.7, "hard": 0.9, "expert": 1.0},
    2: {"easy": 0.62, "medium": 0.95, "hard": 1.3, "expert": 2.0},
    3: {"easy": 0.8, "medium": 1.2, "hard": 1.7, "expert": 2.6},
    4: {"easy": 0.85, "medium": 1.35, "hard": 2.0, "expert": 3.0},
    5: {"easy": 0.9, "medium": 1.45, "hard": 2.3, "expert": 3.4},
    6: {"easy": 0.95, "medium": 1.6, "hard": 2.7, "expert": 4.0},
    7: {"easy": 1.0, "medium": 1.85, "hard": 3.1, "expert": 4.4},
}
# how a section's density follows the song's shape (energy 0 calm .. 3 climax)
ENERGY_FACTOR = {0: 0.6, 1: 0.85, 2: 1.05, 3: 1.4}
EXPERT_PEAK = 4.3   # expert climaxes reach at least this (notes per second) when the music allows

PRIO = {"rest": 0, "swipe": 1, "ring": 2, "bell": 3, "hold": 4, "call": 5, "step": 6}
ROLE_PRIO = {"mel": 0, "fast": 1, "pulse": 2, "chorus": 3, "perc": 4}


class N:
    """Working note (before JSON)."""
    __slots__ = ("b", "k", "lane", "len", "dir", "call", "rank", "role", "pitch", "sig", "stem", "tag", "src")

    def __init__(self, b, k, rank=3, role="", pitch=None, stem=None, **kw):
        self.b = round(b, 4)
        self.k = k
        self.rank = rank
        self.role = role
        self.pitch = pitch
        self.stem = stem
        self.lane = kw.get("lane")
        self.len = kw.get("len", 0.0)
        self.dir = kw.get("dir", 0)
        self.call = kw.get("call", False)
        self.sig = kw.get("sig")
        self.tag = kw.get("tag", "")
        self.src = kw.get("src")

    def prio(self):
        return (PRIO["call"] if self.call else PRIO[self.k], 0 if self.sig is not None else 1, self.rank,
                ROLE_PRIO.get(self.role, 5))

    def json(self):
        d = {"b": self.b, "k": self.k}
        if self.k in ("step", "hold", "ring"):
            d["lane"] = int(self.lane)
        if self.k == "hold":
            d["len"] = self.len
        if self.k == "rest" and abs(self.len - 1) > 1e-9:
            d["len"] = self.len
        if self.k == "swipe":
            d["dir"] = int(self.dir)
        if self.k == "step" and self.call:
            d["call"] = True
        return d


def allowed(song, diff, mech, spec):
    """Stop order and difficulty table decide which extras may appear."""
    lv = DIFFS.index(diff)
    if song.kind == "tutorial":
        return True
    if mech == "hold":
        return "hold" in song.mechanics and lv >= 1
    if mech == "ring":
        return "ring" in song.mechanics and lv >= 2
    if mech in ("swipe", "call"):
        return mech in song.mechanics and lv >= 2
    if mech == "triple":
        return "triple" in song.mechanics and lv >= 3
    return True


def lead_pitch_at(song, b):
    best = None
    for e in song._leads:
        if e.b <= b + 1e-6 < e.b + max(e.dur, 0.25):
            best = e.pitch
        elif e.b > b:
            break
    if best is None:
        best = song.pitch(song.root_at(b))
    return best


class Charter:
    def __init__(self, song):
        self.s = song
        song._leads = sorted([e for e in song.events if e.inst in LEAD_STEMS and e.pitch is not None],
                             key=lambda e: e.b)
        self.third = song.sub == 3

    # ---------------------------------------------------------------- spec
    def spec(self, sec, diff):
        ch = sec.opts.get("chart", "default")
        if ch is None:
            return None
        base = dict(DEFAULTS[diff][min(3, sec.energy)])
        if isinstance(ch, dict) and diff in ch:
            base.update(ch[diff])
        extra = sec.opts.get("add", {}).get(diff)
        if extra:
            base.update(extra)
        return base

    # ---------------------------------------------------------------- selection
    def build(self, diff):
        s = self.s
        notes: list[N] = []
        for sec in s.sections:
            sp = self.spec(sec, diff)
            if sp is None:
                continue
            lo = sec.b + (s.bpb if sec.opts.get("listen_bar") else 0)
            hi = sec.b + sec.len
            inside = [c for c in s.cands if lo - 1e-6 <= c.b < hi - 1e-6]
            steps = dict(sp.get("steps", []))
            for c in inside:
                if c.role in steps and (c.rank <= steps[c.role] or (c.sig is not None and diff != "easy")):
                    notes.append(N(c.b, "step", c.rank, c.role, c.pitch, c.stem, sig=c.sig, src=c))
                elif c.sig is not None and diff in ("hard", "expert") and c.role in ("mel", "fast", "chorus"):
                    notes.append(N(c.b, "step", c.rank, c.role, c.pitch, c.stem, sig=c.sig, src=c))
            # bells
            mode = sp.get("bells", "none")
            bells = [c for c in inside if c.role == "bell"]
            chosen = []
            if mode == "all":
                chosen = bells
            elif mode == "accent":
                chosen = [c for c in bells if c.rank <= 2]
            elif mode in ("bar", "phrase"):
                span = s.bpb * (1 if mode == "bar" else sec.opts.get("phrase_bars", self.phrase_bars()))
                groups = {}
                for c in bells:
                    groups.setdefault(int((c.b - sec.b + 1e-6) // span), []).append(c)
                for g in groups.values():
                    chosen.append(min(g, key=lambda c: (c.rank, c.b)))
            for c in chosen:
                notes.append(N(c.b, "bell", c.rank, "bell", None, c.stem, tag=c.tag if c.tag == "triple" else ("ring" if c.ring else c.tag), src=c))
            # holds
            hk = sp.get("holds", 0)
            if hk and allowed(s, diff, "hold", sp):
                for c in inside:
                    if c.role == "hold" and c.rank <= hk and c.len >= 1.5:
                        ln = min(8.0, max(1.0, int((c.len - 0.25) * 2) / 2))
                        if c.b + ln > hi:
                            ln = max(1.0, int((hi - c.b - 0.25) * 2) / 2)
                        notes.append(N(c.b, "hold", c.rank, "hold", c.pitch, c.stem, len=ln, src=c))
            # swipes and calls
            if sp.get("swipes", True) and allowed(s, diff, "swipe", sp):
                for c in inside:
                    if c.role == "swipe":
                        notes.append(N(c.b, "swipe", 1, "swipe", None, c.stem, dir=c.dir, src=c))
            if sp.get("calls", True) and allowed(s, diff, "call", sp):
                for c in inside:
                    if c.role == "call":
                        notes.append(N(c.b, "step", 2, "call", None, c.stem, call=True, src=c))
            for c in inside:
                if c.role == "rest" and sp.get("rests", True):
                    notes.append(N(c.b, "rest", 0, "rest", None, None, len=c.len, src=c))
            self._sec_opts = sp
        return self.refine(notes, diff)

    def phrase_bars(self):
        bar_s = self.s.bpb * self.s.spb
        return 2 if bar_s >= 2.6 else 4

    # ---------------------------------------------------------------- refinement
    def refine(self, notes, diff):
        s = self.s
        lv = DIFFS.index(diff)
        gap = (V.RULES["overall_gap_third"] if self.third else V.RULES["overall_gap"])[diff]
        if diff == "easy" and s.kind != "tutorial":
            gap = max(gap, V.RULES["easy_min_gap_s"] / s.spb)
            # round the walking beat up to whole beats (1, 2 ...)
            gap = float(int(gap - 1e-6) + 1)
        tutorial = s.kind == "tutorial"

        # 1. merge duplicates on one beat: one step per beat before lanes exist
        by_b = {}
        for n in notes:
            by_b.setdefault((n.b, n.k if n.k != "hold" else "step"), []).append(n)
        merged = []
        for (b, k), lst in by_b.items():
            lst.sort(key=lambda n: n.prio())
            if k == "step":
                # a hold beats a plain step on the same beat
                holds = [n for n in lst if n.k == "hold"]
                pick = holds[0] if holds else lst[0]
                if pick.pitch is None:
                    for n in lst:
                        if n.pitch is not None and n.role in ("mel", "fast"):
                            pick.pitch = n.pitch
                            break
                if any(n.call for n in lst):
                    pick.call = pick.k == "step"
                merged.append(pick)
            else:
                merged.append(lst[0])
        notes = merged

        # 2. rests clear everything inside them (and holds running into them)
        rests = [n for n in notes if n.k == "rest"]
        for r in rests:
            notes = [n for n in notes if n is r or not (r.b - 1e-6 <= n.b < r.b + r.len - 1e-6)]
            for n in notes:
                if n.k == "hold" and n.b < r.b and n.b + n.len > r.b - 0.5:
                    n.len = max(0.0, int((r.b - n.b - 0.5) * 2) / 2)
            notes = [n for n in notes if not (n.k == "hold" and n.len < 1.0)]

        # 3. swipes need a free hand: clear around them
        clear = 1.0 if lv <= 1 else (0.75 if lv == 2 else 0.5)
        for sw in [n for n in notes if n.k == "swipe"]:
            notes = [n for n in notes if n is sw or n.k == "rest" or abs(n.b - sw.b) >= clear - 1e-6]

        # 4. bells against steps, by difficulty. A bell tilts the phone, so both thumbs leave the
        # buttons: steps keep clear of it (half a beat at Medium and Hard, 150 ms at Expert).
        bells = [n for n in notes if n.k == "bell"]
        ring_ok = allowed(s, diff, "ring", {}) or (tutorial and self._ring_in_lesson())
        clear = {"easy": 1.0, "medium": 0.5, "hard": 0.5}.get(diff) or V.RULES["bell_clear_s"]["expert"] / s.spb
        # in a climax the steps are the point: a weak bell crowded by steps gives way to them
        if lv >= 2 and not tutorial:
            step_bs = [n.b for n in notes if n.k in ("step", "hold")]
            keep_b = []
            for bl in bells:
                sec = s.section_at(bl.b)
                crowd = sum(1 for b in step_bs if 1e-6 < abs(b - bl.b) < clear - 1e-6)
                on_beat = any(abs(b - bl.b) < 1e-6 for b in step_bs)
                weak = bl.rank > 1 and bl.tag not in ("ring", "triple")
                if sec is not None and sec.energy >= 3 and crowd >= 2 and weak and not on_beat:
                    continue
                keep_b.append(bl)
            gone = set(id(x) for x in bells) - set(id(x) for x in keep_b)
            notes = [n for n in notes if id(n) not in gone]
            bells = keep_b
        out = []
        bell_bs = {n.b: n for n in bells}
        for n in notes:
            if n.k not in ("step", "hold"):
                out.append(n)
                continue
            # nearest bell
            near = min((abs(n.b - bb) for bb in bell_bs), default=99)
            if near < 1e-6:
                bl = bell_bs[n.b]
                # rings where the score marks a leap (the bell cue lands with a step); at Expert
                # also on the strongest bells, the rest of Expert's bells stay free of the steps
                if n.k == "step" and ring_ok and (bl.tag in ("ring", "triple") or (lv >= 3 and bl.rank == 1)):
                    bl.k = "ring"
                    bl.pitch = n.pitch if n.pitch is not None else bl.pitch
                    bl.role = n.role
                    if bl.tag == "triple" and allowed(s, diff, "triple", {}):
                        out.append(n)  # stays as the extra step of a triple ring
                        n.tag = "triple_step"
                    continue
                continue  # the bell takes the beat
            if near < clear - 1e-6:
                continue
            out.append(n)
        notes = out

        # 5. holds: nothing on their lane (decided after lanes), at medium nothing at all inside
        # 6. thin by overall gap, keeping the most important notes
        notes = self.thin(notes, gap, diff)

        # 7. lanes
        self.lanes(notes, diff)

        # 8. hands, holds and hidden notes
        notes = self.fix_hands(notes, diff)

        # 9. first appearances stand alone
        notes = self.isolate_firsts(notes, diff)

        # 10. density follows the song's shape and the story's curve
        if not tutorial:
            notes = self.fit_density(notes, diff)

        notes.sort(key=lambda n: (n.b, PRIO[n.k]))
        # bells alternate automatically; make sure no bell pair is too close
        notes = self.bell_spacing(notes)
        # the design's easy density cap, enforced by dropping the weakest steps in dense windows
        if diff == "easy" and not tutorial:
            notes = self.cap_density(notes, V.RULES["easy_peak_nps"])
        return notes

    def _ring_in_lesson(self):
        return True

    def thin(self, notes, gap, diff):
        """Greedy by priority: accept a note if no accepted note on another beat is closer than gap."""
        order = sorted(notes, key=lambda n: n.prio())
        acc = []
        beats = []
        import bisect
        for n in order:
            if n.k == "rest":
                acc.append(n)
                continue
            i = bisect.bisect_left(beats, n.b - gap + 1e-6)
            ok = True
            while i < len(beats) and beats[i] < n.b + gap - 1e-6:
                if abs(beats[i] - n.b) > 1e-6:
                    ok = False
                    break
                # same beat: only a triple ring's extra step may share it
                if n.tag != "triple_step":
                    ok = False
                    break
                i += 1
            if ok:
                acc.append(n)
                bisect.insort(beats, n.b)
        return acc

    def lanes(self, notes, diff):
        s = self.s
        sig_lanes = s.signature.get(diff) or s.signature.get("hard") or []
        laned = [n for n in notes if n.k in ("step", "hold", "ring")]
        for n in laned:
            if n.pitch is None:
                n.pitch = lead_pitch_at(s, n.b)
        laned.sort(key=lambda n: n.b)
        phrase = s.bpb * 2
        groups = {}
        for n in laned:
            sec = s.section_at(n.b)
            groups.setdefault((sec.name, int((n.b - sec.b + 1e-6) // phrase)), []).append(n)
        for (secname, _), g in groups.items():
            sec = next(x for x in s.sections if x.name == secname)
            fixed = sec.opts.get("lanes")
            if isinstance(fixed, list):
                continue
            ps = [n.pitch for n in g]
            lo, hi = min(ps), max(ps)
            prev_lane, prev_p = 1, None
            for n in g:
                if fixed == "mid":
                    n.lane = 1
                    continue
                if hi - lo >= 3:
                    x = (n.pitch - lo) / (hi - lo)
                    lane = 0 if x < 0.34 else (1 if x < 0.67 else 2)
                else:
                    if prev_p is None or abs(n.pitch - prev_p) < 0.5:
                        lane = prev_lane
                    else:
                        lane = max(0, min(2, prev_lane + (1 if n.pitch > prev_p else -1)))
                n.lane = lane
                prev_lane, prev_p = lane, n.pitch
        # sections with hand-set lanes (the tutorial's lanes lesson)
        for sec in s.sections:
            fixed = sec.opts.get("lanes")
            if isinstance(fixed, list):
                mine = [n for n in laned if sec.b <= n.b < sec.b + sec.len]
                for i, n in enumerate(mine):
                    n.lane = fixed[i % len(fixed)]
                    n.tag = "fixed"
        # signature motif: hand-set lanes
        if sig_lanes:
            for n in laned:
                if n.sig is not None and n.k in ("step", "ring"):
                    n.lane = sig_lanes[n.sig % len(sig_lanes)]
        if diff == "easy":
            self.easy_lanes(laned, groups)
        else:
            self.balance(groups)
            self.break_jacks(laned)
        self.hold_chains(laned, diff)
        # triple ring: its extra step sits on a different lane from the ring
        for n in laned:
            if n.tag == "triple_step":
                ring = next((m for m in laned if m.k == "ring" and abs(m.b - n.b) < 1e-6), None)
                if ring is not None and ring.lane == n.lane:
                    n.lane = 2 if ring.lane == 0 else 0

    def easy_lanes(self, laned, groups):
        """Easy: one lane at a time. Each phrase has a home lane that follows where the phrase sits
        in the tune (low, middle, high) and moves from one phrase to the next; inside a phrase the
        melody's highest and lowest notes may step one lane off home, after two notes, never 0<->2."""
        s = self.s
        if s.kind == "tutorial":
            return
        keys = sorted(groups, key=lambda k: groups[k][0].b)
        means = {k: sum(n.pitch for n in groups[k]) / len(groups[k]) for k in keys}
        prev_home = None
        for idx, k in enumerate(keys):
            g = [n for n in groups[k] if n.tag != "fixed" and n.sig is None]
            if not g:
                continue
            sec = s.section_at(g[0].b)
            pool = [means[x] for x in keys if x[0] == k[0]]
            lo_m, hi_m = min(pool), max(pool)
            if hi_m - lo_m >= 2:
                x = (means[k] - lo_m) / (hi_m - lo_m)
                home = 0 if x < 0.34 else (1 if x < 0.67 else 2)
            else:
                home = [1, 0, 1, 2][idx % 4]
            if prev_home is not None and home == prev_home:
                home = [1, 0, 1, 2][idx % 4] if [1, 0, 1, 2][idx % 4] != prev_home else (1 if prev_home != 1 else (0 if idx % 2 else 2))
            if prev_home is not None and abs(home - prev_home) == 2:
                home = 1
            ps = [n.pitch for n in g]
            lo, hi = min(ps), max(ps)
            for n in g:
                off = 0
                if hi - lo >= 3 and sec.energy >= 2:
                    x = (n.pitch - lo) / (hi - lo)
                    off = -1 if x < 0.2 else (1 if x > 0.8 else 0)
                n.lane = max(0, min(2, home + off))
            prev_home = home
        prev = None
        run = 0
        for n in laned:
            if n.tag == "fixed":
                prev, run = n.lane, 1
                continue
            if prev is not None and n.lane != prev and run < 2:
                n.lane = prev
            if prev is not None and abs(n.lane - prev) == 2:
                n.lane = 1
            run = run + 1 if n.lane == prev else 1
            prev = n.lane

    def balance(self, groups):
        """Each two-bar phrase keeps its hands balanced: the left share (lane 0, half of lane 1)
        stays between 35 and 65 percent. Notes nearest the middle of the phrase's range move first."""
        for g in groups.values():
            free = [n for n in g if n.tag != "fixed" and n.sig is None and n.k in ("step", "ring")]
            if len(g) < 4:
                continue
            for _ in range(len(g) * 2):
                left = sum(1.0 if n.lane == 0 else (0.5 if n.lane == 1 else 0.0) for n in g) / len(g)
                if 0.35 - 1e-9 <= left <= 0.65 + 1e-9:
                    break
                heavy, toward = (0, 1) if left > 0.65 else (2, -1)
                cand = [n for n in free if n.lane == heavy] or [n for n in free if n.lane == 1]
                if not cand:
                    break
                mid = sum(n.pitch for n in g) / len(g)
                n = min(cand, key=lambda n: (abs(n.pitch - mid), n.b))
                n.lane += toward

    def break_jacks(self, laned):
        """No one-thumb jacks, whatever the melody does: a lane never takes two notes closer than
        125 ms, three in a row closer than 180 ms, or four in a row closer than 300 ms. The note that
        would extend the run moves to a neighbouring lane (outer runs go to the middle, where the
        other thumb can take it; middle runs step out following the melody)."""
        spb = self.s.spb
        taps = sorted([n for n in laned if n.k in ("step", "ring", "hold")], key=lambda n: n.b)
        flip = 0
        for _ in range(3):
            changed = False
            run = {125: 1, 180: 1, 300: 1}
            for i in range(1, len(taps)):
                a, c = taps[i - 1], taps[i]
                dt = (c.b - a.b) * spb * 1000
                if dt < 1e-3:
                    continue
                same = c.lane == a.lane
                bad = False
                for lim, cap in ((125, 1), (180, 2), (300, 3)):
                    if same and dt < lim:
                        if run[lim] + 1 > cap:
                            bad = True
                if bad and c.tag != "fixed" and c.sig is None and c.tag != "triple_step":
                    if a.lane == 1:
                        up = c.pitch is not None and a.pitch is not None and c.pitch > a.pitch
                        down = c.pitch is not None and a.pitch is not None and c.pitch < a.pitch
                        c.lane = 2 if up else (0 if down else (0 if flip % 2 else 2))
                        flip += 1
                    else:
                        c.lane = 1
                    changed = True
                    same = False
                for lim in run:
                    run[lim] = run[lim] + 1 if (same and dt < lim) else 1
            if not changed:
                break

    def hold_chains(self, laned, diff):
        """Holds that follow each other closely alternate hands, and at Medium and Hard they are
        cut to leave room for steps in between, so no thumb is trapped for bars on end."""
        holds = sorted([n for n in laned if n.k == "hold"], key=lambda n: n.b)
        for h1, h2 in zip(holds, holds[1:]):
            if h2.b - (h1.b + h1.len) >= 1.5:
                continue
            if diff in ("medium", "hard") and h2.b - h1.b >= 3.0:
                h1.len = max(1.0, min(h1.len, int((h2.b - h1.b - 2.0) * 2) / 2))
            if h2.lane == h1.lane:
                h2.lane = 2 - h1.lane if h1.lane != 1 else (0 if int(h2.b) % 2 else 2)

    def fix_hands(self, notes, diff):
        s = self.s
        notes.sort(key=lambda n: (n.b, PRIO[n.k]))
        # holds: at easy/medium nothing else during a hold; at hard+ the other hand plays on
        holds = [n for n in notes if n.k == "hold"]
        keep = []
        for n in notes:
            bad = False
            for h in holds:
                if h is n:
                    continue
                if h.b - 1e-6 <= n.b <= h.b + h.len + 1e-6:
                    if n.lane == h.lane or n.k in ("swipe", "hold"):
                        bad = True
                    elif diff in ("easy", "medium") and n.k != "rest":
                        bad = True
                    elif n.k in ("bell", "ring") and diff == "hard":
                        bad = True
                    elif n.lane is not None and h.lane != 1 and n.lane != 1 and n.lane == h.lane:
                        bad = True
                    if n.k in ("step", "ring") and n.lane == 1 and h.lane == 1:
                        bad = True
            if not bad:
                keep.append(n)
        notes = keep
        # repeated passes: move or drop notes the hands cannot reach
        meta = {"bpm": s.bpm, "kind": s.kind, "stop": s.stop_no,
                "sections": [{"name": x.name, "b": x.b, "len": x.len} for x in s.sections]}

        def problems(ns):
            d = [x.json() for x in ns]
            _, hand, clear = V.rule_fns(meta, diff, d)
            return V.assign_hands(d, hand, clear) + V.jacks(d, s.spb)

        for _ in range(8):
            probs = problems(notes)
            if not probs:
                break
            drop = set()
            for (i, msg) in probs:
                if i in drop:
                    continue
                n = notes[i]
                if n.k == "step" and n.sig is None and "bell" not in msg:
                    # try the other lanes first
                    moved = False
                    for alt in ([1, 0, 2] if n.lane != 1 else [0, 2]):
                        if alt == n.lane:
                            continue
                        old = n.lane
                        n.lane = alt
                        if not any(j == i for (j, _) in problems(notes)) and not self.hidden(notes, n):
                            moved = True
                            break
                        n.lane = old
                    if not moved:
                        drop.add(i)
                elif n.k in ("step", "ring", "hold", "swipe"):
                    drop.add(i)
            notes = [n for j, n in enumerate(notes) if j not in drop]
        return notes

    def hidden(self, notes, n):
        for h in notes:
            if h.k == "hold" and h is not n and h.lane == n.lane and h.b - 1e-6 <= n.b <= h.b + h.len + 1e-6:
                return True
        return False

    def isolate_firsts(self, notes, diff):
        """The first time each extra (bell, hold, rest-free extras, ring, swipe, call) appears,
        no other extra is within two beats of it, so it is met alone before it is combined."""
        def mech(n):
            return "call" if n.call else n.k

        notes.sort(key=lambda n: n.b)
        seen = set()
        remove = set()
        for n in notes:
            m = mech(n)
            if id(n) in remove or m == "step" or m in seen:
                continue
            seen.add(m)
            lo = n.b - 2.0
            hi = n.b + (n.len if n.k in ("hold", "rest") else 0.0) + 2.0
            for o in notes:
                if o is n or id(o) in remove:
                    continue
                om = mech(o)
                if om in ("step", "rest") or om == m:
                    continue
                if lo - 1e-6 <= o.b <= hi + 1e-6:
                    remove.add(id(o))
        return [n for n in notes if id(n) not in remove]

    def fit_density(self, notes, diff):
        """Thin each section's weakest steps down to its target density."""
        s = self.s
        base = getattr(s, "targets", {}).get(diff) or TARGET[s.stop_no][diff]
        for sec in s.sections:
            if sec.opts.get("chart", "default") is None:
                continue
            tgt = base * ENERGY_FACTOR[min(3, sec.energy)] * sec.opts.get("density", 1.0)
            if diff == "expert" and sec.energy >= 3:
                tgt = max(tgt, EXPERT_PEAK)
            dur = sec.len * s.spb
            inside = [n for n in notes if sec.b <= n.b < sec.b + sec.len and n.k != "rest"]
            excess = len(inside) - int(round(tgt * dur))
            if excess <= 0:
                continue
            # candidates to drop: plain steps, weakest first, spread through the section
            pool = [n for n in inside if n.k == "step" and not n.call and n.sig is None and n.tag != "triple_step"]
            # the same place in every two-bar phrase is thinned the same way, so music that
            # repeats keeps a repeating pattern (phrases echo each other)
            span = 2 * s.bpb
            pool.sort(key=lambda n: (-n.rank, -ROLE_PRIO.get(n.role, 5), (((n.b - sec.b) % span) * 7.31) % 1))
            drop = set(id(n) for n in pool[:excess])
            notes = [n for n in notes if id(n) not in drop]
        return notes

    def bell_spacing(self, notes):
        out = []
        last = -99
        for n in notes:
            if n.k in ("bell", "ring"):
                if n.b - last < V.RULES["bell_gap"] - 1e-6:
                    continue
                else:
                    last = n.b
            out.append(n)
        return out

    def cap_density(self, notes, cap):
        win = V.RULES["peak_window_s"] / self.s.spb
        maxn = int(cap * V.RULES["peak_window_s"] + 1e-6)
        for _ in range(200):
            act = sorted([n for n in notes if n.k != "rest"], key=lambda n: n.b)
            worst = None
            j = 0
            for i in range(len(act)):
                while act[i].b - act[j].b >= win - 1e-6:
                    j += 1
                if i - j + 1 > maxn:
                    worst = act[j:i + 1]
                    break
            if worst is None:
                break
            victim = max((n for n in worst if n.k == "step"), key=lambda n: n.prio(), default=None)
            if victim is None:
                victim = max(worst, key=lambda n: n.prio())
            notes = [n for n in notes if n is not victim]
        return notes


def chart_song(song):
    ch = Charter(song)
    charts = {}
    sources = {}
    for d in DIFFS:
        notes = ch.build(d)
        charts[d] = [n.json() for n in notes]
        sources[d] = [(n.b, n.k, n.stem, n.len) for n in notes]
    return charts, sources
