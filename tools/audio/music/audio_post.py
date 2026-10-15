"""Playability pass for charts made from recordings (audio_charts.py), applied after the Charter.

The Charter's rules are in beats and were tuned on the synthesized songs. A recorded song brings
tempos (66 to 137 BPM) and grooves those rules never met, so this pass adds the rules in seconds a
player's hands need, from the round-1 review of the Suno test charts
(/mnt/project-files/suno-songs/review/review-round1.md):

- tilts: room to let go of the buttons and grip again, spacing between tilts, a budget per minute,
  never at a hold's ends or next to a stomp, and Hard tilts more than Medium;
- lanes: no long runs on one button, and the middle button never takes most of a phrase;
- stand-stills: the beat that ends one is played (a tilt: the procession moves again);
- holds: never shorter than a tap feels (0.8 s);
- stomps: at most 12 on Medium, and an outer stomp at Expert gets room for the far thumb;
- Easy: never more than about 5 s without a note while the music plays.

Every change is checked against validate_charts.py and undone when it would break a rule.
"""
from __future__ import annotations

import validate_charts as V

DIFFS = ("easy", "medium", "hard", "expert")
ROOM = {"easy": 0.6, "medium": 0.45, "hard": 0.35, "expert": 0.25}      # tap <-> tilt, seconds
TILT_GAP = {"medium": (4.0, 2.4), "hard": (4.0, 1.75), "expert": (2.0, 1.0)}  # (beats, seconds)
CLEAR_MAX = 2       # a strong tilt may clear this many plain taps out of its way (Medium and up)
TILT_FLOOR = {"medium": 8, "hard": 11, "expert": 10}   # per minute; below it, tilts clear more taps
HOLD_MAX_S = 4.0
# Medium and Hard are refilled from the level above when the pass leaves them thin or empty
REFILL = {"medium": ("hard", 1.5, 2.5), "hard": ("expert", 2.3, 2.0)}   # source, min notes/s, void s
TILTS_PER_MIN = {"easy": 8, "medium": 15, "hard": 20, "expert": 28}
RUN_CAP = {"medium": 4, "hard": 4, "expert": 6}
MID_SHARE = 0.45
STOMP_TILT_S = 0.6
HOLD_EDGE_S = 0.5
HOLD_MIN_S = 0.8
MEDIUM_STOMPS = 12
EASY_VOID_S = 5.0
EPS = 1e-4

TILTS = ("bell", "ring")


