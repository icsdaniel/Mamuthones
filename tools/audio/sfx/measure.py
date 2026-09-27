"""Measure every file in game/audio/sfx: peaks, clean starts/ends, loop seams,
clicks, and per-bell-set spectral centroid and decay. Writes
tools/audio/sfx/measurements.json and prints a summary.

Run:  python3 tools/audio/sfx/measure.py
"""
from __future__ import annotations

import glob
import json
import os
import re
import numpy as np
import soundfile as sf
from scipy import signal

from dsp import OUT, ROOT

LOOP_DIRS = ("loops", "ambience")


def mono(x):
    return x if x.ndim == 1 else x.mean(axis=1)


def centroid(x, sr):
    """Spectral centroid of the ring: magnitude-weighted, over the STFT frames within
    40 dB of the loudest frame. (Counting the near-silent tail would let the 16-bit
    noise floor, flat up to 22 kHz, drag every centroid up.)"""
    f, t, S = signal.stft(mono(x), sr, nperseg=2048, noverlap=1536)
    P = np.abs(S)
    fe = (P ** 2).sum(axis=0)
    keep = fe >= fe.max() * 1e-4
    band = (f >= 20) & (f <= 20000)
    mag = P[band][:, keep].sum(axis=1)
    return float((f[band] * mag).sum() / (mag.sum() + 1e-12))


def decay_t60(x, sr):
    """T60 from the Schroeder backward integral, line fit between -5 and -25 dB
    (T20 x 3), plus the time to fall 30 dB below the peak envelope."""
    y = mono(x)
    e = np.cumsum((y ** 2)[::-1])[::-1]
    e = 10 * np.log10(e / (e[0] + 1e-20) + 1e-20)
    i5 = np.argmax(e <= -5)
    i25 = np.argmax(e <= -25)
    if i25 <= i5:
        return None
    t = np.arange(i5, i25) / sr
    slope = np.polyfit(t, e[i5:i25], 1)[0]
    return float(-60.0 / slope)


def edt(x, sr):
    """Early decay time: Schroeder curve 0 to -10 dB, times 6 (perceived decay)."""
    y = mono(x)
    e = np.cumsum((y ** 2)[::-1])[::-1]
    e = 10 * np.log10(e / (e[0] + 1e-20) + 1e-20)
    i10 = np.argmax(e <= -10)
    return float(i10 / sr * 6)


def rise_ms(x, sr):
    """Time from the first onset (10 % of the peak 5 ms-RMS envelope) to 90 %: how
    spread out in time the strikes are (a tight row is short, a ragged row long)."""
    y = mono(x)
    w = int(0.005 * sr)
    c = np.concatenate([[0.0], np.cumsum(y ** 2)])
    env = np.sqrt(np.maximum(c[w:] - c[:-w], 0) / w)
    pk = env.max()
    a = np.argmax(env >= 0.1 * pk)
    b = np.argmax(env >= 0.9 * pk)
    return float((b - a) / sr * 1000)


def flatness(x, sr):
    """Spectral flatness (0 = pure tones, 1 = white noise) of the loudest 300 ms."""
    y = mono(x)
    w = int(0.3 * sr)
    if len(y) > w:
        c = np.concatenate([[0.0], np.cumsum(y ** 2)])
        e = c[w:] - c[:-w]
        i = int(np.argmax(e))
        y = y[i:i + w]
    S = np.abs(np.fft.rfft(y * np.hanning(len(y)))) ** 2 + 1e-20
    f = np.fft.rfftfreq(len(y), 1 / sr)
    S = S[(f > 100) & (f < 10000)]
    return float(np.exp(np.mean(np.log(S))) / np.mean(S))


def phone_loss_db(x, sr):
    """How much quieter a sound gets on a phone speaker, modelled as a 4th-order
    500 Hz high-pass (RMS, dB; 0 = nothing lost)."""
    y = mono(x)
    sos = signal.butter(4, 500, "highpass", fs=sr, output="sos")
    return float(20 * np.log10(np.sqrt(np.mean(signal.sosfilt(sos, y) ** 2)) / (np.sqrt(np.mean(y ** 2)) + 1e-12) + 1e-12))


