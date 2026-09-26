#!/usr/bin/env python3
"""Generate placeholder audio for the Godot game.

Real music and bell recordings will replace these. Until then this writes:
  - one backing track per song in game/data/songs.json (count-in, drum on each
    bar, clicks on the other beats), timed to match the song's chart;
  - short sound effects (steps, bells, the Issohadore call, the rope whoosh,
    and a looping drone for held notes).

Run from the repo root:  python3 tools/make_placeholder_audio.py
"""
import json
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "game")
LEAD_IN = 0.2  # seconds of silence before the first count-in click


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000))
        w.writeframes(bytes(frames))


def env(i, attack, decay):
    t = i / RATE
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def click(freq, vol, length=0.05):
    n = int(RATE * length)
    return [vol * math.sin(2 * math.pi * freq * i / RATE) * env(i, 0.002, 0.012) for i in range(n)]


def drum(vol=0.8, length=0.35):
    n, out, phase = int(RATE * length), [], 0.0
    for i in range(n):
        t = i / RATE
        f = 48 + (120 - 48) * math.exp(-t / 0.06)
        phase += 2 * math.pi * f / RATE
        out.append(vol * math.sin(phase) * env(i, 0.004, 0.09))
    return out


def mix(buf, sound, at):
    start = int(at * RATE)
    for k, s in enumerate(sound):
        if start + k < len(buf):
            buf[start + k] += s


def backing(bpm, bars):
    spb = 60.0 / bpm
    beats = bars * 4
    total = LEAD_IN + (4 + beats + 4) * spb
    buf = [0.0] * int(total * RATE)
    for i in range(4):
        mix(buf, click(1320 if i == 0 else 880, 0.5), LEAD_IN + i * spb)
    start = LEAD_IN + 4 * spb
    for i in range(beats):
        t = start + i * spb
        mix(buf, drum() if i % 4 == 0 else click(660, 0.2), t)
    return buf, start


def noise_hit(center, q_len=0.08, vol=0.7):
    # Filtered-noise knock, approximated with a resonant two-pole filter.
    n = int(RATE * q_len)
    r = 0.97
    w0 = 2 * math.pi * center / RATE
    a1, a2 = -2 * r * math.cos(w0), r * r
    y1 = y2 = 0.0
    out = []
    rnd = random.Random(int(center))
    for i in range(n):
        x = (rnd.random() * 2 - 1) * (1 - i / n) ** 3
        y = x - a1 * y1 - a2 * y2
        y2, y1 = y1, y
        out.append(vol * 0.12 * y)
    return out


def bell(scale):
    n = int(RATE * 0.9)
    freqs = [540 * scale, 812 * scale, 1180 * scale, 1630 * scale]
    out = []
    for i in range(n):
        s = sum(1 if math.sin(2 * math.pi * f * i / RATE) > 0 else -1 for f in freqs) / len(freqs)
        out.append(0.35 * s * env(i, 0.004, 0.25))
    return out


def call():
    n, out, phase = int(RATE * 0.2), [], 0.0
    for i in range(n):
        t = i / RATE
        f = 260 * (420 / 260) ** min(1.0, t / 0.12)
        phase += f / RATE
        saw = 2 * (phase % 1.0) - 1
        out.append(0.3 * saw * env(i, 0.01, 0.06))
    return out


def whoosh():
    n, out = int(RATE * 0.3), []
    rnd = random.Random(7)
    y = 0.0
    for i in range(n):
        x = rnd.random() * 2 - 1
        a = 0.2 + 0.7 * (i / n)  # brighter as it sweeps
        y = y + a * (x - y)
        out.append(0.6 * y * math.sin(math.pi * i / n))
    return out


def drone_loop(freq):
    # Exactly one second, a whole number of cycles for every partial, so it loops cleanly.
    n, out = RATE, []
    partials = [(round(freq), 1.0), (round(freq * 1.5), 0.4), (round(freq * 2), 0.25)]
    for i in range(n):
        s = 0.0
        for f, a in partials:
            ph = (f * i / RATE) % 1.0
            s += a * (2 * ph - 1)
        out.append(0.12 * s)
    return out


def main():
    audio = os.path.join(ROOT, "audio")
    os.makedirs(audio, exist_ok=True)
    with open(os.path.join(ROOT, "data", "songs.json")) as f:
        songs = json.load(f)["songs"]
    for song in songs:
        buf, start = backing(song["bpm"], len(song["chart"]))
        write_wav(os.path.join(audio, song["id"] + ".wav"), buf)
        print(f"{song['id']}: first chart beat at {start:.4f} s (songs.json first_beat = {song['first_beat']})")
        assert abs(start - song["first_beat"]) < 1e-3, "update first_beat in songs.json"
    for lane, f in (("left", 650), ("middle", 1000), ("right", 1500)):
        write_wav(os.path.join(audio, f"step_{lane}.wav"), noise_hit(f))
    write_wav(os.path.join(audio, "bell_up.wav"), bell(1.0))
    write_wav(os.path.join(audio, "bell_down.wav"), bell(0.75))
    write_wav(os.path.join(audio, "call.wav"), call())
    write_wav(os.path.join(audio, "whoosh.wav"), whoosh())
    for lane, f in (("left", 147), ("middle", 196), ("right", 262)):
        write_wav(os.path.join(audio, f"drone_{lane}.wav"), drone_loop(f))


if __name__ == "__main__":
    main()
