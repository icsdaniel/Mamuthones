"""The hold's rope and its knot, drawn pixel by pixel (the cuts from Daniele's controls sheet were too
small: the knot was blown up past the art grid, and the rope's segment left a seam where it repeated):

    python3 tools/art/chatgpt/hemp.py

rope.webp: a seamless vertical tile of twisted hemp, 16 x 32 art px (it repeats down the hold; the
    twist's period divides the tile, so the repeat never shows);
knot.webp: the knot at the rope's far end, a round fist of hemp turns, 36 x 30 art px (about its size
    at the hit line, so it is only ever shrunk).
Colours from the style palette (common.py); saved 4x with nearest like the other cuts.
"""
import os
import numpy as np
import common as c

AI = os.path.join(c.GAME, "art/ai")
HEMP = ["#24160f", "#4a2c0e", "#8a5a1c", "#c89030", "#ecc055", "#fff0a0"]


def col(i):
    return np.array(c._rgb(HEMP[int(np.clip(i, 0, len(HEMP) - 1))]), np.uint8)


def rope(w=16, h=32, period=8):
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            if x == 0 or x == w - 1:
                out[y, x] = [*col(0), 255]
                continue
            u = (x - 0.5) / (w - 1) * 2.0 - 1.0          # -1 .. 1 across
            body = 1.0 - u * u                              # round
            light = 1.0 + 2.6 * body - 0.9 * u            # lit from the left
            # the strands: slanting turns, one every `period` rows, wrapping round the cord
            ph = (y + x * 0.75) % period
            if ph < 1.0:
                tone = light - 2.2                          # the groove between two strands
            elif ph < 2.0:
                tone = light + 0.8                          # the lit lip of the next
            else:
                tone = light - 0.25 * (ph - 2.0) / (period - 2.0) * 2.0
            out[y, x] = [*col(round(tone)), 255]
    return out


def knot(w=36, h=30):
    out = np.zeros((h, w, 4), np.uint8)
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0 + 0.5
    rx, ry = w / 2.0 - 1.0, h / 2.0 - 1.0
    for y in range(h):
        for x in range(w):
            u, v = (x - cx) / rx, (y - cy) / ry
            d = u * u + v * v
            if d > 1.0:
                continue
            z = np.sqrt(max(0.0, 1.0 - d))
            light = 0.6 + 3.6 * z * (0.7 - 0.35 * u - 0.5 * v)
            # three sets of turns: round the middle (across), and up over each side (along)
            if abs(u) < 0.42:
                ph = (y + 0.3 * x) % 5
            else:
                ph = (x * (1 if u > 0 else -1) + 0.35 * y) % 5
            if ph < 1.0:
                tone = light - 2.0
            elif ph < 2.0:
                tone = light + 0.7
            else:
                tone = light
            # the seams where the sets meet
            if abs(abs(u) - 0.42) < 0.06:
                tone = min(tone, light - 1.6)
            out[y, x] = [*col(round(tone)), 255]
    # a one px dark outline
    a = out[..., 3] > 0
    edge = a & ~(np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1))
    out[edge, :3] = col(0)
    return out


if __name__ == "__main__":
    c.save(rope(), os.path.join(AI, "rope.webp"), 4)
    c.save(knot(), os.path.join(AI, "knot.webp"), 4)