def attack_ms(x, sr):
    """Time from the first sound (-30 dB of the peak 10 ms envelope) to within 6 dB of
    the peak: how quickly the sound arrives at full strength."""
    y = mono(x)
    w = int(0.01 * sr)
    c = np.concatenate([[0.0], np.cumsum(y ** 2)])
    env = np.sqrt(np.maximum(c[w:] - c[:-w], 0) / w)
    pk = env.max()
    a = np.argmax(env >= pk * 10 ** (-30 / 20))
    b = np.argmax(env >= pk * 0.5)
    return float((b - a) / sr * 1000)


def hf_click_score(x, sr):
    """Largest sample-to-sample jump of the >6 kHz residual, relative to its local RMS
    (10 ms). Isolated steps (clicks) score high; noise and strikes stay moderate."""
    y = mono(x)
    sos = signal.butter(4, 6000, "highpass", fs=sr, output="sos")
    h = signal.sosfilt(sos, y)
    w = int(0.01 * sr)
    rms = np.sqrt(np.convolve(h ** 2, np.ones(w) / w, "same")) + 1e-6
    return float(np.max(np.abs(h) / np.maximum(rms, np.max(np.abs(y)) * 1e-3)))


def seam_hf(x, sr):
    """High-passed (>6 kHz) level right at the loop junction, relative to the 99th
    percentile of the same signal across the loop. About 1 or less: no click."""
    y = mono(x)
    sos = signal.butter(4, 6000, "highpass", fs=sr, output="sos")
    whole = np.abs(signal.sosfilt(sos, np.concatenate([y[-4096:], y, y[:4096]])))
    j = 4096 + len(y)
    ref = np.percentile(whole[4096:-4096], 99) + 1e-9
    return float(np.max(whole[j - 32:j + 32]) / ref)


def seam_hf_abs(x, sr):
    y = mono(x)
    sos = signal.butter(4, 6000, "highpass", fs=sr, output="sos")
    whole = np.abs(signal.sosfilt(sos, np.concatenate([y[-4096:], y[:4096]])))
    return float(20 * np.log10(np.max(whole[4096 - 32:4096 + 32]) + 1e-12))


def seam(x):
    """Loop seam: the jump from the last sample to the first, in units of the
    typical (95th percentile) step inside the loop."""
    y = x if x.ndim == 1 else x
    d = np.abs(np.diff(y, axis=0))
    typ = np.percentile(d, 95, axis=0) + 1e-9
    jump = np.abs(y[0] - y[-1])
    return float(np.max(jump / typ))


