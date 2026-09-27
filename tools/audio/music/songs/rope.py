"""Stop 5 - The Rope. The Issohadores work the crowd: playful, calls and throws.

E Dorian, 116 bpm, 4/4. A skipping launeddas tune over the drone, light frame drum, the crowd,
the Issohadores' calls and the crack of the rope, the tenore answering the boghe.
Signature: the tune's skipping figure (dotted eighth, sixteenth: B C# B G), lanes 2 0 2 1: a left-right bounce like the rope.
Chart mechanics introduced here: rope swipes and off-beat calls (Hard and Expert).
"""
from score import Song

SKIP = "5*:.75 6*:.25 5*:.5 3*:.5 "
TUNE_A = (SKIP + "4:.75 5:.25 4:.5 2:.5 3:.75 4:.25 5:.5 7:.5 6:1 5:1 "
          + SKIP + "4:.75 5:.25 6:.5 7:.5 8:.5 7:.25 6:.25 5:.5 4:.5 5:2")
TUNE_B = ("8:.75 7:.25 8:.5 6:.5 7:.75 6:.25 5:.5 4:.5 3:.75 4:.25 5:.5 3:.5 2:1 1:1 "
          + SKIP + "4:.75 5:.25 6:.5 7:.5 4:.5 3:.25 2:.25 3:.5 2:.5 1:2")
FAST = ("5:.25 6 5 6 5 4 3 4 5:.5 3 5 7 8:.25 7 6 5 6 5 4 3 4:.5 2 3 4 "
        "5:.25 6 5 6 5 4 3 4 5:.5 7 8 7 8:.25 7 6 5 4 3 2 3 1:2")
OST = "1:.5 3 1 4 1 3 2 3"
VERSE = "5:1 4:.5 3:.5 4:1 5:1 6:1 5:.5 4:.5 5:2"          # the boghe's question (2 bars)
VERSE2 = "5:1 6:.5 7:.5 8:1 7:1 6:1 5:.5 4:.5 3:2"


