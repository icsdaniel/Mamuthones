#!/usr/bin/env python3
"""Render the whole soundtrack from the written scores.

    python3 tools/audio/music/render.py                 # everything
    python3 tools/audio/music/render.py fires rope      # some songs (story ids or piazza ids)
    python3 tools/audio/music/render.py --no-remix fires
    options: --stems DIR (default /tmp/mamuthones_stems), --report FILE (JSON measurements)

For each story song it writes game/audio/music/<id>.ogg, <id>_remix.ogg and
game/data/songs/<id>.json (with charts), keeps every stem as FLAC under the stems folder, and
measures loudness, true peak, chart-to-onset timing, rests and bell cues.
"""
from __future__ import annotations

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402

import analyze  # noqa: E402
import dsp  # noqa: E402
import mixer  # noqa: E402
from charts import chart_song  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MUSIC = os.path.join(ROOT, "game", "audio", "music")
SONGS = os.path.join(ROOT, "game", "data", "songs")

STORY = ["workshop", "fires", "bonfires", "carnival", "rope", "piazza", "shrove"]
PIAZZA = ["piazza_fire", "piazza_crowd", "piazza_dusk"]


def load_song(sid):
    if sid.startswith("piazza_"):
        from songs import piazza_mode
        return piazza_mode.build(sid).finalize()
    mod = __import__(f"songs.{sid}", fromlist=["build"])
    return mod.build().finalize()


def dumps_song(d):
    """JSON with one note per line so charts diff and read well."""
    lines = ["{"]
    keys = list(d.keys())
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        if k == "charts":
            lines.append('  "charts": {')
            names = list(d["charts"].keys())
            for j, name in enumerate(names):
                notes = d["charts"][name]
                lines.append(f'    "{name}": [')
                for m, n in enumerate(notes):
                    lines.append("      " + json.dumps(n) + ("," if m < len(notes) - 1 else ""))
                lines.append("    ]" + ("," if j < len(names) - 1 else ""))
            lines.append("  }" + comma)
        elif k in ("sections", "lessons"):
            lines.append(f'  "{k}": [')
            for m, x in enumerate(d[k]):
                lines.append("    " + json.dumps(x) + ("," if m < len(d[k]) - 1 else ""))
            lines.append("  ]" + comma)
        else:
            lines.append(f"  {json.dumps(k)}: {json.dumps(d[k], ensure_ascii=False)}{comma}")
    lines.append("}")
    return "\n".join(lines) + "\n"


def finish(song, stems, n, out_name, quality):
    x = mixer.mix(song, stems, n)
    x = mixer.master(x)
    path = os.path.join(MUSIC, out_name + ".ogg")
    y = mixer.write_ogg(path, x, quality)
    tp = dsp.true_peak_db(y)
    tries = 0
    while tp > -1.0 and tries < 3:
        x = x * 10 ** ((-1.2 - tp) / 20)
        y = mixer.write_ogg(path, x, quality)
        tp = dsp.true_peak_db(y)
        tries += 1
    meas = {
        "lufs": round(dsp.integrated_loudness(y), 2),
        "true_peak_db": round(tp, 2),
        "seconds": round(len(y) / dsp.SR, 3),
        "bytes": os.path.getsize(path),
    }
    return y, meas


