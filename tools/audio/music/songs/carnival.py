"""Stop 4 - Carnival Sunday. The full procession: launeddas and tenore.

F Ionian, 108 bpm, 4/4. The launeddas (tumbu drone on F, mancosa ostinato, mancosedda figures in
repeated, varied "nodas"), the tenore with a procession song, bass and frame drums.
Signature: the procession's walk, "step, step, leap": bass drum on 1 and 2, the leap on 3
(lanes 0, 2, then a full ring in the middle at Hard and Expert).
Chart mechanic introduced here: full rings (step and bell together) at Hard.
"""
from score import Song

NODA1 = "5:.5 6 5 3 5:1 6:.5 5 4:.5 5 4 2 4:1 5:.5 4 3:.5 4 5 6 7 6 5 4 3:1 2:.5 3 1:2"
NODA2 = ("5:.25 6 5 6 5:.5 3 5:.25 6 5 6 5:.5 3 4:.25 5 4 5 4:.5 2 4:.25 5 4 5 4:.5 2 "
         "3:.5 4 5 6 7:.25 6 7 6 5:.5 4 3:.5 2 3 2 1:2")
NODA3 = ("5:.25 6 7 8 7 6 5 6 5 6 7 8 9 8 7 6 8:.25 7 6 5 6 5 4 3 4:.5 5 6 5 "
         "5:.25 6 5 6 5 6 5 6 7:.5 6 5 4 3:.5 4 3 2 1:2")
OST = "1:.5 3 1 3 1 3 2 3"          # mancosa: the bouncing middle pipe
SONG1 = "1:1 3:1 5:1.5 4:.5 3:1 2:1 1:2 3:1 5:1 6:1.5 5:.5 4:1 3:1 2:2"
SONG2 = "5:1 6:1 5:1.5 4:.5 3:1 4:1 5:2 6:1 5:.5 4:.5 3:1 2:1 1:4"
WALK = "B...B...B......."


