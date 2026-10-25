#!/usr/bin/env python3
"""Everything a new recorded song needs before the pattern charter, from its WAV alone (no stems).

    python3 tools/audio/music/song_prep.py <id> <song.wav> <stop> "<English title>" "<Italian title>" <bpm hint> [--remix]

1. Stems stand in for a separation: drums = the percussive part (HPSS), bass = the harmonic part under
   250 Hz, other = the rest of the harmonic part (the tune). 24 kHz mono, which is all
   pattern_analysis reads.
2. Tempo, the first bar's downbeat and the swing are measured from the drums: a grid search over the
   tempo (the hint picks the octave), refined by fitting the drum hits that land near a sixteenth, with
   the bar's first beat chosen by the kick and by where the harmony changes.
3. Writes game/audio/music/<id>.ogg and <id>_lift.ogg (the tune alone, for the hits-lift layer), the
   song file and the pattern config (recorded/<id>_pattern.json), runs pattern_analysis and
   pattern_bars. pattern_chart.py --write then charts it.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

import librosa
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfiltfilt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
STEMS = "/tmp/claude-0/stems"
WORK = "/mnt/project-files/suno-songs/work/pattern"
SR = 24000
HOP = 128


def stems(y):
    yh, yp = librosa.effects.hpss(y, margin=2.0)
    sos = butter(4, 250, "lowpass", fs=SR, output="sos")
    bass = sosfiltfilt(sos, yh)
    return {"drums": yp, "bass": bass, "other": yh - bass}


def grid(drums, hint):
    env = librosa.onset.onset_strength(y=drums, sr=SR, hop_length=HOP, aggregate=np.median)
    fs = SR / HOP
    best = (-1, hint, 0.0)
    for bpm in np.arange(hint * 0.9, hint * 1.1, 0.1):
        spb = 60 / bpm
        for off in np.arange(0, spb, 0.005):
            pos = np.arange(off, len(env) / fs - 1, spb)
            sc = env[(pos * fs).astype(int)].mean()
            if sc > best[0]:
                best = (sc, bpm, off)
    _, bpm, off = best
    # refine: fit the strong drum hits within 30 ms of a sixteenth slot to a line (tempo and offset)
    thr = np.percentile(env, 92)
    pk = np.array([i for i in range(3, len(env) - 3) if env[i] > thr and env[i] == env[i - 3:i + 4].max()])
    t = pk / fs
    for _ in range(3):
        spb = 60 / bpm
        k = np.round((t - off) / (spb / 4))
        res = t - (off + k * spb / 4)
        ok = np.abs(res) < 0.03
        A = np.c_[np.ones(ok.sum()), k[ok]]
        c, *_ = np.linalg.lstsq(A, t[ok], rcond=None)
        off, slot = c[0], c[1]
        bpm = 60 / (slot * 4)
    spb = 60 / bpm
    # swing: how late the odd sixteenths sound (median of the hits that land near them)
    k = np.round((t - off) / (spb / 4))
    res = t - (off + k * spb / 4)
    odd = (k % 2 == 1) & (np.abs(res) < 0.06)
    swing = float(np.median(res[odd]) / spb) if odd.sum() > 20 else 0.0
    even = (k % 2 == 0) & (np.abs(res) < 0.06)
    swing -= float(np.median(res[even]) / spb) if even.sum() > 20 else 0.0
    return bpm, off % spb, swing, env


def downbeat(y, drums, bpm, off, bass):
    """Which of the four beats opens the bar: the kick, and where the harmony turns."""
    spb = 60 / bpm
    lo = np.abs(librosa.stft(bass, n_fft=1024, hop_length=HOP)).sum(0)
    lo = np.maximum(np.diff(lo, prepend=lo[0]), 0)
    fs = SR / HOP
    beats = np.arange(off, len(y) / SR - 1, spb)
    kick = np.array([lo[max(0, int((b - 0.03) * fs)):int((b + 0.05) * fs) + 1].max() for b in beats])
    ch = librosa.feature.chroma_cqt(y=y, sr=SR, hop_length=HOP)
    cb = np.array([ch[:, int((b + 0.02) * fs):int((b + spb * 0.9) * fs) + 1].mean(1) for b in beats])
    turn = np.r_[0, np.linalg.norm(cb[1:] - cb[:-1], axis=1)]
    score = []
    for p in range(4):
        sk = kick[p::4].sum() / (kick.sum() + 1e-9)
        st = turn[p::4].sum() / (turn.sum() + 1e-9)
        score.append(sk + 2 * st)
    return int(np.argmax(score)), score


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    sid, wav, stop, en, it, hint = argv[0], argv[1], int(argv[2]), argv[3], argv[4], float(argv[5])
    remix = "--remix" in flags
    y48, sr0 = sf.read(wav, always_2d=True)
    length = round(len(y48) / sr0, 3)
    y = librosa.resample(y48.mean(1), orig_sr=sr0, target_sr=SR)
    st = stems(y)
    d = os.path.join(STEMS, sid.replace("suno_", "") + "_n")
    os.makedirs(d, exist_ok=True)
    g = 0.89 / max(np.abs(y).max(), 1e-6)
    for k, v in list(st.items()) + [("mix", y)]:
        sf.write(os.path.join(d, k + ".wav"), v * g, SR, subtype="PCM_16")
    bpm, off, swing, _ = grid(st["drums"], hint)
    p, score = downbeat(y, st["drums"], bpm, off, st["bass"])
    spb = 60 / bpm
    first = off + p * spb
    print(f"{sid}: bpm {bpm:.2f} first downbeat {first:.3f} (beat {p + 1} of the bar; scores {np.round(score, 2).tolist()}) swing {swing:.3f}")
    bpm, first, swing = round(bpm, 2), round(first, 3), round(max(0.0, swing), 3) if swing > 0.02 else 0.0
    # audio: the song (as sent) and its lift layer (the tune alone), both Vorbis like the other songs
    out = os.path.join(ROOT, "game", "audio", "music")
    for name, src in ((sid, wav), (sid + "_lift", os.path.join(d, "other.wav"))):
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", src, "-c:a", "libvorbis", "-q:a", "5", "-ar", "44100", os.path.join(out, name + ".ogg")]
        subprocess.run(cmd, check=True)
    meta = {"title": {"en": en, "it": it}, "stop": stop, "bpm": bpm, "offset": first, "id": sid,
            "audio": f"res://audio/music/{sid}.ogg", "length": length, "preview": 40.0, "rests": []}
    if swing:
        meta["swing"] = swing
    rec = os.path.join(HERE, "recorded")
    json.dump(meta, open(os.path.join(rec, sid + ".json"), "w"), indent=1, ensure_ascii=False)
    cfg = {"song": sid, "bpm": bpm, "offset": first, "length": length, "stems": {
        "drums": [os.path.join(d, "drums.wav")], "bass": [os.path.join(d, "bass.wav")], "lead": [os.path.join(d, "other.wav")]},
        "analysis": os.path.join(WORK, sid.replace("suno_", "") + "_ana.json"), "lead_register": [55, 88], "lead_centre": 67}
    if swing:
        cfg["swing"] = swing
    cp = os.path.join(rec, sid + "_pattern.json")
    json.dump(cfg, open(cp, "w"), indent=1, ensure_ascii=False)
    sys.path.insert(0, HERE)
    import pattern_analysis as pa
    ana = pa.analyse(cfg)
    json.dump(ana, open(cfg["analysis"], "w"))
    import pattern_bars as pb
    pb.main(cp)
    # the song file the game reads: sections from the bar kinds, charts come from pattern_chart --write
    cfg = json.load(open(cp))
    kinds = {int(b): k for k, bs in cfg["bars"].items() for b in bs}
    secs = []
    for b in sorted(kinds):
        if secs and secs[-1]["name"] == kinds[b] and secs[-1]["b"] + secs[-1]["len"] == b * 4:
            secs[-1]["len"] += 4.0
        else:
            secs.append({"name": kinds[b], "b": b * 4.0, "len": 4.0})
    song = {"id": sid, "title": meta["title"], "stop": stop, "kind": "story", "bpm": bpm, "offset": first,
            "audio": meta["audio"], "length": length, "preview": 40.0, "key_root": 62}
    if swing:
        song["swing"] = swing
    song["sections"] = secs
    song["charts"] = {d_: [{"b": 0, "k": "step", "lane": 1}] for d_ in ("easy", "medium", "hard", "expert")}
    song["level_rules"] = {"easy": "medium", "medium": "hard", "hard": "expert", "expert": "expert"}
    json.dump(song, open(os.path.join(ROOT, "game", "data", "songs", sid + ".json"), "w"), indent=1, ensure_ascii=False)
    print("prepared", sid)


if __name__ == "__main__":
    main(sys.argv[1:])