def main():
    files = sorted(glob.glob(os.path.join(OUT, "**", "*.wav"), recursive=True) +
                   glob.glob(os.path.join(OUT, "**", "*.ogg"), recursive=True))
    rows = {}
    problems = []
    for p in files:
        rel = os.path.relpath(p, OUT)
        x, sr = sf.read(p, always_2d=False)
        peak = float(np.max(np.abs(x)))
        pk_db = 20 * np.log10(peak + 1e-12)
        is_loop = rel.split(os.sep)[0] in LOOP_DIRS
        first = float(np.max(np.abs(np.atleast_1d(x[0]))))
        last = float(np.max(np.abs(np.atleast_1d(x[-1]))))
        r = dict(sr=sr, seconds=round(len(x) / sr, 3), channels=1 if x.ndim == 1 else x.shape[1],
                 peak_dbfs=round(pk_db, 2), first_sample=round(first, 5), last_sample=round(last, 5),
                 kbytes=round(os.path.getsize(p) / 1024, 1))
        m = np.abs(mono(x))
        r["onset_ms"] = round(float(np.argmax(m >= 0.1 * peak)) / sr * 1000, 2)
        r["hf_click"] = round(hf_click_score(x, sr), 1)
        r["rise_ms"] = round(rise_ms(x, sr), 1)
        r["phone_loss_db"] = round(phone_loss_db(x, sr), 1)
        r["attack_ms"] = round(attack_ms(x, sr), 1)
        if rel.startswith(("voice/", "fx/", "steps/", "ui/")):
            r["flatness"] = round(flatness(x, sr), 3)
        if is_loop:
            r["seam_ratio"] = round(seam(x), 2)
            r["seam_hf"] = round(seam_hf(x, sr), 2)
            r["seam_hf_dbfs"] = round(seam_hf_abs(x, sr), 1)
            if r["seam_hf"] > 2.0 and r["seam_hf_dbfs"] > -60:
                problems.append(f"{rel}: high-frequency burst at the loop seam ({r['seam_hf']})")
            if r["seam_ratio"] > 3.0:
                problems.append(f"{rel}: loop seam jump {r['seam_ratio']}x a typical step")
        else:
            if first > 0.003 or last > 0.003:
                problems.append(f"{rel}: starts/ends away from zero ({first:.4f}, {last:.4f})")
        if pk_db > -1.0:
            problems.append(f"{rel}: peak {pk_db:.2f} dBFS > -1")
        if sr != 44100:
            problems.append(f"{rel}: sample rate {sr}")
        rows[rel] = r
    # bell sets
    bells = {}
    for s in ("light", "village", "full"):
        cs, ds = [], []
        by = {}
        for rel, r in rows.items():
            m = re.match(rf"bells/{s}_(up|down)_(\w+)_(\d)\.wav", rel)
            if not m:
                continue
            x, sr = sf.read(os.path.join(OUT, rel))
            c = centroid(x, sr)
            d = decay_t60(x, sr)
            r["centroid_hz"] = round(c, 1)
            r["t60_s"] = round(d, 3) if d else None
            r["edt_s"] = round(edt(x, sr), 3)
            key = f"{m.group(1)}_{m.group(2)}"
            y3 = np.atleast_2d(x[: int(0.3 * sr)].T).T  # (n, ch): power summed over channels
            by.setdefault(key, []).append((c, d, r["peak_dbfs"], 10 * np.log10(np.mean(np.sum(y3 ** 2, axis=1))), r["edt_s"]))
        summ = {}
        for key, v in sorted(by.items()):
            summ[key] = dict(centroid_hz=round(float(np.mean([a[0] for a in v])), 1),
                             t60_s=round(float(np.mean([a[1] for a in v if a[1]])), 3),
                             peak_dbfs=round(float(np.max([a[2] for a in v])), 2),
                             rms300_dbfs=round(float(np.mean([a[3] for a in v])), 2),
                             edt_s=round(float(np.mean([a[4] for a in v])), 3))
        perf = [summ[k] for k in ("up_perfect", "down_perfect") if k in summ]
        if perf:
            summ["perfect_mean"] = dict(centroid_hz=round(float(np.mean([p["centroid_hz"] for p in perf])), 1),
                                        t60_s=round(float(np.mean([p["t60_s"] for p in perf])), 3))
        bells[s] = summ
    diffs = {}
    order = ["light", "village", "full"]
    for a, b in zip(order, order[1:]):
        if "perfect_mean" in bells.get(a, {}) and "perfect_mean" in bells.get(b, {}):
            pa, pb = bells[a]["perfect_mean"], bells[b]["perfect_mean"]
            dc = (pa["centroid_hz"] - pb["centroid_hz"]) / pa["centroid_hz"] * 100
            dt = (pb["t60_s"] - pa["t60_s"]) / pa["t60_s"] * 100
            diffs[f"{a}->{b}"] = dict(centroid_drop_pct=round(dc, 1), decay_rise_pct=round(dt, 1))
            if dc < 15 or dt < 15:
                problems.append(f"bell sets {a}->{b} differ too little: centroid {dc:.1f}%, decay {dt:.1f}%")
    for s in order:
        if "up_perfect" in bells.get(s, {}):
            u, d = bells[s]["up_perfect"], bells[s]["down_perfect"]
            diffs[f"{s} up vs down"] = dict(centroid_pct=round((u["centroid_hz"] - d["centroid_hz"]) / d["centroid_hz"] * 100, 1),
                                            rms_db=round(u["rms300_dbfs"] - d["rms300_dbfs"], 2))
    for rel, r in rows.items():
        if not rel.startswith(("loops", "ambience")) and r["channels"] >= 1:
            pass
    # step tones: measured pitch against the lane's note in each key
    from steps import base_midi, LANE_INTERVALS, mtof
    worst = 0.0
    for lane in range(3):
        for pc in range(12):
            rel = f"steps/tone_{lane}_{pc:02d}.wav"
            if rel not in rows:
                continue  # odd keys are the tone below at pitch_scale 2^(1/12): exact
            x, sr = sf.read(os.path.join(OUT, rel))
            want = mtof(base_midi(pc) + LANE_INTERVALS[lane])
            # instantaneous frequency of the fundamental (band-passed +-1 semitone),
            # median over 30-200 ms; reflections of the same partial don't bias it
            sos = signal.butter(2, [want * 2 ** (-1 / 12), want * 2 ** (1 / 12)], "bandpass", fs=sr, output="sos")
            band = signal.sosfiltfilt(sos, x)
            ph = np.unwrap(np.angle(signal.hilbert(band)))
            inst = np.diff(ph) * sr / (2 * np.pi)
            f = float(np.median(inst[int(0.03 * sr):int(0.2 * sr)]))
            e1 = np.sum(band ** 2)
            sos2 = signal.butter(2, [2 * want * 2 ** (-1 / 12), 2 * want * 2 ** (1 / 12)], "bandpass", fs=sr, output="sos")
            e2 = np.sum(signal.sosfiltfilt(sos2, x) ** 2)
            rows[rel]["fundamental_over_2nd_db"] = round(float(10 * np.log10(e1 / (e2 + 1e-20))), 1)
            cents = 1200 * np.log2(f / want)
            rows[rel]["pitch_hz"] = round(float(f), 2)
            rows[rel]["pitch_error_cents"] = round(float(cents), 2)
            worst = max(worst, abs(cents))
    if worst > 5:
        problems.append(f"step tone pitch off by {worst:.1f} cents")
    tone_pitch_worst_cents = round(float(worst), 2)
    total = sum(os.path.getsize(p) for p in glob.glob(os.path.join(OUT, "**", "*"), recursive=True) if os.path.isfile(p))
    groups = {}
    for rel, r in rows.items():
        m = re.match(r"(bells/row_(tight|loose)|voice/call|fx/rope|fx/count|steps/tone|steps/foot|bells/\w+_miss|bells/\w+_perfect|bells/\w+_early|bells/\w+_late|bells/\w+_accent|bells/\w+_jangle|ui/\w+?_|ambience/\w+)", rel)
        if m:
            groups.setdefault(m.group(1), []).append(r)
    summary = {}
    for g, v in groups.items():
        summary[g] = dict(rise_ms=round(float(np.mean([r["rise_ms"] for r in v])), 1),
                          phone_loss_db_worst=round(float(np.min([r["phone_loss_db"] for r in v])), 1),
                          attack_ms_worst=round(float(np.max([r["attack_ms"] for r in v])), 1),
                          seconds=round(float(np.mean([r["seconds"] for r in v])), 2))
        if "flatness" in v[0]:
            summary[g]["flatness"] = round(float(np.mean([r["flatness"] for r in v])), 3)
    report = dict(total_mbytes=round(total / 1e6, 2), files=len(rows), problems=problems,
                  groups=summary,
                  tone_pitch_worst_cents=tone_pitch_worst_cents,
                  bell_sets=bells, bell_set_differences=diffs, per_file=rows)
    with open(os.path.join(ROOT, "tools", "audio", "sfx", "measurements.json"), "w") as f:
        json.dump(report, f, indent=1)
    print(json.dumps({k: report[k] for k in ("total_mbytes", "files", "problems", "tone_pitch_worst_cents", "groups", "bell_set_differences")}, indent=1))
    for s in order:
        for k, v in bells.get(s, {}).items():
            print(s, k, v)


if __name__ == "__main__":
    main()