def render_one(sid, opts, report):
    t0 = time.time()
    song = load_song(sid)
    stems, n = mixer.render_stems(song)
    stem_dir = os.path.join(opts["stems"], sid)
    mixer.save_stems(stems, stem_dir)
    y, meas = finish(song, stems, n, sid, opts["quality"])
    dsp.spectrogram_png(os.path.join(opts["stems"], sid + ".png"), y)
    entry = {"audio": meas, "features": analyze.features(y)}
    charts, sources = chart_song(song) if song.kind != "piazza" else piazza_chart(song)
    entry["timing"] = analyze.timing_report(song, sources, stems, charts)
    entry["rests"] = analyze.rest_report(song, stems, sources)
    entry["cues"] = analyze.cue_report(song, stems, sources)

    data = {
        "id": song.id,
        "title": song.title,
        "stop": song.stop_no,
        "kind": song.kind,
        "bpm": song.bpm,
        "offset": round(song.offset, 4),
        "audio": f"res://audio/music/{song.id}.ogg",
    }
    if song.kind != "piazza" and opts["remix"]:
        import remix
        rsong = remix.build(song, stems)
        rstems, rn = mixer.render_stems(rsong)
        mixer.save_stems(rstems, os.path.join(opts["stems"], sid + "_remix"))
        ry, rmeas = finish(rsong, rstems, rn, sid + "_remix", opts["quality"])
        dsp.spectrogram_png(os.path.join(opts["stems"], sid + "_remix.png"), ry)
        rsrc = remix.remix_sources(rsong, sources)
        entry["remix"] = {"audio": rmeas, "features": analyze.features(ry),
                          "timing": analyze.timing_report(rsong, rsrc, rstems, charts)}
        data["remix"] = {"id": sid + "_remix", "bpm": song.bpm, "offset": round(rsong.offset, 4),
                         "audio": f"res://audio/music/{sid}_remix.ogg"}
    elif song.kind != "piazza":
        old = os.path.join(SONGS, sid + ".json")
        if os.path.exists(old):
            with open(old, encoding="utf-8") as f:
                prev = json.load(f)
            if "remix" in prev:
                data["remix"] = prev["remix"]
    data["length"] = meas["seconds"]
    data["preview"] = round(song.preview if song.preview is not None else song.time(song.sections[1].b), 2)
    data["key_root"] = song.key_root
    data["sections"] = [{"name": s.name, "b": s.b, "len": s.len} for s in song.sections]
    if song.kind == "tutorial":
        data["lessons"] = song.lessons
    data["charts"] = charts
    with open(os.path.join(SONGS, sid + ".json"), "w", encoding="utf-8") as f:
        f.write(dumps_song(data))
    entry["seconds_to_render"] = round(time.time() - t0, 1)
    report[sid] = entry
    tim = entry["timing"]
    print(f"{sid:14s} {meas['seconds']:6.1f}s  {meas['lufs']:6.2f} LUFS  TP {meas['true_peak_db']:5.2f}  "
          f"{meas['bytes'] / 1e6:4.2f} MB  timing " +
          " ".join(f"{d}:{v['within_20ms'] * 100:.0f}%" for d, v in tim.items()) +
          (f"  remix {entry['remix']['audio']['lufs']:.2f} LUFS" if "remix" in entry else "") +
          f"  [{entry['seconds_to_render']}s]", flush=True)
    return entry


def piazza_chart(song):
    from charts import N
    notes = [N(c.b, "bell", c.rank, "bell", None, c.stem, src=c) for c in song.cands if c.role == "bell"]
    notes.sort(key=lambda n: n.b)
    return {"piazza": [n.json() for n in notes]}, {"piazza": [(n.b, n.k, n.stem, 0) for n in notes]}


def _job(args):
    sid, opts = args
    rep = {}
    render_one(sid, opts, rep)
    return sid, rep[sid]


def main(argv):
    opts = {"stems": "/tmp/mamuthones_stems", "remix": True, "quality": 0.4, "report": None}
    ids = []
    it = iter(argv)
    for a in it:
        if a == "--stems":
            opts["stems"] = next(it)
        elif a == "--no-remix":
            opts["remix"] = False
        elif a == "--report":
            opts["report"] = next(it)
        elif a == "--quality":
            opts["quality"] = float(next(it))
        elif a == "-j":
            opts["jobs"] = int(next(it))
        else:
            ids.append(a)
    ids = ids or STORY + PIAZZA
    os.makedirs(MUSIC, exist_ok=True)
    os.makedirs(SONGS, exist_ok=True)
    os.makedirs(opts["stems"], exist_ok=True)
    rpath = opts["report"] or os.path.join(opts["stems"], "report.json")
    report = {}
    if os.path.exists(rpath):
        with open(rpath) as f:
            report = json.load(f)
    jobs = opts.get("jobs", 1)
    if jobs > 1 and len(ids) > 1:
        import multiprocessing as mp
        with mp.get_context("fork").Pool(jobs) as pool:
            for sid, entry in pool.imap_unordered(_job, [(sid, opts) for sid in ids]):
                report[sid] = entry
                with open(rpath, "w") as f:
                    json.dump(report, f, indent=1, default=float)
    else:
        for sid in ids:
            render_one(sid, opts, report)
            with open(rpath, "w") as f:
                json.dump(report, f, indent=1, default=float)
    total = sum(os.path.getsize(os.path.join(MUSIC, f)) for f in os.listdir(MUSIC) if f.endswith(".ogg"))
    print(f"total music: {total / 1e6:.1f} MB; report: {rpath}")


if __name__ == "__main__":
    main(sys.argv[1:])