def build():
    s = Song("carnival", "Carnival Sunday", "Domenica di Carnevale", 4, "story", 108, 4, 65, "ionian")
    s.reverb = {"t60": 1.3, "wet": 0.16, "predelay": 0.02, "bright": 7000,
                "early": ((0.041, 0.25), (0.067, 0.18), (0.093, 0.12))}
    s.mechanics = {"step", "bell", "rest", "hold", "ring"}
    s.signature = {"medium": [0, 2, 1], "hard": [0, 2, 1], "expert": [0, 2, 1]}
    s.countin()
    tumbu = s.key_root - 24

    def harm(bar0, degs):
        for i, d in enumerate(degs):
            s.chord((bar0 + i) * 4, 1, d)

    def launeddas(b, bars, noda, ost=True, vel=0.85):
        s.drone("tumbu", b, bars * 4, tumbu, vel=0.55)
        for k in range(0, bars, 4):
            s.melody("mancosedda", b + k * 4, noda, vel=vel, role="mel", hold_min=99)
            if ost:
                for j in range(4):
                    s.melody("mancosa", b + (k + j) * 4, OST, vel=0.55, role="fast", rank_shift=1, hold_min=99)

    def walk(b, bars, rank_even=1):
        s.drums(b, bars, WALK, sig=True)
        for bar in range(bars):
            s.bell_cue(b + bar * 4 + 2, rank=rank_even if bar % 2 == 0 else 2, ring=True)

    # ---- intro: the drone, the procession's bells far off, then the walk
    b = s.sec("intro", 4, 0, chart=None)
    harm(0, [1, 1, 1, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.5)
    for i in range(6):
        s.ev("bells", b + i * 2 + 4, 1, None, 0.12 + 0.05 * i, count=8, spread=0.05, width=0.6)
    s.melody("mancosa", b + 8, OST + " " + OST, vel=0.5, role="fast", cands=False)
    s.drums(b + 12, 1, WALK, cands=False)

    # ---- procession A: the launeddas lead, the walk
    b = s.sec("procession1", 8, 1)
    harm(b // 4, [1, 1, 5, 1, 1, 1, 5, 1])
    launeddas(b, 8, NODA1)
    walk(b, 8)
    s.drums(b, 8, "..t...t...t.T.t.")

    # ---- tenore: the procession song, launeddas drop to the drone
    b = s.sec("song1", 8, 1)
    harm(b // 4, [1, 1, 5, 1, 4, 1, 5, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.45)
    s.tenore(b, 32, "rhythm", pattern="x.......x...o...", vowels="oaoe", vel=0.8)
    s.melody("boghe", b, SONG1, vel=0.9)
    s.melody("boghe", b + 16, SONG2, vel=0.9)
    s.drums(b, 8, "B.......B.......")
    s.drums(b, 8, "....t.......t...")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)

    # ---- procession A': both together, the variation noda with trills
    b = s.sec("procession2", 8, 2)
    harm(b // 4, [1, 1, 5, 1, 1, 1, 5, 1])
    launeddas(b, 8, NODA2)
    s.tenore(b, 32, "rhythm", pattern="x...o...x...o.o.", vowels="aoia", vel=0.7)
    walk(b, 8)
    s.drums(b, 8, "..t...t.t.t.T.tt")

    # ---- break: the launeddas alone, the row halts twice
    b = s.sec("halt", 4, 1)
    harm(b // 4, [1, 1, 1, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.55)
    s.melody("mancosedda", b, "5:.25 6 5 6 5 6 5 6 5:1 r:1 5:.25 6 5 6 5 6 5 6 8:1 r:1"
                              " 5:.25 6 5 6 5 6 5 6 5:1 r:1 7:.25 6 7 6 5 4 3 2 1:1 r:1", vel=0.9, hold_min=99)
    for bar in range(4):
        s.drums(b + bar * 4, 1, "B.......B.......")
        s.bell_cue(b + bar * 4 + 2, rank=1, ring=True)
        s.stop(b + bar * 4 + 3, 1)

    # ---- tenore again, higher and with the launeddas answering each phrase
    b = s.sec("song2", 8, 2)
    harm(b // 4, [1, 1, 5, 1, 4, 1, 5, 1])
    s.drone("tumbu", b, 32, tumbu, vel=0.5)
    s.tenore(b, 32, "rhythm", pattern="x...o...x...o.o.", vowels="oaoe", vel=0.85)
    s.melody("boghe", b, SONG2, vel=0.95)
    s.melody("boghe", b + 16, SONG1, vel=0.95)
    for k in (0, 8, 16, 24):
        # answers in the gaps of the song (the last beats of every other bar)
        s.melody("mancosedda", b + k + 6, "5:.25 6 5 4 3:1", vel=0.7, role="fast", hold_min=99)
    s.drums(b, 8, "B.......B...b...")
    s.drums(b, 8, "....t.t.....t.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2)
        if bar % 2 == 1:
            s.bell_cue(b + bar * 4 + 2, rank=3, big=False)

    # ---- build: all together, noda 2 then 3, the walk returns
    b = s.sec("build", 8, 2)
    harm(b // 4, [1, 1, 5, 1, 4, 4, 5, 5])
    launeddas(b, 4, NODA2, vel=0.9)
    launeddas(b + 16, 4, NODA3, vel=0.9)
    s.tenore(b, 32, "rhythm", pattern="x...o.o.x...o.o.", vowels="aoia", vel=0.8)
    walk(b, 8)
    s.drums(b, 8, "t.t.t.t.T.t.t.tt", fill="t.t.t.t.TtTtTTTT")

    # ---- climax: fast figures, the leap on every bar, the tenore at full voice
    b = s.sec("climax", 8, 3)
    harm(b // 4, [1, 1, 5, 1, 1, 4, 5, 1])
    launeddas(b, 8, NODA3, vel=1.0)
    s.tenore(b, 32, "rhythm", pattern="x.o.o.o.x.o.o.o.", vowels="aoiao", vel=0.9)
    s.melody("boghe", b + 16, SONG2, vel=0.95, cands=False)
    walk(b, 8)
    s.drums(b, 8, "t.ttt.t.T.ttt.tt")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=3, big=False)

    # ---- outro: the drone, the last leap, a halt, the final stroke
    b = s.sec("outro", 4, 1)
    harm(b // 4, [1, 1, 1, 1])
    s.drone("tumbu", b, 16, tumbu, vel=0.55)
    s.melody("mancosedda", b, NODA1, vel=0.8, hold_min=99)
    s.drums(b, 2, WALK, sig=True)
    s.bell_cue(b + 2, rank=1, ring=True)
    s.bell_cue(b + 6, rank=2, ring=True)
    s.tenore(b + 8, 1, "rhythm", pattern="x...............", vowels="o", vel=0.9)
    s.drums(b + 8, 1, "B...............")
    s.bell_cue(b + 8, rank=1)
    s.stop(b + 9, 3)
    s.tenore(b + 12, 4, "drone", vowels="o", vel=0.75, sustain_cands=False)
    s.bell_cue(b + 12, rank=1)
    for i in range(5):
        s.ev("bells", b + 14 + i * 2, 1, None, 0.3 - 0.05 * i, count=8, spread=0.05, width=0.6)
    s.tail = 7.0
    s.preview = s.time(s.section("climax").b)
    return s
