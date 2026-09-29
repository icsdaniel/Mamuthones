"""Pixel type for the play screen: hand-drawn bitmap fonts written as BMFont (.fnt + .png) that Godot
imports as fonts, so Labels and draw_string() set them like any font:

    python3 tools/art/pixel/type.py         # writes game/art/px/field/font_*.fnt / .png

  caps        5 x 7 capitals, with the lower case drawn as 5-px small capitals (so "Perfect" sets as
              a tall P and small ERFECT), digits, the punctuation and accents the game's strings use.
  big         the same letters doubled with Scale2x (EPX), so diagonals and curves stay smooth and
              every stem is two art pixels: judgement words, the count-in.
  score       the score's figures, 7 x 10 with two-pixel stems.
  count       the score's figures doubled twice (Scale2x), 40 px tall: the count-in.

Each glyph carries a one-pixel K0 outline (and the big and score faces a K0 drop shadow a pixel
below), so text holds up over the fire. "tint" faces are white inside the outline (a Label's font
colour tints them); the "_gold" and score faces bake a cream-to-gold ramp from top to bottom (use
them with a white font colour). The game sets them at a whole multiple of their size (PxType).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from palette import P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/field")

# ------------------------------------------------------------------------------------------ glyphs
# Capitals and figures: 7 rows. Small capitals (the lower case): 5 rows. '#' ink, '.' paper.

CAPS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "..##.", ".#...", "#....", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
}

SMALL = {
    "a": [".##.", "#..#", "####", "#..#", "#..#"],
    "b": ["###.", "#..#", "###.", "#..#", "###."],
    "c": [".###", "#...", "#...", "#...", ".###"],
    "d": ["###.", "#..#", "#..#", "#..#", "###."],
    "e": ["####", "#...", "###.", "#...", "####"],
    "f": ["####", "#...", "###.", "#...", "#..."],
    "g": [".###", "#...", "#.##", "#..#", ".###"],
    "h": ["#..#", "#..#", "####", "#..#", "#..#"],
    "i": ["###", ".#.", ".#.", ".#.", "###"],
    "j": ["..##", "...#", "...#", "#..#", ".##."],
    "k": ["#..#", "#.#.", "##..", "#.#.", "#..#"],
    "l": ["#...", "#...", "#...", "#...", "####"],
    "m": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
    "n": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "o": [".##.", "#..#", "#..#", "#..#", ".##."],
    "p": ["###.", "#..#", "###.", "#...", "#..."],
    "q": [".##.", "#..#", "#..#", "#.#.", ".#.#"],
    "r": ["###.", "#..#", "###.", "#.#.", "#..#"],
    "s": [".###", "#...", ".##.", "...#", "###."],
    "t": ["###", ".#.", ".#.", ".#.", ".#."],
    "u": ["#..#", "#..#", "#..#", "#..#", ".##."],
    "v": ["#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
    "w": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
    "x": ["#..#", "#..#", ".##.", "#..#", "#..#"],
    "y": ["#...#", ".#.#.", "..#..", "..#..", "..#.."],
    "z": ["####", "..#.", ".#..", "#...", "####"],
}

# Punctuation: (rows, top row in the 7-row cap band; may run to row 8 for descenders)
PUNCT = {
    "!": (["#", "#", "#", "#", "#", ".", "#"], 0),
    "%": (["##..#", "##.#.", "..#..", ".#...", "#..##", "...##"], 1),
    "'": (["#", "#"], 0),
    "’": (["#", "#"], 0),
    "(": ([".#", "#.", "#.", "#.", "#.", "#.", ".#"], 0),
    ")": (["#.", ".#", ".#", ".#", ".#", ".#", "#."], 0),
    "+": ([".#.", "###", ".#."], 2),
    ",": ([".#", ".#", "#."], 5),
    "-": (["###"], 3),
    "−": (["####"], 3),
    ".": (["#"], 6),
    "/": (["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."], 0),
    ":": (["#", ".", ".", "#"], 2),
    ";": ([".#", "..", "..", ".#", "#."], 2),
    "?": ([".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."], 0),
    "«": (["..#.#", ".#.#.", "#.#..", ".#.#.", "..#.#"], 1),
    "»": (["#.#..", ".#.#.", "..#.#", ".#.#.", "#.#.."], 1),
    "·": (["#"], 3),
    "×": (["#.#", ".#.", "#.#"], 3),
    "…": (["#.#.#"], 6),
}

# Accented letters: base glyph + accent pixels above it (grave leans left-high, acute right-high).
ACCENTS = {"à": ("a", "grave"), "á": ("a", "acute"), "è": ("e", "grave"), "é": ("e", "acute"),
           "ì": ("i", "grave"), "ù": ("u", "grave"), "È": ("E", "grave"),
           "ò": ("o", "grave"), "í": ("i", "acute"), "ó": ("o", "acute"), "ú": ("u", "acute")}

SPACE = 3


def mask(rows):
    return np.array([[c == "#" for c in r] for r in rows], bool)


def caps_cells():
    """Every glyph of the caps face on a 10-row cell: rows 0-1 accents, 2-8 capitals (baseline under
    row 8), small capitals 4-8, row 9 descenders. Returns {char: mask}."""
    cells = {}

    def put(rows, top):
        m = mask(rows)
        c = np.zeros((10, m.shape[1]), bool)
        c[top:top + m.shape[0]] = m
        return c

    for ch, rows in CAPS.items():
        cells[ch] = put(rows, 2)
    for ch, rows in SMALL.items():
        cells[ch] = put(rows, 4)
    for ch, (rows, top) in PUNCT.items():
        cells[ch] = put(rows, 2 + top)
    for ch, (base, kind) in ACCENTS.items():
        c = cells[base].copy()
        w = c.shape[1]
        top = 2 if base.islower() else 0
        mid = w // 2
        if kind == "grave":
            pts = [(top, mid - 1), (top + 1, mid)]
        else:
            pts = [(top, mid + 1), (top + 1, mid)]
        if base.isupper():
            # no room above a capital: a one-pixel accent, the cap's top row kept
            pts = [(1, mid + (-1 if kind == "grave" else 1))]
        for (y, x) in pts:
            if 0 <= x < w:
                c[y, x] = True
        cells[ch] = c
    return cells


def scale2x(m):
    """EPX / Scale2x on a boolean mask: doubles it, rounding the steps of diagonals."""
    h, w = m.shape
    pad = np.zeros((h + 2, w + 2), bool)
    pad[1:-1, 1:-1] = m
    out = np.zeros((h * 2, w * 2), bool)
    for y in range(h):
        for x in range(w):
            p = pad[y + 1, x + 1]
            A, B, C, D = pad[y, x + 1], pad[y + 1, x + 2], pad[y + 1, x], pad[y + 2, x + 1]
            e0 = e1 = e2 = e3 = p
            if C == A and C != D and A != B:
                e0 = A
            if A == B and A != C and B != D:
                e1 = B
            if D == C and D != B and C != A:
                e2 = C
            if B == D and B != A and D != C:
                e3 = D
            out[2 * y, 2 * x] = e0
            out[2 * y, 2 * x + 1] = e1
            out[2 * y + 1, 2 * x] = e2
            out[2 * y + 1, 2 * x + 1] = e3
    return out


SCORE = {
    "0": ["..###..", ".##.##.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".##.##.", "..###.."],
    "1": ["...##..", "..###..", ".####..", "...##..", "...##..", "...##..", "...##..", "...##..", "...##..", ".######"],
    "2": [".#####.", "##...##", ".....##", ".....##", "....##.", "..###..", ".##....", "##.....", "##.....", "#######"],
    "3": [".#####.", "##...##", ".....##", ".....##", "..####.", ".....##", ".....##", ".....##", "##...##", ".#####."],
    "4": ["....##.", "...###.", "..####.", ".##.##.", "##..##.", "##..##.", "#######", "....##.", "....##.", "....##."],
    "5": ["#######", "##.....", "##.....", "######.", ".....##", ".....##", ".....##", ".....##", "##...##", ".#####."],
    "6": ["..####.", ".##....", "##.....", "##.....", "######.", "##...##", "##...##", "##...##", "##...##", ".#####."],
    "7": ["#######", ".....##", ".....##", "....##.", "....##.", "...##..", "...##..", "..##...", "..##...", "..##..."],
    "8": [".#####.", "##...##", "##...##", "##...##", ".#####.", "##...##", "##...##", "##...##", "##...##", ".#####."],
    "9": [".#####.", "##...##", "##...##", "##...##", "##...##", ".######", ".....##", ".....##", "....##.", ".####.."],
}
SCORE_PUNCT = {
    ",": (["##", "##", ".#", "#."], 8),
    ".": (["##", "##"], 8),
    "+": (["..##..", "..##..", "######", "######", "..##..", "..##.."], 2),
    "-": (["######", "######"], 4),
    "−": (["######", "######"], 4),
    "×": (["##..##", ".####.", "..##..", ".####.", "##..##"], 3),
    "x": (["##..##", ".####.", "..##..", ".####.", "##..##"], 3),
}


def score_cells():
    cells = {}
    for ch, rows in SCORE.items():
        c = np.zeros((12, 7), bool)
        c[0:10] = mask(rows)
        cells[ch] = c
    for ch, (rows, top) in SCORE_PUNCT.items():
        m = mask(rows)
        c = np.zeros((12, m.shape[1]), bool)
        c[top:top + m.shape[0]] = m
        cells[ch] = c
    return cells


# ------------------------------------------------------------------------------------------ faces

def rgba(name):
    c = P[name]
    return (int(c[0]), int(c[1]), int(c[2]), 255)


def dilate(m):
    out = m.copy()
    out[1:, :] |= m[:-1, :]
    out[:-1, :] |= m[1:, :]
    out[:, 1:] |= m[:, :-1]
    out[:, :-1] |= m[:, 1:]
    return out


def render(cell, ramp, band, shadow):
    """A glyph image: the cell padded by 1 (2 below with a shadow), K0 outline, the ink filled white
    (ramp None) or with `ramp` spread over rows band[0]..band[1] of the cell."""
    h, w = cell.shape
    ph = h + 2 + (1 if shadow else 0)
    m = np.zeros((ph, w + 2), bool)
    m[1:1 + h, 1:1 + w] = cell
    ol = dilate(m)
    if shadow:
        sh = np.zeros_like(ol)
        sh[1:, :] = ol[:-1, :]
        ol |= sh
    img = np.zeros((ph, w + 2, 4), np.uint8)
    img[ol & ~m] = rgba("K0")
    if ramp is None:
        img[m] = (255, 255, 255, 255)
    else:
        y0, y1 = band
        for y in range(ph):
            k = min(max((y - 1 - y0) / max(1, (y1 - y0)), 0.0), 0.999)
            col = rgba(ramp[int(k * len(ramp))])
            img[y][m[y]] = col
    return img


def write_font(name, cells, size, base, line_h, ramp=None, band=(0, 1), shadow=False, space=SPACE, gap=1):
    imgs = {ch: render(c, ramp, band, shadow) for ch, c in cells.items()}
    # pack in rows 256 wide
    W = 256
    x = y = 0
    row_h = 0
    places = {}
    for ch in sorted(imgs, key=ord):
        im = imgs[ch]
        h, w = im.shape[:2]
        if x + w > W:
            x = 0
            y += row_h + 1
            row_h = 0
        places[ch] = (x, y)
        x += w + 1
        row_h = max(row_h, h)
    H = y + row_h
    H2 = 1
    while H2 < H:
        H2 *= 2
    sheet = np.zeros((H2, W, 4), np.uint8)
    for ch, (px_, py_) in places.items():
        im = imgs[ch]
        sheet[py_:py_ + im.shape[0], px_:px_ + im.shape[1]] = im
    from PIL import Image
    Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, name + ".png"))
    lines = [f'info face="{name}" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
             f"common lineHeight={line_h} base={base} scaleW={W} scaleH={H2} pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0",
             f'page id=0 file="{name}.png"',
             f"chars count={len(imgs) + 1}",
             f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={space} page=0 chnl=15"]
    for ch in sorted(imgs, key=ord):
        im = imgs[ch]
        h, w = im.shape[:2]
        px_, py_ = places[ch]
        adv = cells[ch].shape[1] + gap
        lines.append(f"char id={ord(ch)} x={px_} y={py_} width={w} height={h} xoffset=-1 yoffset=-1 xadvance={adv} page=0 chnl=15")
    with open(os.path.join(OUT, name + ".fnt"), "w") as f:
        f.write("\n".join(lines) + "\n")


GOLD_RAMP = ["BONE4", "GOLD5", "GOLD5", "GOLD4", "GOLD4", "GOLD3"]
SCORE_RAMP = ["BONE4", "BONE4", "BONE3", "GOLD5", "GOLD5", "GOLD4", "GOLD4", "GOLD3"]


def main():
    os.makedirs(OUT, exist_ok=True)
    caps = caps_cells()
    write_font("font_caps", caps, 10, 9, 12)
    write_font("font_caps_gold", caps, 10, 9, 12, GOLD_RAMP, (2, 8))
    big = {ch: scale2x(c) for ch, c in caps.items()}
    write_font("font_big", big, 20, 18, 22, None, (4, 17), True, space=6, gap=2)
    write_font("font_big_gold", big, 20, 18, 22, GOLD_RAMP, (4, 17), True, space=6, gap=2)
    sc = score_cells()
    write_font("font_score", sc, 12, 10, 13, SCORE_RAMP, (0, 9), True, space=4, gap=1)
    # the count-in's figures: the score's, doubled twice with Scale2x (4-px stems, smooth curves)
    count = {d: scale2x(scale2x(sc[d])) for d in "0123456789"}
    write_font("font_count", count, 48, 40, 50, SCORE_RAMP, (0, 39), True, space=12, gap=4)
    print("wrote fonts to", OUT)


if __name__ == "__main__":
    main()
