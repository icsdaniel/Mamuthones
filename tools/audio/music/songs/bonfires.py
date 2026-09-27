"""Stop 3 - Around the Bonfires (17 January). A circle dance (ballu) in 12/8.

G Mixolydian, 100 dotted-quarter beats per minute, four beats (twelve eighths) to the bar.
The tenore sings the ballu's long-short lilt on nonsense syllables, the boghe the dance tune,
the frame drum and the dancers' feet keep the circle turning.
Signature: the tune's turning hook D E D C B C D ("round the fire"), lanes 0 1 2 1 0 2 1: a climb and a turn.
Chart mechanic introduced here: holds (the tenore's long chords in the B sections).
"""
from score import Song

T = "1/3"
Q = "2/3"
HOOK = f"5*:{Q} 6*:{T} 5*:{Q} 4*:{T} 3*:{Q} 4*:{T} 5*:1 "
A1 = HOOK + f"6:{Q} 5:{T} 4:{Q} 3:{T} 2:1 r:1 3:{Q} 4:{T} 5:{Q} 6:{T} 7:{Q} 6:{T} 5:1 4:{Q} 3:{T} 2:{Q} 3:{T} 1:2"
A2 = HOOK + f"6:{Q} 7:{T} 1':{Q} 7:{T} 6:1 r:1 5:{Q} 4:{T} 3:{Q} 2:{T} 3:{Q} 4:{T} 5:1 2:{Q} 3:{T} 2:{Q} 7,:{T} 1:2"
B1 = "1':2@o 7:1 6:1 5:3 r:1 6:2 5:1 4:1 3:3 r:1"
B2 = f"1':2@o 2':1 1':1 7:3 r:1 6:{Q} 5:{T} 4:{Q} 3:{T} 2:1 3:1 1:3 r:1"
BALLU = "x-ox-ox-ox-o"


