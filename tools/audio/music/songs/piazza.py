"""Stop 6 - The Piazza. Big, loud, fast: the fastest song.

B Aeolian, 144 bpm, 4/4. The launeddas in driving eighths and trills, the tenore chanting, bass
drum on every beat in the climaxes, frame drum sixteenths, the crowd filling the square.
Signature: the trill that opens the tune, F# E F# E F# in sixteenths - across the hands,
lanes 2 0 2 0 1.
Feature: speed.
"""
from score import Song

SIG = "5*:.25 4* 5* 4* 5*:.5 "
TUNE_A = (SIG + "6 5 4 3 4 5:.5 5 6 7 8:1 7:.5 6 " + SIG + "6 5 4 3 2 3:.5 2 1 7, 1:2")
TUNE_B = ("8:.5 8 7 6 7 6 5 4 5:.5 6 7 8 9:1 8:.5 7 8:.5 7 6 5 4 3 4 5 3:.5 2 1 2 1:2")
FAST = ("5:.25 6 5 6 5 4 3 4 5 6 7 8 7 6 5 4 5:.25 6 7 8 9 8 7 6 8:.5 7 6 5 "
        "4:.25 5 4 5 4 3 2 3 4 5 6 5 4 3 2 3 1:.5 2 3 4 5:2")
OST = "1:.25 1 5, 1 3 1 5, 1 1 1 5, 1 3 1 5, 1"
CHANT_A = "1:1 3:1 5:1 5:1 6:1 5:1 4:2 3:1 4:1 5:1 3:1 2:2 1:2"
CHANT_B = "5:1 6:1 7:1 8:1 7:1 6:1 5:2 4:1 5:1 6:1 4:1 5:4"


