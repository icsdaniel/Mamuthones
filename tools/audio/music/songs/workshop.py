"""Stop 1 - The Workshop (the night before). Tutorial song.

A single frame drum and a single voice (boghe) in the carving workshop, the hearth crackling.
D Dorian, 80 bpm, 4/4. It introduces the leitmotif that returns in the finale:
    D G A B | A G A - | F E F G | F E D -
Seven four-bar lessons, each a closed, loopable phrase that ends on the tonic, then the whole
thing put together, then the theme once more.
"""
from score import Song

THEME_A = "1:1 4:1.5 5:.5 6:1 5:.5 4:.5 5:2 4:.5 3 2 3 4:1 3:.5 2 1:3 r:2"
THEME_B = "5:1 7:1.5 6:.5 5:1 4:.5 3:.5 4:2 3:.5 2 1 7,:.5 1:1 2:1 1:4 r:1"


def build():
    s = Song("workshop", "The Workshop", "La bottega", 1, "tutorial", 80, 4, 62, "dorian")
    s.reverb = {"t60": 0.9, "wet": 0.22, "predelay": 0.008, "bright": 5000}
    s.preview = None
    s.countin()
    s.chord(0, 44, 1)

    # ---- intro: the voice alone sings the theme
    b = s.sec("intro", 4, 0, chart=None)
    s.melody("boghe", b, THEME_A, vel=0.75, vowel="a", cands=False)
    s.ev("fire", b - 4, 190, None, 0.5)

    # ---- lesson 1: steps. The drum walks on every beat; the voice holds a low hum.
    b = s.sec("lesson_steps", 4, 0, listen_bar=True, lanes="mid",
              chart={d: dict(steps=[("pulse", 3)], bells="none") for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "D...d...D...d...")
    s.melody("boghe", b, "1:4@o 1:4 5,:4 1:4", vel=0.45, cands=False)
    s.lesson("steps", b, 16)

    # ---- lesson 2: lanes. Low, middle, high: the voice sings the lane on every drum beat.
    b = s.sec("lesson_lanes", 4, 0, listen_bar=True, lanes=[0, 1, 2, 1, 0, 2],
              chart={d: dict(steps=[("pulse", 3)], bells="none") for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "D...d...D...d...")
    s.melody("boghe", b, "1,:2@a 3,:1 5,:1 1,:2 3,:2 5,:2 3,:2 1,:2 5,:2", vel=0.7, octave=1, hold_min=99)
    s.lesson("lanes", b, 16)

    # ---- lesson 3: bells. A rim click, then the big stroke: ring on it.
    b = s.sec("lesson_bells", 4, 0, listen_bar=True,
              chart={d: dict(steps=[], bells="all") for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "................")
    s.melody("boghe", b, "5,:4@o 4,:4 3,:4 1,:4", vel=0.45, octave=1, cands=False)
    for bar in range(4):
        s.bell_cue(b + bar * 4, rank=1, land="frame")
        s.bell_cue(b + bar * 4 + 2, rank=1, land="frame", big=False)
    s.lesson("bells", b, 16)

    # ---- lesson 4: holds. Long sung notes: keep the button down while the voice holds.
    b = s.sec("lesson_holds", 4, 0, listen_bar=True,
              chart={d: dict(steps=[], bells="none", holds=5) for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "d.......d.......")
    s.melody("boghe", b, "1:1.5@a r:.5 3:1.5@o r:.5 1:1.5@a r:.5 3:1.5@o r:.5 5:1.5@a r:.5 3:1.5@o r:.5 "
                         "5:1.5@a r:.5 1:1.5@o r:.5", vel=0.8, hold_min=1.5)
    s.lesson("holds", b, 16)

    # ---- lesson 5: stand still. Drum and voice stop dead; so does the row.
    b = s.sec("lesson_still", 4, 0, listen_bar=True,
              chart={d: dict(steps=[("pulse", 3)], bells="none") for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "D...d...D...d...")
    s.melody("boghe", b, "5:1@a 4 3 2 1:1 r:3 5:1 4 3 2 1:1 r:3", vel=0.7, cands=False)
    s.stop(b + 5, 3, tempt=None)   # the first stand-still is met bare; the next one tempts
    s.stop(b + 13, 3)
    s.lesson("still", b, 16)

    # ---- lesson 6: stomps. The Issohadore calls, then the rope cracks: stomp with both thumbs.
    b = s.sec("lesson_stomps", 4, 0, listen_bar=True,
              chart={d: dict(steps=[], bells="none", stomps=True) for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "d.......d.......")
    # a demonstration throw in the listening bar, then one per bar
    for i, rb in enumerate((b + 2, b + 4, b + 6, b + 8, b + 10, b + 12, b + 14)):
        s.ev("calls", rb - 1, 0.6, None, 0.8, kind="hei" if i % 2 else "ohi")
        s.rope(rb, 1 if i % 2 == 0 else -1)
    s.lesson("stomps", b, 16)

    # ---- lesson 7: full ring. Step and bell together on the big stroke.
    b = s.sec("lesson_full", 4, 0, listen_bar=True,
              chart={d: dict(steps=[("mel", 1)], bells="all", rings=True) for d in ("easy", "medium", "hard", "expert")})
    s.drums(b, 4, "........d.......")
    s.melody("boghe", b, "1:2@a 3:2 3:2 5:2 5:2 3:2 1:2 1:2", vel=0.75, rank_shift=-2, hold_min=99)
    for bar in range(8):
        s.bell_cue(b + bar * 2, rank=1, ring=True, land="frame")
    s.lesson("full", b, 16)

    # ---- together: the theme with the drum, everything once more in turn
    b = s.sec("together", 8, 1, chart={
        "easy": dict(steps=[("pulse", 2)], bells="phrase", holds=5, stomps=True, rings=False),
        "medium": dict(steps=[("pulse", 3), ("mel", 3)], bells="bar", holds=5, stomps=True),
        "hard": dict(steps=[("pulse", 3), ("mel", 4)], bells="accent", holds=5, stomps=True, rings=True),
        "expert": dict(steps=[("pulse", 4), ("mel", 4), ("perc", 4)], bells="all", holds=5, stomps=True, rings=True),
    })
    s.drums(b, 8, ["D..tD.t.D..tD.t.", "D..tD.t.D.t.D.tt"])
    s.melody("boghe", b, THEME_A, vel=0.85)
    s.melody("boghe", b + 16, THEME_B, vel=0.85)
    s.bell_cue(b + 8, rank=1, land="frame")
    s.bell_cue(b + 16, rank=1, land="frame", ring=True)
    s.bell_cue(b + 24, rank=2, land="frame")
    s.stop(b + 29, 3)
    s.ev("calls", b + 10, 0.6, None, 0.7, kind="ohi")
    s.rope(b + 12, 1)

    # ---- outro: the theme, softly, ending on a long tonic and one last stroke
    b = s.sec("outro", 4, 0, chart={
        "easy": dict(steps=[("pulse", 1)], bells="phrase"),
        "medium": dict(steps=[("pulse", 2)], bells="phrase"),
        "hard": dict(steps=[("pulse", 3), ("mel", 3)], bells="phrase"),
        "expert": dict(steps=[("pulse", 3), ("mel", 4)], bells="phrase"),
    })
    s.drums(b, 3, "D.......d.......")
    s.melody("boghe", b, "1:1 4:1.5 5:.5 6:1 5:.5 4:.5 5:2 4:.5 3 2 3 4:1 3:.5 2 1:4", vel=0.7, hold_min=99)
    s.bell_cue(b + 12, rank=1, land="frame")
    s.preview = s.time(s.section("together").b)
    return s
