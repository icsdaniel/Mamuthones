"""Written scores: songs as lists of timed events plus the chart candidates they create.

A song is written once, in beats. Each helper that writes music (a melody, a drum pattern, a
tenore chord, a bell cue, a stop, a rope throw) also records *chart candidates*: the audible
events a chart note may sit on, with the stem that plays them, their metric weight (rank) and
their pitch. The charter (charts.py) only ever places notes on these candidates, so every
note has a sound under it.

Beat 0 is the first downbeat after the count-in; the count-in lives at negative beats.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
}

# Default drum alphabet for pattern strings: char -> (instrument, hit, velocity)
DRUM_KEYS = {
    "D": ("frame", "dum", 1.0), "d": ("frame", "dum", 0.6),
    "T": ("frame", "tak", 1.0), "t": ("frame", "tak", 0.55),
    "S": ("frame", "slap", 1.0), "s": ("frame", "slap", 0.6),
    "k": ("frame", "rim", 0.7), "K": ("frame", "rim", 1.0),
    "B": ("bass", "hit", 1.0), "b": ("bass", "hit", 0.6),
    "P": ("stomp", "hit", 1.0), "p": ("stomp", "hit", 0.6),
    "C": ("clap", "hit", 1.0), "c": ("clap", "hit", 0.6),
}


@dataclass
class Ev:
    inst: str
    b: float
    dur: float = 0.25
    pitch: float | None = None
    vel: float = 1.0
    p: dict = field(default_factory=dict)


@dataclass
class Cand:
    b: float
    role: str          # pulse, perc, mel, fast, chorus, hold, bell, rest, swipe, call
    rank: int          # 1 strongest (downbeat) .. 5 weakest
    stem: str | None   # instrument whose onset sits exactly at b (None for rests)
    pitch: float | None = None
    len: float = 0.0
    dir: int = 0
    sig: int | None = None      # index inside the song's signature motif
    ring: bool = False          # a bell here may be written as a full ring (step + bell)
    tag: str = ""


@dataclass
class Section:
    name: str
    b: float
    len: float
    energy: int
    opts: dict


class Song:
    def __init__(self, id, title_en, title_it, stop, kind, bpm, bpb, key_root, mode, sub=2,
                 countin_beats=None, lead=0.5, tail=3.5):
        self.id = id
        self.title = {"en": title_en, "it": title_it}
        self.stop_no = stop
        self.kind = kind
        self.bpm = bpm
        self.bpb = bpb              # beats per bar
        self.sub = sub              # 2 = simple (eighths are half beats), 3 = compound (thirds)
        self.key_root = key_root
        self.mode = mode
        self.scale = MODES[mode]
        self.countin_beats = countin_beats if countin_beats is not None else bpb
        self.lead = lead
        self.tail = tail
        self.events: list[Ev] = []
        self.cands: list[Cand] = []
        self.sections: list[Section] = []
        self.stops: list[tuple[float, float]] = []
        self.harm: list[tuple[float, float, int]] = []   # (b, len, root degree) for tenore/remix
        self.lessons: list[dict] = []
        self.signature: dict = {}      # difficulty -> list of lanes for sig notes
        self.mechanics = {"step", "bell", "rest"}
        self.reverb = {"t60": 1.6, "wet": 0.18}
        self.remix_style = None
        self.preview = None
        self.end_b = 0.0
        self.mix = {}                  # per-instrument gain overrides

    # ------------------------------------------------------------ time and pitch
    @property
    def spb(self):
        return 60.0 / self.bpm

    @property
    def offset(self):
        return self.lead + self.countin_beats * self.spb

    def time(self, b):
        return self.offset + b * self.spb

    def pitch(self, deg, octave=0, alter=0):
        """Scale degree (1-based, may run past 7 or below 1) to MIDI."""
        d = deg - 1
        return self.key_root + self.scale[d % 7] + 12 * (d // 7) + 12 * octave + alter

    def rank_of(self, b):
        pos = round((b % self.bpb) * 12) / 12
        if abs(pos) < 1e-6:
            return 1
        if self.bpb == 4 and abs(pos - 2) < 1e-6:
            return 2
        if abs(pos - round(pos)) < 1e-6:
            return 3
        frac = pos - int(pos)
        if self.sub == 2 and abs(frac - 0.5) < 1e-6:
            return 4
        if abs(frac - 1 / 3) < 1e-6 or abs(frac - 2 / 3) < 1e-6:
            return 4    # triplet eighths: compound meter, or a triplet passage in a straight song
        return 5

    # ------------------------------------------------------------ structure
    def sec(self, name, bars, energy, **opts):
        b = self.sections[-1].b + self.sections[-1].len if self.sections else 0.0
        s = Section(name, b, bars * self.bpb, energy, opts)
        self.sections.append(s)
        self.end_b = s.b + s.len
        return b

    def section(self, name):
        return next(s for s in self.sections if s.name == name)

    def section_at(self, b):
        for s in self.sections:
            if s.b <= b + 1e-6 < s.b + s.len:
                return s
        return self.sections[-1]

    def lesson(self, topic, b, beats):
        self.lessons.append({"topic": topic, "b": b, "len": beats})

    # ------------------------------------------------------------ primitive writers
    def ev(self, inst, b, dur=0.25, pitch=None, vel=1.0, **p):
        e = Ev(inst, b, dur, pitch, vel, p)
        self.events.append(e)
        return e

    def cand(self, b, role, stem, rank=None, **kw):
        c = Cand(b, role, self.rank_of(b) if rank is None else rank, stem, **kw)
        self.cands.append(c)
        return c

    def chord(self, b, bars_or_beats, root_deg, beats=False):
        ln = bars_or_beats if beats else bars_or_beats * self.bpb
        self.harm.append((b, ln, root_deg))

    def root_at(self, b):
        r = 1
        for (hb, hl, deg) in self.harm:
            if hb <= b + 1e-6:
                r = deg
        return r

    # ------------------------------------------------------------ notation
    TOKEN = re.compile(r"^(r|[#b]?-?\d+)([',]*)(?::([\d./]+))?(?:@([a-z]+))?([~!*^h]*)$")

    def parse(self, text, dur=1.0, vowel="a"):
        """Tokens like 5  5':.5  b2,:1/3@o  r:2  3~ (legato)  1! (accent)  6* (signature note)
        Durations persist until changed; vowels persist too. Returns (offset, dur, midi|None,
        vowel, flags) tuples with offsets relative to the start."""
        out = []
        t = 0.0
        for tok in text.split():
            fl = "".join(ch for ch in tok if ch in "~!*^h")
            tok = "".join(ch for ch in tok if ch not in "~!*^h") + fl
            m = self.TOKEN.match(tok)
            if not m:
                raise ValueError(f"bad token {tok!r} in {self.id}")
            head, octs, d, v, flags = m.groups()
            if d:
                dur = eval(d) if "/" in d else float(d)  # noqa: S307 - our own score text
            if v:
                vowel = v
            if head == "r":
                t += dur
                continue
            alter = 0
            if head[0] == "#":
                alter, head = 1, head[1:]
            elif head[0] == "b":
                alter, head = -1, head[1:]
            octave = octs.count("'") - octs.count(",")
            out.append((t, dur, self.pitch(int(head), octave, alter), vowel, flags))
            t += dur
        return out, t

    # ------------------------------------------------------------ musical helpers
    def melody(self, inst, b0, text, vel=0.85, octave=0, dur=1.0, vowel="a", role="mel",
               sig_start=None, hold_min=1.5, cands=True, rank_shift=0, **p):
        """Writes a monophonic line; every note is a chart candidate on its own stem."""
        notes, total = self.parse(text, dur, vowel)
        sig_i = sig_start
        for (t, d, midi, v, flags) in notes:
            b = b0 + t
            acc = "!" in flags
            self.ev(inst, b, d, midi + 12 * octave, vel * (1.15 if acc else 1.0), vowel=v,
                    legato="~" in flags, accent=acc, **p)
            if not cands:
                continue
            rk = min(5, max(1, self.rank_of(b) + rank_shift - (1 if acc else 0)))
            c = self.cand(b, role, inst, rank=rk, pitch=midi + 12 * octave, len=d)
            if "*" in flags and sig_i is not None:
                c.sig = sig_i
                sig_i += 1
            if d >= hold_min or "h" in flags:
                self.cand(b, "hold", inst, rank=rk, pitch=midi + 12 * octave, len=d)
        return total

    def drums(self, b0, bars, pattern, keys=None, vel=1.0, cands=True, fill=None, sig=False):
        """pattern: one string per bar (or one repeated); len/bpb chars per beat.
        '.' is silence; letters come from DRUM_KEYS (or keys)."""
        keys = {**DRUM_KEYS, **(keys or {})}
        pats = pattern if isinstance(pattern, list) else [pattern]
        for bar in range(bars):
            pat = pats[bar % len(pats)].replace(" ", "")
            if fill and bar == bars - 1:
                pat = fill.replace(" ", "")
            step = self.bpb / len(pat)
            k = 0
            for i, ch in enumerate(pat):
                if ch == ".":
                    continue
                inst, hit, v = keys[ch]
                b = b0 + bar * self.bpb + i * step
                self.ev(inst, b, step, None, v * vel, hit=hit)
                if cands:
                    role = "pulse" if hit in ("dum", "hit") and inst in ("frame", "bass", "stomp") else "perc"
                    rk = self.rank_of(b)
                    if v < 0.8:
                        rk = min(5, rk + 1)
                    c = self.cand(b, role, inst, rank=rk)
                    if sig:
                        c.sig = k
                        k += 1
        return bars * self.bpb

    def bell_cue(self, b, rank=2, ring=False, cue="rim", land=True, big=True):
        """An accent the player's bell can land on, with an audible cue half a beat before.

        The landing is a bass drum hit (plus the procession's own weight); the cue is a bright
        rim click (or a call) so the player hears the bell coming."""
        land_inst = land if isinstance(land, str) else "bass"
        if land:
            hit = "dum" if land_inst == "frame" else "hit"
            ex = self.find(land_inst, b)
            if ex:
                ex.vel = max(ex.vel, 1.0 if big else 0.85)
                ex.p["hit"] = hit
            else:
                self.ev(land_inst, b, 0.5, None, 1.0 if big else 0.85, hit=hit)
        if cue == "rim":
            cb = b - (0.5 if self.sub == 2 else 1 / 3)
            ex = self.find("frame", cb)
            if ex and ex.p.get("hit") == "slap":
                ex.p["cue"] = True  # an off-beat shout is already a strong cue
            elif ex:
                ex.p["hit"] = "rim"
                ex.p["cue"] = True
                ex.vel = 0.9
            else:
                self.ev("frame", cb, 0.25, None, 0.9, hit="rim", cue=True)
        elif cue == "call":
            self.ev("calls", b - 1.0, 0.6, None, 0.8, kind="ohi", cue=True)
        return self.cand(b, "bell", land_inst if land else "bass", rank=rank, ring=ring)

    def find(self, inst, b):
        for e in self.events:
            if e.inst == inst and abs(e.b - b) < 1e-6:
                return e
        return None

    MIN_REST = 2.0

    def stop(self, b, beats, tempt=None, at=0.5):
        """A real musical rest: every non-sustaining instrument is silent in [b, b+beats). A stand-still
        lasts at least two beats. tempt puts something inside it the player must not answer:
        "call" (an Issohadore's shout) or "shake" (the small bells shaking like a bell cue), at b+at."""
        assert beats >= self.MIN_REST - 1e-9, f"stand-still at b={b} is shorter than {self.MIN_REST} beats"
        self.stops.append((b, beats))
        self.cand(b, "rest", None, rank=1, len=beats)
        if tempt == "call":
            self.ev("calls", b + at, 0.6, None, 0.8, kind="hei", tempt=True)
        elif tempt == "shake":
            self.ev("bells", b + at, 0.5, None, 0.22, count=3, spread=0.02, width=0.4, tempt=True)

    def rope(self, b, direction):
        """The Issohadore throws the rope: a whoosh that ends in a crack exactly on b."""
        self.ev("rope", b, 0.5, None, 1.0, dir=direction)
        self.cand(b, "swipe", "rope", rank=2, dir=direction)

    def offcall(self, b, vel=1.0):
        """Off-beat accent: a frame drum slap with a short shout from the row."""
        self.ev("frame", b, 0.25, None, 0.95 * vel, hit="slap")
        self.ev("calls", b, 0.4, None, 0.55 * vel, kind="hup")
        self.cand(b, "call", "frame", rank=4)

    def tenore(self, b0, beats, style="drone", pattern=None, vowels="aoe", vel=0.8, mesu=12,
               sustain_cands=True, parts=("bassu", "contra", "mesu"), rank_shift=0):
        """The tenore chorus (bassu, contra, mesu boghe) on the harmony track.

        drone: one sustained chord per harmony change; rhythm: syllables on the pattern
        ('x' strong, 'o' weak, '-' extend, '.' rest), one char per step."""
        vw = list(vowels)
        if style == "drone":
            changes = sorted({b0} | {hb for (hb, hl, d) in self.harm if b0 < hb < b0 + beats})
            changes.append(b0 + beats)
            for i in range(len(changes) - 1):
                cb, ce = changes[i], changes[i + 1]
                root = self.root_at(cb)
                base = self.pitch(root) - 24
                v = vw[i % len(vw)]
                for part in parts:
                    pitch = base + {"bassu": 0, "contra": 7, "mesu": mesu}[part]
                    self.ev(part, cb, ce - cb, pitch, vel * {"bassu": 1.0, "contra": 0.8, "mesu": 0.7}[part],
                            vowel=v, legato=False, drone=True)
                if sustain_cands:
                    self.cand(cb, "hold", "bassu", pitch=base, len=ce - cb)
            return
        pat = pattern.replace(" ", "")
        step = self.bpb / len(pat)
        nbars = int(round(beats / self.bpb))
        k = 0
        for bar in range(nbars):
            i = 0
            while i < len(pat):
                ch = pat[i]
                if ch not in "xo":
                    i += 1
                    continue
                j = i + 1
                while j < len(pat) and pat[j] == "-":
                    j += 1
                b = b0 + bar * self.bpb + i * step
                d = (j - i) * step
                root = self.root_at(b)
                base = self.pitch(root) - 24
                v = vw[k % len(vw)]
                k += 1
                strong = ch == "x"
                for part in parts:
                    pitch = base + {"bassu": 0, "contra": 7, "mesu": mesu}[part]
                    self.ev(part, b, d * 0.92, pitch,
                            vel * (1.0 if strong else 0.7) * {"bassu": 1.0, "contra": 0.8, "mesu": 0.7}[part],
                            vowel=v, legato=False, syll=True)
                rk = min(5, self.rank_of(b) + rank_shift + (0 if strong else 1))
                self.cand(b, "chorus", "bassu", rank=rk, pitch=base, len=d)
                if d >= 1.5 and sustain_cands:
                    self.cand(b, "hold", "bassu", rank=rk, pitch=base, len=d)
                i = j

    def drone(self, inst, b0, beats, pitch, vel=0.6, **p):
        self.ev(inst, b0, beats, pitch, vel, drone=True, **p)

    def auto_fills(self):
        """A frame-drum pickup in the last beat of a section that leads into an equal or bigger one,
        so sections join with a musical transition (skipped where the music stands still)."""
        if self.kind != "story":
            return
        for a, z in zip(self.sections, self.sections[1:]):
            if z.energy < max(1, a.energy) or a.opts.get("chart", "default") is None:
                continue
            end = z.b
            span = 1.0 if self.sub == 2 else 1.0
            step = 0.25 if self.sub == 2 else 1 / 3
            if any(sb < end and sb + sl > end - span for (sb, sl) in self.stops):
                continue
            if not any(e.inst == "frame" and a.b <= e.b < end for e in self.events):
                continue
            k = 0
            t = end - span
            while t < end - 1e-6:
                if not self.find("frame", t):
                    self.ev("frame", t, step, None, 0.45 + 0.15 * k, hit="tak", fill=True)
                k += 1
                t += step

    def finalize(self):
        """Fills between sections. Stand-stills keep their full length: a bell's cue (the rim click or
        call half a beat before a bell that follows the rest) still sounds inside them, and so do the
        temptations - everything else is silent."""
        self.auto_fills()
        for (sb, sl) in self.stops:
            assert sl >= self.MIN_REST - 1e-9, f"{self.id}: stand-still at b={sb} is {sl} beats"
        return self

    def countin(self, style="rim"):
        """One bar (or countin_beats) of clicks before beat 0, accent on the first."""
        n = self.countin_beats
        for i in range(n):
            b = -n + i
            self.ev("count", b, 0.25, None, 1.0 if i % self.bpb == 0 else 0.7, hit=style)