def build():
    s = Song("piazza", "The Piazza", "La piazza", 6, "story", 144, 4, 59, "aeolian")
    s.reverb = {"t60": 1.6, "wet": 0.2, "predelay": 0.025, "bright": 6500,
                "early": ((0.052, 0.3), (0.083, 0.22), (0.121, 0.15))}
    s.mechanics = {"step", "bell", "rest", "hold", "ring", "swipe", "call"}
    s.signature = {"medium": [2, 0, 2, 0, 1], "hard": [2, 0, 2, 0, 1], "expert": [2, 0, 2, 0, 1]}
    s.countin()
    tumbu = s.key_root - 12
    s.ev("crowd", -4, 400, None, 0.45)

    def harm(bar0, degs):
        for i, d in enumerate(degs):
            s.chord((bar0 + i) * 4, 1, d)

    def pipes(b, bars, tune, vel=0.9, ost=True):
        s.drone("tumbu", b, bars * 4, tumbu, vel=0.5)
        for k in range(0, bars, 4):
            s.melody("mancosedda", b + k * 4, tune, vel=vel, octave=1, hold_min=99, sig_start=0)
            if ost:
                for j in range(4):
                    s.melody("mancosa", b + (k + j) * 4, OST, vel=0.45, octave=1, role="fast", rank_shift=1,
                             hold_min=99)

    # ---- intro: the square roars, the row arrives, the drum starts
    b = s.sec("intro", 4, 0, chart=None)
    harm(0, [1, 1, 1, 1])
    for i in range(8):
        s.ev("bells", b + i * 2, 1, None, 0.15 + 0.06 * i, count=10, spread=0.05, width=0.7)
    s.drone("tumbu", b + 8, 8, tumbu, vel=0.5)
    s.drums(b + 8, 2, "B...B...B...B...", cands=False)
    s.ev("crowd", b + 12, 4, None, 0.5, cheer=True)

    # ---- A1: the tune
    b = s.sec("tune1", 8, 1)
    harm(b // 4, [1, 1, 6, 7, 1, 1, 6, 7])
    pipes(b, 4, TUNE_A)
    pipes(b + 16, 4, TUNE_B)
    s.drums(b, 8, "B.......B.......")
    s.drums(b, 8, "....t.t.....t.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)

    # ---- A2: the tenore joins, bass drum on every beat
    b = s.sec("tune2", 8, 2)
    harm(b // 4, [1, 1, 6, 7, 1, 1, 6, 7])
    pipes(b, 4, TUNE_A)
    pipes(b + 16, 4, TUNE_B)
    s.tenore(b, 32, "rhythm", pattern="x...o...x...o.o.", vowels="aoia", vel=0.8)
    s.drums(b, 8, "B...B...B...B...")
    s.drums(b, 8, "..t...t...t.t.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=bar % 2 == 0)
        if bar % 2 == 1:
            s.offcall(b + bar * 4 + 3.5)

    # ---- chant: the boghe and tenore over big drum strokes, long chords to hold
    b = s.sec("chant1", 8, 1)
    harm(b // 4, [1, 1, 4, 4, 6, 6, 7, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.45)
    s.melody("boghe", b, CHANT_A, vel=0.95)
    s.melody("boghe", b + 16, CHANT_B, vel=0.95)
    for k in range(4):
        s.tenore(b + k * 8, 8, "drone", vowels=["o", "a", "o", "e"][k], vel=0.85)
    s.drums(b, 8, "B.......B...b.b.")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
    s.stop(b + 30, 2)

    # ---- A3: the tune with throws and shouts
    b = s.sec("tune3", 8, 2)
    harm(b // 4, [1, 1, 6, 7, 1, 1, 6, 7])
    pipes(b, 4, TUNE_B)
    pipes(b + 16, 4, TUNE_A)
    s.tenore(b, 32, "rhythm", pattern="x.o.x...x.o.x.o.", vowels="aoia", vel=0.85)
    s.drums(b, 8, "B...B...B...B...")
    s.drums(b, 8, "t.t.t.t.t.t.t.tt")
    for bar in range(8):
        if bar in (3, 7):
            s.ev("calls", b + bar * 4 - 1, 0.6, None, 0.85, kind="ohi")
            s.rope(b + bar * 4, 1 if bar == 3 else -1)
        else:
            s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        if bar % 2 == 0:
            s.offcall(b + bar * 4 + 1.5)

    # ---- halt: the square holds its breath (the crowd carries on)
    b = s.sec("halt", 4, 1)
    harm(b // 4, [1, 1, 1, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.5)
    for bar in range(4):
        s.melody("mancosedda", b + bar * 4, "5:.25 4 5 4 5 4 5 4 8:1 r:1", vel=0.95, octave=1, hold_min=99)
        s.drums(b + bar * 4, 1, "B...B...B.......")
        s.bell_cue(b + bar * 4 + 2, rank=1, ring=True)
        s.stop(b + bar * 4 + 3, 1)
    s.ev("crowd", b + 3.2, 2, None, 0.5, cheer=True)
    s.ev("crowd", b + 11.2, 2, None, 0.5, cheer=True)

    # ---- build: sixteenths on the pipes, the drum climbs
    b = s.sec("build", 8, 2)
    harm(b // 4, [1, 1, 6, 6, 7, 7, 5, 5])
    pipes(b, 4, FAST, vel=0.95)
    pipes(b + 16, 4, FAST, vel=1.0)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.o.x.o.x.o.", vowels="aoia", vel=0.85)
    s.drums(b, 8, "B...B...B...B...", fill="B.B.B.B.BBBBBBBB")
    s.drums(b, 8, "t.tTt.tTt.tTt.tT")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
        s.bell_cue(b + bar * 4 + 2, rank=3, big=False)

    # ---- climax 1: everything, the tune at full tilt
    b = s.sec("climax1", 8, 3)
    harm(b // 4, [1, 1, 6, 7, 1, 1, 6, 7])
    pipes(b, 4, TUNE_A, vel=1.0)
    pipes(b + 16, 4, TUNE_B, vel=1.0)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.oox.o.x.oo", vowels="aoiao", vel=0.95)
    s.drums(b, 8, "B...B...B...B...")
    s.drums(b, 8, "t.ttT.t.t.ttT.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
        s.bell_cue(b + bar * 4 + 2, rank=2 if bar % 2 else 3)
        s.ev("bells", b + bar * 4 + 1, 1, None, 0.25, count=10)
    s.ev("crowd", b, 32, None, 0.65)

    # ---- chant 2: a breath before the end, higher
    b = s.sec("chant2", 8, 2)
    harm(b // 4, [1, 1, 4, 4, 6, 6, 7, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.5)
    s.melody("boghe", b, CHANT_B, vel=1.0)
    s.melody("boghe", b + 16, CHANT_A, vel=1.0, octave=1)
    s.tenore(b, 32, "rhythm", pattern="x.......x...o.o.", vowels="oaoe", vel=0.9)
    s.drums(b, 8, "B.......B...B...")
    s.drums(b, 8, "....t.t.....t.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
    s.ev("calls", b + 15, 0.6, None, 0.85, kind="hei")
    s.rope(b + 16, 1)
    s.stop(b + 30, 2)

    # ---- climax 2: the fast figure over everything
    b = s.sec("climax2", 8, 3)
    harm(b // 4, [1, 1, 6, 7, 1, 6, 7, 1])
    pipes(b, 4, FAST, vel=1.0)
    pipes(b + 16, 4, TUNE_A, vel=1.0)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.oox.o.x.oo", vowels="aoiao", vel=1.0)
    s.drums(b, 8, "B...B...B..BB...")
    s.drums(b, 8, "ttttT.t.t.ttTttt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
        s.bell_cue(b + bar * 4 + 2, rank=2)
        s.ev("bells", b + bar * 4 + 3, 1, None, 0.25, count=10)
    s.ev("crowd", b, 32, None, 0.7)

    # ---- outro: last strokes and the roar
    b = s.sec("outro", 4, 1)
    harm(b // 4, [1, 1, 1, 1])
    s.drone("tumbu", b, 8, tumbu, vel=0.5)
    s.melody("mancosedda", b, SIG + "6 5 4 3 4 1:4", vel=1.0, octave=1, sig_start=0, hold_min=99)
    s.drums(b, 2, "B...B...B...B...")
    s.bell_cue(b, rank=1, ring=True)
    s.bell_cue(b + 4, rank=1)
    s.tenore(b + 8, 1, "rhythm", pattern="x...............", vowels="a", vel=1.0)
    s.drums(b + 8, 1, "B...............")
    s.bell_cue(b + 8, rank=1)
    s.stop(b + 9, 3)
    s.bell_cue(b + 12, rank=1)
    s.tenore(b + 12, 4, "drone", vowels="a", vel=0.8, sustain_cands=False)
    s.ev("crowd", b + 12.2, 8, None, 0.7, cheer=True)
    s.tail = 6.0
    s.preview = s.time(s.section("climax1").b)
    return s
