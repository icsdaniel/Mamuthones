#!/usr/bin/env python3
"""Charts for recorded songs (Suno and other audio files), written by the same Charter as the
synthesized songs.

A recorded song has no score, so its chart candidates come from the audio: a features file (see
tools/audio/music/audio_features.py) gives, on every sixteenth of a fixed beat grid, how hard the
kick, the snare, the hats and the tune strike there, how loud the tune sounds, and its pitch. From
those this script writes the candidates the Charter needs (pulse, perc, mel, fast, chorus, hold,
bell, stomp, rest), the sections and their energy, and then charts every difficulty with the usual
rules, so a recorded song plays like the others.

    python3 tools/audio/music/audio_charts.py <config.json> [--write]

The config names the song (id, titles, stop, bpm, offset, audio, features file) and may add
stand-stills, density targets and section overrides. With --write the song file goes to
game/data/songs/<id>.json; without it the charts are only validated and summarised.
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, ".."))

import audio_post  # noqa: E402
import charts as C  # noqa: E402
import validate_charts as V  # noqa: E402
from score import Cand, Ev, Section, Song  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))


class AudioSong(Song):
    """A Song whose beat grid comes from a recording: offset is the measured first downbeat."""

    def __init__(self, cfg):
        super().__init__(cfg["id"], cfg["title"]["en"], cfg["title"]["it"], cfg["stop"], "story",
                         cfg["bpm"], 4, cfg.get("key_root", 62), "ionian", sub=2)
        self._offset = cfg["offset"]
        self.mechanics = {"step", "bell", "rest", "hold", "stomp", "ring", "triple"}
        if "targets" in cfg:
            self.targets = cfg["targets"]

    @property
    def offset(self):
        return self._offset

    def root_at(self, b):
        return 1


def metric_rank(b):
    pos = round((b % 4) * 4) / 4
    if abs(pos) < 1e-6:
        return 1
    if abs(pos - 2) < 1e-6:
        return 2
    if abs(pos - round(pos)) < 1e-6:
        return 3
    if abs(pos - int(pos) - 0.5) < 1e-6:
        return 4
    return 5


def candidates(song, feat, cfg):
    """Chart candidates from the features: every one sits on a sound the player hears."""
    th = {"kick": 0.45, "snare": 0.5, "hat": 0.6, "mel": 0.55, "chorus": 0.4, "tune": 0.25,
          "bell": 0.55, "bell_off": 1.1, "bass": 0.6, "hold_next": 0.6, "stomp": 1.0}
    th.update(cfg.get("thresholds", {}))
    S = feat["slots"]
    spb = 60.0 / song.bpm
    # drums have no pitch: give each a register, so the lanes follow kick (left), hats (middle)
    # and snare (right) instead of all sitting where the tune last was
    P_BASS, P_KICK, P_HAT, P_SNARE = 50.0, 55.0, 66.0, 77.0
    # how busy the tune is in each bar (a hold needs a tune that plays, not a drums-only bar)
    tune_bar = {}
    for s in S:
        if s["mel"] >= th["mel"] and s["h"] >= th["tune"]:
            tune_bar[s["i"] // 16] = tune_bar.get(s["i"] // 16, 0) + 1
    end_b = song.end_b
    cands = []
    events = []
    rests = [(r["b"], r["len"]) for r in cfg.get("rests", [])]

    def in_rest(b):
        return any(rb - 1e-6 <= b < rb + rl - 1e-6 for rb, rl in rests)

    def pitch_near(i):
        for j in (i, i + 1, i - 1, i + 2):
            if 0 <= j < len(S) and S[j]["pitch"] is not None:
                return S[j]["pitch"]
        return None

    drop_bars = set()
    for bar in range(len(S) // 16):
        sl = S[bar * 16:bar * 16 + 16]
        if sum(1 for s in sl if s["kick"] >= th["kick"]) <= 1:
            drop_bars.add(bar)

    for i, s in enumerate(S):
        b = s["b"]
        if b >= end_b - 1e-6 or in_rest(b):
            continue
        if i % 2 == 1 and cfg.get("swing"):
            b = round(b + cfg["swing"], 4)    # a swung sixteenth sounds late: the note follows it
        r = metric_rank(b)
        kick = s["kick"] >= th["kick"]
        if kick:
            cands.append(Cand(b, "pulse", max(1, r - (1 if s["kick"] >= 0.9 else 0)), "drums", pitch=P_KICK))
        if not kick and (s["snare"] >= th["snare"] or s["hat"] >= th["hat"]):
            p = P_SNARE if s["snare"] >= th["snare"] and s["snare"] >= s["hat"] else P_HAT
            cands.append(Cand(b, "perc", min(5, r + 1), "drums", pitch=p))
        # the bass line (from stems): its own notes where no kick plays, low on the buttons
        if not kick and s.get("bass", 0.0) >= th["bass"]:
            cands.append(Cand(b, "chorus", min(5, r + 1), "bass", pitch=P_BASS))
        tune = s["h"] >= th["tune"]
        if tune and s["mel"] >= th["mel"]:
            p = pitch_near(i)
            role = "fast" if i % 2 == 1 else "mel"
            rk = max(1, r - (1 if s["mel"] >= 1.0 else 0))
            if i % 4 != 0 and s["mel"] < 0.8:
                rk = min(5, rk + 1)    # a soft onset off the beat is more likely a chop than the hook
            cands.append(Cand(b, role, rk, "tune", pitch=p))
            # how long the note sounds: until the tune's next clear onset, while it keeps sounding
            j = i + 1
            while j < len(S) and S[j]["mel"] < th["hold_next"] and S[j]["h"] >= 0.5 * max(s["h"], 0.3):
                j += 1
            dur = (j - i) / 4
            if p is not None:
                events.append(Ev("lead_pitch", b, max(0.25, dur), p))
            # a hold: a long note (0.8 s or more) that keeps sounding, in a bar where the tune plays
            if j > i + 1:
                sustain = sum(S[k]["h"] for k in range(i + 1, j)) / (j - i - 1)
            else:
                sustain = 0.0
            if dur >= 1.5 and r <= 4 and dur * spb >= 0.8 and sustain >= 0.8 * s["h"] \
                    and tune_bar.get(i // 16, 0) >= 2:
                cands.append(Cand(b, "hold", r, "tune", pitch=p, len=dur))
        elif tune and s["mel"] >= th["chorus"] and r <= 4:
            cands.append(Cand(b, "chorus", min(5, r + 1), "tune", pitch=pitch_near(i)))
        # bells: strong accents on beats; the downbeat after a drop bar and phrase downbeats rank first
        if i % 4 == 0 and s["all"] >= th["bell"]:
            bar = i // 16
            if i % 16 == 0 and ((bar - 1) in drop_bars or bar % 4 == 0):
                br = 1
            elif i % 16 == 0 or (bar in drop_bars and i % 8 == 0):
                br = 2
            elif i % 16 == 8:
                br = 3
            elif s["all"] >= th["bell_off"]:
                br = 4
            else:
                continue
            ring = s["mel"] >= th["mel"]
            cands.append(Cand(b, "bell", br, "drums", ring=ring))
    # stomps: the heaviest unison hits, at most one every two bars, from the busier sections
    heavy = [s for s in S if s["b"] < end_b and not in_rest(s["b"]) and int(s["i"]) % 4 == 0
             and s["kick"] >= th["stomp"] and s["snare"] >= 0.8 * th["stomp"]]
    if len(heavy) < 4:
        # no kick and snare together (boom bap): the loudest backbeat snares instead
        top = sorted(s["all"] for s in S)[int(0.95 * len(S))]
        heavy = [s for s in S if s["b"] < end_b and not in_rest(s["b"]) and int(s["i"]) % 16 in (4, 12)
                 and s["snare"] >= th["stomp"] and s["all"] >= top]
    taken = []
    for s in sorted(heavy, key=lambda s: -(s["kick"] + s["snare"] + s["all"])):
        if song.section_at(s["b"]).energy < 2 or any(abs(s["b"] - o["b"]) < 8 - 1e-6 for o in taken):
            continue
        taken.append(s)
    for k, s in enumerate(sorted(taken, key=lambda s: s["b"])):
        cands.append(Cand(s["b"], "stomp", 1, "drums", dir=1 if k % 2 == 0 else -1))
    for rb, rl in rests:
        cands.append(Cand(rb, "rest", 0, None, len=rl))
    cands.sort(key=lambda c: (c.b, c.role))
    return cands, events


def sections(song, feat, cfg):
    """Four-bar phrases grouped into sections; energy 0..3 from how loud and busy each is."""
    S = feat["slots"]
    nbar = len(S) // 16
    last = cfg.get("end_bar", nbar)
    if "sections" in cfg:
        out = []
        for name, b0, bars, energy in cfg["sections"]:
            out.append(Section(name, b0 * 4.0, bars * 4.0, energy, {}))
        return out
    phr = []
    first = cfg.get("first_bar", 0)
    for b0 in range(first, last, 4):
        b1 = min(b0 + 4, last)
        sl = S[b0 * 16:b1 * 16]
        loud = sum(s["m"] for s in sl) / max(1, len(sl))
        busy = sum(1 for s in sl if s["mel"] >= 0.55 or s["kick"] >= 0.45) / max(1, len(sl))
        phr.append((b0, b1, loud + busy))
    vals = sorted(v for _, _, v in phr)
    def q(x):
        return sum(1 for v in vals if v < x) / max(1, len(vals) - 1)
    out = []
    for k, (b0, b1, v) in enumerate(phr):
        e = 0 if q(v) < 0.2 else (1 if q(v) < 0.5 else (2 if q(v) < 0.8 else 3))
        if k == 0:
            e = 0
        out.append(Section(f"p{k:02d}", b0 * 4.0, (b1 - b0) * 4.0, e, {"listen_bar": True} if k == 0 else {}))
    return out


def build(cfg):
    feat = json.load(open(os.path.join(ROOT, cfg["features"]) if not os.path.isabs(cfg["features"]) else cfg["features"]))
    song = AudioSong(cfg)
    song.sections = sections(song, feat, cfg)
    song.end_b = song.sections[-1].b + song.sections[-1].len
    for sec in song.sections:
        # Expert rings accents, not every beat: the playability pass keeps a tilt budget anyway, and
        # a bell on every beat would crowd out the steps and chords around it first
        sec.opts.setdefault("add", {}).setdefault("expert", {})["bells"] = "accent"
        # Medium plays what Hard's tables pick and Hard what Expert's pick (each on its own grid):
        # with the Charter's tables Medium felt like Easy (Daniele, 2026-10-15)
        e = min(3, sec.energy)
        sec.opts["add"].setdefault("medium", {})["steps"] = C.DEFAULTS["hard"][e]["steps"]
        sec.opts["add"].setdefault("hard", {})["steps"] = [x for x in C.DEFAULTS["expert"][e]["steps"] if x[0] != "fast"]
        sec.opts.update(cfg.get("section_opts", {}).get(sec.name, {}))
    song.cands, song.events = candidates(song, feat, cfg)
    # a swung song's Expert plays its late sixteenths: they sit closer than a sixteenth to the next
    # eighth, so the gap rules shrink by the swing while charting (the validator does the same)
    saved = {k: V.RULES[k]["expert"] for k in ("overall_gap", "hand_gap")}
    for k in saved:
        V.RULES[k]["expert"] = saved[k] - cfg.get("swing", 0.0)
    try:
        charts, _ = C.chart_song(song)
    finally:
        for k, v in saved.items():
            V.RULES[k]["expert"] = v
    # Easy rings at most one bell a phrase (8 beats), however the sections fall on the bars
    last = -99.0
    keep = []
    for n in charts["easy"]:
        if n["k"] == "bell":
            if n["b"] - last < 8.0 - 1e-6:
                continue
            last = n["b"]
        keep.append(n)
    charts["easy"] = keep
    data = {
        "id": cfg["id"], "title": cfg["title"], "stop": cfg["stop"], "kind": "story",
        "bpm": cfg["bpm"], "offset": cfg["offset"], "audio": cfg["audio"],
        "length": cfg["length"], "preview": cfg.get("preview", 30.0), "key_root": cfg.get("key_root", 62),
        "sections": [{"name": s.name, "b": s.b, "len": s.len} for s in song.sections],
        "charts": charts,
    }
    if cfg.get("swing"):
        data["swing"] = cfg["swing"]
    if not cfg.get("raw"):
        rests = [(r["b"], r["len"]) for r in cfg.get("rests", [])]
        for line in audio_post.apply(data, song, feat, rests):
            print("  post", line)
    return song, data


def main(argv):
    cfg = json.load(open(argv[0]))
    song, data = build(cfg)
    alen = V.ogg_length(V.res_to_path(data["audio"]))
    errs, summ = V.check_song(data, alen)
    print(f"{data['id']}: {data['bpm']} bpm, {len(data['sections'])} sections, energies "
          + "".join(str(s.energy) for s in song.sections))
    for d, s in summ.items():
        if s:
            print(f"  {d:<7} {s['notes']:>4} notes  {s['avg_nps']:.2f}/s avg  {s['peak_nps']:.2f}/s peak  "
                  f"{V.fmt_mech(s['mechanics'])}")
    for e in errs[:30]:
        print("  ERROR", e)
    if "--write" in argv:
        out = os.path.join(ROOT, "game", "data", "songs", data["id"] + ".json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        print("wrote", out)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