def build():
    s = Song("rope", "The Rope", "La fune", 5, "story", 116, 4, 64, "dorian")
    s.reverb = {"t60": 1.2, "wet": 0.15, "predelay": 0.02, "bright": 7000,
                "early": ((0.035, 0.2), (0.058, 0.15))}
    s.mechanics = {"step", "bell", "rest", "hold", "ring", "swipe", "call"}
    s.signature = {"medium": [2, 0, 2, 1], "hard": [2, 0, 2, 1], "expert": [2, 0, 2, 1]}
    s.countin()
    tumbu = s.key_root - 24
    s.ev("crowd", -4, 400, None, 0.35)

    def harm(bar0, degs):
        for i, d in enumerate(degs):
            s.chord((bar0 + i) * 4, 1, d)

    def pipes(b, bars, tune, vel=0.9, ost=True):
        s.drone("tumbu", b, bars * 4, tumbu, vel=0.5)
        for k in range(0, bars, 4):
            s.melody("mancosedda", b + k * 4, tune, vel=vel, hold_min=99, sig_start=0)
            if ost:
                for j in range(4):
                    s.melody("mancosa", b + (k + j) * 4, OST, vel=0.5, role="fast", rank_shift=1, hold_min=99)

    def throw(b, direction, cheer=False):
        s.ev("calls", b - 1, 0.6, None, 0.85, kind="ohi" if direction > 0 else "hei")
        s.rope(b, direction)
        if cheer:
            s.ev("crowd", b + 0.25, 3, None, 0.5, cheer=True)

    # ---- intro: the crowd, the drone, a first throw, laughter
    b = s.sec("intro", 4, 0, chart=None)
    harm(0, [1, 1, 1, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.45)
    s.ev("calls", b + 3, 0.6, None, 0.8, kind="ohi")
    s.ev("rope", b + 4, 0.5, None, 0.8, dir=1)
    s.ev("crowd", b + 4.25, 3, None, 0.5, cheer=True)
    s.melody("mancosa", b + 8, OST + " " + OST, vel=0.5, cands=False)
    s.drums(b + 12, 1, "D...t.t.D.t.t.t.", cands=False)

    # ---- tune A: skipping pipes, off-beat shouts from the row
    b = s.sec("tune1", 8, 1)
    harm(b // 4, [1, 1, 4, 1, 1, 1, 4, 1])
    pipes(b, 8, TUNE_A)
    s.drums(b, 8, ["D...t.t.D.t.t...", "D...t.t.D.t.t.t."])
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        if bar % 2 == 1:
            s.offcall(b + bar * 4 + 3.5)

    # ---- the rope: call, crack, laughter - the pipes answer each throw
    b = s.sec("throws1", 8, 1)
    harm(b // 4, [1, 1, 4, 1, 1, 1, 4, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.5)
    for k in range(4):
        s.melody("mancosedda", b + k * 8 + 2, "5:.25 6 5 6 5:.5 3 4:.25 5 4 5 4:.5 2", vel=0.8, hold_min=99)
        s.melody("mancosedda", b + k * 8 + 6, "3:.5 4 5 7 8:.5 7 6 5", vel=0.8, hold_min=99)
        throw(b + k * 8, 1 if k % 2 == 0 else -1, cheer=True)
    s.drums(b, 8, "D.......D.t.t...")
    for bar in range(8):
        if bar % 2 == 1:
            s.bell_cue(b + bar * 4, rank=1)

    # ---- tune A again with the tenore's shouts, throws every four bars
    b = s.sec("tune2", 8, 2)
    harm(b // 4, [1, 1, 4, 1, 1, 1, 4, 1])
    pipes(b, 8, TUNE_B)
    s.tenore(b, 32, "rhythm", pattern="x.......x...o...", vowels="oaoe", vel=0.7)
    s.drums(b, 8, ["D...t.t.D.t.t...", "D.t.t.t.D.t.t.t."])
    for bar in range(8):
        if bar % 4 != 0:
            s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        if bar % 2 == 1:
            s.offcall(b + bar * 4 + 1.5)
            s.offcall(b + bar * 4 + 3.5)
    throw(b, 1)
    throw(b + 16, -1)
    s.stop(b + 29, 3)

    # ---- question and answer: the boghe asks, the tenore answers (holds), someone gets caught
    b = s.sec("answer", 8, 1)
    harm(b // 4, [1, 1, 4, 5, 1, 1, 7, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.4)
    for k in range(2):
        s.melody("boghe", b + k * 16, VERSE if k == 0 else VERSE2, vel=0.9)
        s.tenore(b + k * 16 + 8, 8, "rhythm", pattern="x...x...x.x.x---", vowels="oaoe", vel=0.85)
        s.offcall(b + k * 16 + 9.5)
        s.offcall(b + k * 16 + 13.5)
    s.drums(b, 8, "D.......D.......")
    for bar in range(0, 8, 2):
        s.bell_cue(b + bar * 4, rank=1)
    throw(b + 28, 1, cheer=True)

    # ---- tune A3: the pipes and the tenore together, a throw at each phrase end
    b = s.sec("tune3", 8, 2)
    harm(b // 4, [1, 1, 4, 1, 1, 1, 4, 1])
    pipes(b, 8, TUNE_A)
    s.tenore(b, 32, "rhythm", pattern="x...o...x...o.o.", vowels="aoia", vel=0.75)
    s.drums(b, 8, ["D.t.t.t.D.t.t...", "D.t.t.t.D.t.t.t."])
    for bar in range(8):
        if bar % 4 != 3:
            s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=bar % 2 == 0)
        if bar % 2 == 0:
            s.offcall(b + bar * 4 + 3.5)
    throw(b + 12, -1)
    throw(b + 28, 1)

    # ---- build: throws come faster, the fast figure, the crowd louder
    b = s.sec("build", 8, 2)
    harm(b // 4, [1, 1, 4, 4, 7, 7, 5, 5])
    pipes(b, 8, FAST, vel=0.95)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.o.x.o.x.o.", vowels="aoia", vel=0.8)
    s.drums(b, 8, "D.t.t.t.D.t.t.t.", fill="D.t.t.t.DtTtTTTT")
    for bar in range(8):
        if bar % 2 == 1:
            throw(b + bar * 4, 1 if (bar // 2) % 2 == 0 else -1)
        else:
            s.bell_cue(b + bar * 4, rank=1, ring=True)
        s.offcall(b + bar * 4 + 2.5)
    s.ev("crowd", b, 32, None, 0.5)
    s.stop(b + 29, 3, tempt="shake")

    # ---- climax: everything - the tune at full tilt, throws, shouts, leaps
    b = s.sec("climax", 8, 3)
    harm(b // 4, [1, 1, 4, 1, 1, 4, 7, 1])
    pipes(b, 4, TUNE_A, vel=1.0)
    pipes(b + 16, 4, FAST, vel=1.0)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.oox.o.x.oo", vowels="aoiao", vel=0.9)
    s.drums(b, 8, "D.ttT.t.D.ttT.tt")
    s.drums(b, 8, "B.......B.......")
    for bar in range(8):
        if bar in (3, 7):
            throw(b + bar * 4, 1 if bar == 3 else -1, cheer=True)
        else:
            s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
            s.bell_cue(b + bar * 4 + 2, rank=3)
            if bar in (0, 1, 4, 5):
                # Expert's extra: an off-beat bell on the "and" of four
                s.bell_cue(b + bar * 4 + 3.5, rank=3, big=False)
        s.offcall(b + bar * 4 + 1.5)
    s.ev("crowd", b, 32, None, 0.6)

    # ---- outro: one last throw, the halt, the final stroke and laughter
    b = s.sec("outro", 4, 1)
    harm(b // 4, [1, 1, 1, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.5)
    s.melody("mancosedda", b, SKIP + "4:.75 5:.25 4:.5 2:.5 1:2 r:2", vel=0.85, sig_start=0, hold_min=99)
    s.drums(b, 2, "D...t.t.D.t.t...")
    s.bell_cue(b, rank=1)
    throw(b + 8, -1)
    s.stop(b + 9, 3)
    s.bell_cue(b + 12, rank=1)
    s.ev("crowd", b + 12.25, 3, None, 0.5, cheer=True)   # laughter after the halt, not inside it
    s.tenore(b + 12, 4, "drone", vowels="o", vel=0.75, sustain_cands=False)
    s.tail = 6.0
    s.preview = s.time(s.section("climax").b)
    return s
