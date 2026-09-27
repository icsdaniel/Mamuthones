"""Stop 7 - Shrove Tuesday (the last procession). The finale: everything.

D Mixolydian, 126 bpm, 4/4. The Workshop's theme comes back, brightened (F# and C natural), on
the launeddas and the whole tenore; the walk from Carnival Sunday, the ballu lilt from the
bonfires, the rope, a triplet climax, and at the end the voice alone again as the procession walks
away into the night.
Signature: the theme's rising fourth and turn, D G A B A (lanes 0 1 2 2 1).
Feature: everything, triplets and triple rings at Expert.
"""
from score import Song

THEME = "1*:1 4*:1.5 5*:.5 6*:1 5*:.5 4:.5 5:2 4:.5 3 2 3 4:1 3:.5 2 1:3 r:2"
THEME_PIPE = "1*:1 4*:1.5 5*:.5 6*:1 5*:.5 4:.5 5:2 4:.5 3 2 3 4:1 3:.5 2 1:3 5,:.5 7,"
THEME_B = "5:1 7:1.5 6:.5 5:1 4:.5 3:.5 4:2 3:.5 2 1 7,:.5 1:1 2:1 1:4 r:1"
T = "1/3"
TRIP = (f"1*:1 4*:1 5*:{T} 6* 5* 6*:1 5:{T} 4 5 3:{T} 4 5 4:{T} 3 2 3:{T} 2 1 "
        f"5:{T} 6 7 8:1 7:{T} 6 5 6:1 5:{T} 4 3 4:{T} 3 2 1:2")
NODA = "5:.5 6 5 3 5:1 6:.5 5 4:.5 5 4 2 4:1 5:.5 4 3:.5 4 5 6 7 6 5 4 3:1 2:.5 3 1:2"
FAST = ("5:.25 6 7 8 7 6 5 6 5 6 7 8 9 8 7 6 8:.25 7 6 5 6 5 4 3 4:.5 5 6 5 "
        "5:.25 6 5 6 5 6 5 6 7:.5 6 5 4 3:.25 4 3 2 3 2 1 2 1:2")
OST = "1:.5 3 1 3 1 3 2 3"
WALK = "B...B...B......."
BALLU = "x-ox-ox-ox-o"


