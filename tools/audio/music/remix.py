"""Remixes: each story song rearranged in a modern style on the same beat grid.

The remix is written from the song's own score, so the same charts work:
- the song's melodies (boghe, mancosedda) become a synth lead, the mancosa ostinato an arpeggio;
- the tenore's syllables become chopped vocals (a slice of the song's own tenore stem, retriggered
  on every syllable and re-pitched to the chord);
- the song's drum strokes are translated to a modern kit (so every beat the charts follow is
  still struck), and a style groove is laid on top;
- pads and a sub bass follow the song's harmony track; rests stay silent; the rim clicks that
  announce bells, the rope and the calls are kept.
"""
from __future__ import annotations

import copy

from score import Song

STYLES = {
    # kick, snare, hat patterns are one bar (16 steps; 12 for compound songs); '.' is silence
    "workshop": dict(name="lo-fi hip hop", kick="x.......x.x.....", snare="....x.......x...",
                     hat="x.x.x.x.x.x.x.x.", sub="x-------x-------", swing=0.1, pad_cut=1100, lead="pluck",
                     chop_shift=0, kick_style="punch", snare_style="snare", lead_oct=0, crackle=True),
    "fires": dict(name="half-time trap", kick="x.........x.....", snare="........x.......",
                  hat="xxxxxxxxxxxxxxxx", sub="x---------x-----", swing=0.0, pad_cut=900, lead="square",
                  chop_shift=-12, kick_style="808", snare_style="clap", lead_oct=0, rolls=True),
    "bonfires": dict(name="afro house", kick="x..x..x..x..", snare="...x.....x..", hat="xxxxxxxxxxxx",
                     sub="x.x..x.x..x.", swing=0.0, pad_cut=2200, lead="pluck", chop_shift=12,
                     kick_style="punch", snare_style="clap", lead_oct=0),
    "carnival": dict(name="deep house", kick="x...x...x...x...", snare="....x.......x...",
                     hat="..x...x...x...x.", sub="..x-..x-..x-..x-", swing=0.0, pad_cut=1600, lead="pluck",
                     chop_shift=0, kick_style="punch", snare_style="clap", lead_oct=0, stabs=True),
    "rope": dict(name="UK garage", kick="x.........x.....", snare="....x.......x...", hat="x.xxx.x.x.xxx.x.",
                 sub="x..x..x...x..x..", swing=0.12, pad_cut=2000, lead="pluck", chop_shift=12,
                 kick_style="punch", snare_style="snare", lead_oct=0),
    "piazza": dict(name="breakbeat", kick="x.........x.x...", snare="....x.......x...", hat="x.x.x.x.x.x.x.x.",
                   sub="x---x---x---x---", swing=0.0, pad_cut=1400, lead="square", chop_shift=0,
                   kick_style="punch", snare_style="snare", lead_oct=0, reese=True),
    "shrove": dict(name="big room", kick="x...x...x...x...", snare="....x.......x...", hat="xxxxxxxxxxxxxxxx",
                   sub="x.x.x.x.x.x.x.x.", swing=0.0, pad_cut=4000, lead="square", chop_shift=12,
                   kick_style="punch", snare_style="clap", lead_oct=0),
}

VOICES = ("bassu", "contra", "mesu")


