"""Audio -> per-slot features on a fixed beat grid (16th slots).

    python3 tools/audio/music/audio_features.py <song.wav> <bpm> <offset> <out.json> [stems_dir]

stems_dir (optional) holds drums.wav, bass.wav, other.wav from a source separation; without it the
mix is split into percussive and harmonic parts (HPSS) and frequency bands.
"""
import json, sys, os
import numpy as np, librosa

SR = 22050
HOP = 128

def load(p):
    y, _ = librosa.load(p, sr=SR, mono=True)
    return y

def band_onset(y, lo, hi):
    S = np.abs(librosa.stft(y, n_fft=2048, hop_length=HOP))
    f = librosa.fft_frequencies(sr=SR, n_fft=2048)
    # linear (not dB) flux: a drum hit jumps far above a rolling bass line or a quiet tail
    B = S[(f >= lo) & (f < hi)] ** 0.5
    # drums are short and regular: the raw flux, read at the slot, finds them reliably
    return np.maximum(0, np.diff(B, axis=1, prepend=B[:, :1])).sum(0)


def peaks_only(env):
    """Keep only the onset envelope's local peaks (a struck note), so a busy band does not smear
    its strength over its neighbours."""
    env = env - np.convolve(env, np.ones(64) / 64, "same")   # remove the slow level
    env = np.maximum(env, 0)
    pk = librosa.util.peak_pick(env, pre_max=6, post_max=6, pre_avg=24, post_avg=24, delta=0.0, wait=8)
    out = np.zeros_like(env)
    out[pk] = env[pk]
    return out

def main():
    path, bpm, off, out = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
    stems = sys.argv[5] if len(sys.argv) > 5 else None
    mix = load(path)
    if stems:
        drums = load(os.path.join(stems, "drums.wav"))
        bass = load(os.path.join(stems, "bass.wav"))
        other = load(os.path.join(stems, "other.wav"))
        n = min(len(mix), len(drums), len(other), len(bass))
        mix, drums, bass, other = mix[:n], drums[:n], bass[:n], other[:n]
        perc, harm = drums, other
    else:
        harm, perc = librosa.effects.hpss(mix, margin=2.0)
        bass = None
    # the tune without the bass: high-passed harmonic part
    import scipy.signal as sg
    tune = sg.sosfilt(sg.butter(4, 250, "highpass", fs=SR, output="sos"), harm).astype(np.float32)
    spb = 60.0 / bpm
    dur = len(mix) / SR
    nslots = int((dur - off) / (spb / 4))
    fps = SR / HOP
    feats = {
        "kick": band_onset(perc, 30, 160),
        "snare": band_onset(perc, 180, 2500),
        "hat": band_onset(perc, 5000, 11000),
        "mel": peaks_only(librosa.onset.onset_strength(y=tune, sr=SR, hop_length=HOP)),
        "all": librosa.onset.onset_strength(y=mix, sr=SR, hop_length=HOP),
    }
    if bass is not None:
        feats["bass"] = librosa.onset.onset_strength(y=bass, sr=SR, hop_length=HOP)
    # loudness of harmonic and percussive parts (sustain, silence)
    rms_h = librosa.feature.rms(y=tune, hop_length=HOP)[0]
    rms_p = librosa.feature.rms(y=perc, hop_length=HOP)[0]
    rms_m = librosa.feature.rms(y=mix, hop_length=HOP)[0]
    # melody pitch on the harmonic part
    # (pyin crashes under numba here: the strongest constant-Q bin is the melody's pitch)
    C = np.abs(librosa.cqt(tune, sr=SR, hop_length=HOP * 4, fmin=librosa.note_to_hz("A3"), n_bins=48, bins_per_octave=12))
    top = C.argmax(0)
    strength = C.max(0) / (np.percentile(C.max(0), 95) + 1e-9)
    f0 = librosa.midi_to_hz(librosa.note_to_midi("A3") + top)
    voiced = strength > 0.2
    f0t = librosa.times_like(top, sr=SR, hop_length=HOP * 4)

    def peak(arr, t, w=0.03):
        i0 = max(0, int((t - w) * fps)); i1 = min(len(arr), int((t + w) * fps) + 1)
        return float(arr[i0:i1].max()) if i1 > i0 else 0.0

    def mean(arr, t0, t1):
        i0 = max(0, int(t0 * fps)); i1 = min(len(arr), int(t1 * fps) + 1)
        return float(arr[i0:i1].mean()) if i1 > i0 else 0.0

    # normalise each onset curve by its 98th percentile at slot positions
    slots = []
    raw = {k: [] for k in feats}
    for i in range(nslots):
        t = off + i * spb / 4
        for k, a in feats.items():
            raw[k].append(peak(a, t))
    # drums: 95th percentile of every slot; peak-picked tune curves: 90th percentile of their hits
    norm = {k: (np.percentile(v, 95) if k in ("kick", "snare", "hat", "all")
                else np.percentile([x for x in v if x > 0] or [1.0], 90)) + 1e-9 for k, v in raw.items()}
    lvl_h = np.percentile(rms_h, 95); lvl_p = np.percentile(rms_p, 95); lvl_m = np.percentile(rms_m, 95)
    for i in range(nslots):
        t = off + i * spb / 4
        j = np.searchsorted(f0t, t + 0.04)
        j = min(j, len(f0) - 1)
        hz = f0[j] if voiced[j] else None
        slots.append({
            "i": i, "b": i / 4, "t": round(t, 4),
            **{k: round(float(min(1.5, raw[k][i] / norm[k])), 3) for k in feats},
            "h": round(float(mean(rms_h, t, t + spb / 4) / lvl_h), 3),
            "p": round(float(mean(rms_p, t, t + spb / 4) / lvl_p), 3),
            "m": round(float(mean(rms_m, t, t + spb / 4) / lvl_m), 3),
            "pitch": None if hz is None or np.isnan(hz) else round(float(librosa.hz_to_midi(hz)), 2),
        })
    json.dump({"bpm": bpm, "offset": off, "duration": dur, "slots": slots}, open(out, "w"))
    print(out, nslots, "slots")

main()