def build():
    s = Song("shrove", "Shrove Tuesday", "Martedì grasso", 7, "story", 126, 4, 62, "mixolydian")
    s.reverb = {"t60": 1.8, "wet": 0.2, "predelay": 0.025, "bright": 6500,
                "early": ((0.047, 0.25), (0.079, 0.2), (0.11, 0.12))}
    s.mechanics = {"step", "bell", "rest", "hold", "ring", "swipe", "call", "triple"}
    s.signature = {"medium": [0, 1, 2, 2, 1], "hard": [0, 1, 2, 2, 1], "expert": [0, 1, 2, 2, 1]}
    s.countin()
    tumbu = s.key_root - 24
    s.ev("fire", -4, 30, None, 0.35)
    s.ev("crowd", 12, 400, None, 0.3)

    def harm(bar0, degs):
        for i, d in enumerate(degs):
            s.chord((bar0 + i) * 4, 1, d)

    def pipes(b, bars, tune, vel=0.9, ost=True, octave=0):
        s.drone("tumbu", b, bars * 4, tumbu, vel=0.5)
        for k in range(0, bars, 4):
            s.melody("mancosedda", b + k * 4, tune, vel=vel, octave=octave, hold_min=99, sig_start=0)
            if ost:
                for j in range(4):
                    s.melody("mancosa", b + (k + j) * 4, OST, vel=0.5, role="fast", rank_shift=1, hold_min=99)

    # ---- intro: the voice alone, as in the workshop, now in the bright mode
    b = s.sec("intro", 4, 0, chart=None)
    harm(0, [1, 1, 1, 1])
    s.melody("boghe", b, THEME, vel=0.8, cands=False)
    s.drums(b + 12, 1, "D...D...D...D.t.", cands=False)

    # ---- the theme on the launeddas, the tenore underneath
    b = s.sec("theme", 8, 1)
    harm(b // 4, [1, 4, 5, 1, 1, 4, 5, 1])
    pipes(b, 8, THEME_PIPE)
    s.tenore(b, 32, "rhythm", pattern="x.......x...o...", vowels="oaoe", vel=0.75)
    s.drums(b, 8, "D...t...D...t.t.")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)

    # ---- the walk of Carnival Sunday: step, step, leap
    b = s.sec("walk", 8, 2)
    harm(b // 4, [1, 1, 5, 1, 1, 1, 5, 1])
    pipes(b, 8, NODA)
    s.drums(b, 8, WALK, sig=False)
    s.drums(b, 8, "..t...t.t.t.T.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4 + 2, rank=1 if bar % 2 == 0 else 2, ring=True)
        if bar % 2 == 1:
            s.offcall(b + bar * 4 + 3.5)

    # ---- the bonfire's lilt: the tenore in triplets, the boghe sings the theme's answer
    b = s.sec("lilt", 8, 2)
    harm(b // 4, [1, 1, 7, 1, 4, 1, 7, 1])
    s.tenore(b, 32, "rhythm", pattern=BALLU, vowels="oaoi", vel=0.85)
    s.melody("boghe", b, THEME_B, vel=0.95)
    s.melody("boghe", b + 16, THEME, vel=0.95, sig_start=0)
    s.drone("tumbu", b, 32, tumbu, vel=0.45)
    s.drums(b, 8, "D.tD.tD.tD.t")
    s.drums(b, 8, "P.....P.....")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, land="stomp")

    # ---- the rope: throws and shouts over the pipes
    b = s.sec("rope", 8, 2)
    harm(b // 4, [1, 1, 4, 1, 1, 1, 7, 1])
    pipes(b, 8, NODA, vel=0.9)
    s.tenore(b, 32, "rhythm", pattern="x...o...x...o.o.", vowels="aoia", vel=0.8)
    s.drums(b, 8, "D.t.t.t.D.t.t.t.")
    for bar in range(8):
        if bar % 2 == 1:
            s.ev("calls", b + bar * 4 - 1, 0.6, None, 0.85, kind="ohi" if bar % 4 == 1 else "hei")
            s.rope(b + bar * 4, 1 if bar % 4 == 1 else -1)
        else:
            s.bell_cue(b + bar * 4, rank=1, ring=True)
        s.offcall(b + bar * 4 + 2.5)

    # ---- halt: the procession stops; the long chords of the tenore (holds) between
    b = s.sec("halt", 4, 1)
    harm(b // 4, [1, 4, 5, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.5)
    for bar in range(4):
        s.tenore(b + bar * 4, 2, "drone", vowels="oa"[bar % 2], vel=0.9)
        s.melody("boghe", b + bar * 4, ["5:2", "6:2", "7:2", "8:2"][bar], vel=0.9)
        s.drums(b + bar * 4, 1, "B...............")
        s.stop(b + bar * 4 + 2, 2, tempt=("call", "shake", "call", "shake")[bar])
    s.bell_cue(b + 16, rank=1)

    # ---- build: the fast figure, drums climbing
    b = s.sec("build", 8, 2)
    harm(b // 4, [1, 1, 4, 4, 7, 7, 5, 5])
    pipes(b, 8, FAST, vel=0.95)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.o.x.o.x.o.", vowels="aoia", vel=0.85)
    s.drums(b, 8, "B...B...B...B...", fill="B.B.B.B.BBBBBBBB")
    s.drums(b, 8, "t.tTt.tTt.tTt.tT", fill="tttTtttTTTTTTTTT")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
        s.bell_cue(b + bar * 4 + 2, rank=3, big=False)

    # ---- climax in triplets: the theme in 12/8 over everything, triple rings on the leaps
    b = s.sec("climax", 8, 3)
    harm(b // 4, [1, 4, 5, 1, 1, 4, 5, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.55)
    s.melody("mancosedda", b, TRIP, vel=1.0, hold_min=99, sig_start=0)
    s.melody("mancosedda", b + 16, TRIP, vel=1.0, hold_min=99, sig_start=0)
    s.melody("mancosa", b, " ".join(["1:1/3 3 5"] * 32), vel=0.5, role="fast", rank_shift=0, hold_min=99)
    s.tenore(b, 32, "rhythm", pattern="x-ox-ox-ox-o", vowels="aoiao", vel=0.95)
    s.drums(b, 8, "B..B..B..B..")
    s.drums(b, 8, ["D.tDttD.tDtt", "DttDttDttDtt"])
    for bar in range(8):
        c = s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
        if bar % 2 == 0:
            c.tag = "triple"
        s.bell_cue(b + bar * 4 + 2, rank=2)
        s.ev("bells", b + bar * 4 + 1, 1, None, 0.25, count=12)
    s.ev("crowd", b, 32, None, 0.55)

    # ---- final: straight again, the theme on everything, the last big push
    b = s.sec("final", 8, 3)
    harm(b // 4, [1, 4, 5, 1, 1, 4, 5, 1])
    pipes(b, 4, THEME_PIPE, vel=1.0)
    pipes(b + 16, 4, FAST, vel=1.0)
    s.melody("boghe", b, THEME, vel=1.0, cands=False)
    s.tenore(b, 32, "rhythm", pattern="x.o.x.oox.o.x.oo", vowels="aoiao", vel=1.0)
    s.drums(b, 8, "B...B...B..BB...")
    s.drums(b, 8, "t.ttT.t.t.ttT.tt")
    for bar in range(8):
        c = s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, ring=True)
        if bar % 4 == 3:
            c.tag = "triple"
        s.bell_cue(b + bar * 4 + 2, rank=2)
        if bar % 2 == 1:
            s.offcall(b + bar * 4 + 3.5)
    s.ev("calls", b + 27, 0.6, None, 0.85, kind="ohi")
    s.rope(b + 28, 1)
    s.ev("crowd", b, 32, None, 0.65)

    # ---- outro: the voice alone with the theme, the bells walk away into the night
    b = s.sec("outro", 6, 0)
    harm(b // 4, [1, 1, 1, 1, 1, 1])
    s.melody("boghe", b, THEME, vel=0.8, hold_min=99)
    s.tenore(b, 16, "drone", vowels="oa", vel=0.6, sustain_cands=False)
    s.drums(b, 3, "D.......d.......")
    s.bell_cue(b, rank=1)
    s.bell_cue(b + 8, rank=1)
    s.stop(b + 14, 2)
    s.bell_cue(b + 16, rank=1, land="frame")
    s.melody("boghe", b + 16, "1:8@o", vel=0.7, cands=False)
    for i in range(8):
        s.ev("bells", b + 17 + i * 2, 1, None, 0.45 - 0.05 * i, count=10, spread=0.05, width=0.6)
    s.ev("fire", b, 40, None, 0.3)
    s.tail = 10.0
    s.preview = s.time(s.section("climax").b)
    return s
