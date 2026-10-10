"""Stop 2 - Sant'Antonio's Fires (16 January). First appearance: slow and heavy.

A Aeolian, 68 bpm, 4/4. The full tenore (a heavy bassu), a big bass drum walking on 1 and 3, a
frame drum, the bonfire, and the procession's bells arriving from far away in the intro.
Signature: the boghe's sigh that opens every phrase, E up to F and back down (5 b6 5 4).
Chart mechanics: steps, bells, stand-stills (the procession halts at the end of each phrase).
"""
from score import Song

A1 = "5*:2 6*:1 5*:.5 4*:.5 5:3 r:1 4:1 3:.5 2:.5 3:1 4:1 3:.5 2:.5 1:1 r:2"
A2 = "5*:2 6*:1 5*:.5 4*:.5 6:3 r:1 5:1 4:.5 3:.5 4:1 2:1 3:.5 2:.5 1:1 r:2"
B1 = "1':2 7:1 6:1 5:2 6:1 5:.5 4:.5 3:1 4:1 5:1 4:.5 3:.5 2:2 r:2"
B2 = "1':2 2':1 1':1 7:2 6:1 5:1 4:1 5:.5 4:.5 3:1 2:1 1:2 r:2"


# Easy walks on beats 1 and 3 of every bar (the slow procession step), about 0.57 notes a second
EASY_WALK = {"easy": dict(steps=[("pulse", 3)])}


def build():
    s = Song("fires", "Sant'Antonio's Fires", "I fuochi di Sant'Antonio", 2, "story", 68, 4, 57, "aeolian")
    s.reverb = {"t60": 2.2, "wet": 0.22, "predelay": 0.03, "bright": 4500}
    s.mechanics = {"step", "bell", "rest"}
    s.signature = {"medium": [1, 2, 1, 0], "hard": [1, 2, 1, 0], "expert": [1, 2, 1, 0]}
    s.targets = {"easy": 0.82}
    s.countin()
    s.tail = 7.0
    s.ev("fire", -6, 200, None, 0.55)

    def harm(b0, degs):
        for i, d in enumerate(degs):
            s.chord(b0 + i * 4, 1, d)

    # ---- intro: the fire, the bells coming closer at walking pace, the bassu enters
    b = s.sec("intro", 2, 0, chart=None)
    harm(b, [1, 1])
    for i in range(8):
        s.ev("bells", b + i, 1, None, 0.12 + 0.05 * i, count=8, spread=0.05, width=0.6)
    s.tenore(b + 4, 4, "drone", vowels="o", vel=0.6, parts=("bassu",), sustain_cands=False)
    s.drums(b + 4, 1, "B.......b.......", cands=False)

    # ---- verse 1: drone chords, the boghe's first phrases, the heavy walk
    b = s.sec("verse1", 8, 1, add=EASY_WALK)
    harm(b, [1, 1, 1, 1, 1, 1, 7, 1])
    s.tenore(b, 32, "drone", vowels="oa", vel=0.75)
    s.melody("boghe", b, A1, vel=0.85, sig_start=0)
    s.melody("boghe", b + 16, A2, vel=0.85, sig_start=0)
    s.drums(b, 8, "B.......b.......")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
    # verse 1 flows on without a halt: the first stand-still is the end of verse 2 (a shake inside)

    # ---- verse 2: the tenore turns rhythmic, the frame drum joins, the answer phrases (higher)
    b = s.sec("verse2", 8, 2, add=EASY_WALK)
    harm(b, [1, 1, 7, 1, 1, 1, 7, 1])
    s.tenore(b, 32, "rhythm", pattern="x.......x...o.o.", vowels="oaoe", vel=0.8)
    s.melody("boghe", b, B1, vel=0.9)
    s.melody("boghe", b + 16, B2, vel=0.9)
    s.drums(b, 8, "B...t...B...t...")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        if bar % 2 == 1 and bar != 7:
            s.bell_cue(b + bar * 4 + 2, rank=3, big=False)
    s.stop(b + 30, 2, tempt="shake")

    # ---- build: the harmony climbs (bVI bVII bVI bVII iv v), drums double, a roll into the stop
    b = s.sec("build", 8, 2, add=EASY_WALK)
    harm(b, [6, 6, 7, 7, 6, 6, 4, 5])
    s.tenore(b, 32, "rhythm", pattern="x...o.o.x...o.o.", vowels="aoae", vel=0.85)
    s.melody("boghe", b, A1, vel=0.9, sig_start=0)
    s.melody("boghe", b + 16, "5*:2 6*:1 5*:.5 4*:.5 6:2 7:2 1':1 7:.5 6:.5 5:1 6:1 7:2 r:2", vel=0.95, sig_start=0)
    s.drums(b, 8, "B...b...B...b...", fill="B...b...B.b.bbbb")
    s.drums(b, 8, "..t.T.t...t.T.t.", fill="..t.T.t.TtTtTTTT")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        s.bell_cue(b + bar * 4 + 2, rank=3, big=False) if bar < 7 else None
    s.stop(b + 30, 2)

    # ---- climax: everything, the melody an octave up, the row's bells behind the beat
    b = s.sec("climax", 8, 3, chart={"hard": dict(steps=[("pulse", 4), ("mel", 5), ("chorus", 5), ("perc", 5)])})
    harm(b, [1, 1, 7, 1, 6, 7, 4, 1])
    s.tenore(b, 32, "rhythm", pattern="x...o.o.x.o.o.o.", vowels="aoae", vel=0.95)
    s.melody("boghe", b, A1, vel=1.0, octave=1, sig_start=0)
    s.melody("boghe", b + 16, B2, vel=1.0)
    s.drums(b, 8, "B...B...B..bB...")
    s.drums(b, 8, ["t.ttT.t.t.ttT.tt", "ttttT.t.t.ttTttt"])
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        s.bell_cue(b + bar * 4 + 2, rank=2 if bar % 2 else 3)
        s.ev("bells", b + bar * 4 + 1, 1, None, 0.35, count=10, spread=0.04)
        s.ev("bells", b + bar * 4 + 3, 1, None, 0.3, count=10, spread=0.04)
    # the break: the whole row stops dead in the middle of the run, and comes back in on the bar
    s.stop(b + 14, 2, tempt="shake")

    # ---- outro: back to the drone, one last halt, the last stroke, the bells walk away
    b = s.sec("outro", 4, 1)
    harm(b, [1, 1, 1, 1])
    s.tenore(b, 8, "drone", vowels="oa", vel=0.75)
    s.melody("boghe", b, "5*:2 6*:1 5*:.5 4*:.5 3:.5 2:.5 1:3", vel=0.85, sig_start=0)
    s.drums(b, 2, "B.......b.......")
    s.bell_cue(b, rank=1)
    s.bell_cue(b + 8, rank=1)
    s.tenore(b + 8, 1, "rhythm", pattern="x...............", vowels="o", vel=0.9)
    s.stop(b + 9, 2)
    s.bell_cue(b + 12, rank=1)
    s.tenore(b + 12, 4, "drone", vowels="o", vel=0.7, sustain_cands=False)
    for i in range(6):
        s.ev("bells", b + 13 + i * 2, 1, None, 0.4 - 0.06 * i, count=8, spread=0.05, width=0.6)
    s.preview = s.time(s.section("climax").b)
    return s