def build():
    s = Song("bonfires", "Around the Bonfires", "Attorno ai fuochi", 3, "story", 100, 4, 55, "mixolydian",
             sub=3)
    s.reverb = {"t60": 1.4, "wet": 0.18, "predelay": 0.02, "bright": 6000}
    s.mechanics = {"step", "bell", "rest", "hold"}
    s.signature = {"medium": [0, 1, 2, 1, 0, 2, 1], "hard": [0, 1, 2, 1, 0, 2, 1], "expert": [0, 1, 2, 1, 0, 2, 1]}
    s.countin()
    s.ev("fire", -4, 240, None, 0.3)
    hard_mid = "default"

    def harm_a(bar0):
        for i, deg in enumerate([1, 4, 1, 1, 1, 4, 1, 1]):
            s.chord((bar0 + i) * 4, 1, deg)

    def harm_b(bar0):
        for i, deg in enumerate([4, 4, 1, 1, 7, 7, 5, 1]):
            s.chord((bar0 + i) * 4, 1, deg)

    # ---- intro: drum and feet start the circle, the tenore joins
    b = s.sec("intro", 2, 0, chart=None)
    harm_a(0)
    s.drums(b, 2, "D.tD.tD.tD.t", cands=False)
    s.drums(b, 2, "P.....p.....", cands=False)
    s.tenore(b + 4, 4, "rhythm", pattern=BALLU, vowels="oaoi", vel=0.7)

    # ---- A1: the tune
    b = s.sec("dance1", 8, 1, chart=hard_mid)
    harm_a(b // 4)
    s.tenore(b, 32, "rhythm", pattern=BALLU, vowels="oaoi", vel=0.75)
    s.melody("boghe", b, A1, vel=0.9, sig_start=0)
    s.melody("boghe", b + 16, A2, vel=0.9, sig_start=0)
    s.drums(b, 8, ["D.tD.tD.tD.t", "D.tD.tD.tDtt"])
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, land="stomp")

    # ---- A2: the feet get louder, the stop at the end
    b = s.sec("dance2", 8, 2, chart=hard_mid)
    harm_a(b // 4)
    s.tenore(b, 32, "rhythm", pattern=BALLU, vowels="aoia", vel=0.8)
    s.melody("boghe", b, A2, vel=0.9, sig_start=0)
    s.melody("boghe", b + 16, A1, vel=0.9, sig_start=0)
    s.drums(b, 8, ["D.tD.tD.tD.t", "D.tDttD.tDtt"])
    s.drums(b, 8, "P..p..P..p..")
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, land="stomp")
        if bar % 2 == 1:
            s.bell_cue(b + bar * 4 + 2, rank=3, land="stomp", big=False)
    s.stop(b + 30, 2)

    # ---- B1: the circle turns slowly - long tenore chords (holds), the boghe answers above
    b = s.sec("turn1", 8, 1, chart={"medium": dict(steps=[("pulse", 3), ("mel", 3)], holds=3, bells="phrase"),
                                     "hard": dict(steps=[("pulse", 3), ("mel", 4), ("perc", 4)], holds=4, bells="bar"),
                                     "expert": dict(steps=[("pulse", 3), ("mel", 4), ("perc", 4)], holds=5)})
    harm_b(b // 4)
    for i in range(4):
        s.tenore(b + i * 8, 8, "drone", vowels=["o", "a", "o", "e"][i], vel=0.8)
    s.melody("boghe", b, B1, vel=0.85)
    s.melody("boghe", b + 16, B2, vel=0.85)
    s.drums(b, 8, "D.....d.....")
    for bar in range(0, 8, 2):
        s.bell_cue(b + bar * 4 + 2, rank=1, land="stomp")
    s.stop(b + 30, 2, tempt="call")

    # ---- A3: back into the dance, claps on the off-beats
    b = s.sec("dance3", 8, 2, chart=hard_mid)
    harm_a(b // 4)
    s.tenore(b, 32, "rhythm", pattern=BALLU, vowels="oaoi", vel=0.85)
    s.melody("boghe", b, A1, vel=0.95, sig_start=0)
    s.melody("boghe", b + 16, A2, vel=0.95, sig_start=0)
    s.drums(b, 8, ["D.tD.tD.tD.t", "D.tDttD.tDtt"])
    s.drums(b, 8, "P..p..P..p..")
    s.drums(b, 8, "...c.....c..", cands=False)
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, land="stomp")
        s.bell_cue(b + bar * 4 + 2, rank=3, land="stomp", big=False)

    # ---- B2: the turn again, fuller, holds with the drum under them
    b = s.sec("turn2", 8, 2, chart={"medium": dict(steps=[("pulse", 3), ("mel", 3)], holds=3, bells="phrase"),
                                     "hard": dict(steps=[("pulse", 3), ("mel", 4), ("perc", 4)], holds=4, bells="bar"),
                                     "expert": dict(holds=5)})
    harm_b(b // 4)
    for i in range(4):
        s.tenore(b + i * 8, 8, "drone", vowels=["a", "o", "a", "e"][i], vel=0.85)
    s.melody("boghe", b, B2, vel=0.9)
    s.melody("boghe", b + 16, B1, vel=0.9)
    s.drums(b, 8, "D.tD.tD.....", fill="D.tD.tDtTDTT")
    s.drums(b, 8, "P.....P.....")
    for bar in range(8):
        s.bell_cue(b + bar * 4 + (2 if bar % 2 == 0 else 0), rank=1 if bar % 2 == 0 else 2, land="stomp")

    # ---- climax: everyone dances, the lilt doubled, bells on every half bar
    b = s.sec("climax", 8, 3)
    harm_a(b // 4)
    s.tenore(b, 32, "rhythm", pattern="x-oxooxooxoo", vowels="aoiao", vel=0.95)
    s.melody("boghe", b, A1, vel=1.0, sig_start=0)
    s.melody("boghe", b + 16, A2, vel=1.0, sig_start=0)
    s.drums(b, 8, ["DttDttDttDtt", "DttDtTDttDTT"])
    s.drums(b, 8, "P..P..P..P..")
    s.drums(b, 8, "...C.....C..", cands=False)
    for bar in range(8):
        s.bell_cue(b + bar * 4, rank=1 if bar % 2 == 0 else 2, land="stomp")
        s.bell_cue(b + bar * 4 + 2, rank=2 if bar % 2 else 3, land="stomp")
        s.ev("bells", b + bar * 4 + 1, 1, None, 0.25, count=8)
        s.ev("bells", b + bar * 4 + 3, 1, None, 0.25, count=8)

    # ---- outro: the hook once more, a long last chord
    b = s.sec("outro", 4, 1)
    s.chord(b, 4, 1)
    s.tenore(b, 8, "rhythm", pattern=BALLU, vowels="oaoi", vel=0.8)
    s.melody("boghe", b, HOOK + f"4:{Q} 3:{T} 2:{Q} 3:{T} 1:2", vel=0.9, sig_start=0)
    s.drums(b, 2, "D.tD.tD.tD.t")
    s.bell_cue(b, rank=1, land="stomp")
    s.bell_cue(b + 8, rank=1, land="stomp")
    s.tenore(b + 8, 8, "drone", vowels="oa", vel=0.8)
    s.stop(b + 9, 3)
    s.melody("boghe", b + 12, "1:4@o", vel=0.8, cands=False)
    s.tenore(b + 12, 4, "drone", vowels="o", vel=0.7, sustain_cands=False)
    s.bell_cue(b + 12, rank=1, land="stomp")
    s.preview = s.time(s.section("climax").b)
    return s