def build(song: Song, stems: dict) -> Song:
    st = STYLES[song.id]
    r = Song(song.id + "_remix", song.title["en"] + " (remix)", song.title["it"] + " (remix)", song.stop_no,
             song.kind, song.bpm, song.bpb, song.key_root, song.mode, sub=song.sub,
             countin_beats=song.countin_beats, lead=song.lead, tail=max(4.0, min(song.tail, 6.0)))
    r.sections = copy.deepcopy(song.sections)
    r.stops = list(song.stops)
    r.harm = list(song.harm)
    r.end_b = song.end_b
    r.remix_style = st
    r.chop_source = {k: stems[k] for k in ("bassu", "boghe") if k in stems}
    r.reverb = {"t60": 1.1, "wet": 0.14, "predelay": 0.012, "bright": 8000}
    r.mix = {"frame": 0.8}
    r.source = song
    spb = song.bpb
    steps = len(st["kick"])
    step_b = spb / steps

    # count-in: the same sticks as the song, so the lead-in is identical
    for e in song.events:
        if e.inst == "count":
            r.ev("count", e.b, e.dur, None, e.vel, **e.p)

    energy_at = {}
    for sec in song.sections:
        energy_at[sec.name] = sec.energy

    def energy(b):
        return song.section_at(b).energy

    def in_stop(b):
        return any(sb - 1e-6 <= b < sb + sl - 1e-6 for (sb, sl) in song.stops)

    # ---- 1. translate the song's own strokes (every beat the charts follow stays audible)
    for e in song.events:
        if e.inst == "bass" or e.inst == "stomp":
            r.ev("kick", e.b, 0.5, None, e.vel * 0.95, style=st["kick_style"])
        elif e.inst == "frame":
            h = e.p.get("hit")
            if h == "dum":
                r.ev("kick", e.b, 0.5, None, e.vel * 0.7, style="punch")
            elif h == "tak":
                r.ev("hat", e.b, 0.25, None, 0.5 + 0.5 * e.vel)
            elif h == "slap":
                r.ev("snare", e.b, 0.25, None, e.vel * 0.9, style="clap")
            elif h == "rim":
                r.ev("frame", e.b, 0.25, None, e.vel, hit="rim", cue=True)   # the bell cue, unchanged
        elif e.inst == "clap":
            r.ev("snare", e.b, 0.25, None, e.vel * 0.8, style="clap")
        elif e.inst in ("rope", "calls"):
            r.ev(e.inst, e.b, e.dur, e.pitch, e.vel, **e.p)
        elif e.inst == "bells" and e.p.get("tempt"):
            r.ev("bells", e.b, e.dur, e.pitch, e.vel, **e.p)   # the stand-still's temptation

    # ---- 2. the style groove on top, by section energy. Every section line is heard: the groove
    # drops out in the last bar before it (a snare fill builds instead), an impact marks the new
    # section, and a section at the same energy as the one before takes a variation (half-time kick,
    # no hats, the lead an octave up), so the layers come in and out.
    have = {(e.inst, round(e.b, 4)) for e in r.events}
    secs = [x for x in song.sections]
    # the remix's own energy per section: the tutorial's lessons (all calm in the song) alternate
    # between a light and a fuller groove, and "together" is its climax
    eff = {x.name: x.energy for x in secs}
    if song.kind == "tutorial":
        lessons = [x for x in secs if x.name.startswith("lesson")]
        for i, x in enumerate(lessons):
            eff[x.name] = 1 + i % 2
        for x in secs:
            if x.name == "together":
                eff[x.name] = 3
    r.variation = {}
    r.automation = []
    for si, sec in enumerate(secs):
        e_ = eff[sec.name]
        prev = secs[si - 1] if si > 0 else None
        nxt = secs[si + 1] if si + 1 < len(secs) else None
        var = bool(prev is not None and eff[prev.name] == e_ and si % 2 == 1 and e_ < 3)
        r.variation[sec.name] = var
        if var:
            r.automation.append((sec.b, sec.b + sec.len, -5.0, ("pad", "chop")))
        elif e_ <= 1:
            r.automation.append((sec.b, sec.b + sec.len, -3.0, ("pad", "lead")))
        if si > 0 and e_ >= 1 and not in_stop(sec.b):
            r.ev("impact", sec.b, 2, None, 0.5 if e_ < 3 else 0.9)
        nbars = int(sec.len // spb)
        for bar in range(nbars):
            b0 = sec.b + bar * spb
            pre_drop = nxt is not None and bar == nbars - 1 and eff[nxt.name] >= 1 and e_ >= 1
            if pre_drop:
                # the music pulls back for the fill: pads, voices and lead dip, then the new section
                # lands with everything at once
                r.automation.append((b0 + spb / 2, b0 + spb, -12.0, ("pad", "sub", "lead", "arp", "chop")))
                # the fill: snare eighths, then sixteenths on the last beat, rising
                nf = 8 if song.sub == 2 else 6
                for k in range(nf):
                    fb = b0 + spb / 2 + k * (spb / 2) / nf
                    if not in_stop(fb):
                        r.ev("snare", fb, 0.25, None, 0.35 + 0.6 * k / nf, style=st["snare_style"])
            for i in range(steps):
                b = b0 + i * step_b
                if in_stop(b):
                    continue
                if pre_drop and b >= b0 + spb / 2 - 1e-6:
                    continue
                sw = st["swing"] * step_b * 2 if (i % 2 == 1 and song.sub == 2) else 0.0
                kick_on = st["kick"][i] == "x" and (not var or i == 0)
                if e_ >= 1 and kick_on and ("kick", round(b, 4)) not in have:
                    r.ev("kick", b, 0.5, None, 0.9, style=st["kick_style"])
                if e_ >= 2 and st["snare"][i] == "x" and ("snare", round(b, 4)) not in have:
                    r.ev("snare", b, 0.5, None, 0.85, style=st["snare_style"])
                if e_ >= 1 and st["hat"][i] == "x" and not var:
                    r.ev("hat", b + sw, 0.25, None, 0.35 + (0.25 if i % 4 == 0 else 0.0), open=st.get("stabs") and i % 4 == 2)
                    if st.get("rolls") and e_ >= 3 and i % 8 == 7:
                        for k in range(1, 3):
                            r.ev("hat", b + k * step_b / 3, 0.1, None, 0.3)
            # sub bass on the chord root
            root = song.root_at(b0)
            base = song.pitch(root) - 24
            if st.get("reese"):
                base -= 0
            pat = st["sub"]
            sstep = spb / len(pat)
            i = 0
            if e_ >= 2 and not pre_drop and not var:
                while i < len(pat):
                    if pat[i] == "x":
                        j = i + 1
                        while j < len(pat) and pat[j] == "-":
                            j += 1
                        b = b0 + i * sstep
                        if not in_stop(b):
                            r.ev("sub", b, (j - i) * sstep * 0.95, base, 0.9)
                        i = j
                    else:
                        i += 1
        # risers into climaxes, an impact on the first beat
        if e_ >= 3:
            r.ev("riser", sec.b - 2 * spb, 2 * spb, None, 0.8)

    def eff_at(b):
        return eff[song.section_at(b).name]

    # ---- 3. harmony: pads on every chord (stabs for house)
    for (hb, hl, deg) in song.harm:
        if hb >= song.end_b:
            continue
        notes = [song.pitch(deg) - 12, song.pitch(deg + 2) - 12, song.pitch(deg + 4) - 12, song.pitch(deg) ]
        if st.get("stabs") and energy(hb) >= 1:
            for k in range(int(hl // 1)):
                b = hb + k + 0.5
                if not in_stop(b):
                    r.ev("pad", b, 0.35, None, 0.8, notes=notes, attack=0.005)
        else:
            # a chord is held until a stand-still cuts it, then comes back after the rest
            cuts = sorted([hb, hb + hl] + [x for (sb, sl) in song.stops for x in (sb, sb + sl)
                                           if hb < x < hb + hl])
            for a, z in zip(cuts, cuts[1:]):
                if z - a > 0.25 and not in_stop(a):
                    r.ev("pad", a, z - a, None, (0.35, 0.45, 0.6, 0.85)[min(3, eff_at(a))], notes=notes,
                         attack=0.2 if a == hb else 0.05)

    # ---- 4. melodies: the lead sings the boghe and the mancosedda; the mancosa becomes an arp
    for e in song.events:
        if e.inst in ("boghe", "mancosedda") and e.pitch is not None:
            p = e.pitch + 12 * st["lead_oct"] + (12 if r.variation.get(song.section_at(e.b).name) else 0)
            while p > 84:
                p -= 12
            r.ev("lead", e.b, e.dur, p, 0.8 * e.vel)
            if eff_at(e.b) >= 3 and p + 12 <= 96:
                r.ev("lead", e.b, e.dur, p + 12, 0.35 * e.vel)   # the climax doubles the hook
        elif e.inst == "mancosa" and e.pitch is not None:
            r.ev("arp", e.b, min(e.dur, 0.5), e.pitch + 12, 0.5 * e.vel)

    # ---- 5. chopped voices on every tenore syllable, re-pitched to the chord
    src = next((e for e in song.events if e.inst == "bassu" and e.p.get("syll")), None)
    src_b = next((e for e in song.events if e.inst == "boghe"), None)
    for e in song.events:
        if e.inst != "bassu":
            continue
        dur_s = min(0.28, e.dur * song.spb * 0.9)
        if e.p.get("syll") and src is not None:
            r.ev("chop", e.b, e.dur, None, 0.9 * e.vel, stem="bassu", src_s=int(song.time(src.b) * 44100 - 0.03 * 44100),
                 src_len=dur_s + 0.03, pre=0.03, shift=(e.pitch - src.pitch) + st["chop_shift"])
        elif e.p.get("drone") and src_b is not None:
            # a long chord becomes a held, filtered vocal slice from the boghe
            r.ev("chop", e.b, e.dur, None, 0.6 * e.vel, stem="boghe",
                 src_s=int(song.time(src_b.b) * 44100 - 0.05 * 44100), src_len=min(0.6, e.dur * song.spb) + 0.05,
                 pre=0.05, shift=(e.pitch + 24 - src_b.pitch) % 12 - 12 + st["chop_shift"])

    if st.get("crackle"):
        r.ev("fire", -4, 400, None, 0.25)
    for e in song.events:
        if e.inst == "crowd" and song.id == "piazza":
            r.ev("crowd", e.b, e.dur, None, e.vel * 0.6, **e.p)
    r.cands = song.cands
    return r


STEM_MAP = {
    "boghe": "lead", "mancosedda": "lead", "mancosa": "arp",
    "bassu": "chop", "contra": "chop", "mesu": "chop",
    "bass": "kick", "stomp": "kick", "clap": "snare", "rope": "rope", "calls": "calls",
}


def remix_sources(rsong, sources):
    """Which remix stem sounds each chart note (for the timing check on the remix)."""
    song = rsong.source
    frame_hits = {round(e.b, 4): e.p.get("hit") for e in song.events if e.inst == "frame"}
    out = {}
    for d, lst in sources.items():
        res = []
        for (b, k, stem, ln) in lst:
            if stem == "frame":
                h = frame_hits.get(round(b, 4))
                stem2 = {"dum": "kick", "tak": "hat", "slap": "snare", "rim": "frame"}.get(h, "kick")
            else:
                stem2 = STEM_MAP.get(stem, stem)
            res.append((b, k, stem2, ln))
        out[d] = res
    return out