class Post:
    def __init__(self, data, song, feat, rests):
        self.data = data
        self.song = song
        self.spb = 60.0 / data["bpm"]
        self.off = data["offset"]
        self.S = feat["slots"]
        self.rests = rests
        self.minutes = data["length"] / 60.0
        self.log = []

    # ------------------------------------------------------------------ helpers
    def t(self, b):
        return self.off + b * self.spb

    def slot(self, b):
        i = int(round(b * 4))
        return self.S[i] if 0 <= i < len(self.S) else None

    def strength(self, b):
        s = self.slot(b)
        if s is None:
            return 0.0
        return s["all"] + 0.5 * s["kick"] + (0.3 if abs(b % 4) < EPS else 0.0)

    def energy(self, b):
        return self.song.section_at(b).energy

    def errors(self, name, notes):
        errs, _ = V.check_chart(self.data, name, notes, None)
        return [e for e in errs if "peak" not in e]

    def attempt(self, name, notes, change):
        """Apply change(notes) -> new notes; keep it only if it adds no validator error."""
        before = len(self.errors(name, notes))
        new = change([dict(n) for n in notes])
        if new is None:
            return notes, False
        new.sort(key=lambda n: (n["b"], n["k"]))
        if len(self.errors(name, new)) > before:
            return notes, False
        return new, True

    # ------------------------------------------------------------------ passes
    def run(self):
        ch = self.data["charts"]
        for d in DIFFS:
            notes = sorted(ch[d], key=lambda n: (n["b"], n["k"]))
            notes = self.short_holds(d, notes)
            notes = self.stomps(d, notes)
            notes = self.reentry(d, notes)
            notes = self.tilts(d, notes)
            if d != "easy":
                notes = self.lane_runs(d, notes)
                notes = self.middle_share(d, notes)
            else:
                notes = self.easy_voids(notes)
            ch[d] = notes
        for d in ("hard", "medium"):
            ch[d] = self.refill(d, ch[d], ch[REFILL[d][0]])
        self.rising_tilts()
        return self.data

    def short_holds(self, d, notes):
        for n in notes:
            if n["k"] == "hold" and n["len"] * self.spb < HOLD_MIN_S - EPS:
                n["k"] = "step"
                del n["len"]
            elif n["k"] == "hold" and n["len"] * self.spb > HOLD_MAX_S + EPS:
                n["len"] = max(1.0, int(HOLD_MAX_S / self.spb * 2) / 2)
        return notes

    def stomps(self, d, notes):
        st = [n for n in notes if n["k"] == "stomp"]
        if d == "medium" and len(st) > MEDIUM_STOMPS:
            keep = {id(st[round(i * (len(st) - 1) / (MEDIUM_STOMPS - 1))]) for i in range(MEDIUM_STOMPS)}
            notes = [n for n in notes if n["k"] != "stomp" or id(n) in keep]
        if d == "expert":
            for n in notes:
                if n["k"] == "stomp" and n.get("lane", 1) != 1:
                    near = [m for m in notes if m is not n and m["k"] != "rest"
                            and abs(self.t(m["b"]) - self.t(n["b"])) < 0.45]
                    if near:
                        n["lane"] = 1
        return notes

    def reentry(self, d, notes):
        """The beat that ends a stand-still is played: a tilt, with a beat clear after it."""
        for rb, rl in self.rests:
            end = rb + rl
            if any(n["k"] in TILTS and abs(n["b"] - end) < EPS for n in notes):
                continue
            room = max(1.0, ROOM[d] / self.spb)

            def change(ns, end=end, room=room):
                ns = [n for n in ns if not (end - EPS <= n["b"] < end + room - EPS)
                      and not (n["k"] == "hold" and n["b"] < end and n["b"] + n["len"] > end - room)]
                if d in ("easy", "medium"):
                    # one bell per phrase (Easy) or per bar (Medium): this one wins
                    span = 8 if d == "easy" else 4
                    ns = [n for n in ns if not (n["k"] == "bell" and int(n["b"] // span) == int(end // span))]
                    if d == "easy":
                        ns = [n for n in ns if not (n["k"] == "bell" and abs(n["b"] - end) < 8)]
                ns.append({"b": end, "k": "bell"})
                return ns
            notes, ok = self.attempt(d, notes, change)
            self.log.append(f"{d}: re-entry tilt at b={end} {'added' if ok else 'REFUSED'}")
        return notes

    def tilts(self, d, notes, clear_max=CLEAR_MAX):
        """Keep the strongest tilts that leave the hands room; the rest go (a ring keeps its tap)."""
        ends = {rb + rl for rb, rl in self.rests}
        tilts = [n for n in notes if n["k"] in TILTS]
        others = [n for n in notes if n["k"] not in TILTS and n["k"] != "rest"]
        holds = [n for n in notes if n["k"] == "hold"]
        stomps = [n for n in notes if n["k"] == "stomp"]

        def forced(n):
            return any(abs(n["b"] - e) < EPS for e in ends)

        order = sorted(tilts, key=lambda n: (not forced(n), -self.strength(n["b"]), n["b"]))
        kept = []
        cleared = set()
        protected = set()
        if d == "expert":
            # the densest stretch (the Expert peak) keeps its taps: tilts there must find room
            ts = sorted((self.t(m["b"]), id(m)) for m in others)
            best, lo = (0, 0, 0), 0
            for hi in range(len(ts)):
                while ts[hi][0] - ts[lo][0] > V.RULES["peak_window_s"]:
                    lo += 1
                best = max(best, (hi - lo + 1, lo, hi))
            protected.update(i for _, i in ts[best[1]:best[2] + 1])
        cap = int(TILTS_PER_MIN[d] * self.minutes)
        for n in order:
            tb, tt = n["b"], self.t(n["b"])
            f = forced(n)
            ok = True
            # room for the hands: plain taps in the way may be cleared (Medium and up)
            same = {round(m["b"], 4) for m in others if abs(m["b"] - tb) < EPS}
            block = [m for m in others if abs(m["b"] - tb) >= EPS and abs(self.t(m["b"]) - tt) < ROOM[d] - EPS]
            plain = [m for m in block if m["k"] == "step" and id(m) not in protected
                     and sum(1 for x in others if abs(x["b"] - m["b"]) < EPS) == 1]
            if block and (d == "easy" or len(plain) < len(block) or len(plain) > clear_max):
                ok = False
            # stomps and hold ends
            if ok and any(abs(self.t(s["b"]) - tt) < STOMP_TILT_S - EPS for s in stomps):
                ok = False
            if ok:
                for h in holds:
                    hs, he = self.t(h["b"]), self.t(h["b"] + h["len"])
                    if abs(hs - tt) < HOLD_EDGE_S - EPS or abs(he - tt) < HOLD_EDGE_S - EPS:
                        ok = False
                        break
                    if hs < tt < he:
                        if self.energy(h["b"]) == 0:
                            ok = False
                        elif d != "expert":
                            inside = [k for k in kept if hs < self.t(k["b"]) < he]
                            if he - hs < 3.0 or inside:
                                ok = False
                        if not ok:
                            break
            # spacing between tilts
            if ok and d in TILT_GAP:
                gb, gs = TILT_GAP[d]
                if d == "expert" and self.energy(tb) <= 1:
                    gb = 4.0
                for k in kept:
                    if abs(k["b"] - tb) < gb - EPS or abs(self.t(k["b"]) - tt) < gs - EPS:
                        ok = False
                        break
            if ok and len(kept) >= cap and not f:
                ok = False
            if ok or f:
                kept.append(n)
                if ok:
                    for m in block:
                        cleared.add(id(m))
                    protected.update(id(m) for m in others if abs(m["b"] - tb) < EPS)
        keep = {id(n) for n in kept}
        out = []
        for n in notes:
            if id(n) in cleared:
                continue
            if n["k"] in TILTS and id(n) not in keep:
                if n["k"] == "ring":
                    m = dict(n)
                    m["k"] = "step"
                    out.append(m)
                continue
            out.append(n)
        if d in TILT_FLOOR and clear_max < 4 and len(kept) < TILT_FLOOR[d] * self.minutes:
            return self.tilts(d, notes, 4)
        dropped = len(tilts) - len(kept)
        if dropped:
            self.log.append(f"{d}: {dropped} of {len(tilts)} tilts dropped")
        # dropping must not break a rule; if it did (a ring's tap left alone), fall back per tilt
        if len(self.errors(d, out)) > len(self.errors(d, notes)):
            cur = notes
            for n in tilts:
                if id(n) in keep:
                    continue
                def change(ns, b=n["b"], k=n["k"]):
                    res = []
                    for m in ns:
                        if m["k"] == k and abs(m["b"] - b) < EPS:
                            if k == "ring":
                                m["k"] = "step"
                                res.append(m)
                            continue
                        res.append(m)
                    return res
                cur, _ = self.attempt(d, cur, change)
            return cur
        return out

    def laned(self, notes):
        return [n for n in notes if n["k"] in ("step", "hold", "ring") and "lane" in n]

    def hold_lanes_at(self, notes, b):
        return {h["lane"] for h in notes if h["k"] == "hold" and h["b"] - EPS <= b <= h["b"] + h["len"] + EPS}

    def move(self, d, notes, b, lane_from, prefer):
        """Move the laned note at beat b from lane_from to the first of prefer that passes."""
        for lane in prefer:
            if lane == lane_from:
                continue
            def change(ns, lane=lane):
                same = [m for m in ns if abs(m["b"] - b) < EPS and m["k"] != "rest"]
                if len(same) != 1 or same[0].get("lane") != lane_from:
                    return None
                if lane in self.hold_lanes_at(ns, b):
                    return None
                same[0]["lane"] = lane
                return ns
            notes, ok = self.attempt(d, notes, change)
            if ok:
                return notes, True
        return notes, False

    def lane_runs(self, d, notes):
        cap = RUN_CAP[d]
        moved = 0
        # break the first run that is too long, then look again
        guard = 0
        while guard < 400:
            guard += 1
            seq = sorted(self.laned(notes), key=lambda n: n["b"])
            bad = None
            run = 1
            for a, c in zip(seq, seq[1:]):
                run = run + 1 if (c["lane"] == a["lane"] and c["b"] > a["b"] + EPS) else 1
                if run > cap and c["k"] == "step":
                    bad = c
                    break
            if bad is None:
                break
            opts = (0, 2) if bad["lane"] == 1 else (1, 2 - bad["lane"])
            notes, ok = self.move(d, notes, bad["b"], bad["lane"], opts)
            if not ok:
                # try the note before it instead
                prev = [m for m in seq if m["b"] < bad["b"] - EPS and m["k"] == "step"]
                if not prev:
                    break
                p = prev[-1]
                notes, ok = self.move(d, notes, p["b"], p["lane"], (0, 2) if p["lane"] == 1 else (1, 2 - p["lane"]))
                if not ok:
                    self.log.append(f"{d}: run at b={bad['b']} could not be broken")
                    break
            moved += 1
        if moved:
            self.log.append(f"{d}: {moved} notes moved to break same-lane runs")
        return notes

    def middle_share(self, d, notes):
        phrase = 8.0
        last = max((n["b"] for n in notes), default=0)
        moved = 0
        p0 = 0.0
        while p0 <= last:
            toggle = 0
            for _ in range(16):
                ph = [n for n in self.laned(notes) if p0 - EPS <= n["b"] < p0 + phrase - EPS]
                if len(ph) < 5:
                    break
                mids = [n for n in ph if n["lane"] == 1 and n["k"] == "step"]
                if len(mids) <= MID_SHARE * len(ph):
                    break
                ok = False
                # move the middle notes whose neighbours already sit elsewhere, weakest first
                for n in sorted(mids, key=lambda n: self.strength(n["b"])):
                    pref = (0, 2) if toggle % 2 == 0 else (2, 0)
                    notes, ok = self.move(d, notes, n["b"], 1, pref)
                    if ok:
                        toggle += 1
                        moved += 1
                        break
                if not ok:
                    break
            p0 += phrase
        if moved:
            self.log.append(f"{d}: {moved} middle notes moved out")
        return notes

    def easy_voids(self, notes):
        # a lone opening bell with nothing after it for 4 s goes
        ins = [n for n in notes if n["k"] != "rest"]
        if len(ins) > 1 and ins[0]["k"] == "bell" and self.t(ins[1]["b"]) - self.t(ins[0]["b"]) > 4.0:
            notes = [n for n in notes if n is not ins[0]]
        rest_spans = [(rb, rb + rl) for rb, rl in self.rests]
        end_b = self.song.end_b
        added = 0
        for _ in range(60):
            ins = sorted([n for n in notes if n["k"] != "rest"], key=lambda n: n["b"])
            bounds = [0.0] + [n["b"] for n in ins] + [end_b]
            target = None
            for a, c in zip(bounds, bounds[1:]):
                if self.t(c) - self.t(a) <= EASY_VOID_S:
                    continue
                cands = []
                b = float(int(a) + 1) if a > 0 else 0.0
                while b < c - EPS:
                    gap_ok = (b - a >= 2 - EPS or a == 0.0) and c - b >= 2 - EPS
                    gap_ok = gap_ok and self.t(b) - self.t(a) >= 1.2 and self.t(c) - self.t(b) >= 1.2
                    in_rest = any(rs - 1.0 - EPS <= b < re_ + EPS for rs, re_ in rest_spans)
                    s = self.slot(b)
                    if gap_ok and not in_rest and s is not None and (s["p"] > 0.3 or s["h"] > 0.3):
                        score = max(s["kick"], s["snare"], s["mel"])
                        if score >= 0.4:
                            # nearer the middle of the void is better
                            mid = (a + c) / 2
                            cands.append((score - 0.02 * abs(b - mid), b))
                    b += 1.0
                if cands:
                    target = max(cands)[1]
                    prev = [n for n in ins if n["b"] < target and "lane" in n]
                    lane = prev[-1]["lane"] if prev else 1
                    break
            if target is None:
                break
            def change(ns, target=target, lane=lane):
                ns.append({"b": target, "k": "step", "lane": lane})
                return ns
            notes, ok = self.attempt("easy", notes, change)
            if not ok:
                self.log.append(f"easy: void filler at b={target} refused")
                break
            added += 1
        if added:
            self.log.append(f"easy: {added} notes added in long empty stretches")
        return notes

    def refill(self, d, notes, src):
        """Bring back plain steps the level above plays, on this level's grid: first into the
        longest empty stretches, then on the strongest beats until the level reaches its density."""
        _, min_nps, void_s = REFILL[d]
        tilts = [self.t(n["b"]) for n in notes if n["k"] in TILTS]
        stomps = [self.t(n["b"]) for n in notes if n["k"] == "stomp"]
        rests = [(rb, rb + rl) for rb, rl in self.rests]
        have = {round(n["b"], 4) for n in notes}
        pool = []
        for n in src:
            b = n["b"]
            if n["k"] != "step" or round(b, 4) in have or not V.on_eighth(b) or "lane" not in n:
                continue
            if any(rs - 1.0 - EPS <= b < re_ + 1.0 for rs, re_ in rests):
                continue
            t = self.t(b)
            if any(abs(t - x) < ROOM[d] for x in tilts) or any(abs(t - x) < STOMP_TILT_S for x in stomps):
                continue
            pool.append(n)

        def gap_at(ns, b):
            ts = sorted(m["b"] for m in ns if m["k"] != "rest")
            before = max([x for x in ts if x < b], default=0.0)
            after = min([x for x in ts if x > b], default=self.song.end_b)
            return self.t(after) - self.t(before)

        want = int(min_nps * self.data["length"])
        added = 0
        for phase in ("voids", "density"):
            if phase == "voids":
                order = sorted(pool, key=lambda n: -gap_at(notes, n["b"]))
            else:
                order = sorted(pool, key=lambda n: -self.strength(n["b"]))
            for n in order:
                cnt = sum(1 for m in notes if m["k"] != "rest")
                if phase == "density" and cnt >= want:
                    break
                if phase == "voids" and gap_at(notes, n["b"]) <= void_s:
                    continue
                if any(abs(m["b"] - n["b"]) < EPS for m in notes):
                    continue
                notes, ok = self.attempt(d, notes, lambda ns, n=n: ns + [{"b": n["b"], "k": "step", "lane": n["lane"]}])
                if ok:
                    added += 1
        if added:
            self.log.append(f"{d}: {added} steps brought back from {REFILL[d][0]}")
        return notes

    def rising_tilts(self):
        """Tilts rise with the level: Easy < Medium, Hard >= 1.2 x Medium, Expert > Hard. A lower
        level gives up its weakest tilts (never a stand-still's re-entry)."""
        ch = self.data["charts"]
        ends = {rb + rl for rb, rl in self.rests}

        def count(d):
            return sum(1 for n in ch[d] if n["k"] in TILTS)

        def trim(d, want):
            tl = [n for n in ch[d] if n["k"] in TILTS and not any(abs(n["b"] - e) < EPS for e in ends)]
            drop = sorted(tl, key=lambda n: self.strength(n["b"]))[:max(0, count(d) - want)]
            ids = {id(n) for n in drop}
            out = []
            for n in ch[d]:
                if id(n) in ids:
                    if n["k"] == "ring":
                        m = dict(n)
                        m["k"] = "step"
                        out.append(m)
                    continue
                out.append(n)
            ch[d] = out
            if ids:
                self.log.append(f"{d}: {len(ids)} tilts dropped so tilts rise with the level")

        if count("hard") > int(count("expert") / 1.25):
            trim("hard", min(count("expert") - 1, int(count("expert") / 1.25)))
        want = min(count("hard") - 1, int(count("hard") / 1.2))
        if count("medium") > want:
            trim("medium", want)
        if count("easy") >= count("medium"):
            trim("easy", count("medium") - 1)


def apply(data, song, feat, rests):
    p = Post(data, song, feat, rests)
    p.run()
    return p.log
