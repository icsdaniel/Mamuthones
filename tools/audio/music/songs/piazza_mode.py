"""Piazza mode tracks: bells, crowd, fire and the Issohadores' calls only - no melody.

Each round is the row of Mamuthones jumping in the square. Before every stroke the row's small
bells shake (the cue), then the row lands with a stomp on the beat. The bell crash itself is not in
the music: it is the player's own tilt, so a missed stroke is heard as a missing bell. A soft stomp
keeps every beat; phrases grow from one stroke a bar to syncopated patterns, and a caller announces
each new phrase.
"""
from score import Song

TRACKS = {
    # id: (title en, title it, bpm, fire, crowd, phrases)
    "piazza_fire": ("Round of the Fire", "Giro del fuoco", 92, 0.8, 0.35,
                    ["x...", "x...", "x.x.", "x.x.", "x..x", "..x.", "x.x.", "x.xx", "x...", "x.x."]),
    "piazza_crowd": ("Round of the Crowd", "Giro della folla", 104, 0.3, 0.75,
                     ["x...", "x.x.", "x.x.", "xx..", "x..x", "x.x.", "..xx", "x.x.", "xx.x", "x.x.", "x..x", ".x.x", "x.xx",
                      "x..."]),
    "piazza_dusk": ("Round at Dusk", "Giro al tramonto", 116, 0.5, 0.45,
                    ["x...", "x.x.", "x.x.", "x.xx", ".x.x", "x.x.", "xx.x", ".xx.", "x.x.", "xxx.", "x...", "x.x.",
                     "x.xx", "xx.x", "x.x.", "x..."]),
}


def build(sid):
    title_en, title_it, bpm, fire, crowd, phrases = TRACKS[sid]
    s = Song(sid, title_en, title_it, 0, "piazza", bpm, 4, 60, "ionian")
    s.reverb = {"t60": 1.8, "wet": 0.25, "predelay": 0.03, "bright": 6000,
                "early": ((0.05, 0.3), (0.086, 0.22), (0.12, 0.15))}
    s.mechanics = {"bell"}
    s.tail = 5.0
    # count-in: four light shakes of the small bells, the first stronger
    for i in range(4):
        s.ev("bells", -4 + i, 0.5, None, 0.35 if i else 0.5, count=3, spread=0.01, width=0.3)
    s.ev("fire", -4, 400, None, fire)
    s.ev("crowd", -4, 400, None, crowd)
    # intro: the caller, the crowd answers
    b = s.sec("intro", 2, 0)
    for i in range(8):
        s.ev("stomp", b + i, 1.0, None, 0.3, hit="hit")
    s.ev("calls", b + 1, 0.6, None, 0.9, kind="ohi")
    s.ev("calls", b + 5, 0.6, None, 0.9, kind="aio")
    s.ev("crowd", b + 5.5, 2, None, 0.5, cheer=True)
    # phrases: each is one bar pattern repeated for two bars
    for pi, pat in enumerate(phrases):
        energy = min(3, 1 + pi * 3 // len(phrases))
        b = s.sec(f"round{pi + 1}", 2, energy)
        if pi % 2 == 0:
            s.ev("calls", b - 1.0, 0.6, None, 0.85, kind=["ohi", "hei", "oo"][pi % 3], shift=(pi % 4) - 1)
        for bar in range(2):
            for i, ch in enumerate(pat):
                bb = b + bar * 4 + i
                if ch != "x":
                    s.ev("stomp", bb, 1.0, None, 0.3 + 0.05 * energy, hit="hit")
                    continue
                # the cue: the small bells shake half a beat before; the row lands on the beat
                s.ev("bells", bb - 0.5, 0.5, None, 0.22, count=3, spread=0.02, width=0.4)
                s.ev("stomp", bb, 1.0, None, 0.75 + 0.1 * (i == 0), hit="hit")
                s.cand(bb, "bell", "stomp", rank=1)
        if pi in (3, 7):
            s.ev("crowd", b + 7.3, 2, None, 0.6, cheer=True)
    # ending: three big strokes and the cheer
    b = s.sec("finale", 2, 3)
    s.ev("calls", b - 1, 0.6, None, 1.0, kind="aio")
    for i in (0, 2, 4):
        s.ev("bells", b + i - 0.5, 0.5, None, 0.25, count=3, spread=0.02, width=0.4)
        s.ev("stomp", b + i, 1.0, None, 1.0, hit="hit")
        s.cand(b + i, "bell", "stomp", rank=1)
    # after the last stroke the whole row rings together once the player has
    s.ev("bells", b + 4.5, 2.0, None, 0.35, count=24, spread=0.08)
    s.ev("crowd", b + 4.3, 4, None, 0.8, cheer=True)
    s.preview = s.time(s.sections[2].b)
    return s
