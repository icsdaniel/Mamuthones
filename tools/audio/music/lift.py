#!/usr/bin/env python3
"""Render each song's lift layer: the parts the player's taps follow, alone, to play in sync on top of
the song and bring up while the player hits on time.

    python3 tools/audio/music/lift.py                  # every story song and its remix
    python3 tools/audio/music/lift.py fires rope       # some songs (story ids)

Writes game/audio/music/<id>_lift.ogg and <id>_remix_lift.ogg. The songs and their charts are left
alone: the layer is rendered from the same score (the stems are deterministic) through the same mix
chain, scaled by the gain the master gave the whole song, so at 0 dB it lines up sample for sample
with that part inside the song and doubles it. On top of that it is a little forward (a presence lift
and some air), so bringing it up reads as the tune stepping out, not just as the song getting louder.
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402

import dsp  # noqa: E402
import mixer  # noqa: E402

# The layers the step notes follow: the tune (voice and launeddas) and the frame drum's pulse; in the
# remix the lead, the arpeggio, the vocal chops and the snare.
LIFT = {"boghe", "mancosa", "mancosedda", "frame", "rim"}
LIFT_REMIX = {"lead", "arp", "chop", "snare"}
QUALITY = 0.3


def lift_layer(song, stems, n, insts, path):
    full = mixer.mix(song, stems, n)
    gain = 10 ** ((-14.0 - dsp.integrated_loudness(full)) / 20)
    part = mixer.mix(song, {k: v for k, v in stems.items() if k in insts}, n) * gain
    part = dsp.peaking(part, 3000, 3.0, 0.7)
    part = dsp.peaking(part, 9000, 2.0, 0.7)
    part = dsp.limiter(part, -3.0)
    y = mixer.write_ogg(path, part, QUALITY)
    return {"lufs": round(dsp.integrated_loudness(y), 2), "bytes": os.path.getsize(path),
            "seconds": round(len(y) / dsp.SR, 3)}


def main(argv):
    import render
    ids = argv or render.STORY
    for sid in ids:
        song = render.load_song(sid)
        stems, n = mixer.render_stems(song)
        m = lift_layer(song, stems, n, LIFT, os.path.join(render.MUSIC, sid + "_lift.ogg"))
        main_len = sf.info(os.path.join(render.MUSIC, sid + ".ogg")).duration
        print(f"{sid:10s} lift {m['lufs']:6.2f} LUFS {m['bytes'] / 1e6:4.2f} MB {m['seconds']:.2f}s (song {main_len:.2f}s)",
              flush=True)
        import remix
        rsong = remix.build(song, stems)
        rstems, rn = mixer.render_stems(rsong)
        m = lift_layer(rsong, rstems, rn, LIFT_REMIX, os.path.join(render.MUSIC, sid + "_remix_lift.ogg"))
        print(f"{sid + '_remix':10s} lift {m['lufs']:6.2f} LUFS {m['bytes'] / 1e6:4.2f} MB {m['seconds']:.2f}s", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
